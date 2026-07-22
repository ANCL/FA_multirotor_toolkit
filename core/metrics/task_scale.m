function task = task_scale(A, parameters, solver)
%TASK_SCALE Compute the exact maximum scale of the prescribed task box.
%
% For the square six-input study model, G = A\Lambda maps task-box
% deviations to actuator deviations. Rowwise absolute sums give the exact
% worst-case actuator excursion over the infinity-norm task box.

Lambda = parameters.task.Lambda;
task_diagonal = diag(Lambda);
if norm(Lambda-diag(task_diagonal),Inf) > solver.equality_tolerance || ...
        any(task_diagonal < 0) || ~any(task_diagonal > 0)
    error('fa:InvalidTaskMatrix', ...
        ['task.Lambda must be diagonal with nonnegative entries and at ' ...
         'least one positive entry.']);
end
[mu_min,mu_max] = parse_actuator_bounds( ...
    parameters.actuator_bounds,parameters.n_rotors);
task = struct( ...
    'q_star',NaN, ...
    'mu_hover',nan(6,1), ...
    'G',nan(6), ...
    'row_abs_sums',nan(6,1), ...
    'limiting_actuator',NaN, ...
    'limiting_bound','', ...
    'valid',false, ...
    'failure_reason','');
if rcond(A) <= eps(class(A))
    task.failure_reason = 'allocation matrix is not invertible';
    return;
end

mu_hover = A\parameters.hover_wrench(:);
if any(mu_hover < mu_min-solver.bound_tolerance) || ...
        any(mu_hover > mu_max+solver.bound_tolerance)
    task.failure_reason = 'hover input violates actuator bounds';
    return;
end
G = A\Lambda;
row_abs_sums = sum(abs(G),2);
scale_tolerance = solver.equality_tolerance*max(1,norm(G,Inf));
active = row_abs_sums > scale_tolerance;
task.mu_hover = mu_hover;
task.G = G;
task.row_abs_sums = row_abs_sums;
if ~any(active)
    task.q_star = Inf;
    task.valid = true;
    task.limiting_bound = 'none';
    return;
end

active_indices = find(active);
upper_scale = (mu_max(active)-mu_hover(active))./row_abs_sums(active);
lower_scale = (mu_hover(active)-mu_min(active))./row_abs_sums(active);
all_scales = [upper_scale;lower_scale];
[q_star,location] = min(all_scales);
if ~isfinite(q_star) || q_star < -solver.task_tolerance
    task.failure_reason = 'task scale is negative or nonfinite';
    return;
end
task.q_star = max(0,q_star);
if location <= numel(active_indices)
    task.limiting_actuator = active_indices(location);
    task.limiting_bound = 'upper';
else
    task.limiting_actuator = active_indices(location-numel(active_indices));
    task.limiting_bound = 'lower';
end
task.valid = true;
end
