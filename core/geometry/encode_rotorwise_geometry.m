function x = encode_rotorwise_geometry(geometry, normalization_case, solver)
%ENCODE_ROTORWISE_GEOMETRY Express a physical geometry in rotor-wise P1 coordinates.
% This conversion is used for deterministic seeds and round-trip checks. It
% does not impose symmetry or other structure on the optimized design.

validateattributes(normalization_case,{'numeric'},{'scalar','integer','>=',1,'<=',6});
validateattributes(geometry.p,{'numeric'},{'real','finite','size',[3 6]});
validateattributes(geometry.u,{'numeric'},{'real','finite','size',[3 6]});

p = geometry.p;
u = geometry.u;
ell = vecnorm(p,2,1).';
if abs(ell(normalization_case)-1) > 10*solver.equality_tolerance
    error('fa:SeedNormalizationRadius', ...
        'The selected normalization-case rotor must have unit radius.');
end
gamma = atan2(p(2,:),p(1,:)).';
eta = atan2(-p(3,:).',hypot(p(1,:).',p(2,:).'));
[alpha,beta] = local_installation_angles(gamma,eta,u);
X = [ell gamma eta alpha beta].';
full_x = X(:);
full_x(1+5*(normalization_case-1)) = [];
x = full_x;
end
