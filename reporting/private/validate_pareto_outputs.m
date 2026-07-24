function validate_pareto_outputs(summary,solver)
%VALIDATE_PARETO_OUTPUTS Check completeness and feasibility of the front.
required = {'threshold_index','authority_threshold','r_F0', ...
    'hover_effort','constraint_violation','nondominated'};
if ~all(ismember(required,summary.Properties.VariableNames))
    error('fa:IncompleteParetoFront', ...
        'The selected trade-off summary is missing required columns.');
end
if height(summary) ~= solver.pareto_points || ...
        numel(unique(summary.threshold_index)) ~= solver.pareto_points
    error('fa:IncompleteParetoFront', ...
        'Expected one selected solution for each threshold.');
end
if any(~isfinite(summary.constraint_violation)) || ...
        any(summary.constraint_violation > solver.constraint_tolerance)
    error('fa:InvalidParetoSolution', ...
        'A trade-off point violates constraints.');
end
if any(summary.r_F0+solver.constraint_tolerance < summary.authority_threshold)
    error('fa:InvalidParetoThreshold', ...
        'A selected trade-off point does not satisfy its authority threshold.');
end
if any(~summary.nondominated)
    error('fa:DominatedParetoPoint', ...
        'Every selected trade-off point must be nondominated.');
end

ordered = sortrows(summary,'r_F0');
tolerance = solver.pareto_classification_tolerance;
if any(diff(ordered.r_F0) <= 0) || ...
        any(diff(ordered.hover_effort) < -tolerance)
    error('fa:InvalidParetoOrdering', ...
        'The selected trade-off front is not monotonic.');
end
end
