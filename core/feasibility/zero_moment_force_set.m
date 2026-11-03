function force_set = zero_moment_force_set(A, model, numerics)
%ZERO_MOMENT_FORCE_SET Construct the exact 3D force polytope at zero moment.
%
% For invertible six-rotor A, mu=B*f with B=A\[I;0]. The actuator box
% becomes twelve halfspaces in force coordinates. Vertices are intersections
% of independent triples of their boundary planes. Used for analysis and
% plotting; the optimized authority metric uses the direct halfspace formula.
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
validateattributes(A, {'numeric'}, {'real', 'finite', 'size', [6 6]});
[lower, upper] = parse_actuator_bounds(model.actuator_bounds, 6);
if rcond(A) <= eps(class(A))
    error('fa:SingularAllocation', 'F0 requires an invertible allocation matrix.');
end
B = A \ [eye(3); zeros(3)];
H = [B; -B];
b = [upper; -lower];
% Zero rows cannot form facets but still represent valid inequalities.
active = vecnorm(H, 2, 2) > 100 * eps(max(1, norm(H, Inf)));
if any(b(~active) < -numerics.bound_tolerance)
    error('fa:EmptyForceSet', 'Zero-moment force constraints are inconsistent.');
end
H = H(active, :);
b = b(active);
% Store unit outward normals so offsets are signed force-space distances.
normal_lengths = vecnorm(H, 2, 2);
H = H ./ normal_lengths;
b = b ./ normal_lengths;
triples = nchoosek(1:size(H, 1), 3);
vertices = zeros(3, size(triples, 1));
count = 0;
for k = 1:size(triples, 1)
    indices = triples(k, :);
    H3 = H(indices, :);
    if rcond(H3) < 1e-11, continue; end
    f = H3 \ b(indices);
    if all(H * f <= b + numerics.hull_tolerance)
        count = count + 1;
        vertices(:, count) = f;
    end
end
vertices = vertices(:, 1:count);
if ~isempty(vertices)
    [~, keep] = unique(round(vertices.' / numerics.vertex_tolerance), ...
        'rows', 'stable');
    vertices = vertices(:, keep);
end
affine_dimension = 0;
triangles = zeros(0, 3);
if ~isempty(vertices)
    affine_dimension = rank(vertices - vertices(:, 1), ...
        numerics.hull_tolerance);
end
if affine_dimension == 3 && size(vertices, 2) >= 4
    triangles = convhulln(vertices.');
end
force_set = struct('vertices', vertices.', 'triangles', triangles, ...
    'halfspace_normals', H, 'halfspace_offsets', b, ...
    'affine_dimension', affine_dimension, 'degenerate', affine_dimension < 3);
end
