function fig = preview_geometry_style(design_name)
%PREVIEW_GEOMETRY_STYLE Open one retained geometry without rebuilding reports.
%
% Examples:
%   preview_geometry_style("force_authority")
%   preview_geometry_style("weakest_gain")
%   preview_geometry_style("isotropy")
%   preview_geometry_style("hover_effort")

if nargin < 1
    design_name = "force_authority";
end
root = setup_project();
[selected,specs] = load_selected_designs(root);
row = find_design(specs,design_name);
geometry = selected_geometry(selected,specs.objective(row));
all_geometries = cell(height(specs),1);
for index = 1:height(specs)
    all_geometries{index} = selected_geometry(selected,specs.objective(index));
end
limits = common_limits(all_geometries);
options = struct( ...
    'axis_limits',limits, ...
    'figure_position',[2 2 10.5 8.0], ...
    'view',[48 23]);
fig = plot_multirotor_configuration(geometry,options);
end

function [selected,specs] = load_selected_designs(root)
path_in = fullfile(root,'results','current','01_design_comparison', ...
    'rotorwise_selected_designs.mat');
if ~isfile(path_in)
    error('fa:MissingSelectedGeometry', ...
        'Could not find %s.',path_in);
end
data = load(path_in,'selected');
selected = data.selected;
specs = geometry_specs();
end

function specs = geometry_specs()
specs = table( ...
    ["force_authority";"weakest_gain";"isotropy"; ...
     "hover_effort"], ...
    ["r_F0";"sigma_min";"condition_number";"hover_effort"], ...
    'VariableNames',{'design','objective'});
end

function row = find_design(specs,design_name)
key = lower(strrep(strrep(string(design_name),'-','_'),' ','_'));
row = find(specs.design==key | lower(specs.objective)==key,1);
if isempty(row)
    error('fa:UnknownGeometryPreview', ...
        'Unknown geometry name: %s.',string(design_name));
end
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

function limits = common_limits(geometries)
points = zeros(3,0);
for index = 1:numel(geometries)
    geometry = geometries{index};
    lengths = vecnorm(geometry.p,2,1);
    scale = median(lengths(lengths>0));
    if isempty(scale) || ~isfinite(scale)
        scale = 1;
    end
    tips = geometry.p+0.43*scale*geometry.u;
    points = [points geometry.p tips]; %#ok<AGROW>
end
limit = max(abs(points),[],'all')+0.22;
limits = [-limit limit -limit limit -limit limit];
end
