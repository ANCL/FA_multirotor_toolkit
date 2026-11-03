function metrics = evaluate_design(geometry, model, numerics)
%EVALUATE_DESIGN Evaluate the four design objectives and admissibility.
%
% Outputs r_F0 (maximize), sigma_min (maximize), condition_number
% (minimize), and hover_effort (minimize). A failed admissibility check
% does not turn the other available metrics into an artificial penalty.
% Set numerics.compute_force_authority=false for faster matrix-only calls.
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
geometry_check = check_geometry(geometry, model);
[A, A_force, A_moment] = allocation_matrix(geometry, model);
actuation = check_full_actuation(A, model.characteristic_length, ...
    numerics.full_actuation_threshold);
metrics = struct('geometry_check', geometry_check, ...
    'A', A, 'A_force', A_force, 'A_moment', A_moment, ...
    'A_normalized', actuation.A_normalized, ...
    'singular_values', actuation.singular_values, ...
    'rank', actuation.rank, 'sigma_min', actuation.sigma_min, ...
    'condition_number', actuation.condition_number, ...
    'fully_actuated', actuation.fully_actuated, ...
    'hover', [], 'mu_hover', nan(6, 1), 'hover_effort', Inf, ...
    'hover_feasible', false, 'r_F0', NaN, 'force_authority', [], ...
    'force_authority_computed', false, 'valid', false, 'failure_reason', '', ...
    'constraint_margins', struct('full_actuation', actuation.margin, ...
                                 'hover', -Inf));
if ~geometry_check.valid
    metrics.failure_reason = 'geometry constraints violated';
end
if ~actuation.fully_actuated
    if isempty(metrics.failure_reason)
        metrics.failure_reason = 'full-actuation threshold not satisfied';
    end
    return;
end
hover = solve_hover_input(A, model, numerics);
metrics.hover = hover;
metrics.mu_hover = hover.mu;
metrics.hover_effort = hover.effort;
metrics.hover_feasible = hover.feasible;
metrics.constraint_margins.hover = hover.minimum_margin;
if ~hover.feasible
    if isempty(metrics.failure_reason)
        metrics.failure_reason = 'hover input violates actuator bounds';
    end
    return;
end
if numerics.compute_force_authority
    force_authority = zero_moment_force_authority(A, model, numerics);
    metrics.force_authority = force_authority;
    metrics.force_authority_computed = true;
    metrics.r_F0 = force_authority.radius;
    if ~force_authority.valid
        if isempty(metrics.failure_reason)
            metrics.failure_reason = 'force-authority calculation invalid';
        end
        return;
    end
end
metrics.valid = geometry_check.valid;
if metrics.valid
    metrics.failure_reason = '';
end
end
