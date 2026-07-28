function [records,logger,runtime] = run_optimization_cases( ...
    specifications,store,logger,solver,runtime)
%RUN_OPTIMIZATION_CASES Execute missing cases and return compact records.
% Full solver payloads are authoritative in checkpoint/cases. Every completed
% checkpoint has a compact twin in checkpoint/records. Normal stage logic
% operates only on these twins, so completed studies never reload all solver
% histories into memory.
if isempty(specifications), records = struct([]); return; end
if ~all(arrayfun(@(x) isfield(x,'provenance') && ...
        isfield(x.provenance,'case_hash'),specifications))
    error('fa:UnfinalizedOptimizationPlan', ...
        'Optimization specifications must be finalized before execution.');
end

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
execution = struct('log_optimizer_progress',~runtime.parallel_enabled);
if isempty(pending)
    records = reshape(horzcat(items{:}),1,[]);
    validate_case_records(records,specifications);
    return;
end

study_log('line','Numerical optimization required: %d new case(s).',numel(pending));
if ~runtime.parallel_enabled
    logger.concurrency = 1;
    for k = 1:numel(pending)
        specification = pending(k);
        original_index = pending_indices(k);
        study_log('case_start',specification.index,logger.total, ...
            specification.description);
        result = execute_optimization_case(specification,solver,execution);
        record = case_store_save(store,specification.case_name,result);
        validate_case_result_identity(record,specification, ...
            case_record_path(store,specification.case_name));
        items{original_index} = record;
        logger = study_log('optimization_complete',logger,result, ...
            result.elapsed_seconds);
    end
else
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
                future = parfeval(pool,@execute_optimization_case,1, ...
                    specification,solver,execution);
                futures(end+1,1) = future; %#ok<AGROW>
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
            record = case_store_save(store,specification.case_name,result);
            validate_case_result_identity(record,specification, ...
                case_record_path(store,specification.case_name));
            items{original_index} = record;
            logger = study_log('optimization_complete_case',logger,result, ...
                result.elapsed_seconds,specification.description);
        end
    catch ME
        if ~isempty(futures)
            try, cancel(futures); catch, end
        end
        rethrow(ME);
    end
end

records = reshape(horzcat(items{:}),1,[]);
validate_case_records(records,specifications);
end

function validate_case_records(records,specifications)
if numel(records) ~= numel(specifications)
    error('fa:OptimizationCaseCount', ...
        'Optimization queue returned an unexpected number of compact records.');
end
for k = 1:numel(specifications)
    validate_case_result_identity(records(k),specifications(k),'<compact record>');
end
end
