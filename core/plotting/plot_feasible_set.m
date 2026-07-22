function [fig, source_data, handles] = plot_feasible_set(set_data, options)
%PLOT_FEASIBLE_SET Plot one standalone 0-D to 3-D feasible-set figure.
if nargin < 2
    options = struct();
end
if ~iscell(set_data)
    set_data = arrayfun(@(item) item,set_data,'UniformOutput',false);
end
number_of_sets = numel(set_data);
if number_of_sets < 1
    error('fa:EmptyFeasibleSetPlot','At least one set is required.');
end
options = complete_options(options,number_of_sets);
style = publication_style();

fig = figure('Units','centimeters','Position',options.figure_position, ...
    'Color',style.colors.white);
ax = axes(fig,'Units','normalized', ...
    'Position',[0.12 0.14 0.76 0.80]);
hold(ax,'on');
handles = gobjects(number_of_sets,1);
for index = 1:number_of_sets
    vertices = extract_vertices(set_data{index});
    dimension = extract_dimension(set_data{index},vertices);
    handles(index) = draw_set(ax,vertices,dimension,index,options,style);
    if strlength(options.labels(index)) > 0
        handles(index).DisplayName = options.labels(index);
    else
        handles(index).HandleVisibility = 'off';
    end
end

legend_handles = handles(strlength(options.labels)>0);
if options.show_origin
    origin = plot3(ax,0,0,0,'o','MarkerSize',4.6, ...
        'MarkerFaceColor',style.colors.white, ...
        'MarkerEdgeColor',style.colors.charcoal,'LineWidth',0.8);
    if strlength(options.origin_label) > 0
        origin.DisplayName = options.origin_label;
        legend_handles(end+1) = origin; %#ok<AGROW>
    else
        origin.HandleVisibility = 'off';
    end
end
if ~isempty(options.reference_point)
    point = options.reference_point(:);
    reference = plot3(ax,point(1),point(2),point(3),'d', ...
        'MarkerSize',6.0,'MarkerFaceColor',style.colors.ochre, ...
        'MarkerEdgeColor',style.colors.charcoal,'LineWidth',0.8);
    if strlength(options.reference_label) > 0
        reference.DisplayName = options.reference_label;
        legend_handles(end+1) = reference; %#ok<AGROW>
    else
        reference.HandleVisibility = 'off';
    end
end

% Set the final limits before fixing the 3-D aspect and camera. Doing this
% in the opposite order makes a nearly one-dimensional set freeze an
% extreme camera zoom and causes the hover-effort axes to disappear.
if ~isempty(options.axis_limits)
    axis(ax,options.axis_limits);
end
daspect(ax,[1 1 1]);
view(ax,options.view);
camproj(ax,'orthographic');
axis(ax,'vis3d');
xlabel(ax,options.axis_labels{1});
ylabel(ax,options.axis_labels{2});
zlabel(ax,options.axis_labels{3});
format_publication_axes(ax,'three_dimensional');

if ~isempty(legend_handles)
    legend(ax,legend_handles, ...
        'Location',char(options.legend_location), ...
        'Orientation','vertical', ...
        'Interpreter','latex','Box','off', ...
        'FontSize',style.font.legend);
end

source_data = struct('sets',{set_data},'options',options);
end

function handle = draw_set(ax,vertices,dimension,index,options,style)
color = options.colors(index,:);
if isempty(vertices)
    handle = plot3(ax,NaN,NaN,NaN);
    return;
