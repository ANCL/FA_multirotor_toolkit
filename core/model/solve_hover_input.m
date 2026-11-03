function hover = solve_hover_input(A, model, numerics)
%SOLVE_HOVER_INPUT Compute the unique hover allocation of a six-rotor design.
%
% The allocation is w=A*mu. Hover effort is sum(mu.^2), not a minimized
% redundant allocation cost. Only nonsingular 6-by-6 matrices are supported.
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
validateattributes(A, {'numeric'}, {'real', 'finite', 'size', [6 6]});
[lower, upper] = parse_actuator_bounds(model.actuator_bounds, 6);
hover = struct('mu', nan(6, 1), 'effort', Inf, 'feasible', false, ...
    'residual', Inf, 'minimum_margin', -Inf, 'margins', nan(6, 1));
if rcond(A) <= eps(class(A)), return; end
mu = A \ model.hover_wrench(:);
residual = norm(A * mu - model.hover_wrench(:), Inf);
margins = min(mu - lower, upper - mu);
hover.mu = mu;
hover.residual = residual;
hover.margins = margins;
hover.minimum_margin = min(margins);
hover.feasible = residual <= numerics.equality_tolerance * ...
    max(1, norm(model.hover_wrench, Inf)) && ...
    all(mu >= lower - numerics.bound_tolerance) && ...
    all(mu <= upper + numerics.bound_tolerance);
if hover.feasible
    hover.effort = sum(mu .^ 2);
end
end
