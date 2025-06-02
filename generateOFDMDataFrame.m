function [timeDomainFrame,qpskMappedFordata, sourceInfoBits,pilotSequence, meta] = generateOFDMDataFrame(N_sc, cpMode, codingEnabled,leaverEn)
% generateOFDMDataFrame - 生成包含导频和数据的OFDM符号帧 (总计63个OFDM符号)
%
% 输入参数:
%   N_sc          - 用于数据/导频的激活子载波数，也用于推算N_FFT (scalar integer)12 72 180 300 600可选 900 1200应该也是可以（对于此函数）
%   cpMode        - 循环前缀模式 (string: "normal" 或 "extended")
%   codingEnabled - 是否启用信道编码 (logical: true 或 false)
%   leaverEn      -是否使用交织(logical: true 或 false)
% 输出:
%   timeDomainFrame - 生成的完整时域OFDM符号帧（含CP，复数行向量）
%   qpskMappedFordata -QPSK映射数据
%   sourceInfoBits  - 原始信源信息比特 (二进制行向量)
%   pilotSequence   -导频序列
%   meta            - 包含相关参数和中间结果的结构体

% ===== 0. 参数校验和固定参数设定 =====
validateattributes(N_sc, {'numeric'}, {'scalar', 'positive', 'integer', 'real'}, mfilename, 'N_sc');
cpMode = lower(string(cpMode));
if ~(cpMode == "normal" || cpMode == "extended")
    error('cpMode 必须是 "normal" 或 "extended"。');
end
validateattributes(codingEnabled, {'logical'}, {'scalar'}, mfilename, 'codingEnabled');

delta_f = 15e3;             % 子载波间隔固定为 15 kHz
qpskBitsPerSymbol = 2;      % QPSK每个符号承载的比特数
numDataSymbolsInFrame = 50; % 固定的数据OFDM符号的总数

if codingEnabled
    codeRateR = 1/3;        % 如果启用编码，码率为1/3
    disp('OFDM数据模块：信道编码已启用，码率 R = 1/3');
else
    codeRateR = 1;          % 不编码，等效码率为1
    disp('OFDM数据模块：信道编码未启用。');
end

% Zadoff-Chu 序列参数 (接收端需要知道这些才能正确进行信道估计)
zc_root = 25; % 【重要】选择一个ZC序列的根，例如25。你可以根据需要修改。
zc_length = N_sc; 
fprintf('OFDM数据模块：导频将使用Zadoff-Chu序列：根(Root)=%d, 长度=%d\n', zc_root, zc_length);

% ===== 1. 计算派生系统量 =====
N_fft = 2^nextpow2(N_sc);           % IFFT点数
fs   = N_fft * delta_f;             % 系统采样率 (Hz)
fprintf('OFDM数据模块：系统参数计算: N_fft=%d, fs=%.2f MHz\n', N_fft, fs/1e6);

% ===== 2. 生成信源比特 =====
% 每个数据子载波承载 (qpskBitsPerSymbol * codeRateR) 个信息比特
numInfoBits = N_sc * numDataSymbolsInFrame * qpskBitsPerSymbol * codeRateR;
if mod(numInfoBits, 1) ~= 0 % 确保为整数
    numInfoBits = floor(numInfoBits);
    warning('OFDM数据模块：计算出的信息比特数不是整数，已向下取整为 %d。请检查N_sc,码率,调制阶数以保证能精确填充。', numInfoBits);
end
sourceInfoBits = randi([0 1], 1, numInfoBits); % 生成二进制行向量

% ===== 3. (可选) 信道编码 =====
if codingEnabled
    % --- 此处为理想的Turbo编码器占位符 ---
    % 实际Turbo编码输出长度可能需要根据具体标准或实现来精确确定和处理
    %%% 为简化，这里使用理想的31重复码来匹配码率，实际项目应替换%%%
    codedBits = repelem(sourceInfoBits, round(1/codeRateR)); % 注意round可能不精确
    numExpectedCodedBits = round(numInfoBits / codeRateR);
    if length(codedBits) > numExpectedCodedBits
        codedBits = codedBits(1:numExpectedCodedBits);
    elseif length(codedBits) < numExpectedCodedBits
        codedBits = [codedBits, zeros(1, numExpectedCodedBits - length(codedBits))]; % 补零
    end
    % --- Turbo编码器占位符结束 ---
    fprintf('OFDM数据模块：信道编码后比特数: %d\n', length(codedBits));
else
    codedBits = sourceInfoBits;
end

