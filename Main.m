% --- 主仿真脚本 ---
clear;  clc; close all;
%% 1. 配置输入参数
Nsc     =300;          % 实际工作子载波数 12(12个子载波效果极差，几乎不可用） 72 180 300 600可选 900 1200应该也是可以（对于此函数）
cpMode  = "normal";    % 前导码形制选择"normal" 或 "extended"
pnSeed  = 20250601;    % 前导码随机种子 (也可以换成长度 = Nfft/2 的 PN 向量)
zeroDC  = false;        % 是否把直流子载波置零 true ,false
codingEn   =false;        % 是否使用重复码, true ,false
leaverEn  =true;          % 是否交织, true ,false
delta_f = 15e3;         %子载波间隔固定15K
estimationAndEqEnabled = true;%逻辑值 (true/false), 控制是否执行信道估计和均衡
N_FFT = 2^nextpow2(Nsc);           % FFT点数
fs_current = N_FFT * delta_f;  %当前系统采样率
channelType = 'EVA70';    % 选择信道类型并仿真 支持ETU70,EVA70,EPA5;EVA5,ETU300也兼容.EPA5是衰落最小的，ETU30最坏甚至不可用
simulationSeedBase = 456;   % 信道基础种子
snr_value_dB = 0; % AWGN的信噪比

%% 2. 前导码生成
%调用 buildPreamble
[preamble, meta] = buildPreamble(Nsc, cpMode, pnSeed, zeroDC);

%打印/检查关键信息
fprintf('\n=== meta 信息 ===\n');
disp(meta);
metastored=meta;
fprintf('含 CP 的前导码长度 = %d 样本\n', meta.len);
fprintf('FFT 点数 Nfft     = %d\n', meta.Nfft);
fprintf('采样率 fs         = %.3f MHz\n\n', meta.fs/1e6);

%简单可视化
figure('Name','Preamble diagnostics','NumberTitle','off');

subplot(3,1,1);
stem(abs(meta.Xpre),'filled');
title('|X_{pre}[k]|');
xlabel('子载波索引'); ylabel('幅度');

subplot(3,1,2);
plot(real(preamble)); grid on;
title('含 CP 的前导码——实部');
xlabel('样本索引'); ylabel('Real\{preamble\}');

subplot(3,1,3);
%验证 Schmidl–Cox 重复结构：相关峰应接近 1
r   = meta.p_no_cp;          % 去掉 CP 的部分
L   = meta.L;
Psc = sum(conj(r(1:L)) .* r(L+1:2*L));
Rsc = sum(abs(r(L+1:2*L)).^2);
Msc = abs(Psc)^2 / Rsc^2;
bar(Msc); ylim([0 1.2]);
title(sprintf('Schmidl–Cox 度量 M = %.3f', Msc));
set(gca,'XTick',[]);

%% 3. OFDM调制
%----------  调用生成函数 ----------
[tdFrame, qpskMappedFordata ,srcBits, pilotSequence, meta] = generateOFDMDataFrame(Nsc, cpMode, codingEn,leaverEn);

figure;
scatter(real(qpskMappedFordata), imag(qpskMappedFordata), '.');
axis equal; grid on;
xlim([-1.5 1.5]); ylim([-1.5 1.5]);      % 适合 unit-power QPSK
title('QPSK Constellation (Tx)');
xlabel('In-phase');  ylabel('Quadrature');
fprintf('\n--- 生成帧基本信息 ---\n');
disp(meta);

%----------  简单尺寸一致性检查 ----------
expectedSamples = 0;
for k = 1:meta.numTotalOFDMSymbolsInFrame
    if k == 1 && cpMode=="normal"
        expectedSamples = expectedSamples + meta.N_fft + meta.firstSymbolCpSamples;
    else
        if cpMode=="normal"
            expectedSamples = expectedSamples + meta.N_fft + meta.otherSymbolsCpSamples_normal;
        else
            expectedSamples = expectedSamples + meta.N_fft + meta.extendedCpSamples;
        end
    end
end
assert(length(tdFrame)==expectedSamples, '❌ 总采样数与预期不符！');

fprintf('✅ 采样点数一致，帧生成成功。\n');

%----------  可视化：时域幅度 v.s. 频谱 ----------
figure('Name','OFDM 帧时域/频域特性','Units','normalized',...
       'Position',[.15 .2 .7 .6]);

subplot(2,1,1);
plot(abs(tdFrame));
title('绝对值 |timeDomainFrame|');
xlabel('Sample Index'); ylabel('Magnitude');

subplot(2,1,2);
nfftPlot = 4096;
Pxx = 20*log10( abs( fftshift( fft(tdFrame, nfftPlot) ) ) );
faxis = linspace(-meta.fs_hz/2, meta.fs_hz/2, nfftPlot)/1e6; % MHz
plot(faxis, Pxx);
title('帧整体功率谱');
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB)'); grid on;

