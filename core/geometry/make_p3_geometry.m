function geometry = make_p3_geometry(x)
%MAKE_P3_GEOMETRY Construct the planar shared-installation-angle family.
%
% x = [alpha; beta]. Reaction signs follow the nominal six-rotor model.
x = x(:);
if numel(x) ~= 2 || any(~isfinite(x))
    error('fa:P3Variables', 'P3 requires two finite variables.');
end
radii = ones(6, 1);
azimuth = [0; 2*pi/3; 4*pi/3; pi/3; pi; 5*pi/3];
elevation = zeros(6, 1);
alpha = [ones(3, 1); -ones(3, 1)] * x(1);
beta = x(2) * ones(6, 1);
geometry = angle_geometry(radii, azimuth, elevation, alpha, beta);
geometry.parameterization = 'p3';
geometry.design_variables = x;
end
