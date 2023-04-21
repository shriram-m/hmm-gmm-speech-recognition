function HMM = hmm_gmm_training(training_file_list, DIM, num_of_model, num_of_state, max_iterations, ...
    output_likelihood_iter_path, output_log_likelihood_iter_path, hmm_model_output_dir)

    % This function deals with HMM-GMM training problem. The programe will run as follow: initialization HMM,
    % re-estimating HMM, mixture spliting, re-estimating HMM, mixture spliting, so on. Depend on number of 
    % mixture we want to split and how many iterations we want to re-estimating, user may modify procedure by himself.

    if exist(hmm_model_output_dir, 'dir')
        fprintf('%s | Removing existing models directory...\n', datestr(now, 0));
        rmdir(hmm_model_output_dir);
    end
    mkdir(hmm_model_output_dir);

    % generate initial HMM or global means, vars
    HMM = initialize_hmm_model(training_file_list, DIM, num_of_state, num_of_model, hmm_model_output_dir);

    load (training_file_list, 'trainingfile');

    log_likelihood_iter = zeros(1, 35);
    likelihood_iter = zeros(1, 35);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% re-estimating
    for iter = 1:5
        fprintf('%s | Starting training iteration %d\n', datestr(now, 0), iter);
        [HMM, likelihood, log_likelihood] = hmm_gmm_training_baum_welch_algorithm(HMM, trainingfile);
        log_likelihood_iter(iter) = log_likelihood;
        likelihood_iter(iter) = likelihood;
        save_hmm_model_to_file(HMM, hmm_model_output_dir, iter);
    end
    fprintf('%s | Iterations 1 to 5 complete!\n', datestr(now, 0));

    if max_iterations >= 10
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% spliting
        HMM = split_hmm(HMM); save_hmm_model_to_file(HMM, hmm_model_output_dir, iter+1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% re-estimating
        for iter = 7:10
            fprintf('%s | Starting training iteration %d\n', datestr(now, 0), iter);
            [HMM, likelihood, log_likelihood] = hmm_gmm_training_baum_welch_algorithm(HMM, trainingfile);
            log_likelihood_iter(iter) = log_likelihood;
            likelihood_iter(iter) = likelihood;
            save_hmm_model_to_file(HMM, hmm_model_output_dir, iter);
        end
        fprintf('%s | Iterations 7 to 10 complete!\n', datestr(now, 0));
    end

    if max_iterations >= 20
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% spliting
        HMM = split_hmm(HMM); save_hmm_model_to_file(HMM, hmm_model_output_dir, iter+1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% re-estimating
        for iter = 12:20
            fprintf('%s | Starting training iteration %d\n', datestr(now, 0), iter);
            [HMM, likelihood, log_likelihood] = hmm_gmm_training_baum_welch_algorithm(HMM, trainingfile);
            log_likelihood_iter(iter) = log_likelihood;
            likelihood_iter(iter) = likelihood;
            save_hmm_model_to_file(HMM, hmm_model_output_dir, iter);
        end
        fprintf('%s | Iterations 12 to 20 complete!\n', datestr(now, 0));
    end

    if max_iterations >= 30
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% spliting
        HMM = split_hmm(HMM); save_hmm_model_to_file(HMM, hmm_model_output_dir, iter+1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% re-estimating
        for iter = 22:30
            fprintf('%s | Starting training iteration %d\n', datestr(now, 0), iter);
            [HMM, likelihood, log_likelihood] = hmm_gmm_training_baum_welch_algorithm(HMM, trainingfile);
            log_likelihood_iter(iter) = log_likelihood;
            likelihood_iter(iter) = likelihood;
            save_hmm_model_to_file(HMM, hmm_model_output_dir, iter);
        end
        fprintf('%s | Iterations 22 to 30 complete!\n', datestr(now, 0));
    end

    fprintf('%s | Training phase complete !!\n', datestr(now, 0));

    save(output_likelihood_iter_path, 'likelihood_iter');
    save(output_log_likelihood_iter_path, 'log_likelihood_iter');

    % % % % % log_likelihood_iter % TODO
    % % % % % likelihood_iter
    % figure();
    % plot(log_likelihood_iter,'-*');
    % xlabel('iterations'); ylabel('log likelihood');
    % title(['number of states: ', num2str(num_of_state)]);
end

%%
function HMM = initialize_hmm_model(training_file_list, DIM, num_of_state, num_of_model, hmm_model_output_dir)
    HMM.mean = zeros(DIM, 1, num_of_state, num_of_model);
    HMM.var  =  zeros(DIM, 1, num_of_state, num_of_model);
    HMM.Aij  = zeros(num_of_state+2, num_of_state+2, num_of_model);
    HMM.weight = ones(num_of_state,1,num_of_model);

    sum_of_features = zeros(DIM,1);
    sum_of_features_square = zeros(DIM, 1);
    num_of_feature = 0;

    load (training_file_list, 'trainingfile');
    num_of_uter = size(trainingfile,1);

    for u = 1:num_of_uter
        filename = trainingfile{u,2};
        mfcfile = fopen(filename, 'r', 'b');
        if mfcfile ~= -1
            nSamples = fread(mfcfile, 1, 'int32');
            sampPeriod = fread(mfcfile, 1, 'int32')*1E-7;
            sampSize = fread(mfcfile, 1, 'int16');
            dim = 0.25*sampSize; % dim = 39
            parmKind = fread(mfcfile, 1, 'int16');
            
            features = fread(mfcfile, [dim, nSamples], 'float');
            
            sum_of_features = sum_of_features + sum(features, 2); % for calculating mean
            sum_of_features_square = sum_of_features_square + sum(features.^2, 2); % for calculating variance
            num_of_feature = num_of_feature + size(features,2); % number of elements (feature vectors) in state m of model k
            
            fclose(mfcfile);
        end    
    end
    % calculate value of means, variances, aijs
    HMM = calculate_inital_mean_var_aij(HMM, num_of_state, num_of_model, sum_of_features, sum_of_features_square, num_of_feature);
    save_hmm_model_to_file(HMM, hmm_model_output_dir, 0);
end


function HMM = calculate_inital_mean_var_aij(HMM, num_of_state, num_of_model, sum_of_features, sum_of_features_square, num_of_feature)
    for k = 1:num_of_model
        for m = 1:num_of_state
            HMM.mean(:,1,m,k) = sum_of_features/num_of_feature;
            HMM.var(:,1,m,k) = sum_of_features_square/num_of_feature - HMM.mean(:,1,m,k).*HMM.mean(:,1,m,k);
        end
        for i = 2:num_of_state+1
            HMM.Aij(i,i+1,k) = 0.4;
            HMM.Aij(i,i,k) = 1-HMM.Aij(i,i+1,k);        
        end
        HMM.Aij(1,2,k) = 1;
    end
end


function save_hmm_model_to_file(HMM, hmm_model_output_dir, iter)   
    hmm_output_file = sprintf('HMM_%d.mat', iter);
    save(fullfile(hmm_model_output_dir, hmm_output_file), 'HMM');    
end

function HMM_new = split_hmm(HMM)
    % This function is for mixture incrementing or mixture splitting
    [DIM, num_of_recent_mix, num_of_state, num_of_model] = size(HMM.mean);
    mean = zeros(DIM, num_of_recent_mix+1, num_of_state, num_of_model);
    var = zeros(DIM, num_of_recent_mix+1, num_of_state, num_of_model);
    weight = zeros(num_of_state, num_of_recent_mix+1, num_of_model);
    HMM_new.mean = mean;
    HMM_new.var = var;
    HMM_new.weight = weight;
    HMM_new.Aij = HMM.Aij;
    for k = 1:num_of_model
        for i = 1:num_of_state
            [~, id_max] = max(HMM.weight(i,:,k));
            HMM_new = spliting_for_each_state(HMM_new, HMM, id_max, i, k);
        end
    end
end
    
function HMM_new = spliting_for_each_state(HMM_new, HMM, id_max, i, k)
    rate = 0.2; % according to HTK book (page 157)
    [~, num_of_recent_mix, ~, ~] = size(HMM.mean);
    %%
    HMM_new.mean(:,1:num_of_recent_mix,i,k) = HMM.mean(:,1:num_of_recent_mix,i,k);
    HMM_new.mean(:,num_of_recent_mix+1,i,k) = HMM.mean(:,id_max,i,k) - rate*sqrt(HMM.var(:,id_max,i,k));
    HMM_new.mean(:,id_max,i,k) = HMM.mean(:,id_max,i,k) + rate*sqrt(HMM.var(:,id_max,i,k));
    %%
    HMM_new.var(:,1:num_of_recent_mix,i,k) = HMM.var(:,1:num_of_recent_mix,i,k);
    HMM_new.var(:,num_of_recent_mix+1,i,k) = HMM.var(:,id_max,i,k);
    %%
    HMM_new.weight(i,1:num_of_recent_mix,k) = HMM.weight(i,1:num_of_recent_mix,k);
    HMM_new.weight(i,num_of_recent_mix+1,k) = HMM.weight(i,id_max,k)/2;
    HMM_new.weight(i,id_max,k) = HMM.weight(i,id_max,k)/2;
end

function [HMM, likelihood, log_likelihood] = hmm_gmm_training_baum_welch_algorithm(HMM, trainingfile)    
    log_likelihood = 0;
    likelihood = 0;
    num_of_uter = size(trainingfile,1);
    [DIM, num_of_mix, num_of_state, num_of_model] = size(HMM.mean); % N: number of states, NOT including START and END states (nodes) in HMM
    [sum_mean_numerator, sum_var_numerator, sum_mean_var_denominator, sum_wei_numerator, sum_wei_denominator, sum_aij_numerator] = ...
        initial_sum_mean_var_aij(DIM, num_of_mix, num_of_state, num_of_model);
    
    for u = 1:num_of_uter
        
        model_id = trainingfile{u,1}; % model_id: MODEL ID (0, 1, 2,..., 9)
        filename = trainingfile{u,2};
        
        mfcfile = fopen(filename, 'r', 'b' );
        if mfcfile ~= -1
            nSamples = fread(mfcfile, 1, 'int32');
            sampPeriod = fread(mfcfile, 1, 'int32')*1E-7;
            sampSize = fread(mfcfile, 1, 'int16');
            dim = 0.25*sampSize; % dim = 39
            parmKind = fread(mfcfile, 1, 'int16');
            
            features = fread(mfcfile, [dim, nSamples], 'float');
            
            [mean_numerator, var_numerator, mean_var_denominator, wei_numerator, wei_denominator, aij_numerator, log_likelihood_i, likelihood_i] =...
                forward_backward_hmm_gmm_log_math(HMM.mean(:,:,:,model_id), HMM.var(:,:,:,model_id), HMM.Aij(:,:,model_id), HMM.weight(:,:,model_id), features); % model k_th
            
            sum_mean_numerator(:,:,:,model_id) = sum_mean_numerator(:,:,:,model_id) + mean_numerator(:,:,2:end-1);
            sum_var_numerator(:,:,:,model_id) = sum_var_numerator(:,:,:,model_id) + var_numerator(:,:,2:end-1);
            sum_mean_var_denominator(:,:,model_id) = sum_mean_var_denominator(:,:,model_id) + mean_var_denominator(2:end-1,:);        
            sum_wei_numerator(:,:,model_id) = sum_wei_numerator(:,:,model_id) + wei_numerator(2:end-1,:);
            sum_wei_denominator(:,model_id) = sum_wei_denominator(:,model_id) + wei_denominator(2:end-1);
            sum_aij_numerator(:,:,model_id) = sum_aij_numerator(:,:,model_id) + aij_numerator(2:end-1,2:end-1);
            
            log_likelihood = log_likelihood + log_likelihood_i;
            likelihood = likelihood + likelihood_i;
            
            fclose(mfcfile);        
        end
    end
    
    % calculate value of means, variances, weight, aij
    for model_id = 1:num_of_model
        for n = 1:num_of_state
            for k = 1:num_of_mix
                HMM.mean(:,k,n,model_id) = sum_mean_numerator(:,k,n,model_id) / sum_mean_var_denominator (n,k,model_id);
                HMM.var (:,k,n,model_id) = sum_var_numerator(:,k,n,model_id) / sum_mean_var_denominator (n,k,model_id) -  HMM.mean(:,k,n,model_id).* HMM.mean(:,k,n,model_id);
                HMM.weight(n,k,model_id) = sum_wei_numerator(n,k,model_id) / sum_wei_denominator (n,model_id);
            end
        end
    end
    for model_id = 1:num_of_model
        for i = 2:num_of_state+1
            for j = 2:num_of_state+1
                HMM.Aij (i,j,model_id) = sum_aij_numerator(i-1,j-1,model_id) / sum_wei_denominator (i-1,model_id);
            end
        end
        HMM.Aij (num_of_state+1,num_of_state+2,model_id) = 1 - HMM.Aij (num_of_state+1,num_of_state+1,model_id);
    end
end

% initialization of value of sum_of_features, sum_of_features_square, num_of_feature, num_of_jump
function [sum_mean_numerator, sum_var_numerator, sum_mean_var_denominator, sum_wei_numerator, sum_wei_denominator, sum_aij_numerator] = ...
    initial_sum_mean_var_aij(DIM, num_of_mix, num_of_state, num_of_model)

    sum_mean_numerator = zeros(DIM, num_of_mix, num_of_state, num_of_model);
    sum_var_numerator = zeros(DIM, num_of_mix, num_of_state, num_of_model);
    sum_mean_var_denominator = zeros(num_of_state, num_of_mix, num_of_model);
    sum_wei_numerator = zeros(num_of_state, num_of_mix, num_of_model);
    sum_wei_denominator = zeros(num_of_state, num_of_model);
    sum_aij_numerator = zeros(num_of_state, num_of_state, num_of_model);    
end