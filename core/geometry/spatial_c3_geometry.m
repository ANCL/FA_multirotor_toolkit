function geometry = spatial_c3_geometry(x, parameters)
%SPATIAL_C3_GEOMETRY Decode the two-triplet C3 spatial family.

validateattributes(x, {'numeric'}, {'real','finite','numel',6});
x = x(:);
delta = x(1); eta_s = x(2);
k = (0:2).';
ell = ones(6,1);
gamma = [2*pi*k/3; 2*pi*k/3 + delta];
eta = [eta_s*ones(3,1); -eta_s*ones(3,1)];
alpha = [x(3)*ones(3,1); x(5)*ones(3,1)];
beta = [x(4)*ones(3,1); x(6)*ones(3,1)];
geometry = angle_geometry(ell, gamma, eta, alpha, beta);
geometry.parameterization = 'spatial_c3';
geometry.design_variables = x;
geometry.normalization_case = [];
geometry.reaction_signs = parameters.reaction_signs;
end
