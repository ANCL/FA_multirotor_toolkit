function [fig, source_data] = plot_multirotor_configuration(geometry, options)
%PLOT_MULTIROTOR_CONFIGURATION Draw a restrained multirotor schematic.
%
% The schematic contains only thin arms, filled rotor disks, short tapered
% thrust markers, and a small centre point. Each thrust marker is narrow at
% the rotor plane and widens along the positive thrust direction. The rotor
% disk closes the narrow end, so no exposed point or arrowhead is shown.

if nargin < 2
    options = struct();
end
validate_geometry(geometry);
options = complete_options(options, geometry);
style = publication_style();

fig = figure('Units','centimeters', ...
    'Position',options.figure_position, ...
    'Color',style.colors.white, ...
    'Renderer','painters');
ax = axes(fig,'Units','normalized', ...
    'Position',[0.01 0.01 0.98 0.98]);
hold(ax,'on');

number_of_rotors = size(geometry.p,2);

if options.show_rotor_groups
    if number_of_rotors ~= 6 || ...
            ~isfield(geometry,'parameterization') || ...
            ~strcmp(char(string(geometry.parameterization)),'spatial_c3')
        error('fa:TriadLabels', ...
            'Grouped rotor labels require a six-rotor spatial C3 design.');
    end

end

% Arms remain visually secondary to the rotor planes and thrust markers.
for rotor = 1:number_of_rotors
    position = geometry.p(:,rotor);
    arm_color = style.colors.geometry_arm;
    if options.show_rotor_groups
        arm_color = rotor_triad_color(rotor,style);
    end
    plot3(ax,[0 position(1)],[0 position(2)],[0 position(3)],'-', ...
        'Color',arm_color, ...
        'LineWidth',options.arm_line_width, ...
        'HandleVisibility','off');
end

% A small point marks the body origin without introducing a body plate.
scatter3(ax,0,0,0,options.center_marker_size, ...
    style.colors.geometry_center,'filled', ...
    'MarkerEdgeColor','none','HandleVisibility','off');

% Opaque filled disks show the rotor-plane orientations and depth ordering.
for rotor = 1:number_of_rotors
    draw_rotor_disk(ax,geometry.p(:,rotor),geometry.u(:,rotor), ...
        options,style,rotor);
end

% Tapered markers widen along the positive thrust direction. Their narrow
% roots lie in the rotor planes and are visually closed by the disks.
for rotor = 1:number_of_rotors
    draw_thrust_frustum(ax,geometry.p(:,rotor),geometry.u(:,rotor), ...
        options,style);
end

if isempty(options.axis_limits)
    axis(ax,'padded');
else
    axis(ax,options.axis_limits);
end
axis(ax,'equal');
axis(ax,'vis3d');
view(ax,options.view);
camproj(ax,'orthographic');
camup(ax,[0 0 1]);

if options.show_angles
    draw_geometry_angle_annotations(ax,geometry,options,style);
end
format_publication_axes(ax,'schematic');

if options.show_rotor_groups
    draw_rotor_group_labels(ax,geometry,options,style);
end

source_data = struct('geometry',geometry,'options',options);
end


function validate_geometry(geometry)
if ~isstruct(geometry) || ~isfield(geometry,'p') || ~isfield(geometry,'u')
    error('fa:InvalidGeometry','Geometry must contain fields p and u.');
end
validateattributes(geometry.p,{'numeric'},{'real','finite','nrows',3});
validateattributes(geometry.u,{'numeric'}, ...
    {'real','finite','size',size(geometry.p)});
if any(abs(vecnorm(geometry.u,2,1)-1) > 1e-7)
    error('fa:InvalidThrustDirection', ...
        'Every thrust direction must have unit length.');
end
end

function options = complete_options(options,geometry)
style = publication_style();
arm_lengths = vecnorm(geometry.p,2,1);
length_scale = median(arm_lengths(arm_lengths>0));
if isempty(length_scale) || ~isfinite(length_scale)
    length_scale = 1;
end

defaults = struct( ...
    'figure_position',style.dimensions.geometry, ...
    'view',[38 30], ...
    'axis_limits',[], ...
    'arm_line_width',0.60, ...
    'rotor_radius',0.155*length_scale, ...
    'rotor_segments',72, ...
    'thrust_frustum_length',0.23*length_scale, ...
    'thrust_frustum_root_radius',0.010*length_scale, ...
    'thrust_frustum_tip_radius',0.038*length_scale, ...
    'thrust_frustum_segments',24, ...
    'center_marker_size',3.5, ...
    'show_angles',false, ...
    'show_rotor_groups',false);

fields = fieldnames(defaults);
for index = 1:numel(fields)
    if ~isfield(options,fields{index})
        options.(fields{index}) = defaults.(fields{index});
    end
end
end

function draw_rotor_disk(ax,position,direction,options,style,rotor)
[basis_1,basis_2] = disc_basis(direction);
angle = 2*pi*(0:options.rotor_segments-1)/options.rotor_segments;
points = position + options.rotor_radius*( ...
    basis_1*cos(angle) + basis_2*sin(angle));

