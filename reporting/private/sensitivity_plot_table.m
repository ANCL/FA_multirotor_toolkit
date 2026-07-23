function T = sensitivity_plot_table(nominal_results,condition_results, ...
    analysis,objective,metric,parameter_source,parameter_name)
%SENSITIVITY_PLOT_TABLE Align nominal and condition-specific source rows.

nominal = nominal_results( ...
    string(nominal_results.analysis)==string(analysis) & ...
    string(nominal_results.objective)==string(objective),:);

condition = condition_results( ...
    string(condition_results.analysis)==string(analysis) & ...
    string(condition_results.objective)==string(objective),:);

n_points = height(nominal);

if n_points < 2 || height(condition) ~= n_points
    error('fa:IncompleteSensitivityFamily', ...
        ['Expected equal nontrivial nominal and condition-specific row ' ...
         'counts for %s/%s.'],analysis,objective);
end

nominal = sortrows(nominal,parameter_source);
condition = sortrows(condition,parameter_source);

if any(string(nominal.case_name) ~= string(condition.case_name))
    error('fa:MisalignedSensitivityFamily', ...
        'Nominal and condition-specific cases are not aligned for %s.', ...
        analysis);
end

case_name = [
    string(nominal.case_name)
    string(condition.case_name)
];

parameter_value = [
    nominal.(parameter_source)
    condition.(parameter_source)
];

design = [
    repmat("Nominal geometry",n_points,1)
    repmat("Condition-specific optimum",n_points,1)
];

metric_value = [
    nominal.(metric)
    condition.(metric)
];

T = table(case_name,parameter_value,design,metric_value, ...
    'VariableNames',{'case_name',parameter_name,'design',metric});
end