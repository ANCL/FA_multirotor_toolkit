function [fig, source_data] = plot_multirotor_configuration(geometry, options)
%PLOT_MULTIROTOR_CONFIGURATION Restrained numbered and sign-colored schematic.
%
% Based on V1's thin-arm, filled-disk, tapered-thrust-marker drawing style.
% Accepts V2 fields geometry.positions/directions (3-by-N) and optionally
% V1 geometry.p/u. Reaction signs may be supplied as options.reaction_signs;
% otherwise use the geometry field or V2 default_model for six rotors.
% No P2/P3 restriction or structural symmetry assumption is made.
%
% Options: axes_handle, reaction_signs, show_legend (default true),
%          view, axis_limits, rotor_radius, thrust_length, labels (true).

if nargin<2, options=struct(); end
if isfield(geometry,'positions')
    p=geometry.positions; u=geometry.directions;
elseif isfield(geometry,'p')
    p=geometry.p; u=geometry.u;
else
    error('fa:PlotGeometry','Expected positions/directions or p/u.');
end
if size(p,1)~=3 || ~isequal(size(p),size(u)) || ...
        any(~isfinite(p(:))) || any(~isfinite(u(:)))
    error('fa:PlotGeometry','Positions and directions must be finite 3-by-N arrays.');
end
n=size(p,2);
if isfield(options,'reaction_signs')
    signs=options.reaction_signs(:).';
elseif isfield(geometry,'reaction_signs')
    signs=geometry.reaction_signs(:).';
elseif n==6
    model=default_model(); signs=model.reaction_signs(:).';
else
    error('fa:PlotSigns','Specify options.reaction_signs for N ~= 6.');
end
if numel(signs)~=n || any(~ismember(signs,[-1 1]))
    error('fa:PlotSigns','reaction_signs must contain one +/-1 per rotor.');
end
if any(abs(vecnorm(u,2,1)-1)>1e-6)
    error('fa:PlotGeometry','All thrust directions must be unit length.');
end
if isfield(options,'axes_handle') && isgraphics(options.axes_handle,'axes')
    ax=options.axes_handle;
    fig=ancestor(ax,'figure');
else
    visible=option(options,'visible','on');
    fig=figure('Visible',visible,'Color','w','Position',[100 100 640 560]);
    ax=axes(fig);
end

cpositive=[0.38 0.57 0.74]; % Subdued blue.
cnegative=[0.78 0.56 0.32]; % Subdued ochre.
carm=[0.62 0.65 0.68];
cray=[0.22 0.29 0.34];
colors=zeros(n,3);
for i=1:n
    if signs(i)>0, colors(i,:)=cpositive;
    else, colors(i,:)=cnegative; end
end
hold(ax,'on');
scale=median(vecnorm(p,2,1));
if ~isfinite(scale) || scale<=0, scale=1; end
r=option(options,'rotor_radius',0.135*scale);
L=option(options,'thrust_length',0.225*scale);

% Thin secondary arms, rotor disks, and tapered thrust markers.
for i=1:n
    plot3(ax,[0 p(1,i)],[0 p(2,i)],[0 p(3,i)],'-', ...
        'Color',carm,'LineWidth',0.75,'HandleVisibility','off');
end
plot3(ax,0,0,0,'.','Color',cray,'MarkerSize',10,'HandleVisibility','off');
for i=1:n
    [b1,b2]=disc_basis(u(:,i));
    t=(0:47)*2*pi/48;
    disc=p(:,i)+r*(b1*cos(t)+b2*sin(t));
    patch(ax,disc(1,:),disc(2,:),disc(3,:),colors(i,:), ...
        'EdgeColor','none','FaceAlpha',1,'HandleVisibility','off');
    root_radius=0.008*scale;
    tip_radius=0.035*scale;
    tip=p(:,i)+L*u(:,i);
    root=p(:,i)+root_radius*(b1*cos(t)+b2*sin(t));
    cap=tip+tip_radius*(b1*cos(t)+b2*sin(t));
    % The frustum points in the thrust direction; disk hides its narrow base.
    for k=1:numel(t)-1
        v=[root(:,k),root(:,k+1),cap(:,k+1),cap(:,k)];
        patch(ax,v(1,:),v(2,:),v(3,:),[0.20 0.26 0.31], ...
            'EdgeColor','none','HandleVisibility','off');
    end
    patch(ax,cap(1,:),cap(2,:),cap(3,:),[0.20 0.26 0.31], ...
        'EdgeColor','none','HandleVisibility','off');
