function [preamble, meta] = buildPreamble(Nsc, cpMode, pnSeq_or_seed, zeroDC)
% buildPreamble - 生成Schmidl-Cox类型的前导码及其循环前缀
%
% 输入参数:
%   Nsc           - 实际使用的子载波数 (scalar integer)
%   cpMode        - 循环前缀模式 (string: "normal" 或 "extended")
%   pnSeq_or_seed - PN序列本身 (长度为 Nfft/2 的复数行向量) 或 
%                   用于生成PN序列的随机数种子 (scalar double/integer)
%   zeroDC        - 是否将直流子载波置零 (logical: true 或 false)
%
% 输出:
%   preamble      - 生成的包含CP的前导码时域序列 (复数行向量)
%   meta          - 包含前导码相关派生参数的结构体:
%                   .Nfft - IFFT点数
%                   .fs   - 采样率 (Hz)
%                   .Ncp  - 前导码的CP长度 (采样点数)
%                   .L    - PN序列长度 (Nfft/2)
%                   .Tcp  - 前导码的目标CP时长 (s)
%                   .Xpre - 生成的频域前导码序列 (1xNfft)
%                   .p    - 未加CP的时域前导码序列 (1xNfft)
%                   .len  - 含CP的前导码总长度 (Ncp + Nfft)

% ===== 0. 输入参数校验 (基础版) =====
validateattributes(Nsc, {'numeric'}, {'scalar', 'positive', 'integer'}, mfilename, 'Nsc');
validateattributes(cpMode, {'string', 'char'}, {}, mfilename, 'cpMode');
cpMode = lower(string(cpMode)); % 转换为小写string以便比较
if ~(cpMode == "normal" || cpMode == "extended")
    error('cpMode 必须是 "normal" 或 "extended"。');
end
validateattributes(zeroDC, {'logical'}, {'scalar'}, mfilename, 'zeroDC');

% ===== 1. 计算派生系统量 =====
Nfft = 2^nextpow2(Nsc);             % IFFT点数，2的幂次方且 >= Nsc
delta_f = 15e3;                     % 子载波间隔固定为 15 kHz
fs   = Nfft * delta_f;              % 系统采样率 (Hz)
L    = Nfft/2;                      % PN序列的长度

if cpMode == "normal"
    Tcp_target = 5.2e-6;            % Normal CP 目标时长 (s)
else % extended
    Tcp_target = 16.7e-6;           % Extended CP 目标时长 (s)
end
Ncp  = round(Tcp_target * fs);      % 前导码的CP采样点数 (四舍五入)

% ===== 2. 生成或获取PN序列 P (长度 L) =====
if isnumeric(pnSeq_or_seed) && numel(pnSeq_or_seed) == L
    P = pnSeq_or_seed;
    if iscolumn(P) % 确保P是行向量
        P = P.';
    end
    if size(P,1) ~= 1 || size(P,2) ~= L
        error('如果 pnSeq_or_seed 是一个序列，它必须是长度为 L=Nfft/2 (%d) 的向量。', L);
    end
else % 认为是随机数种子
    validateattributes(pnSeq_or_seed, {'numeric'}, {'scalar', 'integer'}, mfilename, 'pnSeed');
    try
        rng(pnSeq_or_seed); % 设置随机数种子
    catch ME_rng
        warning('无法使用提供的种子 %s 设置rng。可能版本不兼容或种子无效。将使用默认随机序列。详细信息: %s', ...
                num2str(pnSeq_or_seed), ME_rng.message);
    end
    % 生成随机相位的BPSK/QPSK类型序列通常更好，这里生成随机相位复数序列
    % P = sign(randn(1,L)) + 1j*sign(randn(1,L)); % 随机QPSK类型 (-1-j, -1+j, 1-j, 1+j) / sqrt(2)
    % P = P / sqrt(2); % 归一化到单位功率 (近似)
    % 或者如你之前所写，随机相位，单位幅度：
    P = exp(1j*2*pi*rand(1,L)); % 1xL 的随机相位复数符号
end

% ===== 3. 构造频域前导码序列 Xpre[k] (1xNfft) =====
Xpre = complex(zeros(1, Nfft));   % 初始化为复数0行向量

% 将PN序列P映射到Xpre的奇数索引子载波上 (MATLAB中1-based indexing)
% Xpre(1), Xpre(3), ..., Xpre(Nfft-1)
Xpre(1:2:end) = P; 

% 处理直流子载波 (DC subcarrier, 在MATLAB FFT中是索引1)
if zeroDC
    Xpre(1) = 0; 
    % 如果P被映射到了Xpre(1) (即DC)，并且需要置零DC，这里会覆盖P(1)的值
    % 如果P没有被映射到Xpre(1)(例如，如果映射是从Xpre(2)开始的偶数位)，
    % 并且DC需要保持P(1)的值，则逻辑需要调整。
    % 当前设计：P(1) 映射到 Xpre(1)，如果zeroDC=true，则Xpre(1)被清零。
end

% ===== 4. IFFT变换到时域并添加循环前缀CP =====
% 标准MATLAB ifft不包含 1/Nfft 或 1/sqrt(Nfft) 的归一化
% p[n] (1xNfft)
p = ifft(Xpre, Nfft); 

% 添加CP
% preamble (1x(Ncp+Nfft))
if Ncp > 0
    preamble = [p(end-Ncp+1:end), p];
else % 如果计算出的Ncp为0或负数（不太可能，但做个保护）
    preamble = p;
    if Ncp < 0 
        warning('计算得到的Ncp (%d) 小于0，CP未添加。', Ncp);
        Ncp = 0; % 修正Ncp的值
    end
end


% ===== 5. 构造并返回meta数据 =====
meta = struct();
meta.Nfft = Nfft;
meta.fs = fs;
meta.Ncp = Ncp;
meta.L = L;
meta.Tcp_target = Tcp_target; % 目标CP时长 (s)
meta.Tcp_actual = Ncp / fs;   % 实际CP时长 (s)
meta.Xpre = Xpre;             % 频域前导码序列
meta.p_no_cp = p;             % 未加CP的时域前导码序列
meta.P_sequence = P;          % 使用的PN序列
meta.zeroDC = zeroDC;
meta.len = numel(preamble);   % 含CP的前导码总长度

fprintf('前导码已生成: Nfft=%d, fs=%.2f MHz, Ncp=%d (目标Tcp=%.2fus, 实际Tcp=%.2fus)\n', ...
        Nfft, fs/1e6, Ncp, Tcp_target*1e6, meta.Tcp_actual*1e6);

end