function results = run_architecture_tests()
%RUN_ARCHITECTURE_TESTS Low-cost Stage 01/02/P2 dependency regressions.
root = setup_project();
[parameters,solver] = study_settings();
folders = output_folders(root);
assert(endsWith(string(folders.designs),'01_unrestricted_optimization'));
assert(endsWith(string(folders.parameterizations),'02_parameterization_comparison'));
assert(endsWith(string(folders.pareto),'03_authority_effort'));
assert(endsWith(string(folders.sensitivity),'04_sensitivity'));
assert(endsWith(string(folders.robustness),'05_robustness'));
p1 = design_comparison_case_plan('rotorwise',parameters,solver);
p2p3 = design_comparison_case_plan('structured',parameters,solver);
assert(numel(p1)==4*6*solver.independent_runs);
assert(numel(p2p3)==2*4*solver.independent_runs);
problems = [p1.problem];
assert(all(strcmp({problems.parameterization},'rotorwise')));
problems = [p2p3.problem];
families = string({problems.parameterization});
assert(sum(families=="spatial_c3")==4*solver.independent_runs);
assert(sum(families=="planar_shared")==4*solver.independent_runs);
seeds = initial_structured_seeds('spatial_c3',parameters);
thresholds = linspace(0.2,0.7,3);
pareto = authority_effort_threshold_plan(1,thresholds,seeds,[],parameters,solver);
assert(numel(pareto)==solver.independent_runs);
pareto_problems = [pareto.problem];
assert(all(strcmp({pareto_problems.parameterization},'spatial_c3')));
assert(all([pareto_problems.normalization_case]==0));
assert(all(cellfun(@(x) ~contains(x,'_norm_'),{pareto.case_name})));
assert(numel(authority_effort_case_names(3,solver.independent_runs)) ...
    ==3*solver.independent_runs);
results = struct('passed',true,'p1_cases',numel(p1), ...
    'p2p3_cases',numel(p2p3),'pareto_cases_per_threshold',numel(pareto));
fprintf('STAGE ARCHITECTURE TESTS PASSED\n');
end
