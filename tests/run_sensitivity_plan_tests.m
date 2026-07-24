function results = run_sensitivity_plan_tests()
%RUN_SENSITIVITY_PLAN_TESTS Check expanded scope and legacy case reuse.
setup_project();
[parameters,solver] = study_settings();
selected = mock_selected_designs(parameters,solver);
checks = strings(0,1);

expanded = sensitivity_case_plan(parameters,solver,selected);
assert(expanded.fixed_evaluation_count == 170);
assert(expanded.baseline_result_count == 12);
assert(expanded.optimization_group_count == 158);
assert(expanded.optimization_case_count == 4740);
checks(end+1) = "expanded_plan_counts";

legacy_parameters = legacy_sensitivity_parameters(parameters);
legacy = sensitivity_case_plan(legacy_parameters,solver,selected);
assert(legacy.fixed_evaluation_count == 91);
assert(legacy.baseline_result_count == 6);
assert(legacy.optimization_group_count == 85);
assert(legacy.optimization_case_count == 2550);
checks(end+1) = "legacy_plan_counts";

expanded_names = string({expanded.specifications.case_name});
legacy_names = string({legacy.specifications.case_name});
[found,locations] = ismember(legacy_names,expanded_names);
assert(all(found),'An existing sensitivity case disappeared from the expanded plan.');
for index = 1:numel(legacy.specifications)
    current = expanded.specifications(locations(index));
    previous = legacy.specifications(index);
    assert(strcmp(previous.provenance.case_hash,current.provenance.case_hash), ...
        'Expanded settings changed existing case %s.',previous.case_name);
end
checks(end+1) = "legacy_case_hashes_preserved";

new_names = expanded_names(~ismember(expanded_names,legacy_names));
assert(numel(new_names) == 2190);
checks(end+1) = "new_case_count";

hover_fixed = expanded.fixed_cases( ...
    string({expanded.fixed_cases.analysis})=="hover_load");
assert(numel(hover_fixed) == 17);
for index = 1:numel(hover_fixed)
    factor = hover_fixed(index).physical_value;
    expected_wrench = factor*parameters.hover_wrench;
    assert(norm(hover_fixed(index).parameters.hover_wrench-expected_wrench,Inf) ...
        <= 100*solver.equality_tolerance);
    assert(norm(hover_fixed(index).parameters.task.Lambda- ...
        parameters.task.Lambda,Inf) <= 100*solver.equality_tolerance);
end
checks(end+1) = "hover_load_scaling";

hover_groups = expanded.optimization_groups( ...
    string({expanded.optimization_groups.analysis})=="hover_load");
assert(numel(hover_groups) == 16);
assert(all(arrayfun(@(x) numel(x.objectives)==2,hover_groups)));
checks(end+1) = "hover_load_optimization_groups";

checks = checks(:);
results = table(checks,true(numel(checks),1), ...
    'VariableNames',{'test','passed'});
disp(results);
fprintf('SENSITIVITY PLAN TESTS PASSED: %d/%d\n',height(results),height(results));
end

function selected = mock_selected_designs(parameters,solver)
objectives = parameters.objectives(:);
seeds = initial_rotorwise_seeds(parameters,solver);
design_variables = seeds{1}(1,:).';
template = struct('name','','optimization_result',struct());
selected = repmat(template,numel(objectives),1);
for index = 1:numel(objectives)
    selected(index).name = objectives{index};
    selected(index).optimization_result = struct( ...
        'normalization_case',1, ...
        'design_variables',design_variables);
end
end

function legacy = legacy_sensitivity_parameters(parameters)
legacy = parameters;
legacy.sensitivity.hover_load_factor_values = zeros(1,0);
legacy.sensitivity.optimized_objectives.task_emphasis = {'q_star'};
legacy.sensitivity.optimized_objectives.characteristic_length = ...
    {'sigma_min','condition_number'};
legacy.sensitivity.optimized_objectives.reaction_moment = {'q_star'};
legacy.sensitivity.optimized_objectives.actuator_capacity = {'q_star'};
legacy.sensitivity.optimized_objectives.bidirectional = {'q_star'};
legacy.sensitivity.optimized_objectives.hover_load = {};
end
