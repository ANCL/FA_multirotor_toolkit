function runtime = resolve_runtime(runtime)
%RESOLVE_RUNTIME Determine whether case-level parallel execution is available.
check_runtime_settings(runtime);
has_parallel = license('test','Distrib_Computing_Toolbox') && ...
    exist('parpool','file') == 2 && exist('parfeval','file') == 2;
mode = lower(string(runtime.mode));
switch mode
    case "serial"
        runtime.parallel_enabled = false;
    case "parallel"
        if ~has_parallel
            error('fa:ParallelUnavailable', ...
                ['runtime.mode is parallel, but Parallel Computing Toolbox ' ...
                 'or the required parallel functions are unavailable.']);
        end
        runtime.parallel_enabled = true;
    otherwise
        runtime.parallel_enabled = has_parallel;
end
runtime.active_workers = 1;
runtime.execution_label = 'serial';
if runtime.parallel_enabled
    runtime.execution_label = 'parallel case execution';
end
end
