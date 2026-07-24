function [p,s] = study_settings()
%STUDY_SETTINGS Scientific assumptions and numerical budgets for the study.
% Runtime-only controls are defined separately in runtime_settings.m.

% Scientific assumptions used by the comparative study.
% All quantities are normalized according to the definitions documented in
% MATH_TO_CODE.md.

%% Study identity
p.study_id = 'fa_multirotor_comparative_design';
p.objectives = {'r_F0','sigma_min','condition_number','hover_effort','q_star'};

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
% Rotor distances are normalized by max_i ||p_i|| = 1.
%
% ell_min = 0.30 reserves a central region whose radius is 30% of the
% maximum rotor distance.
%
% exclusion_radius = 0.15 requires rotor centres to remain at least
% 2r = 0.30 apart.
p.geometry.ell_min = 0.30;
p.geometry.exclusion_radius = 0.15;

% The rotor-wise P1 baseline uses local installation coordinates while
% retaining the complete physical sphere for every thrust direction.
% alpha spans a full revolution and beta spans +/-90 deg, so the mapping
% Rz(gamma)Ry(eta)Rx(alpha)Ry(beta)(-e3) can represent any unit u_i.
p.geometry.rotorwise.gamma = [-pi, pi];
p.geometry.rotorwise.eta = [-pi/2, pi/2];
p.geometry.rotorwise.alpha = [-pi, pi];
p.geometry.rotorwise.beta = [-pi/2, pi/2];

% Spatial C3 family.
% Rows are [lower upper] for:
% [delta, eta_s, alpha_+, beta_+, alpha_-, beta_-].
%
% delta spans aligned to fully interleaved triplets.
% Arm elevation is limited to +/-30 deg.
% Rotor installation angles are limited to +/-60 deg.
p.geometry.spatial_ranges = [
     0,       pi/3
    -pi/6,    pi/6
    -pi/3,    pi/3
    -pi/3,    pi/3
    -pi/3,    pi/3
    -pi/3,    pi/3
];

% Planar shared-angle family.
% Rows are [lower upper] for [alpha, beta].
p.geometry.planar_ranges = [
    -pi/3,    pi/3
    -pi/3,    pi/3
];

%% Hover condition
% Body z is downward. A normalized vehicle weight of one therefore
% requires an upward body-frame hover force of -1 along z_B.
p.hover_wrench = [0; 0; -1; 0; 0; 0];

%% Prescribed anisotropic task-wrench set
% Force coordinates are normalized by the unit actuator capacity.
% Moment coordinates are normalized using the unit characteristic length.
%
% The baseline task emphasizes horizontal force, includes moderate
% vertical reserve and roll/pitch moments, and assigns a smaller yaw
% requirement.
baseline_task = [
    0.25    % F_x
    0.25    % F_y
    0.15    % F_z
    0.12    % tau_x
    0.12    % tau_y
    0.06    % tau_z
];

p.task.Lambda = diag(baseline_task);

%% Force-moment normalization
p.force_moment_length = 1;

%% Physical assumption sensitivity
% Task emphasis is parameterized by the physical moment-emphasis fraction
%
%   rho = ||lambda_m||_2 / (||lambda_f||_2 + ||lambda_m||_2),
%
% where lambda = diag(Lambda). The sampled values include the pure-force
% and pure-moment limiting cases while preserving ||lambda||_2.
baseline_force_norm = norm(baseline_task(1:3),2);
baseline_moment_norm = norm(baseline_task(4:6),2);
rho_0 = baseline_moment_norm/(baseline_force_norm+baseline_moment_norm);

% Twenty-five approximately uniform task-emphasis values. Replace the
% nearest uniform value with rho_0 so the exact nominal task remains part
% of the grid without increasing the number of points.
rho_values = linspace(0,1,25);
[~,nominal_rho_index] = min(abs(rho_values-rho_0));
rho_values(nominal_rho_index) = rho_0;
p.sensitivity.task_emphasis_values = sort(rho_values);

% High-resolution physical sensitivity grids.
p.sensitivity.actuator_capacity_values = linspace(0.8,1.2,17);
p.sensitivity.kappa_values = linspace(0,0.06,13);
p.sensitivity.characteristic_length_values = ...
    2.^linspace(-1,1,17);

% Normalized vertical hover-load factor. With fixed gravity and actuator
% normalization, this represents relative vehicle or payload mass. The task
% deviations remain fixed, so only the static weight component is varied.
p.sensitivity.hover_load_factor_values = linspace(0.8,1.2,17);

% Secondary binary comparison; the baseline remains unidirectional.
p.sensitivity.include_bidirectional = true;

% Objectives optimized under each changed assumption.
p.sensitivity.optimized_objectives.task_emphasis = {'q_star'};
p.sensitivity.optimized_objectives.characteristic_length = ...
    {'sigma_min', 'condition_number'};
p.sensitivity.optimized_objectives.reaction_moment = ...
    {'q_star', 'sigma_min', 'condition_number'};
p.sensitivity.optimized_objectives.actuator_capacity = {'q_star', 'r_F0'};
p.sensitivity.optimized_objectives.bidirectional = {'q_star', 'r_F0'};
p.sensitivity.optimized_objectives.hover_load = {'q_star', 'r_F0'};

%% Robustness study
% Apply every perturbation family to the five rotor-wise optima.
p.robustness.design_objectives = {
    'r_F0'
    'sigma_min'
    'condition_number'
    'hover_effort'
    'q_star'
};

% Independent Gaussian position-component errors, normalized by the unit
% maximum rotor radius: 0.5%, 1%, and 2%.
p.robustness.position_sigma = [0.005, 0.010, 0.020];

% Gaussian thrust-direction installation errors: 0.5, 1, and 2 degrees.
p.robustness.direction_sigma_rad = deg2rad([0.5, 1.0, 2.0]);

% Independent multiplicative actuator-capacity standard deviations:
% 2%, 5%, and 10%.
p.robustness.capacity_sigma = [0.02, 0.05, 0.10];

% Independent multiplicative kappa standard deviations:
% 5%, 10%, and 20%.
p.robustness.kappa_sigma = [0.05, 0.10, 0.20];

% Number of perturbation trials retained for each uncertainty level.
p.robustness.trials_per_level = 500;

% Truncate Gaussian samples at +/-3 standard deviations.
p.robustness.truncation_sigma = 3;

% Numerical settings used by the comparative study.
% The same global and local budgets are applied to every objective.

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
s.task_tolerance = 1e-8;
s.task_verification_increment = 1e-5;
s.constraint_tolerance = 1e-6;

%% Pareto settings
s.pareto_classification_tolerance = 1e-4;
s.pareto_points = 41;
end
