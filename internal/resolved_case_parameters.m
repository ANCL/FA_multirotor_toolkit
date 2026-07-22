function resolved = resolved_case_parameters(parameters)
%RESOLVED_CASE_PARAMETERS Numerical model values used by one case.
% Study grids, labels, and unrelated robustness/sensitivity plans are not
% case inputs and therefore cannot invalidate an unchanged case.
fields = {'n_rotors','kappa','reaction_signs','actuator_bounds','geometry', ...
    'hover_wrench','task','force_moment_length'};
resolved = copy_required_fields(parameters,fields,'case parameters');
end

function output = copy_required_fields(input,fields,label)
output = struct();
for k = 1:numel(fields)
    name = fields{k};
    if ~isfield(input,name)
        error('fa:MissingResolvedSetting','Missing %s field: %s',label,name);
    end
    output.(name) = input.(name);
end
end