end
switch dimension
    case 3
        triangles = convhulln(vertices);
        handle = patch(ax,'Faces',triangles,'Vertices',vertices, ...
            'FaceColor',color,'FaceAlpha',options.face_alpha(index), ...
            'EdgeColor',color,'EdgeAlpha',options.edge_alpha(index), ...
            'LineWidth',options.line_width,'FaceLighting','none');
    case 2
        center = mean(vertices,1);
        [~,~,V] = svd(vertices-center,'econ');
        coordinates = (vertices-center)*V(:,1:2);
        order = convhull(coordinates(:,1),coordinates(:,2));
        polygon = vertices(order,:);
        handle = patch(ax,polygon(:,1),polygon(:,2),polygon(:,3),color, ...
            'FaceAlpha',options.face_alpha(index), ...
            'EdgeColor',color,'EdgeAlpha',options.edge_alpha(index), ...
            'LineWidth',options.line_width);
    case 1
        center = mean(vertices,1);
        [~,~,V] = svd(vertices-center,'econ');
        coordinate = (vertices-center)*V(:,1);
        [~,low] = min(coordinate);
        [~,high] = max(coordinate);
        points = vertices([low high],:);
        handle = plot3(ax,points(:,1),points(:,2),points(:,3),'-o', ...
            'LineWidth',options.line_width,'Color',color, ...
            'MarkerFaceColor',color,'MarkerSize',options.marker_size);
    otherwise
        point = mean(vertices,1);
        handle = plot3(ax,point(1),point(2),point(3),'o', ...
            'MarkerSize',options.marker_size,'Color',color, ...
            'MarkerFaceColor',color);
end
if dimension == 3 && options.show_vertices
    plot3(ax,vertices(:,1),vertices(:,2),vertices(:,3),'.', ...
        'Color',style.colors.dark_gray,'MarkerSize',3, ...
        'HandleVisibility','off');
end
end

function vertices = extract_vertices(data)
if ~isfield(data,'vertices')
    error('fa:MissingSetVertices','Feasible-set data must contain vertices.');
end
vertices = data.vertices;
if size(vertices,2) ~= 3 && size(vertices,1) == 3
    vertices = vertices.';
end
validateattributes(vertices,{'numeric'},{'real','finite','ncols',3});
end

function dimension = extract_dimension(data,vertices)
if isfield(data,'affine_dimension')
    dimension = data.affine_dimension;
elseif isempty(vertices)
    dimension = 0;
else
    dimension = rank(vertices-vertices(1,:),1e-9);
end
end

function options = complete_options(options,number_of_sets)
style = publication_style();
if number_of_sets == 1
    colors = style.colors.gray;
    alpha = 0.20;
elseif number_of_sets == 2
    colors = [style.colors.gray;style.colors.blue];
    alpha = [style.alpha.surface_full;style.alpha.surface_restricted];
else
    colors = style.color_order(1:number_of_sets,:);
    alpha = 0.20*ones(number_of_sets,1);
end
defaults = struct( ...
    'figure_position',style.dimensions.force_set, ...
    'view',[35 24], ...
    'axis_labels',{{'$x$','$y$','$z$'}}, ...
    'axis_limits',[], ...
    'labels',strings(number_of_sets,1), ...
    'legend_location',"northeast", ...
    'colors',colors, ...
    'face_alpha',alpha, ...
    'edge_alpha',style.alpha.mesh_edge*ones(number_of_sets,1), ...
    'line_width',0.55, ...
    'marker_size',style.marker.size, ...
    'show_origin',true, ...
    'origin_label',"", ...
    'show_vertices',false, ...
    'reference_point',[], ...
    'reference_label',"");
fields = fieldnames(defaults);
for index = 1:numel(fields)
    if ~isfield(options,fields{index})
        options.(fields{index}) = defaults.(fields{index});
    end
end
options.labels = string(options.labels(:));
options.legend_location = string(options.legend_location);
options.origin_label = string(options.origin_label);
options.reference_label = string(options.reference_label);
if numel(options.labels) ~= number_of_sets
    error('fa:PlotLabelCount','One label is required per feasible set.');
end
validateattributes(options.colors,{'numeric'}, ...
    {'real','finite','size',[number_of_sets 3]});
if isscalar(options.face_alpha)
    options.face_alpha = repmat(options.face_alpha,number_of_sets,1);
end
if isscalar(options.edge_alpha)
    options.edge_alpha = repmat(options.edge_alpha,number_of_sets,1);
end
end
