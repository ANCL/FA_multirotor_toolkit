function output = substitute_symbolic_model(model, variables, values)
%SUBSTITUTE_SYMBOLIC_MODEL Apply substitutions to all symbolic model fields.

if numel(variables) ~= numel(values)
    error('fa:SymbolicSubstitutionSize', ...
        'Symbolic variables and values must have the same number of entries.');
end
output = model;
fields = {'p','u','A','A_f','A_tau','w'};
for k = 1:numel(fields)
    output.(fields{k}) = simplify(subs(model.(fields{k}),variables,values));
end
output.arm_rotations = substitute_cells(model.arm_rotations,variables,values);
output.rotations = substitute_cells(model.rotations,variables,values);
end

function output = substitute_cells(input,variables,values)
output = input;
for k = 1:numel(input)
    output{k} = simplify(subs(input{k},variables,values));
end
end
