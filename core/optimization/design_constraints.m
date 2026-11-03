function [c, ceq] = design_constraints(x, problem, model, numerics)
%DESIGN_CONSTRAINTS Nonlinear physical inequalities for optimization.
%
% c<=0 enforces rotor separation, numerical full actuation, hover input
% bounds, and hover allocation. The P1 radius normalization and other
% parameter bounds are enforced by the variable representation and solver.
% An optional Study 03 epsilon constraint is r_F0 >= authority_threshold.
if nargin < 4 || isempty(numerics), numerics = default_numerics(); end
geometry = decode_design(x, problem);
p = geometry.positions;
pairs = nchoosek(1:6, 2);
separation = vecnorm(p(:, pairs(:,1)) - p(:, pairs(:,2)), 2, 1).';
A = allocation_matrix(geometry, model);
A_bar = normalized_allocation_matrix(A, model.characteristic_length);
singular_values = svd(A_bar);
sigma_min = singular_values(end);
[lower, upper] = parse_actuator_bounds(model.actuator_bounds, 6);

% Even singular trial geometries must return finite, fixed-size constraints.
% A pseudoinverse is used only outside the adequately conditioned region;
% the explicit sigma_min constraint prevents those points being accepted.
if rcond(A) > 1e-12
    mu = A \ model.hover_wrench(:);
else
    mu = pinv(A) * model.hover_wrench(:);
end
residual = norm(A * mu - model.hover_wrench(:), Inf);
c = [model.geometry.minimum_separation - separation; ...
     numerics.full_actuation_threshold - sigma_min; ...
     lower - mu; mu - upper; ...
     residual - numerics.equality_tolerance];
if isfield(problem,'authority_threshold') && ~isempty(problem.authority_threshold)
    radius = signed_force_authority(A, model);
    c(end+1, 1) = problem.authority_threshold - radius;
end
if isfield(problem,'sigma_threshold') && ~isempty(problem.sigma_threshold)
    c(end+1, 1) = problem.sigma_threshold - sigma_min;
end
if isfield(problem,'condition_ceiling') && ~isempty(problem.condition_ceiling)
    c(end+1, 1) = singular_values(1) / max(sigma_min,1e-14) - ...
        problem.condition_ceiling;
end
% Keep GA and patternsearch constraint evaluations numerically defined.
c(~isfinite(c)) = 1e12;
ceq = [];
end

function radius = signed_force_authority(A, model)
%SIGNED_FORCE_AUTHORITY Halfspace radius before hover feasibility clipping.
if rcond(A) <= 1e-12
    radius = -1;
    return;
end
B = A \ [eye(3); zeros(3)];
[lower, upper] = parse_actuator_bounds(model.actuator_bounds, 6);
mu = B * model.hover_wrench(1:3);
rows = vecnorm(B, 2, 2);
active = rows > 100 * eps(max(1, norm(B, Inf)));
if ~any(active)
    radius = -1e12;
    return;
end
radius = min([(upper(active) - mu(active)) ./ rows(active); ...
              (mu(active) - lower(active)) ./ rows(active)]);
if ~isfinite(radius), radius = -1e12; end
end
