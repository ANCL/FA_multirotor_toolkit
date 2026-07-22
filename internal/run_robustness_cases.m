function [results,logger,runtime] = run_robustness_cases( ...
    specifications,store,logger,designs,parameters,solver,runtime)
%RUN_ROBUSTNESS_CASES Execute and checkpoint independent robustness batches.
if ~all(arrayfun(@(x) isfield(x,'provenance') && ...
        isfield(x.provenance,'case_hash'),specifications))
    error('fa:UnfinalizedRobustnessPlan', ...
        'Robustness specifications must be finalized before execution.');
end
completed = arrayfun(@(x) case_store_has(store,x),specifications);
pending = specifications(~completed);
if isempty(pending)
    results = case_store_load(store,specifications);
    validate_robustness_results(results,specifications,designs,solver);
    return;
end
if ~runtime.parallel_enabled
    logger.concurrency = 1;
    for k = 1:numel(pending)
        specification = pending(k);
        study_log('case_start',specification.index,logger.total, ...
            specification.description);
        result = execute_robustness_case( ...
            specification,designs,parameters,solver);
        case_store_save(store,result.case_name,result);
        detail = robustness_detail(result.trials);
        logger = study_log('case_complete',logger,true,detail,result.elapsed_seconds);
    end
else
    [pool,runtime] = ensure_parallel_pool(runtime);
    study_log('line','Parallel case execution: %d workers.',runtime.active_workers);
    logger.concurrency = runtime.max_in_flight;
    futures = parallel.FevalFuture.empty(0,1);
    next_case = 1;
    try
        while next_case <= numel(pending) || ~isempty(futures)
            while next_case <= numel(pending) && ...
                    numel(futures) < runtime.max_in_flight
                specification = pending(next_case);
                study_log('case_dispatched',specification.index,logger.total, ...
                    specification.description);
                future = parfeval(pool,@execute_robustness_case,1, ...
                    specification,designs,parameters,solver);
                futures(end+1,1) = future; %#ok<AGROW>
                next_case = next_case+1;
            end
            [completed_index,result] = fetchNext(futures);
            futures(completed_index) = [];
            case_store_save(store,result.case_name,result);
            detail = [result.description ' | ' robustness_detail(result.trials)];
            logger = study_log('case_complete',logger,true,detail,result.elapsed_seconds);
        end
    catch ME
        if ~isempty(futures)
            try
                cancel(futures);
            catch
                % Preserve the original queue or checkpoint error.
            end
        end
        rethrow(ME);
    end
end
results = case_store_load(store,specifications);
validate_robustness_results(results,specifications,designs,solver);
end

function detail = robustness_detail(trials)
valid = [trials.evaluation_valid];
task = [trials.task_feasible];
detail = sprintf('%d trials | valid %d | task-feasible %d', ...
    numel(trials),sum(valid),sum(task));
end

function validate_robustness_results(results,specifications,designs,solver)
%VALIDATE_ROBUSTNESS_RESULTS Guard batch identity and deterministic trial seeds.
if numel(results) ~= numel(specifications)
    error('fa:RobustnessCaseCount', ...
        'Robustness queue returned an unexpected number of batches.');
end
for k = 1:numel(specifications)
    specification = specifications(k);
    result = results(k);
    if ~strcmp(result.case_name,specification.case_name) || ...
            ~strcmp(result.type,specification.type) || ...
            result.level ~= specification.level || ...
            ~isequal(result.trial_numbers,specification.trial_numbers) || ...
            ~isfield(result,'case_provenance') || ...
            ~strcmp(result.case_provenance.case_hash, ...
                specification.provenance.case_hash)
        error('fa:RobustnessCaseIdentity', ...
            'Robustness checkpoint identity is inconsistent for %s.', ...
            specification.case_name);
    end
    trials = result.trials;
    if numel(trials) ~= numel(specification.trial_numbers)
        error('fa:RobustnessTrialCount', ...
            'Robustness batch %s has an incorrect trial count.', ...
            specification.case_name);
    end
    design_name = designs(specification.design_index).name;
    for j = 1:numel(trials)
        trial_number = specification.trial_numbers(j);
        label = sprintf('%s__%s__%.12g__%d', ...
            design_name,specification.type,specification.level,trial_number);
        expected_seed = stable_seed(solver.master_seed,label);
        if ~strcmp(trials(j).design_name,design_name) || ...
                ~strcmp(trials(j).perturbation_type,specification.type) || ...
                trials(j).level ~= specification.level || ...
                trials(j).trial_number ~= trial_number || ...
                trials(j).seed ~= expected_seed
            error('fa:RobustnessTrialIdentity', ...
                'Robustness trial identity is inconsistent in %s.', ...
                specification.case_name);
        end
    end
end
end

