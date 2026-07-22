function runtime = verify_parallel_runtime(runtime)
%VERIFY_PARALLEL_RUNTIME Open the requested pool and test the worker path.
persistent verified_pool_size
if ~runtime.parallel_enabled
    study_log('line','Execution mode: serial.');
    return;
end
[pool,runtime] = ensure_parallel_pool(runtime);
if isempty(verified_pool_size) || verified_pool_size ~= pool.NumWorkers
    future = parfeval(pool,@parallel_environment_probe,1);
    report = fetchOutputs(future);
    if ~report.optimize_design_visible || ~report.evaluate_design_visible
        error('fa:WorkerPathIncomplete','Parallel worker path verification failed.');
    end
    verified_pool_size = pool.NumWorkers;
end
study_log('line','Execution mode: parallel case execution with %d workers.', ...
    runtime.active_workers);
end
