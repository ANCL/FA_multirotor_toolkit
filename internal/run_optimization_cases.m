function [results,logger,runtime] = run_optimization_cases( ...
    specifications,store,logger,solver,runtime)
%RUN_OPTIMIZATION_CASES Execute compatible independent solver cases.
if isempty(specifications), results = struct([]); return; end
if ~all(arrayfun(@(x) isfield(x,'provenance') && ...
        isfield(x.provenance,'case_hash'),specifications))
    error('fa:UnfinalizedOptimizationPlan', ...
        'Optimization specifications must be finalized before execution.');
end
completed = arrayfun(@(x) case_store_has(store,x),specifications);
pending = specifications(~completed);
execution = struct('log_optimizer_progress',~runtime.parallel_enabled);
if isempty(pending)
    results = case_store_load(store,specifications);
    validate_case_results(results,specifications);
    return;
end
if ~runtime.parallel_enabled
    logger.concurrency = 1;
    for k = 1:numel(pending)
        specification = pending(k);
        study_log('case_start',specification.index,logger.total, ...
            specification.description);
        result = execute_optimization_case(specification,solver,execution);
        case_store_save(store,specification.case_name,result);
        logger = study_log('optimization_complete',logger,result, ...
            result.elapsed_seconds);
    end
else
    [pool,runtime] = ensure_parallel_pool(runtime);
    study_log('line','Parallel case execution: %d workers.',runtime.active_workers);
    logger.concurrency = runtime.max_in_flight;
    futures = parallel.FevalFuture.empty(0,1);
    in_flight_specifications = cell(0,1);
    next_case = 1;
    try
        while next_case <= numel(pending) || ~isempty(futures)
            while next_case <= numel(pending) && ...
                    numel(futures) < runtime.max_in_flight
                specification = pending(next_case);
                study_log('case_dispatched',specification.index,logger.total, ...
                    specification.description);
                future = parfeval(pool,@execute_optimization_case,1, ...
                    specification,solver,execution);
                futures(end+1,1) = future; %#ok<AGROW>
                in_flight_specifications{end+1,1} = specification; %#ok<AGROW>
                next_case = next_case+1;
            end
            [completed_index,result] = fetchNext(futures);
            specification = in_flight_specifications{completed_index};
            futures(completed_index) = [];
            in_flight_specifications(completed_index) = [];
            case_store_save(store,specification.case_name,result);
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
results = case_store_load(store,specifications);
validate_case_results(results,specifications);
end

function validate_case_results(results,specifications)
if numel(results) ~= numel(specifications)
    error('fa:OptimizationCaseCount', ...
        'Optimization queue returned an unexpected number of cases.');
end
for k = 1:numel(specifications)
    specification = specifications(k); result = results(k);
    if ~strcmp(result.case_name,specification.case_name) || ...
            result.seed ~= specification.seed || ...
            ~strcmp(result.objective_name,specification.problem.objective) || ...
            ~strcmp(result.parameterization,specification.problem.parameterization) || ...
            result.normalization_case ~= specification.problem.normalization_case || ...
            ~isfield(result,'case_provenance') || ...
            ~strcmp(result.case_provenance.case_hash, ...
                specification.provenance.case_hash)
        error('fa:OptimizationCaseIdentity', ...
            'Optimization checkpoint identity or provenance is inconsistent for %s.', ...
            specification.case_name);
    end
end
end