%% 4.合并前导码与OFDM调制符号
% 以下变量已经通过调用相应的函数生成：
% preamble  <-- 前导码的时域采样点序列 (来自 buildPreamble)
% tdFrame   <-- 包含数据和导频OFDM符号的时域采样点序列 (来自 generateOFDMDataFrame)

% --- 确保 preamble 和 tdFrame 都是行向量以便水平拼接 ---
% (我们之前设计的函数倾向于输出行向量)

if ~isrow(preamble)
    if iscolumn(preamble)
        preamble = preamble.'; % 如果是列向量，则转置为行向量
        disp('提示：变量 "preamble" 已转置为行向量以便拼接。');
    else
        % 如果不是单行或单列，可能需要更复杂的处理或报错
        error('变量 "preamble" 维度不适合拼接，期望为行向量或列向量。当前维度: %s', mat2str(size(preamble)));
    end
end

if ~isrow(tdFrame)
    if iscolumn(tdFrame)
        tdFrame = tdFrame.'; % 如果是列向量，则转置为行向量
        disp('提示：变量 "tdFrame" 已转置为行向量以便拼接。');
    else
        error('变量 "tdFrame" 维度不适合拼接，期望为行向量或列向量。当前维度: %s', mat2str(size(tdFrame)));
    end
end

% --- 执行拼接 ---
% 将行向量 preamble 和行向量 tdFrame 水平拼接起来
txSignal_OFDM = [preamble, tdFrame];
num_leading_zeros = 10;
txSignal_OFDM = [txSignal_OFDM(:);zeros(num_leading_zeros, 1)]; % 确保 txSignal_OFDM 是列向量
% --- (可选) 验证拼接后信号的长度 ---
fprintf('前导码 (preamble) 长度 (采样点数): %d\n', length(preamble));
fprintf('OFDM数据/导频帧 (tdFrame) 长度 (采样点数): %d\n', length(tdFrame));
fprintf('拼接后的完整发射信号 (txSignal_OFDM) 长度 (采样点数): %d\n', length(txSignal_OFDM));

% 现在 txSignal_OFDM 就是包含了前导码和数据/导频部分的完整时域帧，
% 可以准备送入信道模型了。
% 例如，如果你的信道模型函数 simulateUsingLTEFadingChannel 期望输入是列向量：
% signal_for_channel = txSignal_OFDM.';
% [signal_after_channel, channel_info] = simulateUsingLTEFadingChannel(signal_for_channel, fs_current, channelType, simulationSeed);
% 或者，如果 simulateUsingLTEFadingChannel 内部已经处理了行/列转换，则可以直接传递。




%% 5.信道部分
txSignal_OFDM = txSignal_OFDM(:); % 确保是列向量
% 调用信道函数
[rxSignal_faded_custom, chanInfo_custom] = simulateUsingLTEFadingChannel(txSignal_OFDM, fs_current, channelType, simulationSeedBase);
% 3. 后续处理...
figure;

% 1. 绘制幅度比较
subplot(2,1,1); % 上半部分：幅度
plot(abs(txSignal_OFDM), 'b'); hold on;
plot(abs(rxSignal_faded_custom), 'r');
% 用 sprintf 先生成第二条曲线的标签
label2 = sprintf('通过 %s (LTEfadingchannel) 信道衰落后信号幅度', channelType);
% 把两个标签一起传给 legend
legend('原始信号幅度', label2);
title(sprintf('信号通过 %s (LTEfadingchannel) 信道后的幅度比较', channelType));
xlabel('采样点索引');
ylabel('幅度');

% 2. 绘制功率谱
subplot(2,1,2); % 下半部分：功率谱
nfft = 2048; % 选择一个适当的 FFT 点数（可以根据需要调整）
P_tx = 20*log10(abs(fftshift(fft(txSignal_OFDM, nfft)))); % 原始信号功率谱
P_rx = 20*log10(abs(fftshift(fft(rxSignal_faded_custom, nfft)))); % 经信道衰落后的信号功率谱

