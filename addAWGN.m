function noisySignal = addAWGN(signal, snr_dB)
% addAWGN - 给输入信号添加指定信噪比的加性高斯白噪声
%
% 输入参数:
%   signal   - 输入的复数基带信号 (行向量或列向量)
%   snr_dB   - 期望的信噪比 (SNR)，单位 dB
%
% 输出:
%   noisySignal - 添加了AWGN后的信号 (与输入信号维度相同)

% 确保信号是列向量，以便与许多通信系统工具箱函数保持一致
% (awgn函数本身对行向量或列向量都能处理)
isRowVec = false;
if isrow(signal)
    isRowVec = true;
    signal = signal.'; % 转置为列向量进行内部处理
end

% --- 使用 Communications Toolbox™ 中的 awgn 函数 ---
% 'measured' 选项会让 awgn 函数首先测量输入信号 signal 的功率，
% 然后根据这个测量到的信号功率和指定的 snr_dB 来确定所需的噪声功率。
% awgn 函数能正确处理复数信号 (即噪声的实部和虚部都是高斯的，且功率正确分配)。

noisySignal = awgn(signal, snr_dB, 'measured');

% 如果原始输入是行向量，将输出也转换回行向量
if isRowVec
    noisySignal = noisySignal.';
end

% fprintf('已为信号添加 SNR = %.1f dB 的AWGN噪声。\n', snr_dB);

end