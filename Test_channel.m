% --- Channel测试用例 ---
% 1. 定义OFDM参数并生成基带信号 (txSignal_OFDM)
N_active = 72; 
N_FFT = 128;   
delta_f = 15e3; 
fs_current = N_FFT * delta_f; 

numSamples = N_FFT * 20; 
txSignal_OFDM = complex(randn(numSamples, 1), randn(numSamples, 1)) * 0.707;
txSignal_OFDM = txSignal_OFDM(:); % 确保是列向量

% 2. 选择信道类型并仿真支持ETU70,EVA70,EPA5;EVA5,ETU300也兼容
channelType = 'ETU300'; 
simulationSeedBase = 456;   % 基础种子

% 调用新的信道函数
[rxSignal_faded_custom, chanInfo_custom] = simulateUsingLTEFadingChannel(txSignal_OFDM, fs_current, channelType, simulationSeedBase);

% 3. 后续处理...
figure;
plot(abs(txSignal_OFDM), 'b'); hold on;
plot(abs(rxSignal_faded_custom), 'r');

% 用 sprintf 先生成第二条曲线的标签
label2 = sprintf('通过 %s (LTEfadingchannel) 信道衰落后信号幅度', channelType);

% 把两个标签一起传给 legend
legend('原始信号幅度', label2);

title(sprintf('信号通过 %s (LTEfadingchannel) 信道后的幅度比较', channelType));
xlabel('采样点索引'); 
ylabel('幅度');

disp(chanInfo_custom);
