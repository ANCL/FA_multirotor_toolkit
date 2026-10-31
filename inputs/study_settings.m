function [p,s] = study_settings()
%STUDY_SETTINGS Scientific assumptions and numerical budgets for the study.
% Runtime-only controls are defined separately in runtime_settings.m.

% Scientific assumptions used by the comparative study. Quantities are
% normalized consistently with the allocation, feasibility, and metric code.

%% Study identity
p.study_id = 'fa_multirotor_comparative_design';
p.objectives = {'r_F0','sigma_min','condition_number','hover_effort'};

%% Vehicle and actuator model
p.n_rotors = 6;

% Nominal reaction-moment arm relative to the unit maximum rotor radius.
% This value is treated as a model assumption and varied explicitly later.
p.kappa = 0.03;

% Fixed rotor-label assignment. It does not impose geometric pairing.
p.reaction_signs = [1; 1; 1; -1; -1; -1];

% Mandatory practical baseline: normalized unidirectional actuators.
p.actuator_bounds = [zeros(6,1), ones(6,1)];

%% Geometry admissibility
% Rotor distances are normalized by the maximum rotor radius. The minimum
% arm length reserves a central region, and the exclusion radius enforces
% pairwise rotor separation.
p.geometry.ell_min = 0.30;
p.geometry.exclusion_radius = 0.15;

% The rotor-wise P1 parameterization uses local installation coordinates
% whose configured bounds cover the admissible thrust-direction sphere.
p.geometry.rotorwise.gamma = [-pi, pi];
p.geometry.rotorwise.eta = [-pi/2, pi/2];
p.geometry.rotorwise.alpha = [-pi, pi];
p.geometry.rotorwise.beta = [-pi/2, pi/2];

% Spatial C3 family. Rows are [lower upper] for
% [delta, eta_s, alpha_+, beta_+, alpha_-, beta_-].
p.geometry.spatial_ranges = [
     0,       2*pi/3
    -pi/2,    pi/2
    -pi,      pi
    -pi/2,    pi/2
    -pi,      pi
    -pi/2,    pi/2
];

% Planar shared-angle family.
% Rows are [lower upper] for [alpha, beta].
p.geometry.planar_ranges = [
    -pi,      pi
    -pi/2,    pi/2
];

%% Hover condition
% Body z is downward; the nominal hover wrench applies the opposing
% body-frame force with zero commanded moment.
p.hover_wrench = [0; 0; -1; 0; 0; 0];

%% Force-moment normalization
p.force_moment_length = 1;

%% Physical assumption sensitivity
% Physical sensitivity grids.
p.sensitivity.actuator_capacity_values = linspace(0.8,1.2,17);
p.sensitivity.kappa_values = linspace(0,0.06,13);
p.sensitivity.characteristic_length_values = ...
    2.^linspace(-1,1,17);

% Normalized vertical hover-load factor. With fixed gravity and actuator
% normalization, this represents relative vehicle or payload mass. The
% static weight component changes while the vehicle geometry is fixed.
p.sensitivity.hover_load_factor_values = linspace(0.8,1.2,17);

% Secondary binary comparison; the baseline remains unidirectional.
p.sensitivity.include_bidirectional = true;

% Metrics reported for every physical sensitivity condition. Each metric is
% evaluated on its corresponding baseline P2 optimum.
p.sensitivity.matrix_metrics = { ...
    'r_F0', ...
    'sigma_min', ...
    'condition_number', ...
    'hover_effort'};

% Objectives optimized under each changed assumption.
p.sensitivity.optimized_objectives.characteristic_length = ...
    p.sensitivity.matrix_metrics;
p.sensitivity.optimized_objectives.reaction_moment = ...
    p.sensitivity.matrix_metrics;
p.sensitivity.optimized_objectives.actuator_capacity = ...
    p.sensitivity.matrix_metrics;
p.sensitivity.optimized_objectives.bidirectional = ...
    p.sensitivity.matrix_metrics;
p.sensitivity.optimized_objectives.hover_load = ...
    p.sensitivity.matrix_metrics;

%% Robustness study
% Apply every perturbation family to the configured P2 optima.
p.robustness.design_objectives = {
    'r_F0'
    'sigma_min'
    'condition_number'
    'hover_effort'
};

% Independent Gaussian position-component errors normalized by the maximum
% rotor radius.
p.robustness.position_sigma = [0.005, 0.010, 0.020];

% Gaussian thrust-direction installation errors.
p.robustness.direction_sigma_rad = deg2rad([0.5, 1.0, 2.0]);

% Independent multiplicative actuator-capacity standard deviations.
p.robustness.capacity_sigma = [0.02, 0.05, 0.10];

% Independent multiplicative reaction-moment-ratio standard deviations.
p.robustness.kappa_sigma = [0.05, 0.10, 0.20];

% Number of perturbation trials retained for each uncertainty level.
p.robustness.trials_per_level = 500;

% Truncate Gaussian samples at the configured multiple of standard deviation.
p.robustness.truncation_sigma = 3;

% Numerical settings used by the comparative study.
% Unrestricted P1 searches use a larger population and refinement budget.

%% Required software and solvers
s.validated_release = '2024b';
s.global_solver = 'ga';
s.local_solver = 'patternsearch';

%% Repeated searches
s.master_seed = 20260717;
s.independent_runs = 5;
s.local_refinements = 2;
s.local_start_min_distance = 0.05;

%% Genetic algorithm
s.ga.population_size = 120;
s.ga.max_generations = 60;
s.ga.max_stall_generations = 20;
s.ga.function_tolerance = 1e-10;
s.ga.nonlinear_constraint_algorithm = 'penalty';
s.ga.initial_penalty = 10;
s.ga.penalty_factor = 100;

%% Unrestricted P1 search budget
s.rotorwise_ga_population_size = 400;
s.rotorwise_ga_max_generations = 500;
s.rotorwise_ga_max_stall_generations = 200;
s.rotorwise_patternsearch_max_function_evaluations = 20000;

%% Pattern-search refinement
s.patternsearch.max_function_evaluations = 3000;
s.patternsearch.function_tolerance = 1e-7;
s.patternsearch.mesh_tolerance = 1e-5;

%% Feasibility and verification tolerances
s.full_actuation_threshold = 1e-4;
s.equality_tolerance = 1e-8;
s.bound_tolerance = 1e-9;
s.hull_tolerance = 1e-8;
s.vertex_tolerance = 1e-9;
s.constraint_tolerance = 1e-6;

%% Pareto settings
s.pareto_classification_tolerance = 1e-4;
s.pareto_points = 41;
end
