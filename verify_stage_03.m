function verify_stage_03()
%VERIFY_STAGE_03 Check the four costs, physical constraints, and GA->local.
%
% A short solver integration check, not a scientific convergence study.
setup_project();
model = default_model();
numerics = default_numerics();
g = make_p3_geometry([0.5; 0.2]);
metrics = evaluate_design(g, model, numerics);
assert(metrics.valid);
for name = {'r_F0', 'sigma_min', 'condition_number', 'hover_effort'}
    objective = name{1};
    problem = make_design_problem('p3', objective, '', model);
    cost = design_objective([0.5; 0.2], problem, model);
    expected = metrics.(objective);
    if ismember(objective, {'r_F0', 'sigma_min'}), expected = -expected; end
    assert(abs(cost - expected) < 1e-8);
    [c, ceq] = design_constraints([0.5; 0.2], problem, model, numerics);
    assert(isempty(ceq) && all(c <= 1e-8));
end

% Validate the exact same physical design within the reduced P1 chart.
[x, group] = encode_p1_geometry(g, model);
p1 = make_design_problem('p1', 'hover_effort', group, model);
assert(numel(x) == 28 && all(x >= p1.lower_bounds - 1e-8) && ...
    all(x <= p1.upper_bounds + 1e-8));
[c, ~] = design_constraints(x, p1, model, numerics);
assert(all(c <= 1e-8));

% Exercise both GA and patternsearch with an explicitly supplied feasible
% P3 seed, so this quick check is not dependent on random discovery.
problem = make_design_problem('p3', 'hover_effort', '', model);
problem.initial_designs = [0.5, 0.2];
settings = default_optimization_settings('p3');
settings.ga.population_size = 30;
settings.ga.max_generations = 4;
settings.ga.max_stall_generations = 4;
settings.patternsearch.max_function_evaluations = 80;
settings.local_refinements = 1;
result = optimize_design(problem, model, numerics, settings, 12345);
assert(result.valid, result.failure_reason);
assert(~isempty(result.local_runs));
assert(result.objective_value <= metrics.hover_effort + 1e-8);
assert(all(result.design_variables >= problem.lower_bounds - 1e-8));
assert(all(result.design_variables <= problem.upper_bounds + 1e-8));
fprintf('STAGE 3 VERIFIED: four solver costs, P1/P3 feasibility, GA + patternsearch.\n');
end
