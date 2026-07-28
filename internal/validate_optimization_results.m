function validate_optimization_results(results,expected_cases,label)
%VALIDATE_OPTIMIZATION_RESULTS Verify an in-memory complete case result set.
if nargin < 3 || isempty(label), label = 'optimization result set'; end
expected = string(expected_cases(:));
if isempty(expected)
    if ~isempty(results)
        error('fa:UnexpectedOptimizationResults', ...
            '%s contains results although no cases were expected.',label);
    end
    return;
end
if isempty(results) || ~isstruct(results) || ~isfield(results,'case_name')
    error('fa:MissingRawRuns','%s does not contain optimization results.',label);
end
actual = string({results.case_name}).';
if numel(actual) ~= numel(expected) || ...
        numel(unique(actual)) ~= numel(expected) || ...
        ~all(ismember(expected,actual))
    error('fa:IncompleteOptimization', ...
        '%s is missing or duplicates intended cases.',label);
end
end
