function symbolTypeSequence = generateSymbolTypeSequence(numDataSymbolsTotal, pilotPatternInterval)
% generateSymbolTypeSequence - 根据P,D,D,...,D,P模式生成符号类型序列
%
% 输入参数:
%   numDataSymbolsTotal  - 一个帧中数据OFDM符号的总数 (例如 50)
%   pilotPatternInterval - 数据符号的块长度，每隔这么多数据符号后插入一个导频
%                          (例如，对于P,D,D,D,D模式，这里是4)
%
% 输出:
%   symbolTypeSequence   - 字符串数组，标记每个符号是 "Pilot" 还是 "Data"

    if numDataSymbolsTotal < 0
        error('数据符号总数不能为负。');
    end
    if pilotPatternInterval <= 0
        error('导频图案间隔必须为正。');
    end

    if numDataSymbolsTotal == 0
        numPilotSymbols = 1; % 如果没有数据，至少发送一个导频符号
    else
        % 计算需要的导频数量：第一个是导频，然后每 pilotPatternInterval 个数据符号块前有一个导频
        % 例如，50个数据，间隔4: P [D1 D2 D3 D4] P [D5 D6 D7 D8] ... P [D49 D50]
        % 数据块的数量 = ceil(50/4) = 13 个数据块
        % 导频的数量 = 数据块的数量 = 13 个导频
        numPilotSymbols = ceil(numDataSymbolsTotal / pilotPatternInterval);
    end
    
    numTotalOFDMSymbols = numDataSymbolsTotal + numPilotSymbols;
    
    symbolTypeSequence = strings(1, numTotalOFDMSymbols);
    
    dataSymbolCounter = 0;
    pilotSymbolCounter = 0;
    
    currentSymbolIsPilot = true; % 第一个符号总是导频
    countInDataBlock = 0;

    for i = 1:numTotalOFDMSymbols
        if currentSymbolIsPilot
            if pilotSymbolCounter < numPilotSymbols
                symbolTypeSequence(i) = "Pilot";
                pilotSymbolCounter = pilotSymbolCounter + 1;
                currentSymbolIsPilot = false; % 下一个是数据（如果还有数据）
                countInDataBlock = 0;         % 重置数据块内计数器
            else 
                % 这种情况理论上不应该发生，如果总符号数和导频数计算正确
                % 若导频已插完，但总符号数未到，则剩余的应为数据（但需检查数据是否也已插完）
                if dataSymbolCounter < numDataSymbolsTotal
                    symbolTypeSequence(i) = "Data";
                    dataSymbolCounter = dataSymbolCounter + 1;
                else
                    warning('在符号 %d 处，导频和数据均已按预期数量放置完毕，但总符号数未到。', i);
                    break; % 提前终止
                end
            end
        else % 当前应该放置数据符号
            if dataSymbolCounter < numDataSymbolsTotal
                symbolTypeSequence(i) = "Data";
                dataSymbolCounter = dataSymbolCounter + 1;
                countInDataBlock = countInDataBlock + 1;
                if countInDataBlock == pilotPatternInterval % 当前数据块已满4个
                    if dataSymbolCounter < numDataSymbolsTotal % 如果后面还有数据要发
                        currentSymbolIsPilot = true; % 那么下一个就是导频
                    % else % 数据发完了，循环也快结束了，不需要再置下一个为导频
                    end
                end
            else
                % 数据已放完，但当前槽位不是导频（例如P,D,D，数据结束了，但块内还没到4个D）
                % 这种情况意味着最后一个导频后面跟的数据不足 pilotPatternInterval 个
                % 循环应该在所有数据和导频都放置后自然结束
                % 如果此分支被进入，说明 numTotalOFDMSymbols 的计算可能需要调整以精确匹配
                 warning('在符号 %d 处，数据已按预期数量放置完毕，但当前槽位不是导频。', i);
                 break; % 提前终止
            end
        end
    end
    
    % 最终验证
    if ~(sum(symbolTypeSequence=="Pilot") == numPilotSymbols && sum(symbolTypeSequence=="Data") == numDataSymbolsTotal && nnz(symbolTypeSequence~="") == numTotalOFDMSymbols)
        disp(symbolTypeSequence)
        error('OFDM数据模块：最终生成的导频/数据符号数量与预期不符。\n预计P:%d D:%d，实际P:%d D:%d (总分配%d/%d)。请检查逻辑。', ...
            numPilotSymbols, numDataSymbolsTotal, sum(symbolTypeSequence=="Pilot"), sum(symbolTypeSequence=="Data"), nnz(symbolTypeSequence~=""), numTotalOFDMSymbols);
    end
    
    fprintf('符号类型序列已生成: 共 %d 个OFDM符号 (数据 %d, 导频 %d)。\n', ...
        numTotalOFDMSymbols, numDataSymbolsTotal, numPilotSymbols);
end