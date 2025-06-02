function [ofdmSymbolsWithoutCP, numSymbolsProcessed, cpLengthsUsed] = removeCPForEachSymbol(dataAndPilotSymbolsWithCPs, N_fft, cpMode, fs, numExpectedSymbols)
% removeCPForEachSymbol - 逐个去除OFDM符号的循环前缀(CP)
%
% 输入参数:
%   dataAndPilotSymbolsWithCPs - 包含一个或多个带CP的OFDM符号的串行时域采样点序列 (列向量)
%   N_fft                     - 系统OFDM符号的FFT点数 (scalar integer)
%   cpMode                    - CP类型 (string: "normal" 或 "extended")
%   fs                        - 系统采样率 (Hz)
%   numExpectedSymbols        - 输入序列中预期的OFDM符号总数 (scalar integer)
%
% 输出:
%   ofdmSymbolsWithoutCP      - 矩阵，每列是一个去除了CP的OFDM符号的有用部分 (N_fft x numSymbolsProcessed)
%   numSymbolsProcessed       - 实际成功处理并去除CP的OFDM符号数量
%   cpLengthsUsed             - 一个向量，包含了为每个处理的符号所计算的CP长度

% --- 0. 输入参数校验和准备 ---
validateattributes(dataAndPilotSymbolsWithCPs, {'numeric'}, {'vector'}, mfilename, 'dataAndPilotSymbolsWithCPs');
validateattributes(N_fft, {'numeric'}, {'scalar', 'positive', 'integer'}, mfilename, 'N_fft');
cpMode = lower(string(cpMode));
if ~(cpMode == "normal" || cpMode == "extended")
    error('cpMode 必须是 "normal" 或 "extended"。');
end
validateattributes(fs, {'numeric'}, {'scalar', 'positive'}, mfilename, 'fs');
validateattributes(numExpectedSymbols, {'numeric'}, {'scalar', 'positive', 'integer'}, mfilename, 'numExpectedSymbols');

if ~iscolumn(dataAndPilotSymbolsWithCPs)
    dataAndPilotSymbolsWithCPs = dataAndPilotSymbolsWithCPs(:); % 确保是列向量
end

inputSignalTotalLength = length(dataAndPilotSymbolsWithCPs);

% --- 1. 初始化 ---
ofdmSymbolsWithoutCP_temp = complex(zeros(N_fft, numExpectedSymbols)); % 预分配内存
cpLengthsUsed_temp = zeros(1, numExpectedSymbols);
currentPositionInInput = 1; % 指向输入序列的当前处理位置 (1-based index)
symbolsProcessedCount = 0;

fprintf('开始去除CP模块处理，预期 %d 个OFDM符号...\n', numExpectedSymbols);

% --- 2. 逐个OFDM符号处理循环 ---
for i_sym = 1:numExpectedSymbols
    % a. 计算当前符号的CP长度 (N_cp_current)
    N_cp_current = 0; % 初始化
    if cpMode == "normal"
        if i_sym == 1 % 序列中的第一个符号 (对应之前帧结构中的P0导频)
            Tcp_target = 5.2e-6; % Normal CP, 第一个符号的目标时长
        else
            Tcp_target = 4.7e-6; % Normal CP, 其他符号的目标时长
        end
    else % extended CP
        Tcp_target = 16.7e-6;    % Extended CP, 所有符号的目标时长
    end
    N_cp_current = round(Tcp_target * fs);
    if N_cp_current < 0, N_cp_current = 0; end % 防御性编程，CP长度不能为负

    cpLengthsUsed_temp(i_sym) = N_cp_current; % 记录CP长度

    % b. 计算当前带CP的OFDM符号的总长度
    currentSymbolTotalLength = N_fft + N_cp_current;

    % c. 检查剩余样本是否足够构成一个完整的当前OFDM符号
    if (currentPositionInInput + currentSymbolTotalLength - 1) > inputSignalTotalLength
        warning('去除CP：OFDM符号 %d/%d, 输入序列中剩余样本不足。期望至少 %d, 实际剩余 %d。处理提前终止。', ...
                i_sym, numExpectedSymbols, currentSymbolTotalLength, inputSignalTotalLength - currentPositionInInput + 1);
        break; % 退出循环，不再处理后续符号
    end

    % d. 提取当前带CP的OFDM符号 (作为列向量)
    oneSymbolWithCP = dataAndPilotSymbolsWithCPs(currentPositionInInput : currentPositionInInput + currentSymbolTotalLength - 1);
    
    % e. 去除CP (CP位于符号的前部)
    usefulPartOfSymbol = oneSymbolWithCP(N_cp_current + 1 : end);
    
    % f. 验证并存储去除CP后的有用部分
    if length(usefulPartOfSymbol) ~= N_fft
        error('去除CP后符号 %d 的长度 (%d) 与期望的 N_fft (%d) 不符。请检查CP计算或输入信号。', ...
              i_sym, length(usefulPartOfSymbol), N_fft);
    end
    ofdmSymbolsWithoutCP_temp(:, i_sym) = usefulPartOfSymbol;
    symbolsProcessedCount = symbolsProcessedCount + 1;
    
    % g. 更新输入序列的当前处理位置
    currentPositionInInput = currentPositionInInput + currentSymbolTotalLength;
end

% --- 3. 最终输出处理 ---
if symbolsProcessedCount < numExpectedSymbols
    fprintf('去除CP：实际处理了 %d 个OFDM符号 (预期 %d 个)。\n', symbolsProcessedCount, numExpectedSymbols);
    ofdmSymbolsWithoutCP = ofdmSymbolsWithoutCP_temp(:, 1:symbolsProcessedCount);
    cpLengthsUsed = cpLengthsUsed_temp(1:symbolsProcessedCount);
else
    ofdmSymbolsWithoutCP = ofdmSymbolsWithoutCP_temp;
    cpLengthsUsed = cpLengthsUsed_temp;
    fprintf('去除CP：成功处理了全部 %d 个OFDM符号。\n', symbolsProcessedCount);
    numSymbolsProcessed=symbolsProcessedCount;
end

end