function specifications = authority_effort_threshold_plan( ...
    threshold_index,thresholds,seed_designs,previous_by_case,parameters,solver)
%AUTHORITY_EFFORT_THRESHOLD_PLAN Deterministic cases for one threshold.
count = 6*solver.independent_runs;
template_problem = make_design_problem('rotorwise','hover_effort',1,parameters);
template = make_optimization_case(1,'',template_problem,parameters,1,struct());
specifications = repmat(template,count,1);
local_index = 0;
base_index = (threshold_index-1)*count;
for normalization_case = 1:6
    for run_number = 1:solver.independent_runs
        local_index = local_index+1;
        case_name = sprintf('pareto_%03d_norm_%d_run_%d', ...
            threshold_index,normalization_case,run_number);
        description = sprintf( ...
            'Threshold %d/%d | normalization case %d/6 | repeat %d/%d', ...
            threshold_index,numel(thresholds),normalization_case, ...
            run_number,solver.independent_runs);
        problem = make_design_problem( ...
            'rotorwise','hover_effort',normalization_case,parameters);
        problem.authority_threshold = thresholds(threshold_index);
        problem.initial_designs = seed_designs{normalization_case};
        if ~isempty(previous_by_case{normalization_case})
            problem.initial_designs = [ ...
                previous_by_case{normalization_case};problem.initial_designs];
        end
        problem.case_name = case_name;
        context = struct('authority_threshold',thresholds(threshold_index));
        specifications(local_index) = make_optimization_case( ...
            base_index+local_index,description,problem,parameters, ...
            stable_seed(solver.master_seed,case_name),context);
    end
end
specifications = finalize_optimization_cases(specifications,solver);
end
