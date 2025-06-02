function [demapperInputSymbolsMatrix, channelEstimatesForDataSymbols] = performFreqDomainProcessing(ofdmSymbolsWithoutCP_matrix, symbolTypeSequence, pilotSequenceZC_freq_active_sc, active_indices_human_order, N_fft, N_sc_active, noiseTermForMMSE, estimationAndEqEnabled)
% performFreqDomainProcessing - 执行FFT、信道估计和频域均衡
%
% 输入参数:
%   ofdmSymbolsWithoutCP_matrix  - N_fft x N_totalSymbols 矩阵, 每列是一个去除CP的OFDM时域符号
%   symbolTypeSequence           - 1 x N_totalSymbols 字符串数组/元胞数组, 标记 "Pilot" 或 "Data"
%   pilotSequenceZC_freq_active_sc - 1 x N_sc_active (或 N_sc_active x 1) 已知的导频频域序列 (ZC序列)
%   active_indices_human_order   - 1 x N_sc_active (或 N_sc_active x 1) 向量, 激活子载波在fftshift后频谱中的索引
%   N_fft                        - FFT点数
%   N_sc_active                  - 激活子载波数 (即导频或数据实际占用的子载波数)
%   noiseTermForMMSE             - 用于MMSE均衡的噪声项 (P_Noise_per_SC / P_Signal_per_SC_tx)
%   estimationAndEqEnabled       - 逻辑值 (true/false), 控制是否执行信道估计和均衡
%
% 输出:
%   demapperInputSymbolsMatrix       - N_sc_active x numDataSymbolsOut 矩阵, 均衡后(或未均衡)的数据符号
%   channelEstimatesForDataSymbols - N_sc_active x numDataSymbolsOut 矩阵, 用于均衡每个数据符号的信道估计

% --- 0. 输入参数校验和准备 ---
validateattributes(ofdmSymbolsWithoutCP_matrix, {'numeric'}, {'2d', 'ncols', numel(symbolTypeSequence)}, mfilename, 'ofdmSymbolsWithoutCP_matrix');
validateattributes(symbolTypeSequence, {'string', 'cell'}, {'row', 'numel', size(ofdmSymbolsWithoutCP_matrix,2)}, mfilename, 'symbolTypeSequence');
validateattributes(pilotSequenceZC_freq_active_sc, {'numeric'}, {'vector', 'numel', N_sc_active}, mfilename, 'pilotSequenceZC_freq_active_sc');
validateattributes(active_indices_human_order, {'numeric'}, {'vector', 'numel', N_sc_active, 'positive', 'integer', '<=', N_fft}, mfilename, 'active_indices_human_order');
validateattributes(N_fft, {'numeric'}, {'scalar', 'positive', 'integer'}, mfilename, 'N_fft');
validateattributes(N_sc_active, {'numeric'}, {'scalar', 'positive', 'integer', '<=', N_fft}, mfilename, 'N_sc_active');
validateattributes(noiseTermForMMSE, {'numeric'}, {'scalar', 'real', 'nonnegative'}, mfilename, 'noiseTermForMMSE');
validateattributes(estimationAndEqEnabled, {'logical'}, {'scalar'}, mfilename, 'estimationAndEqEnabled');

% 确保 pilotSequenceZC_freq_active_sc 和 Y_active_sc (后续提取) 都是列向量，便于点除/点乘
pilotSequenceZC_freq_active_sc = pilotSequenceZC_freq_active_sc(:); 
active_indices_human_order = active_indices_human_order(:); % 通常索引是行向量，但转成列在这里影响不大，主要是后续提取后Y_active_sc的形状

N_totalSymbols = size(ofdmSymbolsWithoutCP_matrix, 2);

% --- 1. 初始化 ---
numDataSymbolsOut = sum(strcmpi(symbolTypeSequence, "Data")); % 使用strcmpi忽略大小写
if numDataSymbolsOut == 0 && N_totalSymbols > 0 && any(strcmpi(symbolTypeSequence, "Pilot"))
    % 如果只有导频符号，没有数据符号，则后续解映射输入为空
    fprintf('提示: 输入的符号序列中没有数据符号。\n');
end

demapperInputSymbolsMatrix = complex(zeros(N_sc_active, numDataSymbolsOut));
channelEstimatesForDataSymbols = complex(zeros(N_sc_active, numDataSymbolsOut)); % 可以用NaN初始化，如果未估计

H_latest_pilot_estimate = ones(N_sc_active, 1); % 初始化信道估计 (例如全1，或NaN)
% 如果第一个符号就是数据且需要估计，这个初始化值会被覆盖，但通常第一个是导频
if estimationAndEqEnabled == false
    H_latest_pilot_estimate = ones(N_sc_active,1); % 若不均衡，H可以认为是理想的1
