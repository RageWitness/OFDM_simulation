function [synchronizedFrame, timingOffset, timingMetric] = symbolTimingSynchronizer(receivedSignalNoisy, preambleMeta)
% symbolTimingSynchronizer - 使用Schmidl & Cox类算法进行OFDM符号定时同步
%
% 输入:
%   receivedSignalNoisy - 接收到的含噪声的复数基带信号 (列向量)
%   preambleMeta        - 前导码的meta信息结构体，应包含:
%                           .Nfft (前导码的FFT点数)
%                           .L    (重复部分的长度 Nfft/2)
%                           .Ncp  (前导码的CP采样点数)
%                           .len  (前导码总长度 Nfft+Ncp)
%
% 输出:
%   synchronizedFrame   - 同步后的信号帧 (从估计的起始位置开始)
%   timingOffset        - 估计的帧起始点在receivedSignalNoisy中的索引 (1-based)
%   timingMetric        - 计算得到的定时度量M[d]序列

% --- 0. 输入参数校验和提取 ---
validateattributes(receivedSignalNoisy, {'numeric'}, {'vector'}, mfilename, 'receivedSignalNoisy');
if ~isstruct(preambleMeta) || ...
   ~isfield(preambleMeta, 'Nfft') || ~isfield(preambleMeta, 'L') || ...
   ~isfield(preambleMeta, 'Ncp') || ~isfield(preambleMeta, 'len')
    error('preambleMeta 结构体不完整或格式错误，请确保包含 Nfft, L, Ncp, len 字段。');
end

if ~iscolumn(receivedSignalNoisy)
    receivedSignalNoisy = receivedSignalNoisy(:); % 确保是列向量
end

N_fft = preambleMeta.Nfft;
L     = preambleMeta.L; % L = N_fft / 2
N_cp_preamble = preambleMeta.Ncp;
% expectedPreambleSymbolLength = preambleMeta.len; % 包含CP的前导码符号长度

nSamples = length(receivedSignalNoisy);

% 前导码的有用部分长度是 2*L = N_fft
if nSamples < (N_fft + N_cp_preamble) % 信号长度至少要能容纳一个完整的前导码符号
    warning('接收信号长度 (%d) 可能不足以包含完整的前A导码 (%d)。', nSamples, N_fft + N_cp_preamble);
    % 可以选择报错或继续，但结果可能不可靠
    if nSamples < 2*L % 至少需要2L长度来进行相关计算
        error('接收信号过短，无法执行Schmidl & Cox相关计算。需要至少 %d 点，实际 %d 点。', 2*L, nSamples);
    end
end

% --- 1. 计算Schmidl & Cox定时度量 M[d] ---
% P[d] = sum_{m=0}^{L-1} r*(d+m) * r(d+m+L)
% R[d] = sum_{m=0}^{L-1} |r(d+m+L)|^2
% M[d] = |P[d]|^2 / (R[d]^2)
%
% 搜索范围：d 的取值使得 r(d+m+L) 和 r(d+m) 都在信号范围内。
% 滑动窗口的有效数据部分总长为 2*L。
% d 在MATLAB中是1-based index，表示第一个L长度块的起始。
% 第一个L块: receivedSignalNoisy(d : d+L-1)
% 第二个L块: receivedSignalNoisy(d+L : d+2*L-1)
% 因此，d+2*L-1 <= nSamples  => d <= nSamples - 2*L + 1

max_d_offset = nSamples - 2*L + 1; 
if max_d_offset < 1
    error('信号太短，无法形成2L长度的窗口进行相关。');
end

P_d = zeros(max_d_offset, 1); % 存储P[d]的值
R_d = zeros(max_d_offset, 1); % 存储R[d]的值

for d = 1:max_d_offset 
    block1 = receivedSignalNoisy(d : d+L-1);
    block2 = receivedSignalNoisy(d+L : d+2*L-1);
    
    P_d(d) = sum(conj(block1) .* block2);
    R_d(d) = sum(abs(block2).^2);
end

% 计算定时度量 M[d]
% 为避免除以零 (或非常小的值导致结果溢出)，对R_d做一些处理
R_d_metric = R_d;
R_d_metric(R_d_metric < 1e-10) = 1e-10; % 设置一个小的下限值

timingMetric = (abs(P_d).^2) ./ (R_d_metric.^2);

% --- 2. 寻找最佳定时点 ---
% Schmidl & Cox 的定时度量M[d]会在前导码的CP期间开始上升，并在两个重复部分完全对齐时达到平台或峰值。
% 峰值的位置 d_peak 对应于接收信号中前导码有用部分第一个L块的起始索引。
[~, peak_location_in_metric] = max(timingMetric);
d_estimated_start_of_useful_A = peak_location_in_metric; % M[d]的索引d直接对应接收信号的索引

% 估计的前导码符号（包含CP）的起始位置
% d_estimated_start_of_useful_A 是前导码有用部分(N_fft)中第一个L块的起始点
% 所以，前导码CP的起始点在此之前 N_cp_preamble 个采样点
timingOffset = d_estimated_start_of_useful_A - N_cp_preamble;

% --- 3. 合法性检查和输出 ---
if timingOffset < 1
    warning('符号定时同步：估计的 timingOffset (%d) 小于1，可能前导码未完全捕获或位于信号最前端。将其强制设为1。', timingOffset);
    timingOffset = 1;
end

% 截取同步后的帧
% 假设后续模块知道如何根据这个起始点和帧结构来进一步处理
% （例如，知道前导码多长，数据部分多长）
if timingOffset > nSamples
    warning('符号定时同步：估计的 timingOffset (%d) 超出接收信号长度 (%d)。输出空帧。', timingOffset, nSamples);
    synchronizedFrame = [];
else
    synchronizedFrame = receivedSignalNoisy(timingOffset : end);
end

fprintf('符号定时同步完成: 估计的帧起始偏移 (前导码CP开始处) = %d\n', timingOffset);

% （可选）如果需要绘制，可以在调用此函数后绘制 timingMetric
% figure; plot(timingMetric); title('Schmidl & Cox 定时度量 M[d]'); xlabel('采样点偏移 d'); ylabel('M[d]');

end