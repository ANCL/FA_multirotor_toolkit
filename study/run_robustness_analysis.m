function output = run_robustness_analysis()
%RUN_ROBUSTNESS_ANALYSIS Seeded perturbation trials with batch checkpoints.

[root,parameters,solver,runtime,cleanup] = begin_stage('robustness'); %#ok<NASGU>
try
    folders = output_folders(root);
    stage_folder = ensure_folder(folders.robustness);
    source_file = fullfile(folders.designs,'rotorwise_selected_designs.mat');
    if ~isfile(source_file), error('fa:MissingStage01','Run Stage 01 first.'); end
    design_provenance = assert_compatible_result( ...
        source_file,'design_comparison',parameters,solver);
    source = load(source_file,'selected');
    keep = ismember({source.selected.name},parameters.robustness.design_objectives);
    designs = source.selected(keep);
    if numel(designs) ~= numel(parameters.robustness.design_objectives)
        error('fa:MissingRobustnessDesigns', ...
            'Every requested objective must have a selected Stage 01 design.');
    end

    level_sets = {parameters.robustness.position_sigma, ...
        parameters.robustness.direction_sigma_rad, ...
        parameters.robustness.capacity_sigma,parameters.robustness.kappa_sigma};
    specifications = robustness_case_plan(designs,parameters,solver, ...
        runtime.robustness_batch_size);
    store = open_case_store(fullfile(ensure_folder(folders.checkpoints), ...
        '05_robustness'),'robustness');
    resumed = sum(arrayfun(@(x) case_store_has(store,x),specifications));
    logger = study_log('stage_start','Stage 05','Robustness analysis', ...
        numel(specifications),resumed);

    [batch_results,logger] = run_robustness_cases( ...
        specifications,store,logger,designs,parameters,solver,runtime);
    trial_blocks = {batch_results.trials};
    if isempty(trial_blocks)
        all_trials = struct([]);
    else
        all_trials = vertcat(trial_blocks{:});
    end
    expected_trials = numel(designs)*sum(cellfun(@numel,level_sets))* ...
        parameters.robustness.trials_per_level;
    if numel(all_trials) ~= expected_trials
        error('fa:IncompleteRobustnessTrials', ...
            'Expected %d robustness trials but found %d.', ...
            expected_trials,numel(all_trials));
    end
    keys = robustness_trial_keys(all_trials);
    if numel(unique(keys)) ~= expected_trials
        error('fa:DuplicateRobustnessTrials', ...
            'Robustness results contain duplicate or missing trial identifiers.');
    end

    summary = build_summary_table(all_trials);
    provenance = study_provenance('robustness',parameters,solver, ...
        provenance_plan(specifications),design_provenance);
    save(fullfile(stage_folder,'all_robustness_trials.mat'), ...
        'all_trials','expected_trials','parameters','solver','provenance','-v7.3');
    write_table_bundle(summary,stage_folder,'robustness_summary');
    output = struct('trials',all_trials,'summary',summary, ...
        'provenance',provenance,'folder',stage_folder);
    study_log('stage_finish',logger);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function keys = robustness_trial_keys(trials)
keys = strings(numel(trials),1);
for k = 1:numel(trials)
    keys(k) = sprintf('%s|%s|%.12g|%d',trials(k).design_name, ...
        trials(k).perturbation_type,trials(k).level,trials(k).trial_number);
end
end

function T = build_summary_table(trials)
if isempty(trials), T = table(); return; end
keys = strings(numel(trials),1);
for k = 1:numel(trials)
    keys(k) = sprintf('%s|%s|%.12g',trials(k).design_name, ...
        trials(k).perturbation_type,trials(k).level);
end
unique_keys = unique(keys,'stable'); row_cells = cell(numel(unique_keys),1);
for k = 1:numel(unique_keys)
    subset = trials(keys == unique_keys(k)); statistics = summarize_robustness(subset);
    row = struct('design_name',string(subset(1).design_name), ...
        'perturbation_type',string(subset(1).perturbation_type), ...
        'level',subset(1).level,'total_trials',statistics.total_trials, ...
        'evaluation_validity',statistics.rates.evaluation_valid.proportion, ...
        'evaluation_validity_lower_95',statistics.rates.evaluation_valid.lower_95, ...
        'evaluation_validity_upper_95',statistics.rates.evaluation_valid.upper_95, ...
        'geometric_feasibility',statistics.rates.geometric_feasible.proportion, ...
        'geometric_feasibility_lower_95',statistics.rates.geometric_feasible.lower_95, ...
        'geometric_feasibility_upper_95',statistics.rates.geometric_feasible.upper_95, ...
        'full_actuation_feasibility',statistics.rates.numerically_fully_actuated.proportion, ...
        'full_actuation_lower_95',statistics.rates.numerically_fully_actuated.lower_95, ...
        'full_actuation_upper_95',statistics.rates.numerically_fully_actuated.upper_95, ...
        'hover_feasibility',statistics.rates.hover_feasible.proportion, ...
        'hover_feasibility_lower_95',statistics.rates.hover_feasible.lower_95, ...
        'hover_feasibility_upper_95',statistics.rates.hover_feasible.upper_95, ...
        'task_feasibility',statistics.rates.task_feasible.proportion, ...
        'task_feasibility_lower_95',statistics.rates.task_feasible.lower_95, ...
        'task_feasibility_upper_95',statistics.rates.task_feasible.upper_95);
    metric_names = fieldnames(statistics.metrics);
    for metric_index = 1:numel(metric_names)
        name = metric_names{metric_index};
        row.([name '_median']) = statistics.metrics.(name).median;
        row.([name '_p05']) = statistics.metrics.(name).p05;
        row.([name '_p95']) = statistics.metrics.(name).p95;
        row.([name '_minimum']) = statistics.metrics.(name).minimum;
        row.([name '_maximum']) = statistics.metrics.(name).maximum;
        row.([name '_finite_count']) = statistics.metrics.(name).finite_count;
    end
    row_cells{k} = row;
end
T = struct2table(vertcat(row_cells{:}));
end
