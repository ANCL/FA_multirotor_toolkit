function [pool,runtime] = ensure_parallel_pool(runtime)
%ENSURE_PARALLEL_POOL Start or reuse the process pool used for case execution.
if ~runtime.parallel_enabled
    pool = [];
    runtime.active_workers = 1;
    return;
end
pool = gcp('nocreate');
if isempty(pool)
    profile = char(string(runtime.pool_profile));
    try
        if isempty(runtime.max_workers)
            pool = parpool(profile);
        else
            pool = parpool(profile,runtime.max_workers);
        end
    catch primary_error
        % Older MATLAB installations may expose only the local profile.
        if strcmpi(profile,'local')
            rethrow(primary_error);
        end
        study_log('line', ...
            'Could not start profile %s; falling back to the local profile.',profile);
        if isempty(runtime.max_workers)
            pool = parpool('local');
        else
            pool = parpool('local',runtime.max_workers);
        end
    end
end
runtime.active_workers = pool.NumWorkers;
if isempty(runtime.max_in_flight)
    runtime.max_in_flight = pool.NumWorkers;
else
    runtime.max_in_flight = min(runtime.max_in_flight,pool.NumWorkers);
end
end
