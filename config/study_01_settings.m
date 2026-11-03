function s = study_01_settings()
%STUDY_01_SETTINGS Unrestricted P1 optimization settings.
%
% Study 01 has one case for each objective and P1 normalization group.
% Each case uses multiple SQP starting points; completed cases are saved.

%% Study
s.solver = 'sqp';
s.random_seed = 20260717;
s.objectives = {'r_F0', 'sigma_min', 'condition_number', 'hover_effort'};
s.normalization_groups = {'positive', 'negative'};

%% SQP (independent local starting points within each case)
s.sqp.starts = 16;
s.sqp.max_iterations = 350;
s.sqp.max_function_evaluations = 12000; % Maximum per SQP start.
s.sqp.optimality_tolerance = 1e-7;
s.sqp.step_tolerance = 1e-9;
s.constraint_tolerance = 1e-6;

%% Parallel execution (independent cases)
s.parallel = true;
s.max_workers = 15;
end
