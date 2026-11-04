function plots = plot_study_03()
%PLOT_STUDY_03 Export geometry, overlaid force sets, and torque sets.
% Reads selected Study 03 designs only; no optimization or MAT modification.
setup_project();
root = fileparts(fileparts(mfilename('fullpath')));
output_folder = fullfile(root,'results','study_03');
source_file = fullfile(output_folder,'selected_designs.mat');
if ~isfile(source_file)
    error('fa:Study03Plots','Missing selected_designs.mat. Run summarize_study_03 first.');
end
saved = load(source_file,'selected');
if ~isfield(saved,'selected') || numel(saved.selected) ~= 8
    error('fa:Study03Plots','Expected eight selected P2/P3 SQP designs.');
end
selected = saved.selected;
figures_folder = fullfile(output_folder,'figures');
if ~isfolder(figures_folder), mkdir(figures_folder); end

n = numel(selected);
parameterization = cell(n,1);
objective = cell(n,1);
pdf_file = cell(n,1);
png_file = cell(n,1);
force_pdf_file = cell(n,1);
force_png_file = cell(n,1);
torque_pdf_file = cell(n,1);
torque_png_file = cell(n,1);
geometry_options = struct('visible','off','view',[38 24], ...
    'axis_limits',[-1.45 1.45 -1.45 1.45 -1.45 1.45], ...
    'show_legend',false,'labels',true);
model = default_model();
numerics = default_numerics();

% Prepare all sets first so P2 and P3 share axes for each objective.
analysis_cache = cell(n,1);
for k = 1:n
    analysis_cache{k} = analyze_feasible_sets(selected(k).geometry,model,numerics);
end
[force_limits,torque_limits] = comparison_limits(selected,analysis_cache);

for k = 1:n
    item = selected(k);
    parameterization{k} = item.parameterization;
    objective{k} = item.objective;
    stem = sprintf('%s_%s',item.parameterization,item.objective);
    pdf_file{k} = fullfile(figures_folder,['geometry_' stem '.pdf']);
    png_file{k} = fullfile(figures_folder,['geometry_' stem '.png']);
    force_pdf_file{k} = fullfile(figures_folder,['force_sets_' stem '.pdf']);
    force_png_file{k} = fullfile(figures_folder,['force_sets_' stem '.png']);
    torque_pdf_file{k} = fullfile(figures_folder,['torque_sets_' stem '.pdf']);
    torque_png_file{k} = fullfile(figures_folder,['torque_sets_' stem '.png']);

    [fig,~] = plot_multirotor_configuration(item.geometry,geometry_options);
    save_figure(fig,pdf_file{k},png_file{k});

    analysis = analysis_cache{k};
    % F and F0 share one 3D axes, one legend, and visible wire boundaries.
    options = struct('mode','force','visible','off','view',[36 24], ...
        'show_legend',true,'show_hover',true, ...
        'axis_limits',force_limits(k,:),'camera_zoom',0.72);
    [fig,~] = plot_feasible_set(analysis,options);
    save_figure(fig,force_pdf_file{k},force_png_file{k},true);

    % The projected feasible body-torque set T is exported separately.
    options = struct('mode','torque','visible','off','view',[36 24], ...
        'show_legend',true,'show_zero',true, ...
        'axis_limits',torque_limits(k,:),'camera_zoom',0.72);
    [fig,~] = plot_feasible_set(analysis,options);
    save_figure(fig,torque_pdf_file{k},torque_png_file{k},true);
    fprintf('  %-3s %-17s geometry, overlaid force sets, torque set exported\n', ...
        upper(item.parameterization),item.objective);
end
plots = table(parameterization,objective,pdf_file,png_file,force_pdf_file, ...
    force_png_file,torque_pdf_file,torque_png_file);
fprintf('Study 03 | %d designs | figures: %s\n',n,figures_folder);
end

function save_figure(fig,pdf_file,png_file,full_canvas)
if nargin < 4, full_canvas = false; end
try
    drawnow;
    exportgraphics(fig,pdf_file,'ContentType','vector');
    if full_canvas
        % Preserve the complete canvas for 3D force/torque figures.
        set(fig,'PaperPositionMode','auto','InvertHardcopy','off');
        print(fig,png_file,'-dpng','-r300');
    else
        exportgraphics(fig,png_file,'Resolution',300);
    end
catch err
    close(fig);
    rethrow(err);
end
close(fig);
end


function [force_limits,torque_limits] = comparison_limits(selected,analyses)
% Compare P2 and P3 under the same objective, but allow each objective
% its own data-derived scale. X and Y have the same symmetric limits.
n = numel(selected);
force_limits = nan(n,6);
torque_limits = nan(n,6);
objectives = unique({selected.objective},'stable');
for q = 1:numel(objectives)
    members = find(strcmp({selected.objective},objectives{q}));
    fv = zeros(0,3);
    tv = zeros(0,3);
    for k = members
        d = analyses{k};
        fv = [fv;d.force.vertices;d.zero_moment_force.vertices;d.hover_force(:).']; %#ok<AGROW>
        tv = [tv;d.moment.vertices;0 0 0]; %#ok<AGROW>
    end
    fl = padded_comparison_limits(fv);
    tl = padded_comparison_limits(tv);
    if strcmp(objectives{q},'hover_effort')
        fl = [-6 6 -6 6 -6 6];
    end
    force_limits(members,:) = repmat(fl,numel(members),1);
    torque_limits(members,:) = repmat(tl,numel(members),1);
end
end

function limits = padded_comparison_limits(vertices)
% Shared physical axis limits. Z is allowed its own interval to avoid
% wasting space above/below hover; no geometry or coordinates are changed.
if isempty(vertices) || any(~isfinite(vertices(:)))
    error('fa:Study03Plots','Cannot calculate limits from invalid vertices.');
end
xy = max(max(abs(vertices(:,1:2))));
zlo = min(vertices(:,3));
zhi = max(vertices(:,3));
zspan = zhi-zlo;
% The z-based minimum prevents almost vertical sets creating an
% impractically narrow 3D box; it never clips physical vertices.
xy = max(1.12*xy,0.08*max(zspan,0.1));
zpad = 0.10*max(zspan,0.1);
limits = [-xy xy -xy xy zlo-zpad zhi+zpad];
end
