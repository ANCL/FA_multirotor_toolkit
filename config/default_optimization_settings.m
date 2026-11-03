function settings = default_optimization_settings(parameterization)
%DEFAULT_OPTIMIZATION_SETTINGS SQP defaults and optional GA/patternsearch settings.
%
% Study runners use their own study_XX_settings.m instead. This function
% provides sensible defaults when optimize_design is called directly.
if nargin < 1 || isempty(parameterization), parameterization = 'p1'; end
parameterization = char(string(parameterization));
if ~ismember(parameterization, {'p1', 'p2', 'p3'})
    error('fa:Parameterization', 'Expected p1, p2, or p3.');
end

settings.solver = 'sqp';
settings.sqp.starts = 16;
settings.sqp.max_iterations = 350;
settings.sqp.max_function_evaluations = 12000;
settings.sqp.optimality_tolerance = 1e-7;
settings.sqp.step_tolerance = 1e-9;
settings.constraint_tolerance = 1e-6;
settings.local_refinements = 2;
settings.local_start_min_distance = 0.05;
settings.use_parallel = false;

settings.ga.function_tolerance = 1e-10;
settings.ga.nonlinear_constraint_algorithm = 'penalty';
settings.ga.initial_penalty = 10;
settings.ga.penalty_factor = 100;

settings.patternsearch.function_tolerance = 1e-7;
settings.patternsearch.mesh_tolerance = 1e-5;
if strcmp(parameterization, 'p1')
    settings.ga.population_size = 400;
    settings.ga.max_generations = 500;
    settings.ga.max_stall_generations = 200;
    settings.patternsearch.max_function_evaluations = 20000;
else
    settings.ga.population_size = 120;
    settings.ga.max_generations = 60;
    settings.ga.max_stall_generations = 20;
    settings.patternsearch.max_function_evaluations = 3000;
end
end
