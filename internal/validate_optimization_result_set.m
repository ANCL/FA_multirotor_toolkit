function results = validate_optimization_result_set(path_in)
%VALIDATE_OPTIMIZATION_RESULT_SET Verify intended cases and saved results.
data = load(path_in);
if ~isfield(data,'expected_cases')
    error('fa:MissingExpectedCases', ...
        'Raw optimization file lacks expected_cases: %s',path_in);
end
expected = string(data.expected_cases(:));
if isfield(data,'all_runs')
    results = data.all_runs;
elseif isfield(data,'runs')
    results = data.runs;
elseif isfield(data,'optimized')
    results = data.optimized;
elseif isfield(data,'condition_specific_results')
    results = data.condition_specific_results;
else
    error('fa:MissingRawRuns','Raw optimization results are missing: %s',path_in);
end
actual = string({results.case_name});
if numel(actual) ~= numel(expected) || ...
        numel(unique(actual)) ~= numel(expected) || ...
        ~all(ismember(expected,actual))
    error('fa:IncompleteOptimization', ...
        'Optimization result set is missing or duplicates intended cases: %s',path_in);
end
end
