function verify_stage_01()
%VERIFY_STAGE_01 Check P1 coordinates and physical allocation invariance.
%
% A short deterministic numerical verification; no optimization or files.
setup_project();
model = default_model();
tol = 2e-9;
positive_x = [];

for group = {'positive', 'negative'}
    label = group{1};
    [lb, ub] = p1_bounds(label, model);
    assert(numel(lb) == 28 && numel(ub) == 28);
    % Construct a non-symmetric feasible P1 test geometry, spread in azimuth.
    reference = 1;
    if strcmp(label, 'negative'), reference = 4; end
    radii = [0.87; 0.75; 0.92; 0.83; 0.78; 0.89];
    radii(reference) = 1;
    azimuth = (pi/3) * [0; 2; 4; 1; 3; 5];
    azimuth = atan2(sin(azimuth - azimuth(reference)), ...
        cos(azimuth - azimuth(reference)));
    elevation = [0.12; -0.17; 0.14; -0.11; 0.20; -0.06];
    alpha = [-0.43; 0.37; -0.29; 0.51; -0.48; 0.22];
    beta = [0.17; -0.23; 0.31; -0.16; 0.21; -0.27];
    full_x = reshape([radii, azimuth, elevation, alpha, beta].', 30, 1);
    fixed = 5 * (reference - 1) + [1 2];
    full_x(fixed) = [];
    x = full_x;
    assert(all(x >= lb - tol) && all(x <= ub + tol));
    g = make_p1_geometry(x, label);
    if strcmp(label, 'positive'), positive_x = x; end
    assert(abs(g.radii(reference) - 1) < tol);
    assert(abs(g.azimuth(reference)) < tol);
    assert(abs(max(g.radii) - 1) < tol);
    assert(all(vecnorm(g.directions, 2, 1) > 1 - tol));
    status = check_geometry(g, model);
    assert(status.valid, 'Generated P1 sample failed geometric admissibility.');

    [A, Af, Am] = allocation_matrix(g, model);
    assert(isequal(size(A), [6 6]));
    assert(norm(A - [Af; Am], 'fro') < tol);
    [An, S] = normalized_allocation_matrix(A, model.characteristic_length);
    assert(norm(An - S * A, 'fro') < tol);

    % A same-sign permutation and global yaw are purely representational.
    perm = [3 1 2 6 4 5];
    psi = 0.74;
    R = [cos(psi), -sin(psi), 0; sin(psi), cos(psi), 0; 0, 0, 1];
    transformed.positions = R * g.positions(:, perm);
    transformed.directions = R * g.directions(:, perm);
    transformed_A = allocation_matrix(transformed, model);
    assert(norm(transformed_A - blkdiag(R, R) * A(:, perm), 'fro') < tol);
    assert(max(abs(sort(svd(transformed_A)) - sort(svd(A)))) < tol);
    [d, ~] = geometry_distance(g, transformed, model);
    assert(d < tol, 'Geometry equivalence under yaw/permutation failed.');

    [encoded, selected_group, aligned] = encode_p1_geometry(transformed, model);
    recovered = make_p1_geometry(encoded, selected_group);
    assert(strcmp(selected_group, label));
    assert(norm(recovered.positions - aligned.positions, 'fro') < tol);
    assert(norm(recovered.directions - aligned.directions, 'fro') < tol);
    [d2, ~] = geometry_distance(g, recovered, model);
    assert(d2 < tol, 'P1 encoding changed the physical geometry.');
end

% Confirm that both structured families are nested inside physical P1.
structured = {make_p2_geometry([0.4; 0.2; 0.35; -0.3; -0.4; 0.25]), ...
    make_p3_geometry([0.35; -0.15])};
for k = 1:numel(structured)
    g = structured{k};
    [x, group, reconstructed] = encode_p1_geometry(g, model);
    g2 = make_p1_geometry(x, group);
    assert(norm(g2.positions - reconstructed.positions, 'fro') < tol);
    assert(norm(g2.directions - reconstructed.directions, 'fro') < tol);
    [d, ~] = geometry_distance(g, g2, model);
    assert(d < tol);
    status = check_geometry(g, model);
    assert(status.valid, 'Structured geometry failed geometric admissibility.');
end

% A polar reference position must remain representable.
x = positive_x;
% The position elevation of reference rotor 1 is the first free coordinate.
x(1) = pi/2;
g = make_p1_geometry(x, 'positive');
status = check_geometry(g, model);
assert(status.valid);
[x2, group, aligned] = encode_p1_geometry(g, model);
g2 = make_p1_geometry(x2, group);
assert(norm(g2.positions - aligned.positions, 'fro') < tol);
assert(norm(g2.directions - aligned.directions, 'fro') < tol);

fprintf('STAGE 1 VERIFIED: P1 coordinates, P2/P3 nesting, yaw/permutation invariance.\n');
end
