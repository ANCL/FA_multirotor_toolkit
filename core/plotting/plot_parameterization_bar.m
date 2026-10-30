function [fig, source_data] = plot_parameterization_bar(comparison, metric)
%PLOT_PARAMETERIZATION_BAR Compare P1, P2, and P3 for one metric.
metric = char(string(metric));
if ~ismember(metric,{'r_F0','sigma_min','condition_number','hover_effort'})
    error('fa:ParameterizationMetric','Unknown metric: %s',metric);
end
style = publication_style();
parameterizations = ["rotorwise";"spatial_c3";"planar_shared"];
expected_names = [string(metric);"spatial_c3_"+string(metric); ...
    "planar_shared_"+string(metric)];
values = zeros(3,1);
selected_rows = false(height(comparison),1);
for index = 1:3
    row = string(comparison.parameterization)==parameterizations(index) & ...
        string(comparison.name)==expected_names(index);
    if nnz(row) ~= 1
        error('fa:ParameterizationSourceData', ...
            'Expected one %s result for %s.',metric,parameterizations(index));
    end
    values(index) = comparison.(metric)(row);
    selected_rows = selected_rows | row;
end

fig = figure('Units','centimeters','Position',style.dimensions.column, ...
    'Color',style.colors.white);
ax = axes(fig);
bar_handle = bar(ax,1:3,values,0.62,'FaceColor','flat', ...
    'EdgeColor',style.colors.charcoal,'LineWidth',0.65);
bar_handle.CData = [style.colors.P1;style.colors.P2;style.colors.P3];
set(ax,'XTick',1:3,'XTickLabel',{'$\mathcal P_1$','$\mathcal P_2$','$\mathcal P_3$'});
xlabel(ax,'$\mathrm{Design\ parameterization}$');
ylabel(ax,publication_name('metric',metric));
ylim(ax,padded_limits(values));
format_publication_axes(ax,'quantitative');
source_data = struct('selected_results',comparison(selected_rows,:), ...
    'metric',metric,'values',values);
end

function limits = padded_limits(values)
low = min([0;values(:)]);
high = max(values);
span = max(high-low,0.10*max(abs(values)));
limits = [low high+0.14*max(span,eps)];
end