% % ===== 3.5  比特交织 =====
if leaverEn
interleaverSeed = 20250603;   % <<< 你可以改成任何整数，交织种子
rng(interleaverSeed,'twister');                    % 固定随机种子
interleaverPattern = randperm(length(codedBits));  % 随机排列索引
codedBits = codedBits(interleaverPattern);         % 交织后比特序列
fprintf('OFDM数据模块：已完成随机交织 (seed=%d)。\n', interleaverSeed);
end
% ===== 4. QPSK 星座点映射 =====
if mod(length(codedBits), qpskBitsPerSymbol) ~= 0
    padding = qpskBitsPerSymbol - mod(length(codedBits), qpskBitsPerSymbol);
    codedBits = [codedBits, zeros(1, padding)];
    fprintf('OFDM数据模块：为QPSK映射补零 %d 个比特。\n', padding);
end
qpskMappedForData = qammod(codedBits.', 4, 'InputType','bit', 'UnitAveragePower',true).'; % 输出行向量
qpskMappedFordata = qpskMappedForData;
expectedQPSKSymbolsForData = N_sc * numDataSymbolsInFrame;
if length(qpskMappedForData) ~= expectedQPSKSymbolsForData
     warning('OFDM数据模块：生成的QPSK数据符号数(%d)与预期(%d)不符。可能由于编码输出长度或比特计算。将截断或补零。', length(qpskMappedForData), expectedQPSKSymbolsForData);
    if length(qpskMappedForData) > expectedQPSKSymbolsForData
        qpskDataSymbolsPool = qpskMappedForData(1:expectedQPSKSymbolsForData);
    else
        qpskDataSymbolsPool = [qpskMappedForData, complex(zeros(1, expectedQPSKSymbolsForData-length(qpskMappedForData)))];
    end
else
    qpskDataSymbolsPool = qpskMappedForData;
end


% ===== 5. 生成导频序列 (Zadoff-Chu) =====
% ① 保证长度为奇
if mod(zc_length,2)==0
    zc_length = zc_length - 1;
    warning('ZC 生成长度改为最近奇数 %d', zc_length);
end


pilotSequence_ZC = zadoffChuSeq(zc_root, zc_length).';  % 行向量

% ③ 若导频长度比 N_sc 少 1，还需补零或修改 N_sc
if zc_length < N_sc
    pilotSequence_ZC = [pilotSequence_ZC, 1];   % 右端补1
end
pilotSequence = pilotSequence_ZC;

% ===== 6. 确定OFDM符号总数和类型序列 =====
% 模式 P,D,D,D,D,P,... 包含50个数据符号
% 需要 ceil(50/4) = 13 个数据块。每个数据块前有一个导频。
numPilotSymbols = 13;
numTotalOFDMSymbols = numDataSymbolsInFrame + numPilotSymbols; % 50 + 13 = 63

symbolTypeSequence = strings(1, numTotalOFDMSymbols);
dataSymbolCounter = 0;
pilotCounter = 0;
for i = 1:numTotalOFDMSymbols
    if mod(i-1, 5) == 0 % P, D, D, D, D 结构中，P位于索引 0, 5, 10, ... (即 i=1, 6, 11, ...)
        symbolTypeSequence(i) = "Pilot";
        pilotCounter = pilotCounter + 1;
    else
        if dataSymbolCounter < numDataSymbolsInFrame
            symbolTypeSequence(i) = "Data";
            dataSymbolCounter = dataSymbolCounter + 1;
        else 
            % 如果数据符号已经放完，但根据P,D,D,D,D结构还需要符号位，则可能是最后一个导频后的填充
            % 但对于63个符号和上述结构，应该正好填满
             if pilotCounter < numPilotSymbols % 确保最后一个是导频（如果需要）
                symbolTypeSequence(i) = "Pilot"; 
                pilotCounter = pilotCounter + 1;
             else
                 % 此处不应到达，表示总符号数或P/D分配逻辑可能需要微调
                 % 对于50个数据符号和P,D,D,D,D结构，13个导频，总63个符号，这应该能精确匹配。
             end
        end
    end
end
% 验证生成的导频和数据符号数量
if ~(sum(symbolTypeSequence=="Pilot") == numPilotSymbols && sum(symbolTypeSequence=="Data") == numDataSymbolsInFrame)
    warning('生成的导频/数据符号数量与预期不符，请检查symbolTypeSequence逻辑。预计P:%d D:%d，实际P:%d D:%d', ...
        numPilotSymbols, numDataSymbolsInFrame, sum(symbolTypeSequence=="Pilot"), sum(symbolTypeSequence=="Data"));
end


% ===== 7. 逐个生成OFDM符号的有用部分 (IFFT输出) =====
ofdmSymbolUsefulParts_cols = complex(zeros(N_fft, numTotalOFDMSymbols)); % 每一列是一个符号的有用部分
qpskSymbolPointer = 0; % 指向 qpskDataSymbolsPool 的起始索引

for i_sym = 1:numTotalOFDMSymbols
    symbols_to_map_current = complex(zeros(1, N_sc)); % 当前OFDM符号要映射的N_sc个符号 (行向量)
    
    if symbolTypeSequence(i_sym) == "Pilot"
        symbols_to_map_current = pilotSequence_ZC;
    else % Data symbol
        start_idx_pool = qpskSymbolPointer + 1;
        end_idx_pool = qpskSymbolPointer + N_sc;
        if end_idx_pool > length(qpskDataSymbolsPool)
            error('OFDM数据模块：QPSK符号池中的符号不足以填充所有数据子载波 (符号 %d)。', i_sym);
        end
        symbols_to_map_current = qpskDataSymbolsPool(start_idx_pool:end_idx_pool);
        qpskSymbolPointer = end_idx_pool;
    end
    
    % 子载波映射 (将N_sc个符号放置在N_fft长度的向量中心)
    S_freq = complex(zeros(1, N_fft));
    left_guard_count = floor((N_fft - N_sc)/2);
    S_freq(left_guard_count + 1 : left_guard_count + N_sc) = symbols_to_map_current; 
    
    X_for_ifft = ifftshift(S_freq); % 转换到FFT期望的顺序
    useful_part_row = ifft(X_for_ifft, N_fft); % ifft输出行向量
    ofdmSymbolUsefulParts_cols(:, i_sym) = useful_part_row.'; % 存储为列向量
end

% ===== 8. 为每个OFDM符号添加CP并拼接 =====
timeDomainFrameSamples_list = cell(1, numTotalOFDMSymbols); % 使用元胞数组存储带CP的符号

for i_sym = 1:numTotalOFDMSymbols
    current_useful_part_col = ofdmSymbolUsefulParts_cols(:, i_sym); % 取出列向量
    
    N_cp_current = 0; % 当前符号的CP长度
    if cpMode == "normal"
        if i_sym == 1 % 整个数据/导频帧的第一个符号 (即P0)
            Tcp_target = 5.2e-6;
        else
            Tcp_target = 4.7e-6;
        end
    else % extended CP
        Tcp_target = 16.7e-6;
    end
    N_cp_current = round(Tcp_target * fs);
    
    if N_cp_current > 0
        cp_samples = current_useful_part_col(end-N_cp_current+1:end);
        symbol_with_cp_col = [cp_samples; current_useful_part_col]; 
    else
        symbol_with_cp_col = current_useful_part_col;
        if N_cp_current < 0, N_cp_current = 0; end
    end
    timeDomainFrameSamples_list{i_sym} = symbol_with_cp_col;
end

timeDomainFrame = cat(1, timeDomainFrameSamples_list{:}).'; % 拼接所有列向量后再转置为最终的行向量

% ===== 9. 构造meta数据 =====
meta = struct();
meta.N_fft = N_fft;
meta.fs_hz = fs;
meta.N_sc_active_per_symbol = N_sc;
meta.cpMode = cpMode;
meta.N_cp_first_normal_target_us = 5.2; % 记录目标CP时长
meta.N_cp_other_normal_target_us = 4.7;
meta.N_cp_extended_target_us = 16.7;
meta.codingEnabled = codingEnabled;
meta.codeRateR = codeRateR;
meta.qpskBitsPerSymbol = qpskBitsPerSymbol;
meta.numDataSymbolsInFrame = numDataSymbolsInFrame;
meta.numPilotSymbolsInFrame = sum(symbolTypeSequence=="Pilot"); % 从实际分配中计数
meta.numTotalOFDMSymbolsInFrame = numTotalOFDMSymbols;
meta.symbolTypeSequence = symbolTypeSequence; 
meta.zc_root_used = zc_root;
meta.zc_length_used = zc_length;
meta.pilotSequence_ZC_used = pilotSequence_ZC; 
meta.numInfoBits = numInfoBits;
meta.numCodedBits = length(codedBits);
meta.numTotalQPSKSymbolsForData = length(qpskDataSymbolsPool);
meta.firstSymbolCpSamples = round( (cpMode=="normal")*5.2e-6*fs + (cpMode=="extended")*16.7e-6*fs );
if numTotalOFDMSymbols > 1
    meta.otherSymbolsCpSamples_normal = round(4.7e-6*fs); % Normal CP, other symbols
    meta.extendedCpSamples = round(16.7e-6*fs); % Extended CP, all symbols
end

fprintf('OFDM数据帧已生成: 共%d个OFDM符号 (数据%d, 导频%d)。总采样点数(含CP): %d。\n', ...
    meta.numTotalOFDMSymbolsInFrame, meta.numDataSymbolsInFrame, meta.numPilotSymbolsInFrame, length(timeDomainFrame));
end