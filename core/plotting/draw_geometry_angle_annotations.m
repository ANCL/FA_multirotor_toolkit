function draw_geometry_angle_annotations(ax,geometry,options,style)
%DRAW_GEOMETRY_ANGLE_ANNOTATIONS Physical 3-D arcs in the defined angle convention.
% Reduced, fixed annotations; individual rotor labels are intentionally avoided.
if ~all(isfield(geometry,{'p','u','gamma','eta','alpha','beta'})), return; end
L = median(vecnorm(geometry.p,2,1));
if ~isfinite(L) || L <= 0, L = 1; end
color = style.colors.ochre;
if isfield(geometry,'parameterization') && ...
        strcmp(char(string(geometry.parameterization)),'spatial_c3')
    % Delta: azimuth offset between corresponding arms of the two C3 triplets.
    delta = atan2(sin(geometry.gamma(4)-geometry.gamma(1)), ...
        cos(geometry.gamma(4)-geometry.gamma(1)));
    arc(ax,[0;0;0],[cos(geometry.gamma(1));sin(geometry.gamma(1));0], ...
        [cos(geometry.gamma(4));sin(geometry.gamma(4));0], ...
        0.32*L,sprintf('\\delta=%.1f^\\circ',rad2deg(delta)),color,style);
end
% One representative rotor: arm elevation and the two actual installation
% rotations R_y(beta) followed by R_x(alpha) in the arm-local frame.
i = 1;
g = geometry.gamma(i); e = geometry.eta(i);
a = geometry.alpha(i); b = geometry.beta(i);
Rz = [cos(g) -sin(g) 0;sin(g) cos(g) 0;0 0 1];
Ry = [cos(e) 0 sin(e);0 1 0;-sin(e) 0 cos(e)];
Rx = [1 0 0;0 cos(a) -sin(a);0 sin(a) cos(a)];
Rb = [cos(b) 0 sin(b);0 1 0;-sin(b) 0 cos(b)];
base = Rz*Ry;
horizontal = [cos(g);sin(g);0];
arc(ax,zeros(3,1),horizontal,geometry.p(:,i), ...
    0.57*L,sprintf('\\eta=%.1f^\\circ',rad2deg(e)),color,style);
root = geometry.p(:,i);
v0 = base*[0;0;-1];
vb = base*Rb*[0;0;-1];
a0 = base*[0;1;0];
a1 = base*Rx*[0;1;0];
arc(ax,root,v0,vb,0.19*L, ...
    sprintf('\\beta=%.1f^\\circ',rad2deg(b)),color,style);
arc(ax,root,a0,a1,0.30*L, ...
    sprintf('\\alpha=%.1f^\\circ',rad2deg(a)),color,style);
end

function arc(ax,center,v1,v2,radius,caption,color,style)
v1 = v1/norm(v1); v2 = v2/norm(v2);
angle = acos(max(-1,min(1,dot(v1,v2))));
if angle < 1e-4, return; end
perp = v2-dot(v1,v2)*v1;
if norm(perp) < 1e-8, return; end
perp = perp/norm(perp);
t = linspace(0,angle,40);
points = center + radius*(v1*cos(t)+perp*sin(t));
plot3(ax,points(1,:),points(2,:),points(3,:),'-', ...
    'Color',color,'LineWidth',0.75,'HandleVisibility','off');
midpoint = center + 1.16*radius*(v1*cos(angle/2)+perp*sin(angle/2));
text(ax,midpoint(1),midpoint(2),midpoint(3),['$' caption '$'], ...
    'Interpreter','latex','FontSize',style.font.annotation, ...
    'Color',color,'HorizontalAlignment','center','HandleVisibility','off');
end
