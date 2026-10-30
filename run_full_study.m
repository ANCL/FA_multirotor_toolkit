function output = run_full_study()
%RUN_FULL_STUDY Run or resume all numerical studies in dependency order.
% Compatible completed checkpoints are reused. A mismatch remains local to
% its study or case and never archives the complete results/current tree.
output = struct();
output.design_comparison = run_design_comparison();
output.authority_effort = run_pareto_analysis();
output.sensitivity = run_sensitivity_analysis();
output.robustness = run_robustness_analysis();
fprintf('\nFULL NUMERICAL STUDY COMPLETED OR RESUMED\n');
end
