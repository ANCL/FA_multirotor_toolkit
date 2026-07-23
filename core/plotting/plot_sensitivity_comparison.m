function fig = plot_sensitivity_comparison(source_data,x_variable,y_variable,options)
%PLOT_SENSITIVITY_COMPARISON One-panel physical sensitivity comparison.
if nargin < 4, options = struct(); end
options = complete_options(options);
required = {x_variable,y_variable,'design'};
if ~all(ismember(required,source_data.Properties.VariableNames))
    error('fa:SensitivityPlotColumns', ...
        'Sensitivity source data are incomplete for %s/%s.', ...
        x_variable,y_variable);
end
style = publication_style();
fig = figure('Units','centimeters', ...
    'Position',style.dimensions.column, ...
    'Color',style.colors.white);
ax = axes(fig);
hold(ax,'on');

nominal = sortrows(source_data( ...
    string(source_data.design)=="Nominal geometry",:),x_variable);
condition = sortrows(source_data( ...
    string(source_data.design)=="Condition-specific optimum",:),x_variable);
if isempty(nominal) || height(nominal) ~= height(condition)
    error('fa:SensitivityPlotRows', ...
        ['Expected equal nonempty nominal and condition-specific ' ...
         'sensitivity series.']);
end

nominal_x = nominal.(x_variable);
condition_x = condition.(x_variable);

alignment_scale = max(1,max(abs([nominal_x;condition_x])));
alignment_tolerance = 100*eps(alignment_scale);

if any(abs(nominal_x-condition_x) > alignment_tolerance)
    error('fa:SensitivityPlotRows', ...
        'Nominal and condition-specific sensitivity points are not aligned.');
end

condition_line = plot(ax,condition.(x_variable),condition.(y_variable),'-s', ...
    'Color',style.colors.blue, ...
    'LineWidth',1.1, ...
    'MarkerSize',5, ...
    'MarkerFaceColor',style.colors.blue, ...
    'MarkerEdgeColor',style.colors.blue, ...
    'DisplayName','Condition-specific optimum');
nominal_line = plot(ax,nominal.(x_variable),nominal.(y_variable),'--o', ...
    'Color',style.colors.black, ...
    'LineWidth',1.1, ...
    'MarkerSize',5, ...
    'MarkerFaceColor',style.colors.white, ...
    'MarkerEdgeColor',style.colors.black, ...
    'DisplayName','Nominal optimum');
if options.show_task_feasibility
    yline(ax,-1,':','Color',style.colors.dark_gray, ...
        'LineWidth',0.8, ...
        'HandleVisibility','off');
end
xlabel(ax,options.x_label);
ylabel(ax,options.y_label);
if options.log_x
    set(ax,'XScale','log');
end
if ~isempty(options.x_ticks)
    xticks(ax,options.x_ticks);
end
if ~isempty(options.x_tick_labels)
    xticklabels(ax,options.x_tick_labels);
end

values = source_data.(y_variable);
values = values(isfinite(values));
if options.show_task_feasibility, values = [values;-1]; end
if ~isempty(values)
    lower = min(values);
    upper = max(values);
    span = max(upper-lower,0.02*max(1,max(abs(values))));
    padding = max(0.06*span,0.008*max(1,max(abs(values))));
    lower_limit = lower-padding;
    upper_limit = upper+padding;
    if lower >= 0
        lower_limit = max(0,lower_limit);
    end
    if options.show_legend
        upper_limit = upper_limit + options.legend_headroom* ...
            max(upper_limit-lower_limit,span);
    end
    ylim(ax,[lower_limit,upper_limit]);
end
format_publication_axes(ax,'quantitative');
ytickformat(ax,'%.3g');
if options.show_legend
    legend(ax,[nominal_line,condition_line], ...
        {'Nominal optimum','Condition-specific optimum'}, ...
        'Location',options.legend_location, ...
        'Orientation','vertical', ...
        'Box','off', ...
        'Interpreter','latex', ...
        'FontSize',style.font.legend*1.2);
end
end

function options = complete_options(options)
defaults = struct('x_label','','y_label','','log_x',false, ...
    'show_task_feasibility',false,'x_ticks',[],'x_tick_labels',{{}}, ...
    'show_legend',false,'legend_location','best', ...
    'legend_headroom',0);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(options,fields{k})
        options.(fields{k}) = defaults.(fields{k});
    end
end
end