faxis = linspace(-fs_current/2, fs_current/2, nfft); % 频率轴，单位 Hz
plot(faxis, P_tx, 'b'); hold on;
plot(faxis, P_rx, 'r');
title('原始信号与信道衰落后信号功率谱比较');
xlabel('频率 (Hz)');
ylabel('功率谱 (dB)');
legend('原始信号功率谱', '衰落后信号功率谱');
grid on;

% 输出信道信息
disp(chanInfo_custom);


%% 6.符号同步部分
% 假设 preamble_meta 是 buildPreamble 返回的 meta 结构体
% rx_noisy_signal 是经过信道和加噪后的接收信号
[syncFrame, offset, M_metric] = symbolTimingSynchronizer(rxSignal_faded_custom,metastored);

fprintf('\n>>> Schmidl-Cox 估计的起点 = %d 样本\n', offset);
fprintf('    同步后帧长度          = %d 样本\n', length(syncFrame));

% 画定时度量，直观看看峰值
figure('Name','Schmidl-Cox Timing Metric','NumberTitle','off');
plot(M_metric); grid on;
title('Schmidl–Cox 定时度量  M_metric[d]');
xlabel('采样点偏移 d'); ylabel('M_metric[d]');
xline(offset+metastored.Ncp, 'r--', '估计帧起点（含CP）');

% 如果想验证 —— 把同步后帧前 meta.len 点取出来，与原 preamble 对齐比较
recovPreamble = syncFrame(1:metastored.len).';
figure('Name','对齐前导码比对','NumberTitle','off');
plot(abs([preamble; recovPreamble]).'); legend('Tx Preamble','Rx(同步后)');
title('同步准确性 (幅度对比)');

%--------去除前导码------
%  获取前导码（含其CP）的总长度
preambleTotalLength = metastored.len; %metastored.len = N_fft_preamble + N_cp_preamble

% 2. 检查 synchronizedFrame 是否足够长
if length(syncFrame) > preambleTotalLength
    % 去掉前导码部分，保留后续的信号
    dataAndPilotSymbolsWithCPs = syncFrame(preambleTotalLength + 1 : end);
    
    fprintf('已移除前导码部分 (长度 %d采样点)。\n', preambleTotalLength);
    fprintf('剩余信号长度 (包含63个OFDM符号及其CP): %d采样点。\n', length(dataAndPilotSymbolsWithCPs));
    
    % 现在 dataAndPilotSymbolsWithCPs 中就是连续的63个OFDM符号（数据和导频），
    % 每一个都还带着它自己的CP。
    % 下一步通常是逐个处理这些符号：先去CP，再做FFT。

else
    % 如果 synchronizedFrame 的长度不大于前导码长度，说明可能没有足够的数据符号
    warning('synchronizedFrame 的长度 (%d) 不足以移除完整的前导码 (长度 %d)。可能没有后续数据符号。', ...
            length(synchronizedFrame), preambleTotalLength);
    dataAndPilotSymbolsWithCPs = []; % 或者根据具体情况处理
end

% 调用函数添加噪声
noisy_received_signal = addAWGN(dataAndPilotSymbolsWithCPs, snr_value_dB);

%计算noiseTermForMMSE----
P_sig = mean(abs(noisy_received_signal).^2); % measured signal power

snr_lin= 10^(snr_value_dB/10);

P_noise_tot = P_sig / snr_lin;% 总噪声功率

sigma_t2 = P_noise_tot / length(noisy_received_signal); % 时域单样本方差

noiseVar_SC = sigma_t2 * N_FFT; % 频域单子载波方差

noiseTermForMMSE = noiseVar_SC; % 因为 P_signal_per_SC = 1


% 6-B. 幅度 + 功率谱三合一对比图
figure('Name','Tx / Faded / Noisy 对比','Units','normalized',...
       'Position',[0.1 0.15 0.8 0.7]);

% ── 1. 时域幅度 ───────────────
subplot(2,1,1);
plot(abs(txSignal_OFDM),          'b'); hold on;
plot(abs(rxSignal_faded_custom),  'r');
plot(abs(noisy_received_signal),  'g');
legend('Tx 原始','Faded','Faded+AWGN');
title(sprintf('时域幅度比较 (SNR = %d dB)', snr_value_dB));
xlabel('Sample Index'); ylabel('Magnitude');

% ── 2. 功率谱 (dB) ────────────
subplot(2,1,2);
nfftPlot = 4096;                         % 画谱用的 FFT 点数
faxis = linspace(-fs_current/2, fs_current/2, nfftPlot)/1e6;  % MHz

P_tx    = 20*log10(abs(fftshift(fft(txSignal_OFDM,        nfftPlot))));
P_faded = 20*log10(abs(fftshift(fft(rxSignal_faded_custom,nfftPlot))));
P_noisy = 20*log10(abs(fftshift(fft(noisy_received_signal,nfftPlot))));

plot(faxis, P_tx,    'b'); hold on;
plot(faxis, P_faded, 'r');
plot(faxis, P_noisy, 'g');
legend('Tx 原始','Faded','Faded+AWGN');
title('功率谱比较');
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB)');
grid on;
 

