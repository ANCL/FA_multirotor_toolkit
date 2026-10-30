function data = design_comparison_plot_data(root,parameters,solver)
%DESIGN_COMPARISON_PLOT_DATA Prepare P1 geometries and force-set overlays.
%
% This helper reads the five retained rotor-wise designs and constructs the
% corresponding full force set F and zero-moment force set F_0. It performs
% postprocessing only and never invokes an optimizer or changes numerical
% results under results/current.

path_in = fullfile(root,'results','current','01_design_comparison', ...
    'rotorwise_selected_designs.mat');
if ~isfile(path_in)
    error('fa:MissingSelectedDesigns','Could not find %s.',path_in);
end
loaded = load(path_in,'selected');
selected = loaded.selected;

specs = table( ...
    ["force_authority";"weakest_gain";"isotropy"; ...
     "hover_effort"], ...
    ["r_F0";"sigma_min";"condition_number";"hover_effort"], ...
    ["geometry_force_authority";"geometry_weakest_gain"; ...
     "geometry_isotropy";"geometry_hover_effort"], ...
    ["force_sets_force_authority";"force_sets_weakest_gain"; ...
     "force_sets_isotropy";"force_sets_hover_effort"], ...
    'VariableNames',{'design','objective','geometry_file','force_file'});

set_options = struct( ...
    'compute_force',true, ...
    'compute_moment',false, ...
    'compute_zero_moment_force',true, ...
    'equality_tolerance',solver.equality_tolerance, ...
    'bound_tolerance',solver.bound_tolerance, ...
    'vertex_tolerance',solver.vertex_tolerance, ...
    'hull_tolerance',solver.hull_tolerance);

number_of_designs = height(specs);
geometries = cell(number_of_designs,1);
force_sets = cell(number_of_designs,1);
for index = 1:number_of_designs
    geometry = selected_geometry(selected,specs.objective(index));
    model = build_multirotor_model(geometry,parameters.kappa, ...
        parameters.reaction_signs,parameters.actuator_bounds);
    geometries{index} = geometry;
    force_sets{index} = build_feasible_wrench_sets(model,set_options);
end

data = struct();
data.specs = specs;
data.geometries = geometries;
data.force_sets = force_sets;
data.force_limits = individual_force_limits( ...
    force_sets,parameters.hover_wrench(1:3));
data.hover_force = parameters.hover_wrench(1:3);
data.set_options = set_options;
end

function geometry = selected_geometry(selected,name)
names = string({selected.name});
match = find(names==string(name),1);
if isempty(match)
    error('fa:MissingSelectedGeometry', ...
        'No selected geometry was found for %s.',string(name));
end
geometry = selected(match).geometry;
end

function limits = individual_force_limits(force_sets,hover_force)
limits = zeros(numel(force_sets),6);
for index = 1:numel(force_sets)
    sets = force_sets{index};
    points = [hover_force(:) sets.force.vertices.' ...
        sets.zero_moment_force.vertices.'];
    limit = max(abs(points),[],'all');
    if isempty(limit) || ~isfinite(limit) || limit <= 0
        limit = 1;
    end
    limit = 1.08*limit;
    limits(index,:) = [-limit limit -limit limit -limit limit];
end
end
