function id = sensitivity_case_id(family,value)
%SENSITIVITY_CASE_ID Deterministic ID from a resolved physical value.
family = char(string(family));
switch family
    case 'actuator_capacity'
        prefix = 'mu_max_';
    case 'reaction_moment'
        prefix = 'kappa_';
    case 'characteristic_length'
        prefix = 'L_';
    case 'hover_load'
        prefix = 'hover_load_';
    otherwise
        error('fa:UnknownSensitivityFamily', ...
            'Unknown physical sensitivity family: %s',family);
end
id = [prefix numeric_case_token(value,6)];
end
