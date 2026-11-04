function sets = build_feasible_wrench_sets(geometry, model, numerics)
%BUILD_FEASIBLE_WRENCH_SETS Construct bounded wrench and projected 3D sets.
%
% F = {A_force*mu | lower <= mu <= upper}; M is the unconstrained
% moment projection. F0 is the force set subject to zero moment.
% The 3D projections are exact zonotopes from all actuator-box corners;
% F0 reuses the toolkit's existing halfspace/vertex implementation.
if nargin < 2 || isempty(model), model = default_model(); end
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
[A, A_force, A_moment] = allocation_matrix(geometry, model);
n = size(A, 2);
if n ~= 6 || size(A, 1) ~= 6
    error('fa:FeasibleSets', 'This toolkit requires a six-rotor 6-by-6 allocation matrix.');
end
[lower, upper] = parse_actuator_bounds(model.actuator_bounds, n);

sets = struct();
sets.force = projected_zonotope(A_force, lower, upper, numerics);
sets.moment = projected_zonotope(A_moment, lower, upper, numerics);
sets.zero_moment_force = zero_moment_force_set(A, model, numerics);
sets.wrench = struct('center', A * ((lower + upper) / 2), ...
    'generators', A * diag((upper - lower) / 2), ...
    'allocation_matrix', A, 'lower_inputs', lower, 'upper_inputs', upper);
end

function result = projected_zonotope(B, lower, upper, numerics)
% Exact 3D projection of an axis-aligned actuator box.
n = numel(lower);
corner_bits = dec2bin(0:(2^n - 1)) - '0';
mu = bsxfun(@plus, lower, bsxfun(@times, upper - lower, corner_bits.'));
vertices = (B * mu).';
quantum = numerics.vertex_tolerance;
[~, keep] = unique(round(vertices / quantum), 'rows', 'stable');
vertices = vertices(keep, :);
if isempty(vertices)
    dimension = 0;
else
    dimension = rank(vertices - vertices(1, :), numerics.hull_tolerance);
end
triangles = zeros(0, 3);
if dimension == 3 && size(vertices, 1) >= 4
    triangles = convhulln(vertices);
end
result = struct('vertices', vertices, 'triangles', triangles, ...
    'affine_dimension', dimension, 'degenerate', dimension < 3, ...
    'center', B * ((lower + upper) / 2), ...
    'generators', B * diag((upper - lower) / 2));
end
