function [fig, handles] = plot_feasible_set(data, options)
%PLOT_FEASIBLE_SET Plot force or torque polytopes with visible wire boundaries.
%
% For analysis returned by analyze_feasible_sets:
%   plot_feasible_set(analysis, struct('mode','force')) overlays F and F0.
%   plot_feasible_set(analysis, struct('mode','torque')) plots T.
% A single set with .vertices/.triangles may also be plotted directly.
% Options: mode, axes_handle, visible, view, axis_limits, show_legend,
%          show_hover, show_zero, labels. Study scripts own export/layout.
if nargin < 2 || isempty(options), options = struct(); end
owns_axes = ~isfield(options,'axes_handle') || ...
    ~isgraphics(options.axes_handle,'axes');
if isfield(options,'axes_handle') && isgraphics(options.axes_handle,'axes')
    ax = options.axes_handle;
    fig = ancestor(ax,'figure');
else
    fig = figure('Visible',opt(options,'visible','on'), ...
        'Color','w','Position',[100 100 760 660]);
    ax = axes('Parent',fig,'Units','normalized', ...
        'Position',[0.18 0.18 0.64 0.63]);
end
hold(ax,'on');
handles = struct('axes',ax,'force',gobjects(0),'zero_moment_force',gobjects(0), ...
    'torque',gobjects(0),'single',gobjects(0),'hover',gobjects(0), ...
    'zero',gobjects(0));
mode = lower(char(string(opt(options,'mode','force'))));
is_analysis = isfield(data,'force') && isfield(data,'zero_moment_force') && isfield(data,'moment');

if ~is_analysis
    if ~isfield(data,'vertices') || ~isfield(data,'triangles')
        error('fa:FeasibleSetPlot','Expected an analysis struct or a 3D polytope.');
    end
    handles.single = draw_polytope(ax,data,[0.45 0.62 0.74],0.35, ...
        [0.22 0.34 0.43],0.70);
    vertices = data.vertices;
    coordinate_type = lower(char(string(opt(options,'coordinate_type','force'))));
    if opt(options,'show_legend',true)
        legend(ax,handles.single,{'Feasible set'}, ...
            'Interpreter','latex','Location','northeast','Box','off');
    end
