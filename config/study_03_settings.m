function s = study_03_settings()
%STUDY_03_SETTINGS P2/P3 comparison with the toolkit's randomized SQP solver.
% Independent random-seed cases; SQP performs additional random starts
% within each case. No GA, patternsearch, or analytical-bound constraints.
s.solver = 'sqp';
s.parameterizations = {'p2', 'p3'};
s.objectives = {'r_F0', 'sigma_min', 'condition_number', 'hover_effort'};
s.repeats = 1;
s.random_seed = 20261103;

% Use the same SQP protocol as Study 01, not the legacy GA budget.
s.sqp.starts = 16;
s.sqp.max_iterations = 350;
s.sqp.max_function_evaluations = 12000;
s.sqp.optimality_tolerance = 1e-7;
s.sqp.step_tolerance = 1e-9;
s.constraint_tolerance = 1e-6;

% Parallelize independent cases, not the starts within a single SQP case.
s.parallel = true;
s.max_workers = 10;
legacy = default_optimization_settings('p2');
s.ga = legacy.ga;
s.patternsearch = legacy.patternsearch;
s.local_refinements = legacy.local_refinements;
s.local_start_min_distance = legacy.local_start_min_distance;
s.use_parallel = false;
end
