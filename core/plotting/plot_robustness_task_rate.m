function [fig, source_data] = plot_robustness_task_rate(summary)
%PLOT_ROBUSTNESS_TASK_RATE Severe-case task-feasibility comparison.
% One grouped bar chart reports the task-feasibility rate at the largest
% tested level of each uncertainty family.

style = publication_style();
[task_rows,authority_rows,labels] = severe_rows(summary);
values = 100*[task_rows.task_feasibility authority_rows.task_feasibility];

fig = figure('Units','centimeters','Position',style.dimensions.column_tall, ...
    'Color',style.colors.white);
ax = axes(fig);
hold(ax,'on');
bars = bar(ax,values,'grouped','BarWidth',0.78);
bars(1).FaceColor = style.colors.blue;
bars(1).EdgeColor = style.colors.blue;
bars(1).LineWidth = 0.65;
bars(1).DisplayName = publication_name('objective','q_star');
bars(2).FaceColor = style.colors.ochre;
bars(2).EdgeColor = style.colors.ochre;
bars(2).LineWidth = 0.65;
bars(2).DisplayName = publication_name('objective','r_F0');
drawnow;
errorbar(ax,bars(1).XEndPoints,values(:,1), ...
    values(:,1)-100*task_rows.task_feasibility_lower_95, ...
    100*task_rows.task_feasibility_upper_95-values(:,1), ...
    'LineStyle','none','Color',style.colors.charcoal, ...
    'LineWidth',style.line.reference_width,'CapSize',4, ...
    'HandleVisibility','off');
errorbar(ax,bars(2).XEndPoints,values(:,2), ...
    values(:,2)-100*authority_rows.task_feasibility_lower_95, ...
    100*authority_rows.task_feasibility_upper_95-values(:,2), ...
    'LineStyle','none','Color',style.colors.charcoal, ...
    'LineWidth',style.line.reference_width,'CapSize',4, ...
    'HandleVisibility','off');
set(ax,'XTick',1:numel(labels),'XTickLabel',cellstr(labels));
xlabel(ax,'$\mathrm{Largest\ tested\ uncertainty}$');
ylabel(ax,'$\mathrm{Task\ feasibility}\ (\%)$');
ylim(ax,[0 105]);
format_publication_axes(ax,'quantitative');
legend(ax,bars,'Location','northeast','Orientation','vertical', ...
    'Interpreter','latex','Box','off','FontSize',style.font.legend);

source_data = table(labels,values(:,1),values(:,2), ...
    'VariableNames',{'Case','TaskOriented','ForceAuthority'});
end

function [task_rows,authority_rows,labels] = severe_rows(summary)
perturbations = ["position";"direction";"capacity";"kappa"];
labels = ["$\mathrm{Position}$"; ...
    "$\mathrm{Direction}$"; ...
    "$\mathrm{Capacity}$"; ...
    "$\mathrm{Reaction\ ratio}$"];
task_rows = table();
authority_rows = table();
for index = 1:numel(perturbations)
    type = perturbations(index);
    rows = summary(string(summary.perturbation_type)==type,:);
    level = max(rows.level);
    task = rows(string(rows.design_name)=="q_star" & rows.level==level,:);
    authority = rows(string(rows.design_name)=="r_F0" & rows.level==level,:);
    if height(task) ~= 1 || height(authority) ~= 1
        error('fa:RobustnessCoverage', ...
            'Expected one severe-case row per key design for %s.',type);
    end
    task_rows = [task_rows;task]; %#ok<AGROW>
    authority_rows = [authority_rows;authority]; %#ok<AGROW>
end
end
