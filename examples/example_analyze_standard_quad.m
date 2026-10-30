function output = example_analyze_standard_quad()
%EXAMPLE_ANALYZE_STANDARD_QUAD Analyze a conventional X-configuration quad.
%
% Standard quadrotor:
%   - 4 equal-length arms
%   - arm azimuths at 45, 135, 225, 315 deg
%   - zero arm elevation
%   - zero rotor tilt
%   - alternating rotor reaction directions
%
% The script uses the same analysis toolkit as the FA multirotor studies.

setup_project();
[parameters,~] = study_settings();

%% =========================================================
% USER INPUTS
% ==========================================================

% Arm length
ell = ones(4,1);

% Standard X-configuration:
gamma = deg2rad([ ...
     45
    135
    225
    315]);

% Arm elevation
eta = zeros(4,1);

% No rotor cant / tilt
alpha = zeros(4,1);
beta  = zeros(4,1);

%% Build geometry

quad_geometry = angle_geometry( ...
    ell, ...
    gamma, ...
    eta, ...
    alpha, ...
    beta);

quad_geometry.parameterization = 'standard_quad_X';
quad_geometry.design_variables = [];
quad_geometry.normalization_case = [];

%% =========================================================
% QUAD-SPECIFIC PARAMETERS
% ==========================================================

% Alternating rotor spin directions.
%
% Change the overall sign if your numbering convention uses
% the opposite CW/CCW assignment.
quad_reaction_signs = [ ...
     1
    -1
     1
    -1];

% Use the same reaction-moment coefficient as the main study.
quad_kappa = parameters.kappa;


%% =========================================================
% ACTUATOR BOUNDS
% ==========================================================

% If all actuators use identical bounds, repeat the first
% study actuator bound for four rotors.
%
% This assumes actuator_bounds is stored rotor-wise as N x 2:
%
%       [lower_bound, upper_bound]
%
quad_actuator_bounds = repmat( ...
    parameters.actuator_bounds(1,:), ...
    4,1);


%% =========================================================
% HOVER WRENCH
% ==========================================================

% Same desired hover wrench used by the study.
quad_hover_wrench = parameters.hover_wrench;


%% =========================================================
% OPTIONAL REQUESTED WRENCHES
% ==========================================================

% Leave empty if the main purpose is to generate the standard
% geometry/allocation figures.
%
% A conventional quad cannot independently generate arbitrary
% six-dimensional wrenches at fixed attitude.

requested_wrenches = zeros(6,0);
requested_wrench_names = strings(0,1);


%% =========================================================
% CASE SPECIFICATION
% ==========================================================

case_spec = struct();

case_spec.name = 'standard_quad_X_45deg';

case_spec.geometry = quad_geometry;

case_spec.kappa = quad_kappa;

case_spec.reaction_signs = quad_reaction_signs;

case_spec.actuator_bounds = quad_actuator_bounds;

case_spec.hover_wrench = quad_hover_wrench;

case_spec.length_scale = parameters.force_moment_length;


case_spec.requested_wrenches = requested_wrenches;

case_spec.requested_wrench_names = requested_wrench_names;


%% =========================================================
% RUN ANALYSIS
% ==========================================================

output = analyze_configuration(case_spec);

fprintf('\nCompleted standard 45-degree X quadrotor analysis.\n');
fprintf('Results folder:\n%s\n',string(output.folder));

end