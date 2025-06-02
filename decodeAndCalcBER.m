function [finalReceivedBits, BER, numErrors, bitsCompared] = decodeAndCalcBER(demappedBitsFromQPSK, originalSourceBits, codingIsEnabled, codeRateR)
% decodeAndCalcBER - (可选)重复码解码并计算误码率BER
%
% 输入参数:
%   demappedBitsFromQPSK - QPSK解调后的比特序列 (行向量)
%   originalSourceBits   - 原始发送的信息比特序列 (行向量)
%   codingIsEnabled      - 是否启用了信道编码 (logical)
%   codeRateR            - 信道编码的码率 (例如 1/3)。仅当 codingIsEnabled=true 时使用。
%
% 输出:
%   finalReceivedBits    - 解码后的最终信息比特序列 (行向量)
%   BER                  - 计算出的误码率
%   numErrors            - 错误比特的数量
%   bitsCompared         - 用于比较的总比特数

% 确保输入是行向量，以便后续处理
demappedBitsFromQPSK = demappedBitsFromQPSK(:).';
originalSourceBits = originalSourceBits(:).';

if codingIsEnabled
    if nargin < 4 || isempty(codeRateR)
        error('当启用信道编码时，必须提供编码率 codeRateR。');
    end
    validateattributes(codeRateR, {'numeric'}, {'scalar', 'positive', '>', 0, '<=', 1}, mfilename, 'codeRateR');

    repetitionFactor = round(1/codeRateR);
    if abs(1/codeRateR - repetitionFactor) > 1e-6 % 检查是否为重复码的整数因子
        error('提供的码率 R=%.2f (重复因子约 %.2f) 可能不适用于简单的重复码解码。此函数仅支持整数重复因子。', codeRateR, 1/codeRateR);
    end
    if repetitionFactor <= 1 && codeRateR < 1 % 码率小于1但重复因子不是大于1的整数
         error('码率 R=%.2f 无效或与重复码解码逻辑不符。', codeRateR);
    end

    fprintf('解码模块：启用重复码解码，重复因子 K = %d (码率 R = 1/%d)。\n', repetitionFactor, repetitionFactor);
    
    numCodedBits = length(demappedBitsFromQPSK);
    if mod(numCodedBits, repetitionFactor) ~= 0
        warning('解码模块：接收到的编码比特数 (%d) 不是重复因子 (%d) 的整数倍。可能导致解码错误或数据丢失。', numCodedBits, repetitionFactor);
        % 可以选择截断到最接近的整数倍，或者报错
        numCodedBits = floor(numCodedBits / repetitionFactor) * repetitionFactor;
        demappedBitsFromQPSK = demappedBitsFromQPSK(1:numCodedBits);
    end
    
    numOriginalBits_expected = numCodedBits / repetitionFactor;
    decoded_bits_temp = zeros(1, numOriginalBits_expected);
    
    for i = 1:numOriginalBits_expected
        start_idx = (i-1)*repetitionFactor + 1;
        end_idx = i*repetitionFactor;
        block_of_coded_bits = demappedBitsFromQPSK(start_idx:end_idx);
        
        % 硬判决：多数表决
        if sum(block_of_coded_bits) >= ceil(repetitionFactor/2) 
            % 如果1的个数大于等于重复因子的一半（向上取整），则判为1
            decoded_bits_temp(i) = 1;
        else
            decoded_bits_temp(i) = 0;
        end
    end
    finalReceivedBits = decoded_bits_temp;
else
    fprintf('解码模块：未启用信道编码。\n');
    finalReceivedBits = demappedBitsFromQPSK;
end

% --- BER 计算 ---
len_orig = length(originalSourceBits);
len_final = length(finalReceivedBits);

if len_final == 0 && len_orig == 0
    % 没有发送比特，也没有接收比特
    numErrors = 0;
    bitsCompared = 0;
    BER = 0; % 或者 NaN，取决于定义
    fprintf('BER计算：没有比特用于比较。\n');
    return;
elseif len_final == 0 && len_orig > 0
    warning('BER计算：解码/解映射后没有比特，但原始有 %d 比特。所有比特均视为错误。', len_orig);
    numErrors = len_orig;
    bitsCompared = len_orig;
    BER = 1.0;
    return;
end


% 确保比较的长度以 originalSourceBits 为准，如果解码后长度不匹配则发出警告
% 这通常暗示了整个链路中比特数量的计算或处理（如编码、QPSK符号池管理）存在问题
if len_final > len_orig
    warning('BER计算：解码/解映射后的比特流 (%d) 比原始信源比特 (%d) 长。将截断解码比特流以进行比较。', len_final, len_orig);
    finalReceivedBits_forBER = finalReceivedBits(1:len_orig);
    bitsCompared = len_orig;
elseif len_final < len_orig
    warning('BER计算：解码/解映射后的比特流 (%d) 比原始信源比特 (%d) 短。将仅比较有效长度部分，或者认为丢失的比特是错误的。', len_final, len_orig);
    % 策略：按较短的长度计算，或者将 originalSourceBits 截断（不推荐，因为丢失的也是错误）
    % 更公平的策略是，如果 finalReceivedBits 短了，认为丢失的那些都是错的。
    % 为简单起见，我们先按实际解码出的长度进行比较，并让 bitsCompared 反映这一点，
    % 但这可能低估实际的BER（如果比特真的丢失了）。
    % 理想情况下，len_final 应该严格等于 len_orig。
    originalSourceBits_forBER = originalSourceBits(1:len_final);
    bitsCompared = len_final;
    % 如果需要将丢失的比特视为错误：
    % numErrors = sum(finalReceivedBits(:) ~= originalSourceBits(1:len_final).') + (len_orig - len_final);
    % bitsCompared = len_orig;
else
    finalReceivedBits_forBER = finalReceivedBits;
    originalSourceBits_forBER = originalSourceBits;
    bitsCompared = len_orig;
end

numErrors = sum(finalReceivedBits_forBER(:) ~= originalSourceBits_forBER(:)); % 确保都是列向量再比较，或都是行向量
BER = numErrors / bitsCompared;

fprintf('BER计算结果：错误比特数 = %d, 比较总比特数 = %d, BER = %e\n', numErrors, bitsCompared, BER);

end