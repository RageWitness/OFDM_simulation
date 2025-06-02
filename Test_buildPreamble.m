% --- 前导码测试用例 ---
% 演示 buildPreamble 的典型用法
% ------------------------------------------------------------
clear;  clc;

%% 1. 配置输入参数
Nsc     = 600;          % 实际工作子载波数 (例如 LTE 6 个 PRB → 72 载波)
cpMode  = "normal";    % "normal" 或 "extended"
pnSeed  = 20250601;    % 随机种子 (也可以换成长度 = Nfft/2 的 PN 向量)
zeroDC  = true;        % 是否把直流子载波置零

%% 2. 调用 buildPreamble
[preamble, meta] = buildPreamble(Nsc, cpMode, pnSeed, zeroDC);

%% 3. 打印/检查关键信息
fprintf('\n=== meta 信息 ===\n');
disp(meta);

fprintf('含 CP 的前导码长度 = %d 样本\n', meta.len);
fprintf('FFT 点数 Nfft     = %d\n', meta.Nfft);
fprintf('采样率 fs         = %.3f MHz\n\n', meta.fs/1e6);

%% 4. 简单可视化
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
% 验证 Schmidl–Cox 重复结构：相关峰应接近 1
r   = meta.p_no_cp;          % 去掉 CP 的部分
L   = meta.L;
Psc = sum(conj(r(1:L)) .* r(L+1:2*L));
Rsc = sum(abs(r(L+1:2*L)).^2);
Msc = abs(Psc)^2 / Rsc^2;
bar(Msc); ylim([0 1.2]);
title(sprintf('Schmidl–Cox 度量 M = %.3f', Msc));
set(gca,'XTick',[]);

%% 5. (可选) 保存前导码到文件
% audiowrite 或 fwrite 均可；下面示例保存为 mat 文件
% save('preamble.mat','preamble','meta');
