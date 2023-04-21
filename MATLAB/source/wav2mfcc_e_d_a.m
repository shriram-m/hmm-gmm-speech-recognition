%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Taken from:
% Lee-Min Lee, Hoang-Hiep Le
% EE Department, Dayeh University
% version 1 (2017-08-31)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function feature_seq=wav2mfcc_e_d_a(speech_raw,fs,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight)
   mfcc=wav2mfcc(speech_raw,fs,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter);
   logpow=wav2logpow(speech_raw,fs,frame_size_sec,frame_shift_sec);
   d_fea=(0.01/frame_shift_sec)*slope([mfcc;logpow],delta_win_weight); % in unit of 10ms
   dd_fea=(0.01/frame_shift_sec)*slope(d_fea,delta_win_weight); % in unit of 10ms
   feature_seq=[mfcc;logpow;d_fea;dd_fea];
end

% calculate the slope of an input vector sequence
% data outside the boundary are assumed to take the boundary values
function out_seq=slope(in_seq,window)
   N=length(window);
   if rem(N,2) == 1
      delta_win = (N-1)/2;
      [dim, frame_no]=size(in_seq);
      
      % prepend in_seq with the first vector and append it with the last vector.
      new_in_seq=[in_seq(:,1)*ones(1,delta_win) in_seq in_seq(:,frame_no)*ones(1,delta_win)];
      out_seq=0*in_seq;
      % time vector for slope estimation
      time_vec=-delta_win:delta_win;
      
      denominator=window*(time_vec.^2)';
      slope_vec=(window.*time_vec/denominator)';
      %delta  coefficient
      for fr=1:frame_no
         out_seq(:,fr)=new_in_seq(:,fr:fr+N-1) * slope_vec; 
      end
   end
end
 