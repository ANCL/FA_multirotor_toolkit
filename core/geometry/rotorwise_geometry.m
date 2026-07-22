function geometry = rotorwise_geometry(x, normalization_case, parameters)
%ROTORWISE_GEOMETRY Decode the rotor-wise P1 geometry.
% Coordinates per rotor are (ell, gamma, eta, alpha, beta). The radius of
% the selected normalization-case rotor is fixed at one and omitted from
% the reduced design vector.

validateattributes(normalization_case, {'numeric'}, {'scalar','integer','>=',1,'<=',6});
x = x(:);
fixed_coordinate = 1 + 5 * (normalization_case - 1);
if numel(x) ~= 29
    error('fa:RotorwiseVariableCount', ...
        'The reduced rotor-wise vector must contain 29 values.');
end
full_x = zeros(30, 1);
free = true(30, 1);
free(fixed_coordinate) = false;
full_x(free) = x;
full_x(fixed_coordinate) = 1;
X = reshape(full_x, 5, 6);

ell = X(1,:).';
gamma = X(2,:).';
eta = X(3,:).';
alpha = X(4,:).';
beta = X(5,:).';
if any(ell < parameters.geometry.ell_min) || any(ell > 1)
    error('fa:RotorwiseRadius', ...
        'Rotor-wise radii must lie in [ell_min,1].');
end

geometry = angle_geometry(ell, gamma, eta, alpha, beta);
geometry.normalization_case = normalization_case;
geometry.parameterization = 'rotorwise';
geometry.design_variables = x;
end
