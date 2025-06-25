% ================= Main (BER vs SNR) =================
clear; clc; close all;

%% 1. 固定系统参数（与原 Main 完全一致）
Nsc     = 300;   % 实际工作子载波数 12(12个子载波效果极差，几乎不可用） 72 180 300 600可选 900 1200应该也是可以（对于此函数）
cpMode = "normal";% 前导码形制选择"normal" 或 "extended"
pnSeed  = 20250601; %前导码随机种子 (也可以换成长度 = Nfft/2 的 PN 向量)
zeroDC = false; % 是否把直流子载波置零 true ,false
codingEn=  false;     % 是否使用重复码, true ,false
leaverEn = false;  % 是否交织, true ,false
estimationAndEqEnabled = true;%是否执行信道估计和均衡逻辑值 (true/false)
delta_f = 15e3;%子载波间隔固定15K

channelType        = 'EPA5';% 选择信道类型并仿真 支持ETU70,EVA70,EPA5;EVA5,ETU300也兼容 EPA5是衰落最小的，ETU30最坏甚至不可用
simulationSeedBase = 456;% 信道基础种子

SNRdB_vec = 0:2:20;                 % <—— 要绘制的 SNR 采样
BER_vec   = nan(size(SNRdB_vec));   % 预分配

%% 2. 预生成前导码和 OFDM 帧（一次即可）
[preamble, preMeta] = buildPreamble(Nsc, cpMode, pnSeed, zeroDC);
[tdFrame, qpskMappedFordata, srcBits, pilotSeq, txMeta] = ...
    generateOFDMDataFrame(Nsc, cpMode, codingEn, leaverEn);

num_leading_zeros = 50; % 插入到txSignal_OFDM后的时域保护长度，不得大于N_fft数！（因ltefadingchannel会截断导致传输数据损坏）
txSignal_OFDM = [preamble, tdFrame].';
txSignal_OFDM = [txSignal_OFDM;zeros(num_leading_zeros,1) ];  % 列向量

N_FFT   = txMeta.N_fft;
fs_curr = N_FFT * delta_f;

%% 3. SNR 循环
for idx = 1:numel(SNRdB_vec)
    snr_dB = SNRdB_vec(idx);
    fprintf('\n========  SNR = %.1f dB  ========\n', snr_dB);

    % 3-A. 衰落信道
    [rxFaded, ~] = simulateUsingLTEFadingChannel( ...
                      txSignal_OFDM, fs_curr, channelType, simulationSeedBase);

    % 3-B. 加 AWGN
    rxNoisy = addAWGN(rxFaded, snr_dB);

    % 3-C. Schmidl-Cox 定时同步
    [syncFrame, offsetSc, ~] = symbolTimingSynchronizer(rxNoisy, preMeta);

    if isempty(syncFrame) || offsetSc <= 0
        % 同步失败（常见于 0 dB），退回“理论起点”
        offsetFallback = num_leading_zeros + 1;
        syncFrame = rxNoisy(offsetFallback:end);
        fprintf('!! S&C 同步失败，改用已知偏移 %d\n', offsetFallback);
    end

    % 3-D. 去前导码
    if length(syncFrame) < preMeta.len
        warning('帧过短，跳过此 SNR');  BER_vec(idx) = 0.5;  continue;
    end
    dataWithCP = syncFrame(preMeta.len+1:end);

    % 3-E. 去 CP
    [ofdmUseful, ~, ~] = removeCPForEachSymbol( ...
                      dataWithCP, N_FFT, cpMode, fs_curr, 63);

    % 3-F. 计算 MMSE 噪声项
    P_sig    = mean(abs(rxNoisy).^2);
    snr_lin  = 10^(snr_dB/10);
    Pn_tot   = P_sig / snr_lin;
    sigma_t2 = Pn_tot / length(rxNoisy);
    noiseTerm= sigma_t2 * N_FFT;       % P_signal_per_SC ≈1

    % 3-G. 频域估计 + 均衡
    symbolTypes = generateSymbolTypeSequence(50,4);
    active_idx  = active_indices_human_orderf(N_FFT,Nsc);

    [eqSymsMat,~] = performFreqDomainProcessing(ofdmUseful, ...
                    symbolTypes, pilotSeq, active_idx, ...
                    N_FFT, Nsc, noiseTerm, estimationAndEqEnabled);

    % 3-H. QPSK 解调
    serSyms = eqSymsMat(:);
    rxBits  = demapQPSK(serSyms);

    % 3-I. 反交织
    if leaverEn
        rng(20250603,'twister');
        tmp        = randperm(length(rxBits));
        invPat(tmp)= 1:length(rxBits);
        rxBits     = rxBits(invPat);
    end

    % 3-J. (可选) 重复码解码 + BER
    [~, BERk, ~, ~] = decodeAndCalcBER(rxBits, srcBits, codingEn, 1/3);
    BER_vec(idx) = BERk;
end

%% 4. 绘 BER 曲线
figure;
semilogy(SNRdB_vec, BER_vec,'o-','LineWidth',1.4);
grid on; xlabel('SNR (dB)'); ylabel('BER');
title(sprintf('BER vs SNR   (N_{SC}=%d, %s)', Nsc, channelType));
% ------若要画未启用和启用信道估计与均衡的对比图请按以下步骤：-------
%1.删掉此脚本的clear选项 2.运行不启用估计与编码的参数 3.工作区中找到BER_vec选项并右键生成副本"BER_vecCopy"
%4.启用信道估计与均衡并把下面取消注释，运行一次此脚本
% figure;
% semilogy(SNRdB_vec, BER_vec,    'r-o', 'LineWidth',1.4);  % 红色：启用信道估计与均衡
% hold on;
% semilogy(SNRdB_vec, BER_vecCopy,'b-s', 'LineWidth',1.4);  % 蓝色：未启用估计与均衡
% grid on;
% xlabel('SNR (dB)');
% ylabel('BER');
% legend('启用信道估计与均衡','未启用估计与均衡','Location','best');
% title(sprintf('BER vs SNR   (N_{SC}=%d, %s)', Nsc, channelType));
% hold off;