disk_color = style.colors.rotor_fill;
if options.show_rotor_groups
    disk_color = rotor_triad_color(rotor,style);
end

patch(ax,points(1,:),points(2,:),points(3,:), ...
    disk_color, ...
    'EdgeColor','none', ...
    'FaceAlpha',1.0, ...
    'FaceLighting','none', ...
    'HandleVisibility','off');
end

function draw_thrust_frustum(ax,position,direction,options,style)
direction = direction/norm(direction);
[basis_1,basis_2] = disc_basis(direction);

number_of_segments = options.thrust_frustum_segments;
angle = 2*pi*(0:number_of_segments-1)/number_of_segments;
root_circle = position + options.thrust_frustum_root_radius*( ...
    basis_1*cos(angle) + basis_2*sin(angle));
end_center = position + options.thrust_frustum_length*direction;
end_circle = end_center + options.thrust_frustum_tip_radius*( ...
    basis_1*cos(angle) + basis_2*sin(angle));

% Side quadrilaterals connect the narrow disk-side root to the wider free
% end. A cap is included only at the free end; the rotor disk closes the
% root and hides any point-like appearance there.
vertices = [root_circle.'; end_circle.'; end_center.'];
side_faces = zeros(number_of_segments,4);
cap_faces = zeros(number_of_segments,3);
end_center_index = 2*number_of_segments + 1;
for segment = 1:number_of_segments
    next_segment = mod(segment,number_of_segments)+1;
    side_faces(segment,:) = [ ...
        segment, ...
        next_segment, ...
        number_of_segments+next_segment, ...
        number_of_segments+segment];
    cap_faces(segment,:) = [ ...
        number_of_segments+segment, ...
        number_of_segments+next_segment, ...
        end_center_index];
end

% MATLAB face matrices must have the same number of columns. Draw the
% quadrilateral side faces and triangular end cap as separate patches.
patch(ax,'Vertices',vertices, ...
    'Faces',side_faces, ...
    'FaceColor',style.colors.thrust_direction, ...
    'EdgeColor','none', ...
    'FaceAlpha',1.0, ...
    'FaceLighting','none', ...
    'HandleVisibility','off');

patch(ax,'Vertices',vertices, ...
    'Faces',cap_faces, ...
    'FaceColor',style.colors.thrust_direction, ...
    'EdgeColor','none', ...
    'FaceAlpha',1.0, ...
    'FaceLighting','none', ...
    'HandleVisibility','off');
end

function [basis_1,basis_2] = disc_basis(direction)
direction = direction/norm(direction);
reference = [0;0;1];
if abs(dot(direction,reference)) > 0.90
    reference = [1;0;0];
end
basis_1 = cross(direction,reference);
basis_1 = basis_1/norm(basis_1);
basis_2 = cross(direction,basis_1);
end

function color = rotor_triad_color(rotor,style)
% Muted group colors, consistent with the publication palette.
if rotor <= 3
    base = style.colors.blue;
else
    base = style.colors.ochre;
end
color = 0.65*base + 0.35*style.colors.white;
end


function draw_rotor_group_labels(ax,geometry,options,style)
%DRAW_ROTOR_GROUP_LABELS Number rotors immediately beyond thrust-cone tips.
% Fixed physical positioning; no adaptive spacing or external legend.

L = median(vecnorm(geometry.p,2,1));

if ~isfinite(L) || L <= 0
    L = 1;
end

% Small clearance after each cone tip.
label_clearance = 0.15*L;

for rotor = 1:6
    direction = geometry.u(:,rotor);
    position = geometry.p(:,rotor);

    % The cone extends along the positive thrust direction.
    cone_tip = position + ...
        options.thrust_frustum_length*direction;

    label_position = cone_tip + label_clearance*direction;

    % Check clearance in the camera viewing plane.
    % Only flip a label if it overlaps a neighbouring rotor.
    forward = ax.CameraTarget(:)-ax.CameraPosition(:);
    forward = forward/norm(forward);

    right = cross(forward,ax.CameraUpVector(:));
    right = right/norm(right);

    up = cross(right,forward);
    screen_basis = [right.';up.'];

    other_rotors = [1:rotor-1,rotor+1:6];

    distances = vecnorm( ...
        screen_basis*(geometry.p(:,other_rotors)-label_position), ...
        2,1);

    minimum_clearance = options.rotor_radius + 0.11*L;

    if min(distances) < minimum_clearance
        % Test the opposite side of this rotor.
        alternate = position - ...
            (options.thrust_frustum_length+label_clearance)*direction;

        alternate_distances = vecnorm( ...
            screen_basis*(geometry.p(:,other_rotors)-alternate), ...
            2,1);

        if min(alternate_distances) > min(distances)+0.05*L
            label_position = alternate;
        end
    end

    text(ax, ...
        label_position(1), ...
        label_position(2), ...
        label_position(3), ...
        sprintf('$%d$',rotor), ...
        'Interpreter','latex', ...
        'FontSize',9, ...
        'FontWeight','normal', ...
        'Color',style.colors.charcoal, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','middle', ...
        'Clipping','off', ...
        'HandleVisibility','off');
end
end
