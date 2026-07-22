function check_runtime_settings(runtime)
%CHECK_RUNTIME_SETTINGS Validate non-scientific execution controls.
issues = {};
valid_modes = ["auto","serial","parallel"];
if ~isfield(runtime,'mode') || ~ismember(lower(string(runtime.mode)),valid_modes)
    issues{end+1} = 'runtime.mode must be auto, serial, or parallel'; %#ok<AGROW>
end
if ~isfield(runtime,'max_workers') || ...
        ~(isempty(runtime.max_workers) || positive_integer(runtime.max_workers))
    issues{end+1} = 'runtime.max_workers must be empty or a positive integer'; %#ok<AGROW>
end
if ~isfield(runtime,'pool_profile') || strlength(string(runtime.pool_profile)) == 0
    issues{end+1} = 'runtime.pool_profile must be a nonempty profile name'; %#ok<AGROW>
end
if ~isfield(runtime,'max_in_flight') || ...
        ~(isempty(runtime.max_in_flight) || positive_integer(runtime.max_in_flight))
    issues{end+1} = 'runtime.max_in_flight must be empty or a positive integer'; %#ok<AGROW>
end
if ~isfield(runtime,'robustness_batch_size') || ...
        ~positive_integer(runtime.robustness_batch_size)
    issues{end+1} = 'runtime.robustness_batch_size must be a positive integer'; %#ok<AGROW>
end
if ~isfield(runtime,'keep_pool_open') || ~islogical(runtime.keep_pool_open) || ...
        ~isscalar(runtime.keep_pool_open)
    issues{end+1} = 'runtime.keep_pool_open must be a logical scalar'; %#ok<AGROW>
end
if ~isempty(issues)
    error('fa:InvalidRuntimeSettings','Runtime settings are invalid:\n- %s', ...
        strjoin(issues,'\n- '));
end
end

function yes = positive_integer(value)
yes = isnumeric(value) && isscalar(value) && isfinite(value) && ...
    value >= 1 && value == floor(value);
end
