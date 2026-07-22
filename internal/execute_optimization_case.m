function result = execute_optimization_case(specification,solver,execution)
%EXECUTE_OPTIMIZATION_CASE Worker-safe optimization entry point.
case_execution = execution;
case_execution.case_provenance = specification.provenance;
result = optimize_design(specification.problem,specification.parameters,solver, ...
    specification.seed,case_execution);
result.context = specification.context;
end
