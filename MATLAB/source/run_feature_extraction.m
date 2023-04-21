function run_feature_extraction(train_indir, train_in_filter, train_outdir, test_indir, test_in_filter, test_outdir)

    out_ext='.mfc';
    outfile_format='htk';% htk format
    frame_size_sec = 0.025;
    frame_shift_sec= 0.010;
    use_hamming=1;
    pre_emp=0;
    bank_no=26;
    cep_order=12;
    lifter=22;

    delta_win=2;
    delta_win_weight = ones(1,2*delta_win+1);

    compute_feature_vectors(train_indir,train_in_filter,train_outdir,out_ext,outfile_format,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight);

    out_ext='.mfc';
    outfile_format='htk';% htk format
    frame_size_sec = 0.025;
    frame_shift_sec= 0.010;
    use_hamming=1;
    pre_emp=0;
    bank_no=26;
    cep_order=12;
    lifter=22;

    delta_win=2;
    delta_win_weight = ones(1,2*delta_win+1);

    compute_feature_vectors(test_indir,test_in_filter,test_outdir,out_ext,outfile_format,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight);
end

function compute_feature_vectors(indir,in_filter,outdir,out_ext,outfile_format,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight)
    if  indir(end) == '/' || indir(end) == '\'
        indir=indir(1:(end-1));
    end
    if  outdir(end) == '/' || outdir(end) == '\'
        ourdir=outdir(1:(end-1));
    end
    if exist(outdir) ~=7
        mkdir(outdir);
    end

    filelist=dir(indir);
    filelist_len=length(filelist);

    % filelist(1)='.'        % filelist(2)='..'  should be excluded
    for k=3:filelist_len
        [pathstr,filenamek,ext] = fileparts(filelist(k).name);
        if filelist(k).isdir
            compute_feature_vectors([indir filesep filenamek],in_filter,[outdir filesep filenamek],out_ext,outfile_format,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight);
        else
            if regexp(filelist(k).name,in_filter)
                infilename=fullfile(indir, filelist(k).name);
                outfilename=[outdir filesep filenamek out_ext];
                read_file_and_compute_mfcc(infilename,outfilename,outfile_format,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight);
            end
        end
    end
end

function feature_seq=read_file_and_compute_mfcc(infilename,outfilename,outfile_format,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight)
    [speech_raw, fs]=audioread(infilename,'native');
    speech_raw=double(speech_raw);

    % Add small amount of noise to prevent NaN sequance due to divide by zero error when the input is perfectly zeros.
    std_deviation = sqrt(0.05); 
    speech_raw = speech_raw + std_deviation * randn(size(speech_raw)); %% Adding Zero mean noise and variance = (std_deviation)^2

    feature_seq=wav2mfcc_e_d_a(speech_raw,fs,frame_size_sec,frame_shift_sec,use_hamming,pre_emp,bank_no,cep_order,lifter,delta_win_weight);

    [dim frame_no]=size(feature_seq);

    switch lower(outfile_format)
        case 'htk' % write htk header, big endian
            fout=fopen(outfilename,'w','b'); % 'n'==local machine format 'b'==big endian 'l'==little endian
            fwrite(fout,frame_no,'int32');
            sampPeriod=round(frame_shift_sec*1E7);    
            fwrite(fout,sampPeriod,'int32');
            sampSize=dim*4;   
            fwrite(fout,sampSize,'int16');
            parmKind=838; % parameter kind code: MFCC=6, _E=64, _D=256, _A=512, MFCC_E_D_A=6+64+256+512=838
            fwrite(fout,parmKind,'int16');  
        case 'b' %big endian  
            fout=fopen(outfilename,'w','b'); 
        case 'ieee-be' %big endian  
            fout=fopen(outfilename,'w','b');     
        case 'l' %little endian  
            fout=fopen(outfilename,'w','l'); 
        case 'ieee-le' %little endian  
            fout=fopen(outfilename,'w','l');          
        otherwise % no header
            fout=fopen(outfilename,'w','n'); % 'n'==local machine format 'b'==big endian 'l'==little endian
    end

    % write data
    fwrite(fout, feature_seq,'float32');

    fclose(fout);
end