%% 7.OFDM接收端
%------去除CP--------------
[ofdmSymbolsUseful, symbolsDone, cpLens] = removeCPForEachSymbol(noisy_received_signal, ...
                                                              N_FFT, ...
                                                              cpMode, ...
                                                              fs_current, ...
                                                              63);
%-----频域估计与均衡
numDataSyms = 50;
pilotInterval = 4; % 每4个数据符号一组
symbolTypes = generateSymbolTypeSequence(numDataSyms, pilotInterval);
disp(symbolTypes);
fprintf('导频数量: %d, 数据符号数量: %d, 总符号数: %d\n', ...
        sum(symbolTypes=="Pilot"), sum(symbolTypes=="Data"), length(symbolTypes));
% 期望输出：导频数量: 13, 数据符号数量: 50, 总符号数: 63
active_indices_human_order = active_indices_human_orderf(N_FFT ,Nsc);
%频域信道估计与均衡
[demapperInputSymbolsMatrix, channelEstimatesForDataSymbols] = performFreqDomainProcessing(ofdmSymbolsUseful,  ...
                                                                                             symbolTypes,  ...
                                                                                             pilotSequence,  ...
                                                                                             active_indices_human_order,  ...
                                                                                             N_FFT, Nsc,  ...
                                                                                             noiseTermForMMSE,  ...
                                                                                             estimationAndEqEnabled);
% demapperInputSymbolsMatrix 是一个 N_sc x numDataSymbols 的矩阵
% 每一列是一个OFDM数据符号在激活子载波上的均衡后符号
% 将矩阵按列优先的顺序转换为一个长列向量
serialized_equalized_symbols = demapperInputSymbolsMatrix(:);

% 如果你的QPSK解调器期望行向量，可以再转置一下：
% serialized_equalized_symbols = demapperInputSymbolsMatrix(:).'; 
% 或者，如果解调器能处理列向量，这样就可以了。

% 现在 serialized_equalized_symbols 就是可以送给QPSK解调器的串行符号流了
% recovered_bits = qamdemod(serialized_equalized_symbols, 4, 'OutputType','bit', 'UnitAveragePower',true); 
% (注意：qamdemod 的参数需要与你使用的 qammod 对应，特别是关于平均功率)
% —— 1. 水平瀑布图 —— 
figure;
imagesc(20*log10(abs(demapperInputSymbolsMatrix))); axis xy;
xlabel('Data-symbol index'); ylabel('Sub-carrier index');
title('Equalised magnitude (dB)'); colorbar;

% —— 2. 星座 —— 
figure; scatter(real(demapperInputSymbolsMatrix(:)), ...
                imag(demapperInputSymbolsMatrix(:)), '.');
axis equal; grid on;
title('Constellation after FDE'); xlim([-2 2]); ylim([-2 2]);
%-----QPSK逆映射-------
demappedBits = demapQPSK(serialized_equalized_symbols);

if leaverEn
% 已做解码前反交织
N = length(demappedBits);                 % demappedBits 来自 QAM 解调
rng(20250603,'twister');      % 同样的种子20250603
interleaverPattern = randperm(N);         % 得到同一随机排列

invPat               = zeros(1,N);        % 构造逆排列
invPat(interleaverPattern) = 1:N;         % 关键一步
demappedBits = demappedBits(invPat);      % 恢复交织前顺序
end


% —————————— 沿用上一步得到 demappedBits ——————————
codeRateR = 1/3;                        % 与发射端一致
[rxBitsDec , BER1, errs1, N1] = decodeAndCalcBER(demappedBits, srcBits, codingEn, codeRateR);  % codingIsEnabled = true 
                                                                         









