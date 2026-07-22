function geometry = planar_shared_geometry(x, parameters)
%PLANAR_SHARED_GEOMETRY Decode the planar shared-angle family.

validateattributes(x, {'numeric'}, {'real','finite','numel',2});
x = x(:);
ell = ones(6,1);
gamma = [0; 2*pi/3; 4*pi/3; pi/3; pi; 5*pi/3];
eta = zeros(6,1);
alpha = parameters.reaction_signs(:) * x(1);
beta = x(2) * ones(6,1);
geometry = angle_geometry(ell, gamma, eta, alpha, beta);
geometry.parameterization = 'planar_shared';
geometry.design_variables = x;
geometry.normalization_case = [];
end
