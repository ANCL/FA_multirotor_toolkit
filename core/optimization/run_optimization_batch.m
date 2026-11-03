function completed = run_optimization_batch(jobs, model, numerics, settings)
%RUN_OPTIMIZATION_BATCH Execute independent cases, saving each completed run.
%
% Reusable by other studies. Existing MAT files are skipped automatically.
% If interrupted, only unfinished cases run next time. Each case keeps its
% complete geometry, metrics, seed, solver output, and numerical settings.

pending = find(~cellfun(@isfile, {jobs.file}));
completed = numel(jobs) - numel(pending);
fprintf('Saved: %d/%d | remaining: %d\n', ...
    completed, numel(jobs), numel(pending));
if isempty(pending), return; end

% Parallelism applies to independent cases, not to SQP starts.
use_parallel = settings.parallel && numel(pending) > 1;
if use_parallel
    if exist('parpool', 'file') ~= 2 || ...
            ~license('test', 'Distrib_Computing_Toolbox')
        warning('fa:ParallelUnavailable', ...
            'Parallel Computing Toolbox is unavailable; running serially.');
        use_parallel = false;
    else
        try
            pool = gcp('nocreate');
            if isempty(pool)
                cluster = parcluster('Processes');
                worker_count = min([settings.max_workers, ...
                    cluster.NumWorkers, numel(pending)]);
                pool = parpool('Processes', worker_count);
            end
        catch exception
            warning('fa:ParallelUnavailable', ...
                'Unable to start a parallel pool: %s. Running serially.', ...
                exception.message);
            use_parallel = false;
        end
    end
end

if use_parallel
    fprintf('Execution: %d parallel workers.\n', pool.NumWorkers);
    updates = parallel.pool.DataQueue;
    afterEach(updates, @print_completion);
    parfor (k = 1:numel(pending), settings.max_workers)
        job = jobs(pending(k));
        result = execute_case(job, model, numerics, settings);
        send(updates, completion_message(job, result));
    end
else
    fprintf('Execution: serial.\n');
    for k = 1:numel(pending)
        job = jobs(pending(k));
        fprintf('Starting %s\n', job.label);
        result = execute_case(job, model, numerics, settings);
        print_completion(completion_message(job, result));
    end
end
completed = sum(cellfun(@isfile, {jobs.file}));
end

function message = completion_message(job, result)
message = struct('label', job.label, 'valid', result.valid, ...
    'value', result.objective_value, ...
    'violation', result.maximum_constraint_violation, ...
    'solver', result.selected_solver, 'seconds', result.elapsed_seconds);
end

function print_completion(message)
if message.valid
    fprintf('FEASIBLE   %-40s | %.12g | %s | %.1f s\n', ...
        message.label, message.value, message.solver, message.seconds);
else
    fprintf('INFEASIBLE %-40s | violation %.3g | %.1f s\n', ...
        message.label, message.violation, message.seconds);
end
end

function result = execute_case(job, model, numerics, settings)
%EXECUTE_CASE Run the optimizer chosen by the study and save the result.
result = job.optimizer(job.problem, model, numerics, settings, job.seed);
save(job.file, 'result', '-v7.3');
end
