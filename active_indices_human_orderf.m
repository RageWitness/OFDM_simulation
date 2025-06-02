%-----给出了数学序列的子载波符号映射位置--------
function [active_indices_human_order] = active_indices_human_orderf(N_fft_system ,N_sc)

left_guard_count = floor((N_fft_system - N_sc)/2);  % =212
active_indices_human_order = (left_guard_count+1) : ...
                             (left_guard_count+N_sc);
