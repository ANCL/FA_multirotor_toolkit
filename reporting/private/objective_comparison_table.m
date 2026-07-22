function T = objective_comparison_table(cross_evaluation,selected)
%OBJECTIVE_COMPARISON_TABLE Cross-evaluation with retained P1 solutions.
columns = {'name','r_F0','sigma_min','condition_number', ...
    'hover_effort','q_star'};
T = cross_evaluation(:,columns);
solution = strings(height(T),1);
for row = 1:height(T)
    internal_name = objective_identifier(string(T.name(row)));
    geometry = selected_geometry(selected,internal_name);
    solution(row) = geometry_solution_text(geometry);
end
T.Solution = solution;
end

function name = objective_identifier(value)
value = lower(strtrim(string(value)));
if any(value == ["r_f0","force-authority design","force authority"])
    name = "r_F0";
elseif any(value == ["sigma_min","weakest-gain design","weakest gain"])
    name = "sigma_min";
elseif any(value == ["condition_number","isotropy design","isotropy"])
    name = "condition_number";
elseif any(value == ["hover_effort","hover-effort design","hover effort"])
    name = "hover_effort";
elseif any(value == ["q_star","task-oriented design","task oriented"])
    name = "q_star";
else
    error('fa:UnknownObjectiveName', ...
        'Could not map objective-comparison row: %s.',value);
end
end

function text = geometry_solution_text(geometry)
required = {'ell','gamma','eta','alpha','beta'};
for index = 1:numel(required)
    if ~isfield(geometry,required{index})
        error('fa:MissingGeometryParameters', ...
            'Selected geometry is missing field %s.',required{index});
    end
end
number_of_rotors = numel(geometry.ell);
lines = strings(number_of_rotors,1);
for rotor = 1:number_of_rotors
    tuple = [ ...
        geometry.ell(rotor), ...
        rad2deg(geometry.gamma(rotor)), ...
        rad2deg(geometry.eta(rotor)), ...
        rad2deg(geometry.alpha(rotor)), ...
        rad2deg(geometry.beta(rotor))];
    prefix = " ";
    suffix = ";";
    if rotor == 1, prefix = "["; end
    if rotor == number_of_rotors, suffix = "]"; end
    lines(rotor) = prefix+"("+strjoin(compose('%.3f',tuple),",")+ ...
        ")"+suffix;
end
text = strjoin(lines,newline);
end
