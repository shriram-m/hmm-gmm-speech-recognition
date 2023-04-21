function accuracy_rate = hmm_gmm_testing(HMM, testing_file_list, testing_output_dir, save_test_results)

    if ~exist(testing_output_dir, 'dir')
        mkdir(testing_output_dir);
    end

    [~, ~, ~, num_of_model] = size(HMM.mean);
    num_of_error = 0;
    num_of_testing = 0;

    load (testing_file_list, 'testingfile');
    num_of_uter = size(testingfile,1);

    parfor u = 1:num_of_uter
        k = testingfile{u,1}; %%%%%% k: MODEL ID
        filename = testingfile{u,2};
        mfcfile = fopen(filename, 'r', 'b' );
        if mfcfile ~= -1
            fprintf('Testing file %s: %s\n', filename, datestr(now, 0));
            nSamples = fread(mfcfile, 1, 'int32');
            sampPeriod = fread(mfcfile, 1, 'int32')*1E-7;
            sampSize = fread(mfcfile, 1, 'int16');
            dim = 0.25*sampSize; % dim = 39
            parmKind = fread(mfcfile, 1, 'int16');
            
            features = fread(mfcfile, [dim, nSamples], 'float');
            fclose(mfcfile);
            
            num_of_testing = num_of_testing + 1;
            % predict which the digit is.......
            fopt_max = -Inf; digit = -1;
            for p = 1:num_of_model
                fopt = hmm_gmm_viterbi_decoding_algorithm(HMM.mean(:,:,:,p), HMM.var(:,:,:,p), HMM.weight(:,:,p), HMM.Aij(:,:,p), features, filename, save_test_results); % model k_th
                if fopt > fopt_max
                    digit = p;
                    fopt_max = fopt;
                end
            end
            if digit ~= k % testing
                num_of_error = num_of_error + 1;
            end
        end
    end
    accuracy_rate = (num_of_testing - num_of_error) * 100 / num_of_testing;
    
    % Save the accuracy in a file
    fileID = fopen(fullfile(testing_output_dir, 'accuracy_rate.txt'), 'a');
    t = datestr(now,'mmmm dd, yyyy HH:MM:SS.FFF AM');
    fprintf(fileID,'\n============================================================\n');
    fprintf(fileID,'%s\t\taccuracy rate: %f', t, accuracy_rate);
    fclose(fileID);
end

function fopt = hmm_gmm_viterbi_decoding_algorithm(mean, var, weight, aij, obs, filename, save_test_results)
    aij = cat(3,aij,aij*aij,aij*aij*aij);                       % in case frame loss
    [DIM, T] = size(obs);                                       % T: length of observations or number of observation frames
    [~, num_of_mix, num_of_state, ~] = size(mean);              % num_of_state: NOT including START and END states (nodes) in HMM
    num_of_state = num_of_state + 2;                            % number of states, including START and END states (nodes) in HMM
    mean_temp = NaN(DIM, num_of_mix, num_of_state);
    var_temp = NaN(DIM, num_of_mix, num_of_state);
    for i = 1:num_of_state-2
        mean_temp(:,:,i+1) = mean(:,:,i);
        var_temp(:,:,i+1) = var(:,:,i);
    end
    mean = mean_temp; var = var_temp;                           % insert value NaN for the state START and END
    weight = [NaN(1,num_of_mix); weight; NaN(1,num_of_mix)];
    aij(end,end) = 1;
    timing = 1:T+1;
    num_of_state = size(mean, 3);
    fjt = -Inf(num_of_state, T);
    s_chain = cell(num_of_state, T);
    
    %%%%%% at t = 1
    dt = timing(1);
    for j=2:num_of_state-1 % 2->14
        fjt(j,1) = log(aij(1,j,dt)) + log_hmm_gmm(mean(:,:,j),var(:,:,j),weight(j,:), obs(:,1));
        if fjt(j,1) > -Inf
            s_chain{j,1} = [1 j];
        end
    end
    
    for t=2:T
        dt = timing(t)-timing(t-1); % in case frame loss and dt = 2, 3, 4,...
        for j=2:num_of_state-1 %(2->14)
            f_max = -Inf;
            i_max = -1;
            f = -Inf;
            for i=2:j
                if(fjt(i,t-1) > -Inf)
                    f = fjt(i,t-1) + log(aij(i,j,dt)) + log_hmm_gmm(mean(:,:,j),var(:,:,j),weight(j,:), obs(:,t));
                end
                if f > f_max % finding the f max
                    f_max = f;
                    i_max = i; % index
                end
            end
            if i_max ~= -1
                s_chain{j,t} = [s_chain{i_max,t-1} j];
                fjt(j,t) = f_max;
            end
        end
    end
    %%%%%% at t = end
    dt = timing(end) - timing(end - 1); % in case frame loss and dt = 2, 3, 4,...
    fopt = -Inf;
    iopt = -1;
    for i=2:num_of_state-1
        f = fjt(i, T) + log(aij(i, num_of_state, dt));
        if f > fopt
            fopt = f;
            iopt = i;
        end
    end

    if save_test_results
        [pathstr, filename, ext] = fileparts(filename);
        save(fullfile('..\output\testing_results', sprintf('fjt_%s.mat', filename)), 'fjt');
        save(fullfile('..\output\testing_results', sprintf('fopt_%s.mat', filename)), 'fopt');
        save(fullfile('..\output\testing_results', sprintf('s_chain_%s.mat', filename)), 's_chain');
        save(fullfile('..\output\testing_results', sprintf('iopt_%s.mat', filename)), 'iopt');
    end
end

%% this function is for the case of multiple Gaussian HMM
function log_b = log_hmm_gmm(mean_i, var_i, c_j, o_i)
    [dim, num_of_mix] = size(mean_i);
    log_N = -Inf(1,num_of_mix);
    log_c = -Inf(1,num_of_mix);
    for m = 1:num_of_mix
        log_N(m) = -1/2*(dim*log(2*pi) + sum(log(var_i(:,m))) + sum((o_i - mean_i(:,m)).*(o_i - mean_i(:,m))./var_i(:,m)));
        log_c(m) = log(c_j(m));
    end
    y = -Inf(1,num_of_mix);
    ymax = -Inf;
    for m = 1:num_of_mix
        y(m) = log_N(m) + log_c(m);
        if y(m) > ymax
            ymax = y(m);
        end
    end
    if ymax == Inf
        log_b = Inf;
    else
        sum_exp = 0;
        for m = 1:num_of_mix
            if ymax == -Inf && y(m) == -Inf
                sum_exp = sum_exp + 1;
            else
                sum_exp = sum_exp + exp(y(m) - ymax);
            end
        end
        log_b = ymax + log(sum_exp);
    end
end
    