function [alpha, beta] = local_installation_angles(azimuth, elevation, directions)
%LOCAL_INSTALLATION_ANGLES Recover installation angles from thrust axes.
%
% Inverts the angle_geometry direction convention. Near |beta| = pi/2,
% alpha is redundant and is set to zero.

azimuth = azimuth(:);
elevation = elevation(:);
if size(directions, 1) ~= 3 || size(directions, 2) ~= numel(azimuth) || ...
        numel(elevation) ~= numel(azimuth)
    error('fa:InstallationDimensions', 'Directions must be 3-by-N for N azimuth/elevation pairs.');
end
if any(~isfinite(directions), 'all') || any(vecnorm(directions, 2, 1) < eps)
    error('fa:InvalidDirections', 'Thrust directions must be finite and nonzero.');
end
u = directions ./ vecnorm(directions, 2, 1);
cg = cos(azimuth).'; sg = sin(azimuth).';
ce = cos(elevation).'; se = sin(elevation).';
ax = cg .* u(1, :) + sg .* u(2, :);
ay = -sg .* u(1, :) + cg .* u(2, :);
az = u(3, :);
lx = ce .* ax - se .* az;
ly = ay;
lz = se .* ax + ce .* az;
beta = asin(max(-1, min(1, -lx))).';
alpha = atan2(ly, -lz).';
alpha(abs(cos(beta)) < 100 * eps) = 0;
end
