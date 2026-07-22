function resolved = resolved_optimization_solver(solver)
%RESOLVED_OPTIMIZATION_SOLVER Solver values used by one optimization case.
fields = {'global_solver','local_solver','local_refinements', ...
    'local_start_min_distance','ga','patternsearch','full_actuation_threshold', ...
    'equality_tolerance','bound_tolerance','hull_tolerance', ...
    'vertex_tolerance','task_tolerance','constraint_tolerance'};
resolved = copy_required_fields(solver,fields,'optimization solver');
end

function output = copy_required_fields(input,fields,label)
output = struct();
for k = 1:numel(fields)
    name = fields{k};
    if ~isfield(input,name)
        error('fa:MissingResolvedSetting','Missing %s field: %s',label,name);
    end
    output.(name) = input.(name);
end
end
