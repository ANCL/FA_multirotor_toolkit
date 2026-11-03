function verify_stage_02()
%VERIFY_STAGE_02 Verify the four metrics, F0 geometry, and wrench allocation.
%
% Small deterministic checks, including an independent symmetry formula.
setup_project();
model = default_model();
numerics = default_numerics();
tol = 2e-8;

% Nonzero P3 installation angles produce a fully actuated, hover-feasible
% six-rotor example with identical hover input on every rotor.
alpha = 0.5;
beta = 0.2;
geometry = make_p3_geometry([alpha; beta]);
metrics = evaluate_design(geometry, model, numerics);
assert(metrics.valid, metrics.failure_reason);
assert(metrics.fully_actuated && metrics.hover_feasible);
assert(metrics.sigma_min > numerics.full_actuation_threshold);
assert(metrics.condition_number >= 1);
assert(metrics.force_authority_computed && metrics.r_F0 > 0);

% From the symmetric thrust directions, vertical force is shared equally.
mu_expected = 1 / (6 * cos(alpha) * cos(beta));
assert(norm(metrics.mu_hover - mu_expected * ones(6, 1), Inf) < tol);
assert(abs(metrics.hover_effort - 6 * mu_expected^2) < tol);
assert(norm(metrics.A * metrics.mu_hover - model.hover_wrench, Inf) < tol);

% Cross-check the optimized F0 radius against an independently constructed
% 3D halfspace polytope (rather than the stored authority result).
force_set = zero_moment_force_set(metrics.A, model, numerics);
assert(~force_set.degenerate && size(force_set.vertices, 1) >= 4);
assert(all(force_set.halfspace_normals * force_set.vertices.' ...
    <= force_set.halfspace_offsets + tol, 'all'));
normal_lengths = vecnorm(force_set.halfspace_normals, 2, 2);
assert(max(abs(normal_lengths - 1)) < tol);
facet_distances = (force_set.halfspace_offsets - ...
    force_set.halfspace_normals * model.hover_wrench(1:3)) ./ normal_lengths;
assert(abs(min(facet_distances) - metrics.r_F0) < tol);

% The exact hover wrench and zero wrench are both achievable.
hover_check = analyze_wrench(geometry, model.hover_wrench, model, numerics);
assert(hover_check.feasible && strcmp(hover_check.status, 'feasible_unique'));
assert(norm(hover_check.mu - metrics.mu_hover, Inf) < tol);
zero_check = analyze_wrench(geometry, zeros(6, 1), model, numerics);
assert(zero_check.feasible && norm(zero_check.mu) < tol);

% Every objective must be unchanged by a common yaw and same-sign relabeling.
order = [2 3 1 5 6 4];
yaw = 0.63;
R = [cos(yaw) -sin(yaw) 0; sin(yaw) cos(yaw) 0; 0 0 1];
changed.positions = R * geometry.positions(:, order);
changed.directions = R * geometry.directions(:, order);
changed_metrics = evaluate_design(changed, model, numerics);
assert(changed_metrics.valid);
for name = {'r_F0', 'sigma_min', 'condition_number', 'hover_effort'}
    key = name{1};
    assert(abs(changed_metrics.(key) - metrics.(key)) < tol);
end

% A singular geometry is not valid; the evaluator must not report success.
singular = make_p3_geometry([0; 0]);
singular_metrics = evaluate_design(singular, model, numerics);
assert(~singular_metrics.valid && ~singular_metrics.fully_actuated);

analysis = analyze_configuration(geometry, model, numerics);
assert(analysis.metrics.valid && isequal(size(analysis.metrics.A), [6 6]));
fprintf('STAGE 2 VERIFIED: four metrics, hover, force set, wrench feasibility, invariance.\n');
end
