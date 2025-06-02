function [fadedSignal, channelInfo] = simulateCustomTDLChannel(txSignal, fs, channelTypeString, varargin)
% simulateCustomTDLChannel - 手动构建抽头时延线模型模拟衰落信道
% (为每条径在每次调用时创建新的 comm.RayleighChannel 对象)
%
% 输入:
%   txSignal         - 复数基带输入信号 (必须是列向量)
%   fs               - txSignal 的采样率 (Hz)
%   channelTypeString - 字符串，指定信道模型和多普勒频率。
%                       例如: 'EPA5', 'EVA70', 'ETU70', 'ETU300'
%   varargin{1}      - (可选) 随机数种子基础值 (标量, double类型的非负整数)
%                      每个径的实际种子会基于此进行偏移。
%
% 输出:
%   fadedSignal      - 经过衰落信道后的复数基带信号 (列向量)
%   channelInfo      - 包含信道配置和一些结果信息的结构体

% --- 0. 确保 txSignal 是列向量 ---
if ~iscolumn(txSignal)
    if isrow(txSignal)
        txSignal = txSignal.';
        fprintf('提示 (simulateCustomTDLChannel): 输入的 txSignal 是行向量，已自动转置为列向量。\n');
    else
        error('simulateCustomTDLChannel: txSignal 输入必须是单列向量。当前维度为 %s。', mat2str(size(txSignal)));
    end
end
inputSignalLength = length(txSignal);

% --- 1. 加载和解析信道参数 ---
persistent epaTable evaTable etuTable tableDataLoaded;
if isempty(tableDataLoaded)
    try
        epaTable = readtable('Table B.2.1-2 Extended Pedestrian A model (EPA).xlsx', 'VariableNamingRule', 'preserve');
        evaTable = readtable('Table B.2.1-3 Extended Vehicular A model (EVA).xlsx', 'VariableNamingRule', 'preserve');
        etuTable = readtable('Table B.2.1-4 Extended Typical Urban model (ETU).xlsx', 'VariableNamingRule', 'preserve');
        tableDataLoaded = true;
        disp('自定义TDL信道：参数表格已加载。');
    catch ME
        error('自定义TDL信道：无法加载参数表格: %s', ME.message);
    end
end

modelType = '';
maxDopplerShift = 0;
if contains(channelTypeString, 'EPA', 'IgnoreCase', true)
    modelType = 'EPA'; selectedTable = epaTable;
elseif contains(channelTypeString, 'EVA', 'IgnoreCase', true)
    modelType = 'EVA'; selectedTable = evaTable;
elseif contains(channelTypeString, 'ETU', 'IgnoreCase', true)
    modelType = 'ETU'; selectedTable = etuTable;
else
    error('自定义TDL信道：无法识别模型类型 "%s"。', channelTypeString);
end

numStr = regexp(channelTypeString, '\d+', 'match');
if ~isempty(numStr)
    maxDopplerShift = str2double(numStr{1});
else
    switch upper(modelType); case 'EPA'; maxDopplerShift = 5; case 'EVA'; maxDopplerShift = 70; case 'ETU'; maxDopplerShift = 70; end
    fprintf('自定义TDL信道：警告: "%s" 未指定多普勒, 默认为 %d Hz.\n', channelTypeString, maxDopplerShift);
end

pathDelays_s_col = selectedTable.("Excess tap delay[ns]") * 1e-9;
pathGains_dB_col = selectedTable.("Relative power[dB]");
pathDelays_s = pathDelays_s_col(:).';
pathGains_dB = pathGains_dB_col(:).';

% --- 2. 初始化输出信号 ---
pathDelays_samples = round(pathDelays_s * fs);
maxOverallDelay_samples = max(pathDelays_samples);
outputSignalLength = inputSignalLength + maxOverallDelay_samples;
fadedSignal = complex(zeros(outputSignalLength, 1));

numPaths = length(pathDelays_s);
actualPathGainsMatrix = complex(zeros(inputSignalLength, numPaths)); 

baseSeed = 1; 
if nargin > 3 && ~isempty(varargin{1}) && isnumeric(varargin{1})
    validateattributes(varargin{1}, {'double'}, {'scalar', 'nonnegative', 'integer', 'real'}, mfilename, 'OptionalSeedBase');
    baseSeed = varargin{1};
end

% --- 3. 为每个抽头(径)生成衰落并叠加 ---
for i = 1:numPaths
    currentDelay_samples = pathDelays_samples(i);
    currentAvgPower_linear = 10^(pathGains_dB(i) / 10);
    pathGainAmplitudeScale = sqrt(currentAvgPower_linear); % 幅度缩放因子

    pathSeed = baseSeed + i - 1; % 为每个径确保独立的、可重复的种子
    
    % **修改点：每次循环都创建一个新的 comm.RayleighChannel 对象**
    currentPathChanObj = comm.RayleighChannel(...
        'SampleRate',            fs, ...
        'PathDelays',            0, ... 
        'AveragePathGains',      0, ... % 对象输出的衰落平均功率为0dB (线性1)
        'MaximumDopplerShift',   maxDopplerShift, ...
        'RandomStream',          'mt19937ar with seed', ...
        'Seed',                  double(pathSeed), ... % 在创建时设置种子
        'PathGainsOutputPort',   true ...
        );
    % 新创建的对象不需要 reset 或 release 就可以设置Seed (通过构造函数) 或直接调用
    
    dummyInput = ones(inputSignalLength, 1); 
    [~, pathComplexGains] = currentPathChanObj(dummyInput); 
    actualPathGainsMatrix(:, i) = pathComplexGains; 

    fadedTxSignal_thisPath = txSignal .* pathComplexGains .* pathGainAmplitudeScale;
    
    startOutputIndex = currentDelay_samples + 1;
    endOutputIndex   = currentDelay_samples + inputSignalLength;
    fadedSignal(startOutputIndex:endOutputIndex) = fadedSignal(startOutputIndex:endOutputIndex) + fadedTxSignal_thisPath;
end

% --- 4. 填充 channelInfo ---
channelInfo.ChannelTypeUsed = sprintf('%s%d_CustomTDL', upper(modelType), maxDopplerShift);
channelInfo.ConfiguredPathDelays_s = pathDelays_s;
channelInfo.ConfiguredPathGains_dB = pathGains_dB;
channelInfo.PathDelays_samples = pathDelays_samples;
channelInfo.MaximumDopplerShift_Hz = maxDopplerShift;
channelInfo.SampleRate_Hz = fs;
channelInfo.BaseSeedUsed = baseSeed;
channelInfo.ActualPathGainsMatrix = actualPathGainsMatrix; 
channelInfo.InputSignalLength = inputSignalLength;
channelInfo.OutputSignalLength = outputSignalLength;
channelInfo.MaxOverallDelay_samples = maxOverallDelay_samples;

fprintf('自定义TDL信道 "%s" 处理完毕。\n', channelTypeString);

end