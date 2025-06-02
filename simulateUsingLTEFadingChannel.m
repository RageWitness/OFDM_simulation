function [fadedSignal, channelInfo] = simulateUsingLTEFadingChannel(txSignal, fs, channelTypeString, varargin)
% simulateUsingLTEFadingChannel - 使用 lteFadingChannel 和基于表格的参数模拟信道
%
% 输入:
%   txSignal         - 复数基带输入信号 (应为列向量)
%   fs               - txSignal 的采样率 (Hz)
%   channelTypeString - 字符串，指定信道模型和多普勒频率，不区分大小写。
%                       例如: 'EPA5', 'EVA70', 'ETU70', 'ETU300'
%   varargin{1}      - (可选) 随机数种子 (标量, double类型的非负整数)
%
% 输出:
%   fadedSignal      - 经过衰落信道后的复数基带信号 (列向量)
%   channelInfo      - lteFadingChannel 返回的包含信道信息的结构体

% --- 0. 确保 txSignal 是列向量 ---
if ~iscolumn(txSignal)
    if isrow(txSignal)
        txSignal = txSignal.'; 
        fprintf('提示 (simulateUsingLTEFadingChannel): 输入的 txSignal 是行向量，已自动转置为列向量。\n');
    else
        if size(txSignal,2) > 1
             error('simulateUsingLTEFadingChannel: txSignal 输入有 %d 列，但此函数目前按SISO处理（期望1列）。', size(txSignal,2));
        else 
            txSignal = txSignal(:);
            if ~iscolumn(txSignal) 
                 error('simulateUsingLTEFadingChannel: txSignal 输入格式无法处理为列向量。');
            end
        end
    end
end

% --- 1. 使用persistent变量存储表格数据，避免重复读取 ---
persistent epaTable evaTable etuTable tableDataLoaded;

if isempty(tableDataLoaded)
    try
        epaTable = readtable('Table B.2.1-2 Extended Pedestrian A model (EPA).xlsx', 'VariableNamingRule', 'preserve');
        evaTable = readtable('Table B.2.1-3 Extended Vehicular A model (EVA).xlsx', 'VariableNamingRule', 'preserve');
        etuTable = readtable('Table B.2.1-4 Extended Typical Urban model (ETU).xlsx', 'VariableNamingRule', 'preserve');
        tableDataLoaded = true;
        disp('信道参数表格已由 simulateUsingLTEFadingChannel 加载。');
    catch ME
        error('simulateUsingLTEFadingChannel: 无法加载信道参数表格，请确保 .xlsx 文件在MATLAB路径中: %s', ME.message);
    end
end

% --- 2. 解析 channelTypeString 来确定模型类型和多普勒频率 ---
modelBaseType = ''; 
maxDopplerShift = 0;

if contains(channelTypeString, 'EPA', 'IgnoreCase', true)
    modelBaseType = 'EPA';
    selectedTable = epaTable;
elseif contains(channelTypeString, 'EVA', 'IgnoreCase', true)
    modelBaseType = 'EVA';
    selectedTable = evaTable;
elseif contains(channelTypeString, 'ETU', 'IgnoreCase', true)
    modelBaseType = 'ETU';
    selectedTable = etuTable;
else
    error('无法从 "%s" 中识别出 EPA, EVA, 或 ETU 模型类型。', channelTypeString);
end

numStr = regexp(channelTypeString, '\d+', 'match');
if ~isempty(numStr)
    maxDopplerShift = str2double(numStr{1});
else 
    switch upper(modelBaseType)
        case 'EPA'
            maxDopplerShift = 5; 
        case 'EVA'
            maxDopplerShift = 70; 
        case 'ETU'
            maxDopplerShift = 70; 
    end
    fprintf('警告: 信道 "%s" 未明确指定多普勒频率, 为 %s 模型默认为 %d Hz.\n', channelTypeString, modelBaseType, maxDopplerShift);
end

% --- 3. 从选定的表格中提取路径延迟和增益 ---
pathDelays_s = selectedTable.("Excess tap delay[ns]") * 1e-9;   
pathGains_dB = selectedTable.("Relative power[dB]");          

if ~iscolumn(pathDelays_s); pathDelays_s = pathDelays_s.'; end
if ~iscolumn(pathGains_dB); pathGains_dB = pathGains_dB.'; end

% --- 4. 构建 lteFadingChannel 所需的配置结构体 ---
modelConfig = struct();
modelConfig.DelayProfile        = 'Custom'; 
modelConfig.PathDelays          = pathDelays_s; 
% **关键修正点：更改字段名的大小写以匹配错误提示**
modelConfig.AveragePathGaindB  = pathGains_dB; % 原为 AveragePathGainsDB
modelConfig.DopplerFreq         = maxDopplerShift;
modelConfig.SamplingRate        = fs;
modelConfig.NRxAnts             = 1;          
modelConfig.MIMOCorrelation     = 'Low';      
modelConfig.InitTime            = 0;
    % ==== 【关键修改】====
    modelConfig.NormalizePathGains  = 'On';    % 原来写成 true，现在改为 'On'
    modelConfig.PathGainsOutputPort = 'On';    % 原来写成 true，现在改为 'On'
    % 注意：如果不需要归一化或不关心路径增益，可以设成 'Off'
if nargin > 3 && ~isempty(varargin{1}) && isnumeric(varargin{1})
    userSeed = varargin{1};
    validateattributes(userSeed, {'double', 'single'}, {'scalar', 'nonnegative', 'integer', 'real'}, mfilename, 'OptionalSeed');
    modelConfig.Seed            = userSeed;
else
    modelConfig.Seed            = randi([0, 2^32-2]); 
end

% --- 5. 调用 lteFadingChannel ---
[fadedSignal, channelInfo] = lteFadingChannel(modelConfig, txSignal); % 出错行是这里

% --- 6. (可选) 附加一些配置信息到 channelInfo ---
channelInfo.ChannelTypeUsed = sprintf('%s%d', upper(modelBaseType), maxDopplerShift);
channelInfo.ConfiguredPathDelays_s = pathDelays_s;
channelInfo.ConfiguredPathGains_dB = pathGains_dB;
channelInfo.ConfiguredDopplerFreq_Hz = maxDopplerShift;
channelInfo.ConfiguredSamplingRate_Hz = fs;
channelInfo.SeedUsed = modelConfig.Seed;
channelInfo.InputSignalLength = size(txSignal,1);
channelInfo.OutputSignalLength = size(fadedSignal,1); 

fprintf('lteFadingChannel 处理完毕: %s, fs=%.2fMHz, Seed=%d. 输出长度: %d\n', ...
        channelInfo.ChannelTypeUsed, fs/1e6, channelInfo.SeedUsed, channelInfo.OutputSignalLength);

end