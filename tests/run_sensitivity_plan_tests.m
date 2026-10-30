function results = run_sensitivity_plan_tests()
%RUN_SENSITIVITY_PLAN_TESTS Check matrix completeness and plan consistency.
setup_project();
[parameters,solver] = study_settings();
selected = mock_selected_designs(parameters,solver);
checks = strings(0,1);

plan = sensitivity_case_plan(parameters,solver,selected);
metrics = parameters.sensitivity.matrix_metrics;
metric_count = numel(metrics);
point_counts = [ ...
    numel(parameters.sensitivity.actuator_capacity_values), ...
    numel(parameters.sensitivity.kappa_values), ...
    numel(parameters.sensitivity.characteristic_length_values), ...
    1+double(parameters.sensitivity.include_bidirectional), ...
    numel(parameters.sensitivity.hover_load_factor_values)];
expected_fixed = metric_count*sum(point_counts);
expected_baselines = metric_count*numel(point_counts);
assert(plan.fixed_evaluation_count == expected_fixed);
assert(plan.baseline_result_count == expected_baselines);
checks(end+1) = "complete_matrix_plan_counts";

assert(all(arrayfun(@(x) numel(x.objectives)==metric_count,plan.fixed_cases)));
assert(all(arrayfun(@(x) numel(x.objectives)==metric_count,plan.baseline_cases)));
checks(end+1) = "all_fixed_metrics_present";

expected_groups = ...
    changed_count(parameters.sensitivity.actuator_capacity_values,1)* ...
        numel(parameters.sensitivity.optimized_objectives.actuator_capacity) + ...
    changed_count(parameters.sensitivity.kappa_values,parameters.kappa)* ...
        numel(parameters.sensitivity.optimized_objectives.reaction_moment) + ...
    changed_count(parameters.sensitivity.characteristic_length_values, ...
        parameters.force_moment_length)* ...
        numel(parameters.sensitivity.optimized_objectives.characteristic_length) + ...
    double(parameters.sensitivity.include_bidirectional)* ...
        numel(parameters.sensitivity.optimized_objectives.bidirectional) + ...
    changed_count(parameters.sensitivity.hover_load_factor_values,1)* ...
        numel(parameters.sensitivity.optimized_objectives.hover_load);
assert(plan.optimization_group_count == expected_groups);
expected_cases = expected_groups*solver.independent_runs;
assert(plan.optimization_case_count == expected_cases);
checks(end+1) = "optimization_plan_counts";

hover_fixed = plan.fixed_cases( ...
    string({plan.fixed_cases.analysis})=="hover_load");
assert(numel(hover_fixed) == numel(parameters.sensitivity.hover_load_factor_values));
for index = 1:numel(hover_fixed)
    factor = hover_fixed(index).physical_value;
    expected_wrench = factor*parameters.hover_wrench;
    assert(norm(hover_fixed(index).parameters.hover_wrench-expected_wrench,Inf) ...
        <= 100*solver.equality_tolerance);
end
checks(end+1) = "hover_load_scaling";

for family = ["actuator_capacity","reaction_moment", ...
        "characteristic_length","directionality","hover_load"]
    groups = plan.optimization_groups( ...
        string({plan.optimization_groups.analysis})==family);
    assert(all(arrayfun(@(x) numel(x.objectives)==metric_count,groups)));
end
checks(end+1) = "changed_conditions_cover_configured_metrics";

checks = checks(:);
results = table(checks,true(numel(checks),1), ...
    'VariableNames',{'test','passed'});
disp(results);
fprintf('SENSITIVITY PLAN TESTS PASSED: %d/%d\n',height(results),height(results));
end

function count = changed_count(values,baseline)
tolerance = 100*eps(max(1,abs(baseline)));
count = sum(abs(values(:)-baseline) > tolerance);
end

function selected = mock_selected_designs(parameters,solver)
objectives = parameters.objectives(:);
seeds = initial_structured_seeds('spatial_c3',parameters);
design_variables = seeds(1,:).';
template = struct('name','','optimization_result',struct());
selected = repmat(template,numel(objectives),1);
for index = 1:numel(objectives)
    selected(index).name = objectives{index};
    selected(index).optimization_result = struct( ...
        'normalization_case',0, ...
        'design_variables',design_variables);
end
end
