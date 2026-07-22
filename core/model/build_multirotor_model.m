function model = build_multirotor_model(geometry, kappa, reaction_signs, actuator_bounds)
%BUILD_MULTIROTOR_MODEL Build a validated numeric FA multirotor model.
%
% Syntax
%   model = build_multirotor_model(geometry, kappa, reaction_signs, actuator_bounds)
%
% Inputs
%   geometry          - Structure containing 3-by-N fields p and u.
%   kappa              - Scalar or N-vector reaction-moment ratio.
%   reaction_signs     - N-vector containing -1 or +1.
%   actuator_bounds    - [lower upper] or N-by-2 actuator bounds.
%
% Output
%   model              - Canonical model structure containing geometry,
%                        allocation blocks, actuator bounds, and metadata.
%
% Conventions
%   Wrenches are ordered [force; moment] in the body frame. The allocation
%   column is [u_i; cross(p_i,u_i)+kappa_i*s_i*u_i].

if ~isstruct(geometry) || ~isfield(geometry,'p') || ~isfield(geometry,'u')
    error('fa:InvalidGeometry', 'geometry must contain fields p and u.');
end
p = geometry.p;
u = geometry.u;
n_rotors = size(p,2);
[A,A_f,A_tau] = allocation_matrix(p,u,kappa,reaction_signs);
[mu_min,mu_max,bounds] = parse_actuator_bounds(actuator_bounds,n_rotors);

model = geometry;
model.n_rotors = n_rotors;
model.kappa = expand_parameter(kappa,n_rotors,'kappa');
model.reaction_signs = expand_parameter(reaction_signs,n_rotors,'reaction_signs');
model.actuator_bounds = bounds;
model.mu_min = mu_min;
model.mu_max = mu_max;
model.A = A;
model.A_f = A_f;
model.A_tau = A_tau;
model.wrench_order = {'F_x','F_y','F_z','tau_x','tau_y','tau_z'};
validate_allocation_model(model);
end

function value = expand_parameter(value,n,name)
validateattributes(value,{'numeric'},{'real','finite','nonempty'},mfilename,name);
value = value(:);
if isscalar(value)
    value = repmat(value,n,1);
elseif numel(value) ~= n
    error('fa:ParameterSize', ...
        '%s must be scalar or contain one value per rotor.',name);
end
end
