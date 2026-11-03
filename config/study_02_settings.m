function s = study_02_settings()
%STUDY_02_SETTINGS Unrestricted P1 analytical-bound discovery.
%
% Keep settings unchanged while a run is in progress.

s.solver = 'sqp';
s.random_seed = 20261101;
s.objectives = {'r_F0', 'sigma_min', 'condition_number'};
s.normalization_groups = {'positive', 'negative'};
s.target_per_objective = 1000;
s.stagnation_attempts = 1000;   % Stop after consecutive attempts with no NEW design.
s.distinctness_distance = 0.05; % Physical position/direction RMS, modulo yaw/permutations.
s.constraint_tolerance = 10^-3;  % numerical constraint tolerance.
s.batch_size = 10;
s.parallel = true;
s.max_workers = 10;
s.make_figures = true;

s.sqp.max_iterations = 250;
s.sqp.max_function_evaluations = 9000;
s.sqp.optimality_tolerance = 1e-7;
s.sqp.step_tolerance = 1e-9;
end
