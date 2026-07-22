function [A, A_f, A_tau] = allocation_matrix( ...
    p, u, kappa, reaction_signs)
%ALLOCATION_MATRIX Construct the force-before-moment allocation matrix.
%
% Syntax
%   [A, A_f, A_tau] = allocation_matrix( ...
%       p, u, kappa, reaction_signs)
%
% Inputs
%   p               - 3-by-N rotor positions in the body frame.
%   u               - 3-by-N unit thrust directions in the body frame.
%   kappa           - Scalar or N-vector reaction-moment ratios.
%   reaction_signs  - N-vector containing -1 or +1.
%
% Outputs
%   A               - 6-by-N allocation matrix.
%   A_f             - 3-by-N force block.
%   A_tau           - 3-by-N moment block.
%
% Each allocation column is
%   [u_i; cross(p_i,u_i) + kappa_i*reaction_sign_i*u_i].

validateattributes(p,{'numeric'},{'real','finite','nrows',3,'nonempty'});
validateattributes(u,{'numeric'},{'real','finite','size',size(p)});
number_of_rotors = size(p,2);
if any(abs(vecnorm(u,2,1)-1) > 1e-10)
    error('fa:NonUnitThrustDirection', ...
        'Every thrust direction must have unit norm.');
end
kappa = expand_parameter(kappa,number_of_rotors,'kappa');
reaction_signs = expand_parameter( ...
    reaction_signs,number_of_rotors,'reaction_signs');
if any(kappa < 0)
    error('fa:InvalidKappa','kappa must be nonnegative.');
end
if any(abs(abs(reaction_signs)-1) > 1e-12)
    error('fa:InvalidReactionSigns', ...
        'reaction_signs must contain only -1 or +1.');
end

reaction_scale = (kappa.*reaction_signs).';
A_f = u;
A_tau = cross(p,u,1) + u.*reaction_scale;
A = [A_f;A_tau];
end

function value = expand_parameter(value,number_of_rotors,name)
validateattributes(value,{'numeric'},{'real','finite','nonempty'}, ...
    mfilename,name);
value = value(:);
if isscalar(value)
    value = repmat(value,number_of_rotors,1);
elseif numel(value) ~= number_of_rotors
    error('fa:ParameterSize', ...
        '%s must be scalar or contain one value per rotor.',name);
end
end
