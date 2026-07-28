function validate_sensitivity_outputs(summary,parameters,solver)
%VALIDATE_SENSITIVITY_OUTPUTS Validate matrix completeness and data semantics.
expected = sensitivity_expectations(parameters);
expected_rows = sum(expected.point_count.*expected.objective_count);
if height(summary) ~= expected_rows
    error('fa:IncompleteSensitivityOutputs', ...
        'Expected %d sensitivity rows, but found %d.', ...
        expected_rows,height(summary));
end

keys = string(summary.analysis)+"/"+string(summary.case_name)+ ...
    "/"+string(summary.objective);
if numel(unique(keys)) ~= height(summary)
    error('fa:DuplicateSensitivityOutputs', ...
        'Sensitivity rows must have unique analysis/case/objective keys.');
end

required = { ...
    'baseline_metric_value','nominal_geometry','nominal_metric_available', ...
    'nominal_valid','nominal_change_pct','condition_specific_optimum', ...
    'condition_specific_metric_available','condition_specific_valid', ...
    'condition_specific_change_pct', ...
    'condition_specific_improvement','reoptimization_improvement_pct', ...
    'condition_specific_source'};
if ~all(ismember(required,summary.Properties.VariableNames))
    error('fa:IncompleteSensitivityOutputs', ...
        'Sensitivity summaries are missing required reporting fields.');
end

if any(~isfinite(summary.baseline_metric_value))
    error('fa:InvalidSensitivityBaselineReference', ...
        'Every sensitivity cell requires a finite baseline metric value.');
end

validate_metric_series(summary.nominal_geometry, ...
    summary.nominal_metric_available,summary.nominal_valid,'nominal-geometry');
validate_metric_series(summary.condition_specific_optimum, ...
    summary.condition_specific_metric_available,summary.condition_specific_valid, ...
    'condition-specific');
validate_relative_series(summary.nominal_change_pct, ...
    summary.nominal_metric_available,'nominal-geometry');
validate_relative_series(summary.condition_specific_change_pct, ...
    summary.condition_specific_metric_available,'condition-specific');

comparable = summary.nominal_valid & summary.condition_specific_valid;
if any(~isfinite(summary.condition_specific_improvement(comparable))) || ...
        any(~isfinite(summary.reoptimization_improvement_pct(comparable)))
    error('fa:InvalidSensitivityImprovement', ...
        'Comparable sensitivity rows require finite improvement values.');
end
if any(~isnan(summary.condition_specific_improvement(~comparable))) || ...
        any(~isnan(summary.reoptimization_improvement_pct(~comparable)))
    error('fa:InvalidSensitivityImprovement', ...
        'Improvement is undefined when either compared design is invalid.');
end
if any(summary.condition_specific_improvement(comparable) < ...
        -solver.constraint_tolerance)
    error('fa:InferiorConditionSpecificDesign', ...
        'A valid condition-specific optimum is worse than its fixed-geometry incumbent.');
end
if any(summary.reoptimization_improvement_pct(comparable) < ...
        -100*solver.constraint_tolerance)
    error('fa:InferiorConditionSpecificDesign', ...
        'A valid re-optimization improvement percentage is negative.');
end

for family_index = 1:height(expected)
    analysis = expected.analysis(family_index);
    objectives = expected.objectives{family_index};
    for objective_index = 1:numel(objectives)
        objective = string(objectives{objective_index});
        selected = string(summary.analysis)==analysis & ...
            string(summary.objective)==objective;
        family = summary(selected,:);
        if height(family) ~= expected.point_count(family_index)
            error('fa:IncompleteSensitivityFamily', ...
                'Expected %d rows for %s/%s, but found %d.', ...
                expected.point_count(family_index),analysis,objective, ...
                height(family));
        end
        verify_family_grid(family,analysis,expected.values{family_index},solver);
        verify_family_baseline( ...
            family,analysis,expected.baseline_value(family_index),solver);
        verify_relative_reference(family,analysis,objective,solver);
        verify_reoptimization_sources(family,analysis,objective, ...
            parameters,expected.baseline_value(family_index),solver);
    end
end
end

function validate_metric_series(values,available,valid,label)
available = logical(available);
valid = logical(valid);
if any(~isfinite(values(available)))
    error('fa:InvalidSensitivityOutputs', ...
        'Available %s metric values must be finite.',label);
end
if any(~isnan(values(~available)))
    error('fa:InvalidSensitivityOutputs', ...
        'Unavailable %s metric values must be represented by NaN.',label);
end
if any(valid & ~available)
    error('fa:InvalidSensitivityOutputs', ...
        'A valid %s evaluation cannot have an unavailable reported metric.',label);
end
end

function validate_relative_series(values,available,label)
available = logical(available);
if any(~isfinite(values(available)))
    error('fa:InvalidSensitivityOutputs', ...
        'Available %s metrics require finite percentage changes.',label);
end
if any(~isnan(values(~available)))
    error('fa:InvalidSensitivityOutputs', ...
        'Unavailable %s metrics must use NaN percentage changes.',label);
end
end

