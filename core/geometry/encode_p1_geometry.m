function [x, normalization_group, aligned] = encode_p1_geometry(geometry, model)
%ENCODE_P1_GEOMETRY Represent any normalized six-rotor geometry in P1.
%
% Relabels a maximum-radius rotor within its reaction-sign group to the
% group's reference index, then removes global yaw. The resulting P1
% variables preserve positions and directions up to those equivalences.
%
% No global sorting constraints are imposed on the optimization domain.

if nargin < 2 || isempty(model)
    model = default_model();
end
p = geometry.positions;
u = geometry.directions;
if ~isequal(size(p), [3 6]) || ~isequal(size(u), [3 6]) || ...
        any(~isfinite(p), 'all') || any(~isfinite(u), 'all')
    error('fa:P1GeometryShape', 'Positions and directions must be finite 3-by-6 matrices.');
end
radii = vecnorm(p, 2, 1);
if abs(max(radii) - 1) > 1e-8 || any(radii < model.geometry.minimum_radius - 1e-8)
    error('fa:P1Normalization', 'The supplied geometry must have maximum radius 1 and admissible radii.');
end
if any(abs(vecnorm(u, 2, 1) - 1) > 1e-8)
    error('fa:P1Directions', 'All thrust directions must have unit length.');
end

% Choose an actual maximum-radius rotor; ties prefer the first group.
[~, chosen] = max(radii);
if model.reaction_signs(chosen) > 0
    normalization_group = 'positive';
    reference = 1;
else
    normalization_group = 'negative';
    reference = 4;
end
order = 1:6;
order([reference chosen]) = order([chosen reference]);
p = p(:, order);
u = u(:, order);
radii = radii(order);

% Use the reference position to set yaw. At the polar chart singularity,
% orient by another nonvertical position or direction instead.
planar = hypot(p(1, reference), p(2, reference));
if planar > 1e-10
    yaw = -atan2(p(2, reference), p(1, reference));
else
    candidates = [p(1:2, :), u(1:2, :)];
    strengths = vecnorm(candidates, 2, 1);
    [strength, index] = max(strengths);
    if strength > 1e-10
        yaw = -atan2(candidates(2, index), candidates(1, index));
    else
        yaw = 0;
    end
end
R = [cos(yaw), -sin(yaw), 0; sin(yaw), cos(yaw), 0; 0, 0, 1];
p = R * p;
u = R * u;

azimuth = atan2(p(2, :).', p(1, :).');
elevation = atan2(-p(3, :).', hypot(p(1, :).', p(2, :).'));
% Position azimuth is undefined at the poles, so choose chart value 0.
pole = hypot(p(1, :).', p(2, :).') < 1e-10;
azimuth(pole) = 0;
azimuth(reference) = 0;
[alpha, beta] = local_installation_angles(azimuth, elevation, u);
all_variables = reshape([radii(:), azimuth, elevation, alpha, beta].', 30, 1);
fixed = 5 * (reference - 1) + [1 2];
all_variables(fixed) = [];
x = all_variables;
aligned = struct('positions', p, 'directions', u);
end
