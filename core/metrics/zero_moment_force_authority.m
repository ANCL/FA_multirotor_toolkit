function result = zero_moment_force_authority(A, model, numerics)
%ZERO_MOMENT_FORCE_AUTHORITY Compute the exact hover-centered F0-ball radius.
%
% For invertible 6-by-6 A, zero-moment forces f require mu=B*f, with
% B=A\[eye(3);zeros(3)]. Twelve actuator-bound halfspaces determine F0.
% This avoids constructing a convex hull for each optimization evaluation.
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
validateattributes(A, {'numeric'}, {'real', 'finite', 'size', [6 6]});
[lower, upper] = parse_actuator_bounds(model.actuator_bounds, 6);
result = struct('valid', false, 'radius', NaN, 'inside', false, ...
    'limiting_actuator', NaN, 'limiting_bound', '', ...
    'upper_distances', nan(6, 1), 'lower_distances', nan(6, 1), ...
    'B', nan(6, 3), 'mu_hover', nan(6, 1));
if rcond(A) <= eps(class(A)), return; end
B = A \ [eye(3); zeros(3)];
mu_hover = B * model.hover_wrench(1:3);
row_norms = vecnorm(B, 2, 2);
inside = all(mu_hover >= lower - numerics.bound_tolerance) && ...
    all(mu_hover <= upper + numerics.bound_tolerance);
result.B = B;
result.mu_hover = mu_hover;
result.inside = inside;
if ~inside, return; end
active = row_norms > 100 * eps(max(1, norm(B, Inf)));
upper_distances = inf(6, 1);
lower_distances = inf(6, 1);
upper_distances(active) = (upper(active) - mu_hover(active)) ./ row_norms(active);
lower_distances(active) = (mu_hover(active) - lower(active)) ./ row_norms(active);
all_distances = [upper_distances; lower_distances];
[radius, index] = min(all_distances);
result.upper_distances = upper_distances;
result.lower_distances = lower_distances;
if ~isfinite(radius) || radius < -numerics.hull_tolerance, return; end
result.radius = max(0, radius);
result.valid = true;
if index <= 6
    result.limiting_actuator = index;
    result.limiting_bound = 'upper';
else
    result.limiting_actuator = index - 6;
    result.limiting_bound = 'lower';
end
end
