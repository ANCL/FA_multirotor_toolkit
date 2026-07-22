function model = generate_symbolic_allocation(n_rotors, simplify_result)
%GENERATE_SYMBOLIC_ALLOCATION Build the symbolic rotor-to-wrench map.
%
% The geometry follows Rz(gamma)Ry(eta)Rx(alpha)Ry(beta), rotor thrust acts
% along the negative local z-axis, and wrench ordering is [force; moment].

if nargin < 2
    simplify_result = false;
end
if exist('sym','file') ~= 2
    error('fa:MissingSymbolicToolbox', ...
        'Symbolic Math Toolbox is required for symbolic allocation.');
end
validateattributes(n_rotors,{'numeric'}, ...
    {'scalar','integer','positive'});

ell = sym('ell',[n_rotors 1],'real');
gamma = sym('gamma',[n_rotors 1],'real');
eta = sym('eta',[n_rotors 1],'real');
alpha = sym('alpha',[n_rotors 1],'real');
beta = sym('beta',[n_rotors 1],'real');
kappa = sym('kappa',[n_rotors 1],'real');
reaction_signs = sym('s',[n_rotors 1],'real');
mu = sym('mu',[n_rotors 1],'real');
p = sym(zeros(3,n_rotors));
u = sym(zeros(3,n_rotors));
A = sym(zeros(6,n_rotors));
rotations = cell(n_rotors,1);
arm_rotations = cell(n_rotors,1);
e1 = sym([1;0;0]);
e3 = sym([0;0;1]);

for rotor = 1:n_rotors
    arm_rotations{rotor} = rotation_z(gamma(rotor))*rotation_y(eta(rotor));
    rotations{rotor} = arm_rotations{rotor}* ...
        rotation_x(alpha(rotor))*rotation_y(beta(rotor));
    p(:,rotor) = ell(rotor)*arm_rotations{rotor}*e1;
    u(:,rotor) = -rotations{rotor}*e3;
    A(:,rotor) = [u(:,rotor); ...
        cross(p(:,rotor),u(:,rotor)) + ...
        kappa(rotor)*reaction_signs(rotor)*u(:,rotor)];
end
if simplify_result
    p = simplify(p);
    u = simplify(u);
    A = simplify(A);
end
model = struct( ...
    'n_rotors',n_rotors, ...
    'ell',ell, ...
    'gamma',gamma, ...
    'eta',eta, ...
    'alpha',alpha, ...
    'beta',beta, ...
    'kappa',kappa, ...
    'reaction_signs',reaction_signs, ...
    'mu',mu, ...
    'arm_rotations',{arm_rotations}, ...
    'rotations',{rotations}, ...
    'p',p, ...
    'u',u, ...
    'A',A, ...
    'A_f',A(1:3,:), ...
    'A_tau',A(4:6,:), ...
    'w',A*mu);
end

function R = rotation_x(angle)
R = sym([1 0 0;0 cos(angle) -sin(angle);0 sin(angle) cos(angle)]);
end

function R = rotation_y(angle)
R = sym([cos(angle) 0 sin(angle);0 1 0;-sin(angle) 0 cos(angle)]);
end

function R = rotation_z(angle)
R = sym([cos(angle) -sin(angle) 0;sin(angle) cos(angle) 0;0 0 1]);
end
