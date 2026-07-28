function [value,source,is_valid] = condition_specific_sensitivity_value( ...
    T,case_name,objective,metric)
%CONDITION_SPECIFIC_SENSITIVITY_VALUE Read one condition-specific result.
rows = string(T.case_name)==string(case_name) & ...
    string(T.objective)==string(objective);
values = T.(metric);
selected_values = values(rows);
if numel(selected_values) ~= 1
    error('fa:AmbiguousReportingValue', ...
        'Expected one condition-specific value for %s/%s.', ...
        case_name,objective);
end
value = selected_values(1);

sources = string(T.source(rows));
if numel(sources) ~= 1
    error('fa:AmbiguousReportingValue', ...
        'Expected one condition-specific source for %s/%s.', ...
        case_name,objective);
end
source = sources(1);

if ~ismember('valid',T.Properties.VariableNames) || sum(rows) ~= 1
    error('fa:IncompleteSensitivityValidity', ...
        'Condition-specific validity is unavailable for %s/%s.', ...
        case_name,objective);
end
is_valid = logical(T.valid(rows));
end