end
axis(ax,'equal');
axis(ax,'vis3d');
limits=option(options,'axis_limits',[-1.45 1.45 -1.45 1.45 -1.45 1.45]);
axis(ax,limits);
view(ax,option(options,'view',[38 30]));
set(ax,'Visible','off','Projection','orthographic');
set(ax,'CameraUpVector',[0 0 1]);
set(ax,'Color','none');
if option(options,'labels',true)
    draw_numbered_labels(ax,p,u,r,L,scale);
end
if option(options,'show_legend',true)
    h1=plot3(ax,nan,nan,nan,'o','MarkerFaceColor',cpositive, ...
        'MarkerEdgeColor','none','MarkerSize',8);
    h2=plot3(ax,nan,nan,nan,'o','MarkerFaceColor',cnegative, ...
        'MarkerEdgeColor','none','MarkerSize',8);
    legend(ax,[h1 h2],{'$s_i=+1$','$s_i=-1$'}, ...
        'Interpreter','latex','FontSize',9,'Location','north', ...
        'Orientation','horizontal','Box','off');
end
source_data=struct('positions',p,'directions',u, ...
    'reaction_signs',signs,'options',options);
end

function draw_numbered_labels(ax,p,u,rotor_radius,thrust_length,scale)
%DRAW_NUMBERED_LABELS Offset labels in the camera plane to avoid disks.
% Adapted from the original V1 plot_multirotor_configuration label layout.
n=size(p,2);
forward=ax.CameraTarget(:)-ax.CameraPosition(:);
forward=forward/norm(forward);
right=cross(forward,ax.CameraUpVector(:));
right=right/norm(right);
up=cross(right,forward);
projection=[right.';up.'];
rotor_xy=projection*p;
tip_xy=projection*(p+thrust_length*u);
placed=nan(2,n);
angle_offsets=[0 20 -20 40 -40 65 -65 90 -90];
label_radii=scale*[0.27 0.35 0.43];
for k=1:n
    origin=rotor_xy(:,k);
    radial=origin;
    if norm(radial)<1e-8
        radial=[cos(k*pi/3);sin(k*pi/3)];
    end
    radial=radial/norm(radial);
    best_score=Inf; best_xy=origin;
    for radius=label_radii
        for angle_deg=angle_offsets
            a=deg2rad(angle_deg);
            rot=[cos(a) -sin(a);sin(a) cos(a)];
            candidate=origin+radius*rot*radial;
            disk_gap=rotor_radius+0.11*scale;
            distances=vecnorm(rotor_xy-candidate,2,1);
            score=500*sum(max(0,disk_gap-distances).^2)/scale^2;
            for j=1:n
                v=tip_xy(:,j)-rotor_xy(:,j);
                t=max(0,min(1,dot(candidate-rotor_xy(:,j),v) / ...
                    max(dot(v,v),eps)));
                closest=rotor_xy(:,j)+t*v;
                d=norm(candidate-closest);
                score=score+300*max(0,0.12*scale-d)^2/scale^2;
            end
            earlier=placed(:,all(isfinite(placed),1));
            if ~isempty(earlier)
                d=vecnorm(earlier-candidate,2,1);
                score=score+600*sum(max(0,0.25*scale-d).^2)/scale^2;
            end
            score=score+0.03*radius/scale+0.004*abs(angle_deg);
            if score<best_score
                best_score=score; best_xy=candidate;
            end
        end
    end
    placed(:,k)=best_xy;
    xyz=p(:,k)+projection.'*(best_xy-origin);
    text(ax,xyz(1),xyz(2),xyz(3),sprintf('$%d$',k), ...
        'FontSize',9,'Color',[0.15 0.18 0.22], ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Clipping','off','HandleVisibility','off','Interpreter','latex');
end
end

function [b1,b2]=disc_basis(d)
d=d/norm(d);
ref=[0;0;1];
if abs(dot(d,ref))>0.9, ref=[1;0;0]; end
b1=cross(d,ref); b1=b1/norm(b1);
b2=cross(d,b1);
end

function value=option(options,name,default)
if isfield(options,name) && ~isempty(options.(name))
    value=options.(name);
else
    value=default;
end
end
