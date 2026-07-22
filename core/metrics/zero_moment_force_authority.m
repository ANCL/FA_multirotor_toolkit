function result = zero_moment_force_authority(A, actuator_bounds, hover_force, solver)
%ZERO_MOMENT_FORCE_AUTHORITY Exact hover-centred F0 radius for square A.
%
% For a nonsingular six-actuator allocation matrix, every zero-moment force
% f has the unique actuator input
%   mu = B*f,  B = A\[I;0].
% The actuator box therefore gives twelve force-space half-spaces directly.
% Their distances from hover_force give the exact Euclidean radius of the
% largest hover-centred ball contained in F0. No hull construction is needed.

validateattributes(A,{'numeric'},{'real','finite','size',[6 6]});
validateattributes(hover_force,{'numeric'},{'real','finite','numel',3});
[mu_min,mu_max] = parse_actuator_bounds(actuator_bounds,6);

result = struct( ...
    'radius',NaN, ...
    'inside',false, ...
    'B',nan(6,3), ...
    'mu_hover',nan(6,1), ...
    'row_norms',nan(6,1), ...
    'upper_distances',nan(6,1), ...
    'lower_distances',nan(6,1), ...
    'limiting_actuator',NaN, ...
    'limiting_bound','', ...
    'valid',false, ...
    'failure_reason','');

if rcond(A) <= eps(class(A))
    result.failure_reason = 'allocation matrix is not invertible';
    return;
end

force_embedding = [eye(3);zeros(3)];
B = A\force_embedding;
mu_hover = B*hover_force(:);
row_norms = vecnorm(B,2,2);
result.B = B;
result.mu_hover = mu_hover;
result.row_norms = row_norms;

inside = all(mu_hover >= mu_min-solver.bound_tolerance) && ...
    all(mu_hover <= mu_max+solver.bound_tolerance);
result.inside = inside;
if ~inside
    result.failure_reason = 'hover force is outside the zero-moment force set';
    return;
end

active = row_norms > 100*eps(max(1,norm(B,Inf)));
upper_distances = inf(6,1);
lower_distances = inf(6,1);
upper_distances(active) = (mu_max(active)-mu_hover(active))./row_norms(active);
lower_distances(active) = (mu_hover(active)-mu_min(active))./row_norms(active);
result.upper_distances = upper_distances;
result.lower_distances = lower_distances;

all_distances = [upper_distances;lower_distances];
[radius,location] = min(all_distances);
if ~isfinite(radius) || radius < -solver.hull_tolerance
    result.failure_reason = 'zero-moment force authority is negative or nonfinite';
    return;
end
result.radius = max(0,radius);
if location <= 6
    result.limiting_actuator = location;
    result.limiting_bound = 'upper';
else
    result.limiting_actuator = location-6;
    result.limiting_bound = 'lower';
end
result.valid = true;
end
