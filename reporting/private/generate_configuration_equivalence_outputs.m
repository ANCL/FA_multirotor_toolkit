function output = generate_configuration_equivalence_outputs()
%GENERATE_CONFIGURATION_EQUIVALENCE_OUTPUTS Four P2 repeated-run overlays.
% Every figure shows all five saved geometries for one objective. The two
% numerical tables contain no thresholds, clusters, or verbal categories.

root = setup_project();
source = fullfile(root,'results','current', ...
    '07_configuration_equivalence','configuration_equivalence.mat');
if ~isfile(source)
    error('fa:Study07MissingResults', ...
        'Run run_configuration_equivalence_study first.');
end
data = load(source,'runs','alignment_to_best','records');
objectives = {'r_F0','sigma_min','condition_number','hover_effort'};
if numel(data.records)~=20 || height(data.runs)~=20 || ...
        height(data.alignment_to_best)~=20
    error('fa:Study07Count','Expected 20 saved P2 run records.');
end

publication = fullfile(root,'results','publication', ...
    '07_configuration_equivalence');
% Clear only the previous Study 07 publication outputs. This removes old
% distance-matrix figures and the previous automatic ZIP archive.
if isfolder(publication)
    [ok,message] = rmdir(publication,'s');
    if ~ok, error('fa:Study07Reset','%s',message); end
end
figures = fullfile(publication,'figures');
tables = fullfile(publication,'tables');
mkdir(figures);
mkdir(tables);
writetable(data.runs,fullfile(tables,'p2_runs.csv'));
writetable(data.alignment_to_best, ...
    fullfile(tables,'p2_alignment_to_best.csv'));

[style,style_cleanup] = publication_style('activate'); %#ok<NASGU>
figure_names = strings(numel(objectives),1);
for j = 1:numel(objectives)
    obj = objectives{j};
    mask = strcmp({data.records.objective},obj);
    subset = data.records(mask);
    if numel(subset)~=5
        error('fa:Study07ObjectiveCount','Expected five runs for %s.',obj);
    end
    [~,order] = sort([subset.run]);
    subset = subset(order);
    [fig,figure_data] = plot_p2_runs(subset,obj,style);
    name = ['p2_five_runs_' obj];
    cleanup = onCleanup(@() close_if_valid(fig)); %#ok<NASGU>
    export_figure(fig,figures,name);
    write_figure_source_data(figure_data,figures,name);
    close(fig);
    clear cleanup;
    figure_names(j) = string(name);
end
output = struct('folder',publication,'figures',figure_names, ...
    'runs',data.runs,'alignment_to_best',data.alignment_to_best);
fprintf('STUDY 07 OUTPUTS: four P2 overlay figures and two CSV tables.\n%s\n', ...
    publication);
end

function [fig,source_data] = plot_p2_runs(runs,objective,style)
% The standard toolkit geometry schematic is designed for one opaque
% configuration. Here its arm/disk/thrust conventions are drawn as colored
% wireframes to keep five simultaneous configurations visible.
fig = figure('Visible','off','Units','centimeters', ...
    'Position',[2 2 17.5 8.0],'Color',style.colors.white, ...
    'Renderer','painters');
ax = axes(fig,'Units','normalized','Position',[0.02 0.06 0.70 0.88]);
hold(ax,'on');
colors = style.color_order;
handles = gobjects(5,1);
rows = cell(5,1);
angles = linspace(0,2*pi,61);
for k = 1:5
    g = runs(k).geometry;
    color = colors(k,:);
    handles(k) = plot3(ax,nan,nan,nan,'-', ...
        'LineWidth',1.5,'Color',color, ...
        'DisplayName',sprintf('Run %d  (%.8g)',runs(k).run, ...
        runs(k).primary));
    for rotor = 1:6
        p = g.p(:,rotor);
        u = g.u(:,rotor);
        plot3(ax,[0 p(1)],[0 p(2)],[0 p(3)], ...
            'Color',color,'LineWidth',0.85,'HandleVisibility','off');
        [e1,e2] = disc_basis(u);
        disc = p+0.11*(e1*cos(angles)+e2*sin(angles));
        plot3(ax,disc(1,:),disc(2,:),disc(3,:), ...
            'Color',color,'LineWidth',1.00,'HandleVisibility','off');
        tip = p+0.23*u;
        plot3(ax,[p(1) tip(1)],[p(2) tip(2)], ...
            [p(3) tip(3)],'-','Color',color, ...
            'LineWidth',1.35,'HandleVisibility','off');
        plot3(ax,tip(1),tip(2),tip(3),'.','Color',color, ...
            'MarkerSize',5,'HandleVisibility','off');
    end
    run = repmat(runs(k).run,6,1);
    rotor = (1:6).';
    P_x = g.p(1,:).'; P_y = g.p(2,:).'; P_z = g.p(3,:).';
    U_x = g.u(1,:).'; U_y = g.u(2,:).'; U_z = g.u(3,:).';
    rows{k} = table(run,rotor,P_x,P_y,P_z,U_x,U_y,U_z);
end
source_data = vertcat(rows{:});
plot3(ax,0,0,0,'.','Color',style.colors.charcoal, ...
    'MarkerSize',9,'HandleVisibility','off');
axis(ax,'equal'); axis(ax,'vis3d');
view(ax,[55 26]);
camproj(ax,'orthographic');
camup(ax,[0 0 1]);
format_publication_axes(ax,'schematic');
legend(ax,handles,'Location','northeastoutside','Box','off', ...
    'Interpreter','none','FontSize',style.font.legend);
end

function [e1,e2] = disc_basis(u)
u = u/norm(u);
ref = [0;0;1];
if abs(dot(u,ref))>0.9, ref=[1;0;0]; end
e1 = cross(u,ref); e1=e1/norm(e1);
e2 = cross(u,e1);
end

function close_if_valid(fig)
if isgraphics(fig), close(fig); end
end
