function value = objective_value(metrics, objective)
%OBJECTIVE_VALUE Convert a scientific objective to the solver minimization cost.
switch objective
    case 'r_F0', value = -metrics.r_F0;
    case 'sigma_min', value = -metrics.sigma_min;
    case 'condition_number', value = metrics.condition_number;
    case 'hover_effort', value = metrics.hover_effort;
    otherwise
        error('fa:UnknownObjective', 'Unknown objective: %s', objective);
end
if ~metrics.valid || ~isfinite(value)
    value = 1e12;
end
end
