function status = check_geometry(geometry, model)
%CHECK_GEOMETRY Check the nominal radial, separation, and direction rules.
%
% Physical admissibility requires radii in [minimum_radius, 1], maximum
% radius 1, at least minimum_separation between rotor centers, and unit
% thrust directions. Optimization will use these same constraint margins.

p = geometry.positions;
u = geometry.directions;
radii = vecnorm(p, 2, 1);
pairs = nchoosek(1:size(p, 2), 2);
separation = vecnorm(p(:, pairs(:, 1)) - p(:, pairs(:, 2)), 2, 1);

status.minimum_radius_margin = min(radii) - model.geometry.minimum_radius;
status.maximum_radius_margin = 1 - max(radii);
status.normalization_error = abs(max(radii) - 1);
status.minimum_separation_margin = min(separation) - model.geometry.minimum_separation;
status.unit_direction_error = max(abs(vecnorm(u, 2, 1) - 1));

% This tolerance verifies the geometry representation, not optimization
% convergence. Solver-specific feasibility tolerance is configured later.
tol = 1e-9;
status.valid = status.minimum_radius_margin >= -tol && ...
    status.maximum_radius_margin >= -tol && ...
    status.normalization_error <= tol && ...
    status.minimum_separation_margin >= -tol && ...
    status.unit_direction_error <= tol;
end
