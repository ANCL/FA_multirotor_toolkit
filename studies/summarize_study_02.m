function summary = summarize_study_02()
%SUMMARIZE_STUDY_02 Summarize saved analytical-bound discovery results.
% No optimizer is called. Uses the V1-style rotor-disk schematic for plots.

setup_project();
s = study_02_settings();
root = fileparts(fileparts(mfilename('fullpath')));
folder = fullfile(root,'results','study_02');
tables_folder = fullfile(folder,'tables');
figures_folder = fullfile(folder,'figures');
if ~isfolder(tables_folder), mkdir(tables_folder); end
if s.make_figures && ~isfolder(figures_folder), mkdir(figures_folder); end

result_rows=cell(0,13);
rotor_rows=cell(0,13);
status_rows=cell(0,9);
for i=1:numel(s.objectives)
    objective=s.objectives{i};
    accepted=load_study_02_accepted(folder,objective);
    progress_file=fullfile(folder,'progress.mat');
    if isfile(progress_file)
        data=load(progress_file,'progress');
        if isfield(data,'progress') && isfield(data.progress,objective)
            counts=data.progress.(objective);
        else
            error('fa:Study02Progress','No progress record for %s.',objective);
        end
    elseif isempty(accepted)
        status_rows(end+1,:)={objective,0,0,0,0,0,0,NaN,'not run'}; %#ok<AGROW>
        continue;
    else
        error('fa:Study02Progress','Missing progress.mat for %s.',objective);
    end
    gaps=nan(numel(accepted),1);
    for j=1:numel(accepted)
        entry=accepted(j); g=entry.geometry; m=entry.metrics;
        gaps(j)=entry.relative_bound_gap;
        result_rows(end+1,:)={objective,j,entry.attempt_number, ... %#ok<AGROW>
            entry.normalization_group,entry.objective_value, ...
            100*entry.relative_bound_gap,entry.performance_bound_violation, ...
            entry.physical_constraint_violation, ...
            entry.nearest_previous_distance, ...
            m.r_F0,m.sigma_min,m.condition_number,m.hover_effort};
        for k=1:6
            rotor_rows(end+1,:)={objective,j,entry.normalization_group,k, ... %#ok<AGROW>
                sign_of_rotor(k),norm(g.positions(:,k)), ...
                g.positions(1,k),g.positions(2,k),g.positions(3,k), ...
                g.directions(1,k),g.directions(2,k),g.directions(3,k), ...
                dot(g.positions(:,k),g.directions(:,k))};
        end
    end
    if isempty(gaps), med=NaN; else, med=median(gaps)*100; end
    stop_reason='unfinished';
    if numel(accepted)>=s.target_per_objective
        stop_reason='target reached';
    elseif counts.stagnation>=s.stagnation_attempts
        stop_reason='stagnation';
    end
    status_rows(end+1,:)={objective,numel(accepted),counts.saved, ... %#ok<AGROW>
        counts.qualifying,counts.duplicates,counts.failed, ...
        counts.stagnation,med,stop_reason};
    if s.make_figures && ~isempty(accepted)
        plot_gallery(accepted,objective,figures_folder);
    end
end
results=cell2table(result_rows,'VariableNames',{ ...
    'objective','config_id','attempt_number','normalization_group', ...
    'optimized_value','gap_percent','absolute_bound_violation', ...
    'physical_constraint_violation','nearest_previous_RMS_distance', ...
    'r_F0','sigma_min','condition_number','hover_effort'});
rotors=cell2table(rotor_rows,'VariableNames',{ ...
    'objective','config_id','normalization_group','rotor','reaction_sign', ...
    'radius','px','py','pz','ux','uy','uz','p_dot_u'});
status=cell2table(status_rows,'VariableNames',{ ...
    'objective','accepted','sqp_attempts','qualifying_attempts', ...
    'duplicates','failed','consecutive_without_new', ...
    'median_gap_percent','stop_reason'});
writetable(results,fullfile(tables_folder,'discovered_configurations.csv'));
writetable(rotors,fullfile(tables_folder,'rotor_geometries.csv'));
writetable(status,fullfile(tables_folder,'discovery_summary.csv'));
summary=struct('output_folder',folder,'configurations',results, ...
    'rotors',rotors,'status',status);
fprintf('\nSTUDY 02 SUMMARY | saved results only\n');
for i=1:height(status)
    fprintf('  %-17s %3d/%d distinct | %5d attempts | %4d qualifying | %4d duplicates | %s\n', ...
        status.objective{i},status.accepted(i),s.target_per_objective, ...
        status.sqp_attempts(i),status.qualifying_attempts(i), ...
        status.duplicates(i),status.stop_reason{i});
end
fprintf('Tables: %s\n',tables_folder);
if s.make_figures, fprintf('Figures: %s\n',figures_folder); end
end

function s=sign_of_rotor(i)
if i<=3, s=1; else, s=-1; end
end

function plot_gallery(accepted,objective,folder)
n=min(6,numel(accepted));
fig=figure('Visible','off','Color','w','Position',[100 100 1350 800]);
t=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
for i=1:n
    ax=nexttile(t,i);
    options=struct('axes_handle',ax,'show_legend',false, ...
        'view',[38 30],'axis_limits',[-1.4 1.4 -1.4 1.4 -1.4 1.4]);
    plot_multirotor_configuration(accepted(i).geometry,options);
    title(ax,sprintf('Configuration %d  |  gap %.3g%%', ...
        i,100*accepted(i).relative_bound_gap), ...
        'FontSize',10,'FontWeight','normal','Interpreter','none');
end
% One figure-wide legend; every rotor remains numbered in its own panel.
cp=[0.38 0.57 0.74]; cn=[0.78 0.56 0.32];
annotation(fig,'ellipse',[0.38 0.953 0.014 0.023], ...
    'FaceColor',cp,'EdgeColor','none');
annotation(fig,'textbox',[0.397 0.943 0.10 0.043], ...
    'String','$s_i=+1$','Interpreter','latex', ...
    'EdgeColor','none','FontSize',10,'FitBoxToText','off');
annotation(fig,'ellipse',[0.51 0.953 0.014 0.023], ...
    'FaceColor',cn,'EdgeColor','none');
annotation(fig,'textbox',[0.527 0.943 0.10 0.043], ...
    'String','$s_i=-1$','Interpreter','latex', ...
    'EdgeColor','none','FontSize',10,'FitBoxToText','off');
filename=fullfile(folder,sprintf('%s_first_six.png',objective));
try
    exportgraphics(fig,filename,'Resolution',200);
catch
    saveas(fig,filename);
end
close(fig);
end
