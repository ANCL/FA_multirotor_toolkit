function output = run_configuration_equivalence_tests()
%RUN_CONFIGURATION_EQUIVALENCE_TESTS Check Study 07 alignment independently.
% Synthetic tests require no checkpoints, optimization, or external data.
root = setup_project(); %#ok<NASGU>
[parameters,~] = study_settings();
x = [0.31;0.13;0.17;-0.22;-0.25;0.19];
g = spatial_c3_geometry(x,parameters);
signs = parameters.reaction_signs(:).';
orders = perms(1:6);
orders = orders(all(signs(orders)==signs,2),:);

% Identical geometry, to floating-point accuracy.
a = align_multirotor_configurations(g,g,orders);
assert(a.position_rms<1e-12 && a.angle_rms_deg<1e-8, ...
    'Identity geometry should align exactly.');

% Same-sign rotor relabeling and a common yaw are physically equivalent.
order = [2 3 1 5 6 4];
yaw = deg2rad(37);
R = [cos(yaw),-sin(yaw),0;sin(yaw),cos(yaw),0;0,0,1];
h = g;
h.p = R*g.p(:,order);
h.u = R*g.u(:,order);
h.ell = g.ell(order);
h.gamma = g.gamma(order)+yaw;
h.eta = g.eta(order);
h.alpha = g.alpha(order);
h.beta = g.beta(order);
b = align_multirotor_configurations(h,g,orders);
assert(b.position_rms<1e-11 && b.angle_rms_deg<1e-7, ...
    'Yaw and sign-preserving permutation should be removed.');

% Swapping opposite-sign rotor identities is not a permitted equivalence.
% Use deliberately asymmetric positions/axes so no other relabeling masks it.
q = g;
q.p = [0.9 0.1 -0.4 0.3 -0.7 0.5; ...
    0.1 0.8 0.4 -0.8 -0.5 0.2; ...
    0.2 -0.1 0.3 -0.2 0.1 -0.3];
q.u = [0.1 0.3 -0.2 0.4 -0.5 0.2; ...
    0.4 -0.3 0.5 0.2 0.1 -0.4; ...
    -0.9 -0.9 -0.8 -0.8 -0.9 -0.9];
q.u = q.u./vecnorm(q.u,2,1);
q.ell = vecnorm(q.p,2,1).';
q_flip = q;
flip = [4 2 3 1 5 6];
q_flip.p = q.p(:,flip);
q_flip.u = q.u(:,flip);
q_flip.ell = q.ell(flip);
c = align_multirotor_configurations(q_flip,q,orders);
assert(c.position_rms>1e-2 || c.angle_rms_deg>1, ...
    'Opposite-reaction-sign swapping must not be considered equivalent.');

% A genuinely distinct thrust direction remains visibly different.
q2 = q;
q2.u(:,1) = [0;0;-1];
d = align_multirotor_configurations(q2,q,orders);
assert(d.angle_rms_deg>0.1, ...
    'A direction perturbation must not disappear under alignment.');

output = struct('passed',true,'tests',4);
fprintf('Study 07 alignment tests passed: %d.\n',output.tests);
end
