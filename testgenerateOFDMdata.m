%% testGenerateOFDMDataFrame.m
clc; clear; close all;

%---------- 1 设定一组参数 ----------
N_sc       = 600;          % 一个典型偶数子载波数 (会被内部改为 ZC 长度 299 + 0 填充) 12 72 180 300 600可选 900 1200应该也是可以（对于此函数）
cpMode     = "normal";     % "normal" 或 "extended"
codingEn   =true;        % 若要测试重复码占位符, 改 true

%---------- 2 调用生成函数 ----------
[tdFrame, srcBits, pilotSequence,meta] = generateOFDMDataFrame(N_sc, cpMode, codingEn);

fprintf('\n--- 生成帧基本信息 ---\n');
disp(meta);

%---------- 3 简单尺寸一致性检查 ----------
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

%---------- 4 可视化：时域幅度 v.s. 频谱 ----------
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

