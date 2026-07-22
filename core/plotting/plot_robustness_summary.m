function [fig, source_data] = plot_robustness_summary(summary)
%PLOT_ROBUSTNESS_SUMMARY Severe-case task-scale robustness comparison.
% Shows the median and 5th--95th percentile interval at the largest tested
% uncertainty level for the task-oriented and force-authority designs.

style = publication_style();
[task_rows,authority_rows,labels] = severe_rows(summary);
number_of_cases = numel(labels);
y = (1:number_of_cases).';
offset = 0.13;

fig = figure('Units','centimeters','Position',style.dimensions.column_tall, ...
    'Color',style.colors.white);
ax = axes(fig);
hold(ax,'on');

h(1) = horizontal_interval(ax,task_rows,y+offset,style.colors.blue,'o', ...
    publication_name('objective','q_star'),style);
h(2) = horizontal_interval(ax,authority_rows,y-offset,style.colors.ochre,'s', ...
    publication_name('objective','r_F0'),style);
xline(ax,1,'--','Color',style.colors.black, ...
    'LineWidth',style.line.reference_width,'HandleVisibility','off');
set(ax,'YTick',y,'YTickLabel',cellstr(labels),'YDir','reverse');
xlabel(ax,publication_name('metric','q_star'));
ylabel(ax,'$\mathrm{Largest\ tested\ uncertainty}$');
xlim(ax,padded_limits([task_rows.q_star_p05;task_rows.q_star_p95; ...
    authority_rows.q_star_p05;authority_rows.q_star_p95;1]));
ylim(ax,[0.45 number_of_cases+0.55]);
format_publication_axes(ax,'quantitative');
set(ax,'YGrid','off','XGrid','on');
legend(ax,h,'Location','northeast','Orientation','vertical', ...
    'Interpreter','latex','Box','off','FontSize',style.font.legend);

source_data = [task_rows;authority_rows];
source_data.PresentationCase = [labels;labels];
end

function handle = horizontal_interval(ax,T,y,color,marker,label,style)
median_value = T.q_star_median;
low = median_value-T.q_star_p05;
high = T.q_star_p95-median_value;
handle = errorbar(ax,median_value,y,low,high,'horizontal', ...
    'LineStyle','none','Color',color, ...
    'LineWidth',style.line.emphasis_width, ...
    'Marker',marker,'MarkerSize',style.marker.emphasis_size, ...
    'MarkerFaceColor',color,'MarkerEdgeColor',color, ...
    'CapSize',5,'DisplayName',label);
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

function limits = padded_limits(values)
low = min(values);
high = max(values);
span = max(high-low,0.25);
limits = [max(0,low-0.10*span) high+0.12*span];
end
