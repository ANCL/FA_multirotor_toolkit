function files = reporting_result_files(folders)
%REPORTING_RESULT_FILES Canonical paths to completed numerical results.
files.objective_cross = fullfile(folders.designs,'objective_cross_evaluation.mat');
files.rotorwise_designs = fullfile(folders.designs,'rotorwise_selected_designs.mat');
files.rotorwise_raw = fullfile(folders.designs,'rotorwise_all_runs.mat');
files.rotorwise_repeatability = fullfile(folders.designs,'rotorwise_repeatability.mat');
files.rotorwise_optimization_runs = fullfile(folders.designs, ...
    'rotorwise_optimization_runs.mat');
files.task = fullfile(folders.task,'task_capability.mat');
files.task_raw = fullfile(folders.task,'task_verification.mat');
files.parameterization_comparison = fullfile(folders.designs, ...
    'parameterization_comparison.mat');
files.all_designs = fullfile(folders.designs,'all_selected_designs.mat');
files.structured_raw = fullfile(folders.designs,'structured_all_runs.mat');
files.structured_repeatability = fullfile(folders.designs, ...
    'structured_repeatability.mat');
files.structured_optimization_runs = fullfile(folders.designs, ...
    'structured_optimization_runs.mat');
files.nested_domain_audit = fullfile(folders.designs,'nested_domain_audit.mat');
files.pareto = fullfile(folders.pareto,'authority_effort_tradeoff.mat');
files.pareto_all = fullfile(folders.pareto,'authority_effort_all_runs.mat');
files.pareto_raw = fullfile(folders.pareto,'pareto_results.mat');
files.pareto_repeatability = fullfile(folders.pareto,'run_repeatability.mat');
files.pareto_optimization_runs = fullfile(folders.pareto,'optimization_runs.mat');
files.nominal_sensitivity = fullfile(folders.sensitivity, ...
    'nominal_geometry_sensitivity.mat');
files.nominal_sensitivity_raw = fullfile(folders.sensitivity, ...
    'nominal_geometry_sensitivity_raw.mat');
files.condition_specific_sensitivity_raw = fullfile(folders.sensitivity, ...
    'condition_specific_sensitivity.mat');
files.condition_specific_sensitivity_summary = fullfile(folders.sensitivity, ...
    'condition_specific_sensitivity_summary.mat');
files.condition_specific_sensitivity_repeatability = fullfile( ...
    folders.sensitivity,'condition_specific_repeatability.mat');
files.condition_specific_sensitivity_runs = fullfile(folders.sensitivity, ...
    'condition_specific_design_runs.mat');
files.robustness = fullfile(folders.robustness,'robustness_summary.mat');
files.robustness_raw = fullfile(folders.robustness,'all_robustness_trials.mat');
end
