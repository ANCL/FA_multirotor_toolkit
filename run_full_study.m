function output = run_full_study()
%RUN_FULL_STUDY Execute numerical stages in explicit dependency order.
% Never alters or deletes previously completed P1 checkpoints.
output = struct();
output.unrestricted_optimization = run_unrestricted_optimization();
output.parameterization_comparison = run_parameterization_comparison();
output.authority_effort = run_pareto_analysis();
output.sensitivity = run_sensitivity_analysis();
output.robustness = run_robustness_analysis();
fprintf('\nFULL NUMERICAL STUDY COMPLETED OR RESUMED\n');
end