elseif strcmp(mode,'force')
    % The original manuscript presentation: both sets in one 3D axes.
    % Use separate face and wire patches for legible hull edges.
    handles.force = draw_polytope(ax,data.force,[0.75 0.77 0.79],0.16, ...
        [0.46 0.49 0.52],0.55);
    handles.zero_moment_force = draw_polytope(ax,data.zero_moment_force, ...
        [0.28 0.50 0.69],0.36,[0.14 0.32 0.50],0.72);
    hover_force = opt(options,'hover_point',data.hover_force);
    if opt(options,'show_hover',true)
        handles.hover = plot3(ax,hover_force(1),hover_force(2),hover_force(3), ...
            'd','MarkerSize',8,'MarkerFaceColor',[0.83 0.54 0.20], ...
            'MarkerEdgeColor',[0.15 0.19 0.22], ...
            'LineWidth',0.9);
    end
    vertices = [data.force.vertices;data.zero_moment_force.vertices;hover_force(:).'];
    coordinate_type = 'force';
    if opt(options,'show_legend',true)
        legend_handles = [handles.force handles.zero_moment_force];
        entries = {'$\mathcal{F}$','$\mathcal{F}_0$'};
        if isgraphics(handles.hover)
            legend_handles = [legend_handles handles.hover];
            entries{end+1} = '$f_h$';
        end
        legend(ax,legend_handles,entries,'Interpreter','latex', ...
            'Location','northeast','Box','off','FontSize',10);
    end
elseif any(strcmp(mode,{'torque','moment'}))
    handles.torque = draw_polytope(ax,data.moment,[0.51 0.64 0.73],0.34, ...
        [0.22 0.36 0.45],0.75);
    if opt(options,'show_zero',true)
        handles.zero = plot3(ax,0,0,0,'o','MarkerSize',5, ...
            'MarkerFaceColor',[0.82 0.54 0.21], ...
            'MarkerEdgeColor',[0.17 0.20 0.24],'LineWidth',0.8);
    end
    vertices = [data.moment.vertices;0 0 0];
    coordinate_type = 'torque';
    if opt(options,'show_legend',true)
        legend_handles = handles.torque;
        entries = {'$\mathcal{T}$'};
        if isgraphics(handles.zero)
            legend_handles = [legend_handles handles.zero];
            entries{end+1} = '$\tau=0$';
        end
        legend(ax,legend_handles,entries,'Interpreter','latex', ...
            'Location','northeast','Box','off','FontSize',10);
    end
else
    error('fa:FeasibleSetPlot','Unknown plot mode: %s',mode);
end

if opt(options,'labels',true)
    if strcmp(coordinate_type,'torque')
        xlabel(ax,'$\tau_x$','Interpreter','latex');
        ylabel(ax,'$\tau_y$','Interpreter','latex');
        zlabel(ax,'$\tau_z$','Interpreter','latex');
    else
        xlabel(ax,'$F_x$','Interpreter','latex');
        ylabel(ax,'$F_y$','Interpreter','latex');
        zlabel(ax,'$F_z$','Interpreter','latex');
    end
end
% Physical data coordinates are unchanged; axis limits only set the view.
limits = opt(options,'axis_limits',[]);
if isempty(limits)
    limits = padded_limits(vertices);
elseif numel(limits) ~= 6 || any(~isfinite(limits(:)))
    error('fa:FeasibleSetPlot','axis_limits must contain six finite numbers.');
end
limits = reshape(limits,1,6);
if any(limits(1:2:5) >= limits(2:2:6))
    error('fa:FeasibleSetPlot','Each axis lower limit must be below its upper limit.');
end
axis(ax,limits);
set(ax,'Box','on','FontSize',10,'LineWidth',0.8);
grid(ax,'on');
view(ax,opt(options,'view',[36 24]));
set(ax,'DataAspectRatioMode','auto');
pbaspect(ax,[1 1 1]);
% The camera is pulled back without changing orientation or data limits.
% This keeps the projected 3D box and axis labels inside the figure.
if owns_axes
    camzoom(ax,opt(options,'camera_zoom',0.72));
end
end

function limits = padded_limits(vertices)
% Fallback for standalone use; studies may supply shared comparison limits.
if isempty(vertices) || size(vertices,2) ~= 3 || any(~isfinite(vertices(:)))
    error('fa:FeasibleSetPlot','Expected finite N-by-3 vertices.');
end
xy = max(max(abs(vertices(:,1:2))));
zlo = min(vertices(:,3)); zhi = max(vertices(:,3));
zspan = zhi-zlo;
xy = max(1.12*xy,0.08*max(zspan,0.1));
zpad = 0.10*max(zspan,0.1);
limits = [-xy xy -xy xy zlo-zpad zhi+zpad];
end

function surface = draw_polytope(ax,poly,face_color,face_alpha,wire_color,wire_width)
% Draw the translucent polytope and its triangulated boundary wires.
vertices = poly.vertices;
faces = poly.triangles;
if size(vertices,2) ~= 3 || isempty(vertices) || any(~isfinite(vertices(:)))
    error('fa:FeasibleSetPlot','Expected finite N-by-3 vertices.');
end
if isempty(faces)
    surface = scatter3(ax,vertices(:,1),vertices(:,2),vertices(:,3), ...
        16,face_color,'filled');
    return;
end
surface = patch('Parent',ax,'Faces',faces,'Vertices',vertices, ...
    'FaceColor',face_color,'FaceAlpha',face_alpha, ...
    'EdgeColor','none');
patch('Parent',ax,'Faces',faces,'Vertices',vertices, ...
    'FaceColor','none','EdgeColor',wire_color,'EdgeAlpha',0.68, ...
    'LineWidth',wire_width,'HandleVisibility','off');
end

function value = opt(options,name,fallback)
if isfield(options,name) && ~isempty(options.(name))
    value = options.(name);
else
    value = fallback;
end
end
