function geometry = angle_geometry(radii, azimuth, elevation, alpha, beta)
%ANGLE_GEOMETRY Construct rotor positions and unit thrust directions.
%
% Each rotor uses Rz(azimuth) Ry(elevation) Rx(alpha) Ry(beta) (-e3).
% The rotor position is radius * Rz(azimuth) Ry(elevation) e1.
% Angles are in radians; outputs are in the body frame.

radii = radii(:);
azimuth = azimuth(:);
elevation = elevation(:);
alpha = alpha(:);
beta = beta(:);
n = numel(radii);
if n == 0 || any([numel(azimuth), numel(elevation), numel(alpha), numel(beta)] ~= n)
    error('fa:GeometryDimensions', 'All five geometry vectors must have the same nonzero length.');
end
if any(~isfinite([radii; azimuth; elevation; alpha; beta])) || any(radii < 0)
    error('fa:InvalidGeometryAngles', 'Geometry values must be finite and radii nonnegative.');
end

cg = cos(azimuth); sg = sin(azimuth);
ce = cos(elevation); se = sin(elevation);
positions = [radii .* cg .* ce, radii .* sg .* ce, -radii .* se].';

% Apply Ry(beta), Rx(alpha), Ry(elevation), then Rz(azimuth) to -e3.
lx = -sin(beta);
ly = sin(alpha) .* cos(beta);
lz = -cos(alpha) .* cos(beta);
ax = ce .* lx + se .* lz;
ay = ly;
az = -se .* lx + ce .* lz;
directions = [cg .* ax - sg .* ay, sg .* ax + cg .* ay, az].';
directions = directions ./ vecnorm(directions, 2, 1);

geometry = struct('positions', positions, 'directions', directions, ...
    'radii', radii, 'azimuth', azimuth, 'elevation', elevation, ...
    'alpha', alpha, 'beta', beta);
end
