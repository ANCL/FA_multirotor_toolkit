function [records,logger,runtime] = run_robustness_cases( ...
    specifications,store,logger,designs,parameters,solver,runtime)
%RUN_ROBUSTNESS_CASES Execute missing batches and return compact twins.
if ~all(arrayfun(@(x) isfield(x,'provenance') && ...
        isfield(x.provenance,'case_hash'),specifications))
    error('fa:UnfinalizedRobustnessPlan', ...
        'Robustness specifications must be finalized before execution.');
end
if isempty(specifications), records = struct([]); return; end

inventory = case_store_inventory(store,specifications);
study_log('line','Checkpoint store: %d/%d full | %d/%d compact.', ...
    inventory.full_count,inventory.expected, ...
    inventory.record_count,inventory.expected);
items = cell(numel(specifications),1);

completed_indices = find(inventory.full_exists);
if ~isempty(completed_indices)
    completed_specifications = specifications(completed_indices);
    [completed_records,runtime] = reconcile_case_records( ...
        completed_specifications,store,runtime);
    for k = 1:numel(completed_indices)
        items{completed_indices(k)} = completed_records(k);
    end
end

pending_indices = find(~inventory.full_exists);
pending = specifications(pending_indices);
if ~isempty(pending)
    study_log('line','Robustness computation required: %d new batch(es).',numel(pending));
end
if ~runtime.parallel_enabled
    logger.concurrency = 1;
    for k = 1:numel(pending)
        specification = pending(k);
        original_index = pending_indices(k);
        study_log('case_start',specification.index,logger.total, ...
            specification.description);
        result = execute_robustness_case( ...
            specification,designs,parameters,solver);
        record = case_store_save(store,result.case_name,result);
        validate_case_result_identity(record,specification, ...
            case_record_path(store,specification.case_name));
        items{original_index} = record;
        detail = robustness_detail(result.trials);
        logger = study_log('case_complete',logger,true,detail,result.elapsed_seconds);
    end
else
    if ~isempty(pending)
        [pool,runtime] = ensure_parallel_pool(runtime);
        study_log('line','Parallel case execution: %d workers.',runtime.active_workers);
        logger.concurrency = runtime.max_in_flight;
        futures = parallel.FevalFuture.empty(0,1);
        in_flight_specifications = cell(0,1);
        in_flight_indices = zeros(0,1);
        next_case = 1;
        try
            while next_case <= numel(pending) || ~isempty(futures)
                while next_case <= numel(pending) && ...
                        numel(futures) < runtime.max_in_flight
                    specification = pending(next_case);
                    original_index = pending_indices(next_case);
                    study_log('case_dispatched',specification.index,logger.total, ...
                        specification.description);
                    futures(end+1,1) = parfeval(pool,@execute_robustness_case,1, ...
                        specification,designs,parameters,solver); %#ok<AGROW>
                    in_flight_specifications{end+1,1} = specification; %#ok<AGROW>
                    in_flight_indices(end+1,1) = original_index; %#ok<AGROW>
                    next_case = next_case+1;
                end
                [completed_index,result] = fetchNext(futures);
                specification = in_flight_specifications{completed_index};
                original_index = in_flight_indices(completed_index);
                futures(completed_index) = [];
                in_flight_specifications(completed_index) = [];
                in_flight_indices(completed_index) = [];
                record = case_store_save(store,result.case_name,result);
                validate_case_result_identity(record,specification, ...
                    case_record_path(store,specification.case_name));
                items{original_index} = record;
                detail = [result.description ' | ' robustness_detail(result.trials)];
                logger = study_log('case_complete',logger,true,detail,result.elapsed_seconds);
            end
        catch ME
            if ~isempty(futures)
                try, cancel(futures); catch, end
            end
            rethrow(ME);
        end
    end
end

records = reshape(horzcat(items{:}),1,[]);
validate_robustness_results(records,specifications,designs,solver);
end

function detail = robustness_detail(trials)
valid = [trials.evaluation_valid];
detail = sprintf('%d trials | valid %d',numel(trials),sum(valid));
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
    validate_case_result_identity(result,specification,'<compact robustness record>');
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
