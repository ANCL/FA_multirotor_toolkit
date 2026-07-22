function output = example_optimize_one_design()
%EXAMPLE_OPTIMIZE_ONE_DESIGN Run several custom optimization objectives.
%
% Edit only the USER INPUTS section. The default example optimizes all five
% supported objectives for the planar shared-angle family (P3), using one
% deterministic repetition per objective. Each objective is an independent
% custom problem with its own checkpoints, selected design, and complete
% selected-configuration analysis under results/analyses/optimizations/.
%
% This is not the exhaustive comparative study: it uses one selected
% parameterization and does not run sensitivity, Pareto, or robustness work.

setup_project();

%% USER INPUTS
% Supported values: planar_shared, spatial_c3, or rotorwise.
parameterization = 'planar_shared';

% Add, remove, or reorder objectives as needed. Supported objectives are
% r_F0, sigma_min, condition_number, hover_effort, and q_star.
objectives = { ...
    'r_F0'
    'sigma_min'
    'condition_number'
    'hover_effort'
    'q_star'};

% Repetitions are applied independently to every objective. One repetition
% is suitable for demonstrating the workflow. Increase this value when the
% optimization result itself will be used scientifically.
independent_runs = 1;

% false resumes compatible checkpoints. true clears only the corresponding
% custom objective folder before running it again.
overwrite = false;

% Optional partial overrides use the same nested field names as
% study_settings.m and runtime_settings.m. Leave these structures empty to
% retain the validated defaults.
parameter_overrides = struct();
solver_overrides = struct();
runtime_overrides = struct();

% Example optional overrides:
% solver_overrides.ga.max_generations = 30;
% runtime_overrides.mode = 'serial';

%% RUN
number_of_objectives = numel(objectives);
case_outputs = cell(number_of_objectives,1);
output_folders = strings(number_of_objectives,1);

for objective_index = 1:number_of_objectives
    objective = objectives{objective_index};

    case_spec = struct();
    case_spec.name = sprintf( ...
        'example_%s_%s_optimization',parameterization,objective);
    case_spec.parameterization = parameterization;
    case_spec.objective = objective;
    case_spec.independent_runs = independent_runs;
    case_spec.overwrite = overwrite;
    case_spec.parameters = parameter_overrides;
    case_spec.solver = solver_overrides;
    case_spec.runtime = runtime_overrides;

    case_outputs{objective_index} = optimize_custom_design(case_spec);
    output_folders(objective_index) = ...
        string(case_outputs{objective_index}.folder);

    fprintf('\nCompleted objective %d of %d: %s\n%s\n', ...
        objective_index,number_of_objectives,objective, ...
        output_folders(objective_index));
end

output = struct();
output.parameterization = parameterization;
output.objectives = string(objectives(:));
output.cases = case_outputs;
output.folders = output_folders;
end
