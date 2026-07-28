function T = sensitivity_directionality_table(matrix)
%SENSITIVITY_DIRECTIONALITY_TABLE Complete actuator-direction comparison.
metrics = string(unique(matrix.objective( ...
    string(matrix.analysis)=="directionality"),'stable'));
direction_rows = matrix(string(matrix.analysis)=="directionality",:);
if isempty(direction_rows)
    error('fa:MissingDirectionalitySensitivity', ...
        'No directionality sensitivity rows were found.');
end
[~,order] = sort(direction_rows.parameter_value);
direction_rows = direction_rows(order,:);
cases = unique(string(direction_rows.case_name),'stable');

row_count = numel(metrics)*numel(cases);
objective = strings(row_count,1);
case_name = strings(row_count,1);
mu_min = nan(row_count,1);
actuator_bounds = strings(row_count,1);
baseline_metric_value = nan(row_count,1);
nominal_geometry = nan(row_count,1);
nominal_metric_available = false(row_count,1);
nominal_valid = false(row_count,1);
nominal_change_pct = nan(row_count,1);
condition_specific_optimum = nan(row_count,1);
condition_specific_metric_available = false(row_count,1);
condition_specific_valid = false(row_count,1);
condition_specific_change_pct = nan(row_count,1);
improvement = nan(row_count,1);
reoptimization_improvement_pct = nan(row_count,1);
condition_specific_source = strings(row_count,1);

row = 0;
for metric_index = 1:numel(metrics)
    metric = metrics(metric_index);
    for case_index = 1:numel(cases)
        row = row+1;
        case_id = cases(case_index);
        selected = string(matrix.analysis)=="directionality" & ...
            string(matrix.case_name)==case_id & ...
            string(matrix.objective)==metric;
        if sum(selected) ~= 1
            error('fa:MissingDirectionalitySensitivity', ...
                'Expected one directionality row for %s/%s.',case_id,metric);
        end
        source = matrix(selected,:);

        objective(row) = metric;
        case_name(row) = case_id;
        switch case_id
            case "unidirectional"
                mu_min(row) = 0;
                actuator_bounds(row) = "0 <= mu_i <= 1";
            case "bidirectional"
                mu_min(row) = -1;
                actuator_bounds(row) = "-1 <= mu_i <= 1";
            otherwise
                error('fa:UnknownDirectionalityCase', ...
                    'Unknown directionality case: %s.',case_id);
        end

        baseline_metric_value(row) = source.baseline_metric_value;
        nominal_geometry(row) = source.nominal_geometry;
        nominal_metric_available(row) = source.nominal_metric_available;
        nominal_valid(row) = source.nominal_valid;
        nominal_change_pct(row) = source.nominal_change_pct;
        condition_specific_optimum(row) = source.condition_specific_optimum;
        condition_specific_metric_available(row) = ...
            source.condition_specific_metric_available;
        condition_specific_valid(row) = source.condition_specific_valid;
        condition_specific_change_pct(row) = source.condition_specific_change_pct;
        improvement(row) = source.condition_specific_improvement;
        reoptimization_improvement_pct(row) = source.reoptimization_improvement_pct;
        condition_specific_source(row) = string(source.condition_specific_source);
    end
end

T = table(objective,case_name,mu_min,actuator_bounds,baseline_metric_value, ...
    nominal_geometry,nominal_metric_available,nominal_valid,nominal_change_pct, ...
    condition_specific_optimum,condition_specific_metric_available, ...
    condition_specific_valid, ...
    condition_specific_change_pct,improvement, ...
    reoptimization_improvement_pct,condition_specific_source, ...
    'VariableNames',{'objective','case_name','mu_min','actuator_bounds', ...
    'baseline_metric_value','nominal_geometry','nominal_metric_available', ...
    'nominal_valid','nominal_change_pct','condition_specific_optimum', ...
    'condition_specific_metric_available','condition_specific_valid', ...
    'condition_specific_change_pct', ...
    'condition_specific_improvement','reoptimization_improvement_pct', ...
    'condition_specific_source'});
end
