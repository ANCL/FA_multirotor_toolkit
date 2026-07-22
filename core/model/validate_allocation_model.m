function validate_allocation_model(model)
%VALIDATE_ALLOCATION_MODEL Validate the canonical multirotor model.
%
% The function checks dimensions, unit thrust directions, actuator bounds,
% reaction-moment data, wrench ordering, and agreement between the stored
% allocation matrix and the matrix reconstructed from the rotor geometry.

required_fields = { ...
    'n_rotors','p','u','kappa','reaction_signs','actuator_bounds', ...
    'A','A_f','A_tau','wrench_order'};
for field_index = 1:numel(required_fields)
    field_name = required_fields{field_index};
    if ~isfield(model,field_name)
        error('fa:InvalidModel','model.%s is required.',field_name);
    end
end

n_rotors = model.n_rotors;
validateattributes(n_rotors,{'numeric'}, ...
    {'real','finite','scalar','integer','positive'});
validateattributes(model.p,{'numeric'}, ...
    {'real','finite','size',[3 n_rotors]});
validateattributes(model.u,{'numeric'}, ...
    {'real','finite','size',[3 n_rotors]});
if any(abs(vecnorm(model.u,2,1)-1) > 1e-10)
    error('fa:InvalidModel','Every thrust direction must have unit norm.');
end
validateattributes(model.A,{'numeric'}, ...
    {'real','finite','size',[6 n_rotors]});
validateattributes(model.A_f,{'numeric'}, ...
    {'real','finite','size',[3 n_rotors]});
validateattributes(model.A_tau,{'numeric'}, ...
    {'real','finite','size',[3 n_rotors]});

parse_actuator_bounds(model.actuator_bounds,n_rotors);
validateattributes(model.kappa,{'numeric'}, ...
    {'real','finite','numel',n_rotors,'nonnegative'});
validateattributes(model.reaction_signs,{'numeric'}, ...
    {'real','finite','numel',n_rotors});
if any(abs(abs(model.reaction_signs(:))-1) > 1e-12)
    error('fa:InvalidModel','reaction_signs must contain only -1 or +1.');
end

expected_order = {'F_x','F_y','F_z','tau_x','tau_y','tau_z'};
if ~isequal(cellstr(string(model.wrench_order(:).')),expected_order)
    error('fa:InvalidModel', ...
        'wrench_order must be force-before-moment in the canonical order.');
end

[A_expected,A_f_expected,A_tau_expected] = allocation_matrix( ...
    model.p,model.u,model.kappa,model.reaction_signs);
comparison_scale = max(1,norm(A_expected,'fro'));
comparison_tolerance = 1e-12*comparison_scale;
if norm(model.A-A_expected,'fro') > comparison_tolerance || ...
        norm(model.A_f-A_f_expected,'fro') > comparison_tolerance || ...
        norm(model.A_tau-A_tau_expected,'fro') > comparison_tolerance
    error('fa:InvalidModel', ...
        'Stored allocation matrices are inconsistent with the rotor model.');
end
end
