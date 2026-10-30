function data = parameterization_plot_data(selected,parameters,solver)
%PARAMETERIZATION_PLOT_DATA P1/P2/P3 configurations and matched force limits.
objectives = string(parameters.objectives);
families = ["p1","p2","p3"];
prefixes = ["","spatial_c3_","planar_shared_"];
set_options = struct( ...
    'compute_force',true, ...
    'compute_moment',false, ...
    'compute_zero_moment_force',true, ...
    'equality_tolerance',solver.equality_tolerance, ...
    'bound_tolerance',solver.bound_tolerance, ...
    'vertex_tolerance',solver.vertex_tolerance, ...
    'hull_tolerance',solver.hull_tolerance);
data = repmat(struct('family',"",'objective',"",'geometry',struct(), ...
    'sets',struct(),'force_limits',zeros(1,6)), ...
    numel(objectives)*numel(families),1);
for objective_index = 1:numel(objectives)
    limits = 0;
    block = (objective_index-1)*numel(families)+(1:numel(families));
    for family_index = 1:numel(families)
        index = block(family_index);
        name = prefixes(family_index)+objectives(objective_index);
        matched = find(string({selected.name})==name);
        if numel(matched) ~= 1
            error('fa:Stage02PlotDesign','Missing or ambiguous design: %s',name);
        end
        geometry = selected(matched).geometry;
        model = build_multirotor_model(geometry,parameters.kappa, ...
            parameters.reaction_signs,parameters.actuator_bounds);
        sets = build_feasible_wrench_sets(model,set_options);
        points = [parameters.hover_wrench(1:3), ...
            sets.force.vertices.',sets.zero_moment_force.vertices.'];
        limits = max(limits,max(abs(points),[],'all'));
        data(index).family = families(family_index);
        data(index).objective = objectives(objective_index);
        data(index).geometry = geometry;
        data(index).sets = sets;
    end
    limits = 1.08*max(limits,1e-8);
    for index = block
        data(index).force_limits = [-limits limits -limits limits -limits limits];
    end
end
end
