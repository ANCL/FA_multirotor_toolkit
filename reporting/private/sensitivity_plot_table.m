function T = sensitivity_plot_table(matrix,analysis,objective,metric, ...
    parameter_source,parameter_name)
%SENSITIVITY_PLOT_TABLE Build aligned raw-value series from the matrix.
selected = matrix( ...
    string(matrix.analysis)==string(analysis) & ...
    string(matrix.objective)==string(objective),:);
if isempty(selected)
    error('fa:IncompleteSensitivityFamily', ...
        'No sensitivity rows were found for %s/%s.', ...
        analysis,objective);
end

parameter = resolved_plot_parameter(selected,parameter_source);
[parameter,order] = sort(parameter);
selected = selected(order,:);
n_points = height(selected);

case_name = [string(selected.case_name);string(selected.case_name)];
parameter_value = [parameter;parameter];
design = [ ...
    repmat("Nominal geometry",n_points,1); ...
    repmat("Condition-specific optimum",n_points,1)];
metric_value = [selected.nominal_geometry;selected.condition_specific_optimum];
metric_available = [selected.nominal_metric_available; ...
    selected.condition_specific_metric_available];
valid = [selected.nominal_valid;selected.condition_specific_valid];
source = [ ...
    repmat("fixed_nominal_geometry",n_points,1); ...
    string(selected.condition_specific_source)];

T = table(case_name,parameter_value,design,metric_value, ...
    metric_available,valid,source, ...
    'VariableNames',{'case_name',parameter_name,'design',metric, ...
    'metric_available','valid','source'});
end

function values = resolved_plot_parameter(T,parameter_source)
parameter_source = char(string(parameter_source));
switch parameter_source
    case {'mu_min','parameter_value'}
        values = T.parameter_value;
    otherwise
        error('fa:SensitivityPlotParameter', ...
            'Unknown sensitivity parameter source: %s.',parameter_source);
end
values = values(:);
if any(~isfinite(values))
    error('fa:SensitivityPlotParameter', ...
        'Sensitivity parameter values must be finite for plotting.');
end
end
