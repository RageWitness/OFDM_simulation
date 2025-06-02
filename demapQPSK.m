function demappedBits = demapQPSK(receivedSymbols)
% demapQPSK - 对输入的QPSK复数符号序列进行解映射，恢复比特流
%
% 输入参数:
%   receivedSymbols - 经过均衡后的串行QPSK复数符号序列 (行向量或列向量)
%
% 输出:
%   demappedBits    - 解映射得到的二进制比特序列 (行向量)
M = 4; 

demappedBits = qamdemod(receivedSymbols, M, ...
                        'OutputType', 'bit', ...
                        'UnitAveragePower', true); ... % 与发射端匹配
                        
demappedBits = demappedBits(:).'; % 确保输出为行向量
end