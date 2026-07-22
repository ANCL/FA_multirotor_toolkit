function resolved = resolved_evaluation_solver(solver)
%RESOLVED_EVALUATION_SOLVER Tolerances used by deterministic evaluations.
fields = {'full_actuation_threshold','equality_tolerance','bound_tolerance', ...
    'hull_tolerance','task_tolerance'};
resolved = struct();
for k = 1:numel(fields)
    name = fields{k};
    if ~isfield(solver,name)
        error('fa:MissingResolvedSetting', ...
            'Missing evaluation-solver field: %s',name);
    end
    resolved.(name) = solver.(name);
end
end
