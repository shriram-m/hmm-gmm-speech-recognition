% This is the main function for the HMM GMM based speech recognition system.
function hmm_gmm_speech_recognition_main()
    clear

    train_indir='..\wav\train';
    train_in_filter='\.[Ww][Aa][Vv]';
    train_outdir='..\output\mfcc\train';

    test_indir='..\wav\test';
    test_in_filter='\.[Ww][Aa][Vv]';
    test_outdir='..\output\mfcc\test';

    keywords_list = {'marvin', 'off', 'on', 'up', 'down'};

    fprintf('\n=====================================================================\n');
    fprintf('        Welcome to the HMM-GMM based speech recognition demo!');
    fprintf('\n=====================================================================\n\n\n');

    fprintf('%s | Starting feature extraction for the training and testing dataset\n', datestr(now, 0));
    run_feature_extraction(train_indir, train_in_filter, train_outdir, test_indir, test_in_filter, test_outdir);
    fprintf('%s | Feature extraction complete!\n', datestr(now, 0));
    
    % Generate training file list
    training_file_list_name = '..\output\trainingfile_list.mat';
    dir1 = train_outdir;
    dir2 = keywords_list; % List of keywords
    k = 1;
    for model_id = 1 : length(dir2)
        files = dir(fullfile(dir1, dir2{model_id}, '*.mfc'));
        N = length(files); 
        for i = 1 : N
            thisfile = files(i).name; 

            trainingfile{k,1} = model_id;
            trainingfile{k,2} = fullfile(dir1, dir2{model_id}, thisfile);
            k = k + 1;
        end
    end
    fprintf('%s | Saving the training file list\n', datestr(now, 0));
    save(training_file_list_name, 'trainingfile');

    % Generate testing file list
    testing_file_list_name = '..\output\testingfile_list.mat';
    dir1 = test_outdir;
    dir2 = keywords_list; % List of keywords
    k = 1;
    for model_id = 1 : length(dir2)
        files = dir(fullfile(dir1, dir2{model_id}, '*.mfc'));
        N = length(files);
        N = 45;
        for i = 1 : N
            thisfile = files(i).name; 

            testingfile{k,1} = model_id;
            testingfile{k,2} = fullfile(dir1, dir2{model_id}, thisfile);
            k = k + 1;
        end
    end
    fprintf('%s | Saving the testing file list\n\n', datestr(now, 0));
    save(testing_file_list_name, 'testingfile');

    
    DIM = 39;                                       % dimension of the feature vector
    [~, num_of_model] = size(keywords_list);        % number of models: 'marvin', 'off', 'on', 'up', 'down'
    num_of_hmm_states = 13;                         % Note: number of states does not including START and END node in HMM
    max_iterations = 30;
    accuracy_rate = 0;

    output_likelihood_iter_path = '..\output\likelihood_iter.mat';
    output_log_likelihood_iter_path = '..\output\log_likelihood_iter.mat';
    hmm_model_output_dir = '..\output\models';
    testing_output_dir = '..\output\testing_results';


    fprintf('%s | Starting training phase...\n\n', datestr(now, 0));
    HMM = hmm_gmm_training(training_file_list_name, DIM, num_of_model, num_of_hmm_states, max_iterations, ...
                           output_likelihood_iter_path, output_log_likelihood_iter_path, hmm_model_output_dir);     % training phase
    
    fprintf('%s | Starting testing phase...\n\n', datestr(now, 0));
    accuracy_rate = hmm_gmm_testing(HMM, testing_file_list_name, testing_output_dir, false);                        % testing phase
    fprintf('accuracy_rate: %f\n', accuracy_rate);
    save(fullfile(testing_output_dir, 'accuracy_rate.mat'), 'accuracy_rate');
end