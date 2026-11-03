function [A, A_force, A_moment] = allocation_matrix(geometry, model)
%ALLOCATION_MATRIX Construct the force/moment allocation matrix.
%
% Column i = [u_i; cross(p_i, u_i) + reaction_sign_i*k*u_i].
% Geometry is in the body frame; k is the reaction-moment ratio.

p = geometry.positions;
u = geometry.directions;
if size(p, 1) ~= 3 || ~isequal(size(p), size(u)) || ...
        any(abs(vecnorm(u, 2, 1) - 1) > 1e-10)
    error('fa:AllocationGeometry', 'Positions/directions must be 3-by-N with unit thrust directions.');
end
n = size(p, 2);
k = model.reaction_moment_ratio;
if isscalar(k), k = repmat(k, n, 1); end
if numel(k) ~= n || numel(model.reaction_signs) ~= n
    error('fa:AllocationModel', 'Reaction ratios and signs must match the number of rotors.');
end
reaction = (k(:) .* model.reaction_signs(:)).';
A_force = u;
A_moment = cross(p, u, 1) + u .* reaction;
A = [A_force; A_moment];
end
