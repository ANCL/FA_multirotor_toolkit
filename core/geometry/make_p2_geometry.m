function geometry = make_p2_geometry(x)
%MAKE_P2_GEOMETRY Construct the spatial C3-symmetric two-triplet family.
%
% x = [delta; eta_s; alpha_plus; beta_plus; alpha_minus; beta_minus].
x = x(:);
if numel(x) ~= 6 || any(~isfinite(x))
    error('fa:P2Variables', 'P2 requires six finite variables.');
end
k = (0:2).';
radii = ones(6, 1);
azimuth = [2*pi*k/3; 2*pi*k/3 + x(1)];
elevation = [x(2)*ones(3, 1); -x(2)*ones(3, 1)];
alpha = [x(3)*ones(3, 1); x(5)*ones(3, 1)];
beta = [x(4)*ones(3, 1); x(6)*ones(3, 1)];
geometry = angle_geometry(radii, azimuth, elevation, alpha, beta);
geometry.parameterization = 'p2';
geometry.design_variables = x;
end
