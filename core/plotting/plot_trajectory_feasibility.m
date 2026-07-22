function [figures, source_data] = plot_trajectory_feasibility(result, time)
%PLOT_TRAJECTORY_FEASIBILITY Plot allocation, margin, and wrench error.
validateattributes(time,{'numeric'}, ...
    {'real','finite','vector','numel',result.number_of_samples});
time = time(:).';
number_of_actuators = size(result.mu,1);
style = publication_style();
line_styles = {'-','--','-.',':','-','--'};
markers = {'none','none','none','none','o','s'};

figures.actuators = figure('Units','centimeters', ...
    'Position',style.dimensions.double_column,'Color',style.colors.white);
ax = axes(figures.actuators);
hold(ax,'on');
handles = gobjects(number_of_actuators,1);
for actuator = 1:number_of_actuators
    color = style.color_order(1+mod(actuator-1,size(style.color_order,1)),:);
    handles(actuator) = plot(ax,time,result.mu(actuator,:), ...
        'LineStyle',line_styles{1+mod(actuator-1,numel(line_styles))}, ...
        'Marker',markers{1+mod(actuator-1,numel(markers))}, ...
        'MarkerIndices',1:20:numel(time), ...
        'Color',color,'LineWidth',style.line.width, ...
        'DisplayName',['$\mu_{' num2str(actuator) '}$']);
    yline(ax,result.actuator_bounds(actuator,1),'--', ...
        'Color',style.colors.gray,'HandleVisibility','off');
    yline(ax,result.actuator_bounds(actuator,2),'--', ...
        'Color',style.colors.gray,'HandleVisibility','off');
end
xlabel(ax,'$t\ (\mathrm{s})$');
ylabel(ax,'$\mu_i$');
legend(ax,handles,'Interpreter','latex','Location','northeast', ...
    'Orientation','vertical','Box','off','FontSize',style.font.legend);
format_publication_axes(ax,'quantitative');

figures.margin = figure('Units','centimeters', ...
    'Position',style.dimensions.column,'Color',style.colors.white);
ax = axes(figures.margin);
plot(ax,time,result.saturation_margin,'-', ...
    'Color',style.colors.blue,'LineWidth',style.line.emphasis_width);
hold(ax,'on');
yline(ax,0,'--','Color',style.colors.black, ...
    'LineWidth',style.line.reference_width);
if ~isempty(result.infeasible_indices)
    indices = result.infeasible_indices;
    plot(ax,time(indices),zeros(size(indices)),'x', ...
        'Color',style.colors.ochre,'LineWidth',1.1, ...
        'MarkerSize',style.marker.size);
end
xlabel(ax,'$t\ (\mathrm{s})$');
ylabel(ax,'$\mathrm{Minimum\ normalized\ actuator\ margin}$');
format_publication_axes(ax,'quantitative');

figures.error = figure('Units','centimeters', ...
    'Position',style.dimensions.column,'Color',style.colors.white);
ax = axes(figures.error);
plot(ax,time,result.scaled_error,'-', ...
    'Color',style.colors.blue,'LineWidth',style.line.emphasis_width);
hold(ax,'on');
if ~isempty(result.infeasible_indices)
    indices = result.infeasible_indices;
    plot(ax,time(indices),result.scaled_error(indices),'x', ...
        'Color',style.colors.ochre,'LineWidth',1.1, ...
        'MarkerSize',style.marker.size);
end
xlabel(ax,'$t\ (\mathrm{s})$');
ylabel(ax,'$\mathrm{Scaled\ wrench\ error}$');
format_publication_axes(ax,'quantitative');

source_data = struct('result',result,'time',time);
end
