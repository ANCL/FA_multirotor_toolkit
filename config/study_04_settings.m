function s = study_04_settings()
%STUDY_04_SETTINGS P1 Pareto sweeps using the toolkit's existing solvers.
% Each case uses an epsilon constraint; no P2/P3 seeds or restrictions.
% Edit threshold arrays to refine the sampled, numerical Pareto sets.
s.solver = 'sqp'; % 'sqp' (default) or 'ga_patternsearch' (optional)
s.random_seed = 20261104;
s.normalization_groups = {'positive', 'negative'};
s.pairs = {'authority_effort'};
s.authority_effort_thresholds = linspace(0, 0.995*sqrt(2/3), 41);
s.authority_thresholds = [0.05 0.20 0.40 0.60 0.75];
s.sigma_thresholds = [0.10 0.35 0.65 0.95 1.25];
s.condition_thresholds = [1.02 1.08 1.20 1.50 2.50 5.00];
s.joint_authority_thresholds = [0.20 0.50 0.75];
s.joint_sigma_thresholds = [0.30 0.80 1.15];
s.constraint_tolerance = 1e-6;
s.sqp.starts = 16;
s.sqp.max_iterations = 350;
s.sqp.max_function_evaluations = 12000;
s.sqp.optimality_tolerance = 1e-7;
s.sqp.step_tolerance = 1e-9;
s.parallel = true;
s.max_workers = 10;
% Settings for the optional, explicitly selected legacy solver.
legacy = default_optimization_settings('p1');
s.ga = legacy.ga;
s.patternsearch = legacy.patternsearch;
s.local_refinements = legacy.local_refinements;
s.local_start_min_distance = legacy.local_start_min_distance;
s.use_parallel = false; % Independent cases are parallelized, not GA internals.
end
