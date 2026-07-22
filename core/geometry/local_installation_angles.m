function [alpha,beta] = local_installation_angles(gamma,eta,u)
%LOCAL_INSTALLATION_ANGLES Recover local thrust-axis angles from body axes.
%
% The forward convention is the one used by ANGLE_GEOMETRY:
%   u = Rz(gamma) Ry(eta) Rx(alpha) Ry(beta) (-e3).
% The returned ranges are alpha in [-pi,pi] and beta in [-pi/2,pi/2].

validateattributes(gamma,{'numeric'},{'real','finite','vector'});
validateattributes(eta,{'numeric'},{'real','finite','vector'});
validateattributes(u,{'numeric'},{'real','finite','nrows',3});
gamma = gamma(:);
eta = eta(:);
if numel(gamma) ~= numel(eta) || size(u,2) ~= numel(gamma)
    error('fa:LocalAngleSize', ...
        'gamma, eta, and u must contain one entry per rotor.');
end

u = u./vecnorm(u,2,1);
cg = cos(gamma).';
sg = sin(gamma).';
ce = cos(eta).';
se = sin(eta).';

% Undo Rz(gamma), then Ry(eta).
arm_x = cg.*u(1,:) + sg.*u(2,:);
arm_y = -sg.*u(1,:) + cg.*u(2,:);
arm_z = u(3,:);
local_x = ce.*arm_x - se.*arm_z;
local_y = arm_y;
local_z = se.*arm_x + ce.*arm_z;

beta = asin(max(-1,min(1,-local_x))).';
alpha = atan2(local_y,-local_z).';

% At |beta| = pi/2, alpha is physically redundant. Canonicalize the
% numerically indeterminate value to zero for stable seed generation.
pole = abs(cos(beta)) < 100*eps;
alpha(pole) = 0;
end
