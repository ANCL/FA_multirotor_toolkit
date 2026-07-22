function wrench = required_wrench_from_trajectory( ...
    linear_acceleration_I, R_IB, angular_velocity_B, ...
    angular_acceleration_B, mass, inertia_B, gravity_I)
%REQUIRED_WRENCH_FROM_TRAJECTORY Compute the ideal rigid-body wrench.
%
% Syntax
%   wrench = required_wrench_from_trajectory( ...
%       linear_acceleration_I, R_IB, angular_velocity_B, ...
%       angular_acceleration_B, mass, inertia_B, gravity_I)
%
% Inputs
%   linear_acceleration_I   - 3-by-N inertial-frame acceleration.
%   R_IB                    - Constant 3-by-3 rotation or 3-by-3-by-N array
%                             mapping body vectors to the inertial frame.
%   angular_velocity_B      - 3-by-N body angular velocity.
%   angular_acceleration_B  - 3-by-N body angular acceleration.
%   mass                    - Positive vehicle mass.
%   inertia_B               - Symmetric positive-definite 3-by-3 inertia.
%   gravity_I               - Three-element inertial gravity vector.
%
% Outputs
%   wrench.force_B          - Required body-frame force samples.
%   wrench.moment_B         - Required body-frame moment samples.
%   wrench.w_required       - Force-before-moment 6-by-N wrench samples.
%
% The calculation is an ideal rigid-body model. Aerodynamic drag, rotor
% interference, and actuator dynamics are not included.

validateattributes(linear_acceleration_I,{'numeric'}, ...
    {'real','finite','nrows',3,'nonempty'});
number_of_samples = size(linear_acceleration_I,2);
validateattributes(angular_velocity_B,{'numeric'}, ...
    {'real','finite','size',[3 number_of_samples]});
validateattributes(angular_acceleration_B,{'numeric'}, ...
    {'real','finite','size',[3 number_of_samples]});
validateattributes(mass,{'numeric'}, ...
    {'real','finite','scalar','positive'});
validateattributes(inertia_B,{'numeric'}, ...
    {'real','finite','size',[3 3]});
if norm(inertia_B-inertia_B.','fro') > 1e-10*max(1,norm(inertia_B,'fro'))
    error('fa:InvalidInertia','inertia_B must be symmetric.');
end
if min(eig((inertia_B+inertia_B.')/2)) <= 0
    error('fa:InvalidInertia','inertia_B must be positive definite.');
end
validateattributes(gravity_I,{'numeric'},{'real','finite','numel',3});
R_IB = normalize_rotations(R_IB,number_of_samples);
validate_rotations(R_IB);

force_I = mass*(linear_acceleration_I-gravity_I(:));
force_pages = pagemtimes(permute(R_IB,[2 1 3]), ...
    reshape(force_I,3,1,number_of_samples));
force_B = reshape(force_pages,3,number_of_samples);
inertia_omega = inertia_B*angular_velocity_B;
moment_B = inertia_B*angular_acceleration_B + ...
    cross(angular_velocity_B,inertia_omega,1);

wrench = struct( ...
    'force_B',force_B, ...
    'moment_B',moment_B, ...
    'w_required',[force_B;moment_B], ...
    'number_of_samples',number_of_samples);
end

function rotations = normalize_rotations(R_IB,number_of_samples)
validateattributes(R_IB,{'numeric'},{'real','finite','nonempty'});
if isequal(size(R_IB),[3 3])
    rotations = repmat(R_IB,1,1,number_of_samples);
elseif ndims(R_IB) <= 3 && ...
        isequal(size(R_IB),[3 3 number_of_samples])
    rotations = R_IB;
else
    error('fa:InvalidRotationArray', ...
        'R_IB must be 3-by-3 or 3-by-3-by-N.');
end
end

function validate_rotations(rotations)
identity = eye(3);
for sample = 1:size(rotations,3)
    R = rotations(:,:,sample);
    tolerance = 1e-9*max(1,norm(R,'fro'));
    if norm(R.'*R-identity,'fro') > tolerance || det(R) <= 0
        error('fa:InvalidRotationMatrix', ...
            'Every R_IB page must be a proper rotation matrix.');
    end
end
end