end

dataSymbolOutputColCounter = 0; % 用于填充输出矩阵的列索引

if estimationAndEqEnabled
    modeStr = '估计与均衡已启用';
else
    modeStr = '估计与均衡未启用';
end
fprintf('开始FFT、信道估计与均衡处理... 模式: %s\n', modeStr);

% --- 2. 逐个OFDM符号处理 ---
for i_sym = 1:N_totalSymbols
    current_td_symbol = ofdmSymbolsWithoutCP_matrix(:, i_sym);
    
    % b. 进行FFT
    Y_fft_eng_order = fft(current_td_symbol, N_fft);
    
    % c. 将FFT输出转换为“DC中心对齐”的顺序
    Y_fft_centered = fftshift(Y_fft_eng_order);
    
    % d. 根据 active_indices_human_order 提取 N_sc_active 个激活子载波上的接收值
    Y_active_sc = Y_fft_centered(active_indices_human_order);
    Y_active_sc = Y_active_sc(:); % 确保是列向量

    % e. 处理导频符号
    if strcmpi(symbolTypeSequence(i_sym), "Pilot")
        if estimationAndEqEnabled == true
            % 进行LS信道估计
            H_current_pilot_est = Y_active_sc ./ pilotSequenceZC_freq_active_sc; % LS估计
            H_latest_pilot_estimate = H_current_pilot_est; % 更新最近的信道估计
            % fprintf('符号 %d (导频): 已更新信道估计。\n', i_sym);
        end
        % 导频符号本身不作为数据输出到解映射器
        
    % f. 处理数据符号
    elseif strcmpi(symbolTypeSequence(i_sym), "Data")
        dataSymbolOutputColCounter = dataSymbolOutputColCounter + 1;
        
        if estimationAndEqEnabled == true
            % **启用信道估计和均衡**
            if isempty(H_latest_pilot_estimate) || all(isnan(H_latest_pilot_estimate(:))) % 确保H_latest_pilot_estimate已被有效初始化/更新
                error('信道估计缺失或无效 (例如全NaN)，无法对数据符号 %d 进行均衡。确保有导频先于数据，或正确初始化H_latest_pilot_estimate。', i_sym);
            end
            H_to_use = H_latest_pilot_estimate; % 使用最近导频的估计结果

            % --- MMSE 均衡 ---
            conj_H = conj(H_to_use);
            abs_H_sq = abs(H_to_use).^2;
            
            mmse_denominator = abs_H_sq + noiseTermForMMSE;
            % 防止分母过小导致数值问题 (例如，信道为0且噪声也极小)
            mmse_denominator(mmse_denominator < 1e-9) = 1e-9; % 用一个很小的值替换，避免Inf/NaN
                                                              % eps 对于某些数值范围可能太小
            
            mmse_weights = conj_H ./ mmse_denominator;
            output_symbols_for_demapper = mmse_weights .* Y_active_sc;
            % -----------------
            
            demapperInputSymbolsMatrix(:, dataSymbolOutputColCounter) = output_symbols_for_demapper;
            if nargout > 1 % 如果调用者请求了第二个输出参数
                channelEstimatesForDataSymbols(:, dataSymbolOutputColCounter) = H_to_use;
            end
        else
            % **未启用信道估计和均衡**
            % 直接将未均衡的接收符号送给解映射器
            demapperInputSymbolsMatrix(:, dataSymbolOutputColCounter) = Y_active_sc;
            if nargout > 1
                channelEstimatesForDataSymbols(:, dataSymbolOutputColCounter) = ones(N_sc_active, 1); % 标记为理想信道（或NaN）
            end
        end
    else
        warning('符号 %d 的类型既不是 "Pilot" 也不是 "Data"。已跳过。', i_sym);
    end
end

% 如果实际处理的数据符号数与预期不符（例如symbolTypeSequence有问题），调整输出矩阵大小
if dataSymbolOutputColCounter < numDataSymbolsOut
    warning('实际处理的数据符号数 (%d) 小于预期 (%d)。输出矩阵将被截断。', dataSymbolOutputColCounter, numDataSymbolsOut);
    demapperInputSymbolsMatrix = demapperInputSymbolsMatrix(:, 1:dataSymbolOutputColCounter);
    if nargout > 1
        channelEstimatesForDataSymbols = channelEstimatesForDataSymbols(:, 1:dataSymbolOutputColCounter);
    end
end

fprintf('FFT、信道估计与均衡处理完成。共处理 %d 个数据符号。\n', dataSymbolOutputColCounter);

end