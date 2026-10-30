function specifications = authority_effort_threshold_plan( ...
    threshold_index,thresholds,seed_designs,previous_incumbent,parameters,solver)
%AUTHORITY_EFFORT_THRESHOLD_PLAN Optimize one threshold in the P2 family.
count = solver.independent_runs;
template_problem = make_design_problem('spatial_c3','hover_effort',0,parameters);
template = make_optimization_case(1,'',template_problem,parameters,1,struct());
specifications = repmat(template,count,1);
for run_number = 1:count
    case_name = sprintf('pareto_%03d_run_%d',threshold_index,run_number);
    description = sprintf('P2 threshold %d/%d | repeat %d/%d', ...
        threshold_index,numel(thresholds),run_number,count);
    problem = make_design_problem('spatial_c3','hover_effort',0,parameters);
    problem.authority_threshold = thresholds(threshold_index);
    problem.initial_designs = seed_designs;
    if ~isempty(previous_incumbent)
        problem.initial_designs = [previous_incumbent;problem.initial_designs];
    end
    problem.case_name = case_name;
    context = struct('authority_threshold',thresholds(threshold_index));
    specifications(run_number) = make_optimization_case( ...
        (threshold_index-1)*count+run_number,description, ...
        problem,parameters,stable_seed(solver.master_seed,case_name),context);
end
specifications = finalize_optimization_cases(specifications,solver);
end
