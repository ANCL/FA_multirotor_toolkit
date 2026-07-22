function value = condition_specific_sensitivity_value(T,case_name,objective,metric)
%CONDITION_SPECIFIC_SENSITIVITY_VALUE Read one condition-specific value.
rows = string(T.case_name)==string(case_name) & ...
    string(T.objective)==string(objective);
values = T.(metric);
value = unique_reporting_scalar(values(rows), ...
    sprintf('condition-specific %s/%s',case_name,objective));
end
