function geometry = angle_geometry(ell, gamma, eta, alpha, beta)
%ANGLE_GEOMETRY Convert installation coordinates to p_i and u_i.
%
% Syntax
%   geometry = angle_geometry(ell, gamma, eta, alpha, beta)
%
% Inputs
%   ell    - Nonnegative rotor-position radii.
%   gamma  - Position azimuth angles in radians.
%   eta    - Position elevation angles in radians.
%   alpha  - First thrust-axis installation angles in radians.
%   beta   - Second thrust-axis installation angles in radians.
%
% All inputs are scalars or equal-length vectors. The adopted rotation is
% Rz(gamma)Ry(eta)Rx(alpha)Ry(beta), and thrust acts along the negative
% local z-axis.

input_names = {'ell','gamma','eta','alpha','beta'};
input_values = {ell,gamma,eta,alpha,beta};
for input_index = 1:numel(input_values)
    validateattributes(input_values{input_index},{'numeric'}, ...
        {'real','finite','nonempty'},mfilename,input_names{input_index});
end

ell = ell(:);
gamma = gamma(:);
eta = eta(:);
alpha = alpha(:);
beta = beta(:);
number_of_rotors = numel(ell);
if any([numel(gamma),numel(eta),numel(alpha),numel(beta)] ~= ...
        number_of_rotors)
    error('fa:AngleSize', ...
        'Every geometry vector must contain one value per rotor.');
end
if any(ell < 0)
    error('fa:InvalidRotorRadius','ell must be nonnegative.');
end

cos_gamma = cos(gamma);
sin_gamma = sin(gamma);
cos_eta = cos(eta);
sin_eta = sin(eta);
p = [ ...
    ell.*cos_gamma.*cos_eta, ...
    ell.*sin_gamma.*cos_eta, ...
    -ell.*sin_eta].';

% Apply Ry(beta), Rx(alpha), Ry(eta), and Rz(gamma) to -e3.
local_x = -sin(beta);
local_y = sin(alpha).*cos(beta);
local_z = -cos(alpha).*cos(beta);
arm_x = cos_eta.*local_x + sin_eta.*local_z;
arm_y = local_y;
arm_z = -sin_eta.*local_x + cos_eta.*local_z;
u = [ ...
    cos_gamma.*arm_x-sin_gamma.*arm_y, ...
    sin_gamma.*arm_x+cos_gamma.*arm_y, ...
    arm_z].';
u = u./vecnorm(u,2,1);

geometry = struct( ...
    'p',p, ...
    'u',u, ...
    'ell',ell, ...
    'gamma',gamma, ...
    'eta',eta, ...
    'alpha',alpha, ...
    'beta',beta);
end