function expected = sensitivity_expectations(parameters)
matrix_metrics = parameters.sensitivity.matrix_metrics;
expected = table( ...
    ["task_emphasis";"actuator_capacity";"hover_load"; ...
     "reaction_moment";"directionality";"characteristic_length"], ...
    {matrix_metrics;matrix_metrics;matrix_metrics; ...
     matrix_metrics;matrix_metrics;matrix_metrics}, ...
    [numel(parameters.sensitivity.task_emphasis_values); ...
     numel(parameters.sensitivity.actuator_capacity_values); ...
     numel(parameters.sensitivity.hover_load_factor_values); ...
     numel(parameters.sensitivity.kappa_values); ...
     1+double(parameters.sensitivity.include_bidirectional); ...
     numel(parameters.sensitivity.characteristic_length_values)], ...
    {parameters.sensitivity.task_emphasis_values(:); ...
     parameters.sensitivity.actuator_capacity_values(:); ...
     parameters.sensitivity.hover_load_factor_values(:); ...
     parameters.sensitivity.kappa_values(:); ...
     directionality_values(parameters); ...
     parameters.sensitivity.characteristic_length_values(:)}, ...
    [baseline_rho(parameters);1;1;parameters.kappa;0; ...
     parameters.force_moment_length], ...
    'VariableNames',{'analysis','objectives','point_count','values', ...
    'baseline_value'});
expected.objective_count = cellfun(@numel,expected.objectives);
end

function values = directionality_values(parameters)
values = 0;
if parameters.sensitivity.include_bidirectional
    values = [-1;0];
end
end

function verify_family_grid(family,analysis,expected_values,solver)
if analysis=="task_emphasis"
    actual = sort(family.rho);
else
    actual = sort(family.parameter_value);
end
expected_values = sort(expected_values(:));
tolerance = 100*solver.equality_tolerance;
if numel(actual) ~= numel(expected_values) || ...
        any(abs(actual-expected_values) > tolerance)
    error('fa:InvalidSensitivityGrid', ...
        'The sampled values for %s do not match the configured grid.',analysis);
end
end

function verify_family_baseline(family,analysis,baseline,solver)
if analysis=="task_emphasis"
    values = family.rho;
else
    values = family.parameter_value;
end
if sum(abs(values-baseline) <= 100*solver.equality_tolerance) ~= 1
    error('fa:MissingSensitivityBaseline', ...
        'Expected one exact baseline row for %s.',analysis);
end
end

function verify_relative_reference(family,analysis,objective,solver)
baseline_rows = string(family.condition_specific_source)=="baseline";
if sum(baseline_rows) ~= 1
    error('fa:MissingSensitivityBaseline', ...
        'Expected one baseline source for %s/%s.',analysis,objective);
end
baseline_index = find(baseline_rows,1);
if ~family.nominal_valid(baseline_index) || ...
        ~family.condition_specific_valid(baseline_index)
    error('fa:InvalidSensitivityBaselineReference', ...
        'The baseline row must be valid for %s/%s.',analysis,objective);
end
baseline_value = family.nominal_geometry(baseline_index);
scale = max(1,abs(baseline_value));
if abs(baseline_value) <= solver.equality_tolerance
    error('fa:UndefinedSensitivityPercentage', ...
        ['The baseline metric for %s/%s is too close to zero for a ' ...
         'meaningful percentage change.'],analysis,objective);
end
if any(abs(family.baseline_metric_value-baseline_value) > ...
        100*solver.equality_tolerance*scale)
    error('fa:InvalidSensitivityBaselineReference', ...
        'The baseline metric reference is inconsistent for %s/%s.', ...
        analysis,objective);
end
if family.nominal_change_pct(baseline_index) ~= 0 || ...
        family.condition_specific_change_pct(baseline_index) ~= 0 || ...
        family.reoptimization_improvement_pct(baseline_index) ~= 0
    error('fa:InvalidSensitivityBaselineReference', ...
        'Baseline percentage values must be exactly zero for %s/%s.', ...
        analysis,objective);
end
end

function verify_reoptimization_sources( ...
    family,analysis,objective,parameters,baseline,solver)
optimized = optimized_objectives(parameters,analysis);
requires_search = any(strcmp(optimized,char(objective)));
if analysis=="task_emphasis"
    values = family.rho;
else
    values = family.parameter_value;
end
baseline_rows = abs(values-baseline) <= 100*solver.equality_tolerance;
sources = string(family.condition_specific_source);
if any(sources(baseline_rows) ~= "baseline")
    error('fa:InvalidSensitivitySource', ...
        'The exact baseline row for %s/%s must use the baseline source.', ...
        analysis,objective);
end
changed_sources = sources(~baseline_rows);
if requires_search
    if any(changed_sources ~= "checkpoint")
        error('fa:InvalidSensitivitySource', ...
            'Changed %s/%s rows must come from optimization checkpoints.', ...
            analysis,objective);
    end
else
    if any(changed_sources ~= "reused_nominal_optimum")
        error('fa:InvalidSensitivitySource', ...
            'Changed %s/%s rows must explicitly reuse the nominal optimum.', ...
            analysis,objective);
    end
end
end

function objectives = optimized_objectives(parameters,analysis)
switch analysis
    case "task_emphasis"
        objectives = parameters.sensitivity.optimized_objectives.task_emphasis;
    case "actuator_capacity"
        objectives = parameters.sensitivity.optimized_objectives.actuator_capacity;
    case "hover_load"
        objectives = parameters.sensitivity.optimized_objectives.hover_load;
    case "reaction_moment"
        objectives = parameters.sensitivity.optimized_objectives.reaction_moment;
    case "directionality"
        objectives = parameters.sensitivity.optimized_objectives.bidirectional;
    case "characteristic_length"
        objectives = parameters.sensitivity.optimized_objectives.characteristic_length;
    otherwise
        error('fa:UnknownSensitivityFamily', ...
            'Unknown sensitivity family: %s.',analysis);
end
end

function rho = baseline_rho(parameters)
diagonal = diag(parameters.task.Lambda);
force_norm = norm(diagonal(1:3),2);
moment_norm = norm(diagonal(4:6),2);
rho = moment_norm/(force_norm+moment_norm);
end
