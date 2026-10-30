function files = reporting_result_files(folders)
%REPORTING_RESULT_FILES Canonical paths to completed numerical stage data.
files.design_manifest = fullfile(folders.designs,'stage_manifest.mat');
files.objective_cross = fullfile(folders.designs,'objective_cross_evaluation.mat');
files.rotorwise_designs = fullfile(folders.designs,'rotorwise_selected_designs.mat');
files.rotorwise_repeatability = fullfile(folders.designs,'rotorwise_repeatability.mat');
files.rotorwise_optimization_runs = fullfile(folders.designs, ...
    'rotorwise_optimization_runs.mat');
files.parameterization_manifest = fullfile(folders.parameterizations,'stage_manifest.mat');
files.spatial_c3_designs = fullfile(folders.parameterizations,'spatial_c3_selected_designs.mat');
files.parameterization_comparison = fullfile(folders.parameterizations, ...
    'parameterization_comparison.mat');
files.all_designs = fullfile(folders.parameterizations,'all_selected_designs.mat');
files.structured_repeatability = fullfile(folders.parameterizations, ...
    'structured_repeatability.mat');
files.structured_optimization_runs = fullfile(folders.parameterizations, ...
    'structured_optimization_runs.mat');
files.nested_domain_audit = fullfile(folders.parameterizations,'nested_domain_audit.mat');


files.pareto_manifest = fullfile(folders.pareto,'stage_manifest.mat');
files.pareto = fullfile(folders.pareto,'authority_effort_tradeoff.mat');
files.pareto_all = fullfile(folders.pareto,'authority_effort_all_runs.mat');
files.pareto_repeatability = fullfile(folders.pareto,'run_repeatability.mat');
files.pareto_optimization_runs = fullfile(folders.pareto,'optimization_runs.mat');

files.sensitivity_manifest = fullfile(folders.sensitivity,'stage_manifest.mat');
files.nominal_sensitivity = fullfile(folders.sensitivity, ...
    'nominal_geometry_sensitivity.mat');
files.condition_specific_sensitivity_summary = fullfile(folders.sensitivity, ...
    'condition_specific_sensitivity_summary.mat');
files.condition_specific_sensitivity_repeatability = fullfile( ...
    folders.sensitivity,'condition_specific_repeatability.mat');
files.condition_specific_sensitivity_runs = fullfile(folders.sensitivity, ...
    'condition_specific_design_runs.mat');

files.robustness_manifest = fullfile(folders.robustness,'stage_manifest.mat');
files.robustness = fullfile(folders.robustness,'robustness_summary.mat');
files.robustness_trials = fullfile(folders.robustness,'robustness_trials.mat');
end
