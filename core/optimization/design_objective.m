function cost = design_objective(x, problem, model)
%DESIGN_OBJECTIVE Convert scientific performance to minimization cost.
%
% Do not return a flat penalty just because hover is infeasible. Physical
% feasibility is handled independently by design_constraints. The reported
% scientific values are reevaluated by evaluate_design at the end of a run.
geometry = decode_design(x, problem);
A = allocation_matrix(geometry, model);
A_bar = normalized_allocation_matrix(A, model.characteristic_length);
s = svd(A_bar);
switch problem.objective
    case 'sigma_min'
        cost = -s(end);
    case 'condition_number'
        cost = s(1) / max(s(end), 1e-14);
    case 'hover_effort'
        if rcond(A) > 1e-12
            mu = A \ model.hover_wrench(:);
        else
            mu = pinv(A) * model.hover_wrench(:);
        end
        cost = sum(mu.^2);
    case 'r_F0'
        if rcond(A) > 1e-12
            B = A \ [eye(3); zeros(3)];
        else
            B = pinv(A) * [eye(3); zeros(3)];
        end
        [lower, upper] = parse_actuator_bounds(model.actuator_bounds, 6);
        mu = B * model.hover_wrench(1:3);
        norms = vecnorm(B, 2, 2);
        active = norms > 100 * eps(max(1, norm(B, Inf)));
        if any(active)
            distances = [(upper(active)-mu(active))./norms(active); ...
                         (mu(active)-lower(active))./norms(active)];
            cost = -min(distances);
        else
            cost = 1e12;
        end
    otherwise
        error('fa:Objective', 'Unknown scientific objective.');
end
if ~isfinite(cost)
    cost = 1e12;
end
end
