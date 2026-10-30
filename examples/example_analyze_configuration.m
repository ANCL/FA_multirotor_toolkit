function output = example_analyze_configuration()
%EXAMPLE_ANALYZE_CONFIGURATION Analyze several fixed configurations.
%
% Edit only the USER INPUTS section. The example evaluates three distinct
% six-rotor configurations using the same actuator, hover, and wrench
% assumptions. Each configuration receives a complete and independent
% analysis package under results/analyses/configurations/.

setup_project();
[parameters,~] = study_settings();

%% USER INPUTS
% Configuration 1: planar shared-angle family (P3).
planar_geometry = planar_shared_geometry( ...
    deg2rad([30;10]),parameters);

% Configuration 2: spatial C3 family (P2). The variables are ordered as
% [delta, eta_s, alpha_+, beta_+, alpha_-, beta_-].
spatial_geometry = spatial_c3_geometry( ...
    deg2rad([30;15;35;20;-35;-20]),parameters);

% Configuration 3: directly specified rotor-by-rotor geometry. Angles are
% ordered rotor-wise and passed to the common angle_geometry constructor.
ell = [1.00;0.92;0.88;1.00;0.94;0.90];
gamma = deg2rad([0;60;120;180;240;300]);
eta = deg2rad([8;-6;10;-8;6;-10]);
alpha = parameters.reaction_signs(:).*deg2rad([28;32;25;30;27;33]);
beta = deg2rad([8;-10;6;-8;10;-6]);
% ell = [0.36;0.36;0.36;0.36;0.36;0.36];
% gamma = deg2rad([0;60;120;180;240;300]);
% eta = deg2rad([0;0;0;0;0;0]);
% alpha = parameters.reaction_signs(:).*deg2rad([18.3;21.6;20.4;21.4;17;22.6]);
% beta = deg2rad([0;0;0;0;0;0]);
rotorwise_geometry = angle_geometry(ell,gamma,eta,alpha,beta);
rotorwise_geometry.parameterization = 'direct_rotorwise';
rotorwise_geometry.design_variables = [];
rotorwise_geometry.normalization_case = [];

% Optional requested wrenches. Each column is ordered as
% [F_x; F_y; F_z; tau_x; tau_y; tau_z].
requested_wrenches = [ ...
    0.12, 0.00, 0.00, 0.08
    0.00, 0.12, 0.00,-0.06
   -1.00,-1.00,-1.00,-1.00
    0.00, 0.00, 0.00, 0.02
    0.00, 0.00, 0.00, 0.00
    0.00, 0.00, 0.03, 0.015];
requested_wrench_names = [ ...
    "forward_force"
    "lateral_force"
    "yaw_moment"
    "combined_wrench"];

% Add, remove, or reorder entries to change which configurations are run.
configuration_names = [ ...
    "example_planar_shared"
    "example_spatial_c3"
    "example_direct_rotorwise"];
configuration_geometries = { ...
    planar_geometry
    spatial_geometry
    rotorwise_geometry};

%% RUN
number_of_cases = numel(configuration_geometries);
case_outputs = cell(number_of_cases,1);
output_folders = strings(number_of_cases,1);

for case_index = 1:number_of_cases
    case_spec = make_case_spec( ...
        configuration_names(case_index), ...
        configuration_geometries{case_index}, ...
        requested_wrenches,requested_wrench_names,parameters);

    case_outputs{case_index} = analyze_configuration(case_spec);
    output_folders(case_index) = string(case_outputs{case_index}.folder);

    fprintf('\nCompleted configuration %d of %d: %s\n%s\n', ...
        case_index,number_of_cases,configuration_names(case_index), ...
        output_folders(case_index));
end

output = struct();
output.names = configuration_names;
output.cases = case_outputs;
output.folders = output_folders;
end

function case_spec = make_case_spec( ...
    name,geometry,requested_wrenches,requested_wrench_names,parameters)
%MAKE_CASE_SPEC Apply common assumptions to one example configuration.

case_spec = struct();
case_spec.name = char(name);
case_spec.geometry = geometry;
case_spec.kappa = parameters.kappa;
case_spec.reaction_signs = parameters.reaction_signs;
case_spec.actuator_bounds = parameters.actuator_bounds;
case_spec.hover_wrench = parameters.hover_wrench;
case_spec.length_scale = parameters.force_moment_length;
case_spec.requested_wrenches = requested_wrenches;
case_spec.requested_wrench_names = requested_wrench_names;
end
