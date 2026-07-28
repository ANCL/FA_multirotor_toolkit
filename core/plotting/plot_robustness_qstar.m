function [fig, source_data] = plot_robustness_qstar(summary,perturbation)
%PLOT_ROBUSTNESS_QSTAR Median task scale with configured percentile bounds.
style = publication_style();
[D1,D2,x,x_label] = select_data(summary,perturbation);
fig = figure('Units','centimeters','Position',style.dimensions.column, ...
    'Color',style.colors.white);
ax = axes(fig);
hold(ax,'on');
h(1) = errorbar(ax,x,D1.q_star_median, ...
    D1.q_star_median-D1.q_star_p05,D1.q_star_p95-D1.q_star_median, ...
    '-o','Color',style.colors.blue,'LineWidth',style.line.emphasis_width, ...
    'MarkerSize',style.marker.size,'MarkerFaceColor',style.colors.blue, ...
    'CapSize',4,'DisplayName',publication_name('objective','q_star'));
h(2) = errorbar(ax,x,D2.q_star_median, ...
    D2.q_star_median-D2.q_star_p05,D2.q_star_p95-D2.q_star_median, ...
    '-s','Color',style.colors.ochre,'LineWidth',style.line.emphasis_width, ...
    'MarkerSize',style.marker.size,'MarkerFaceColor',style.colors.ochre, ...
    'CapSize',4,'DisplayName',publication_name('objective','r_F0'));
yline(ax,1,'--','Color',style.colors.black, ...
    'LineWidth',style.line.reference_width,'HandleVisibility','off');
xlabel(ax,x_label);
ylabel(ax,publication_name('metric','q_star'));
xlim(ax,padded_x(x));
ylim(ax,padded_y([D1.q_star_p05;D1.q_star_p95; ...
    D2.q_star_p05;D2.q_star_p95;1]));
format_publication_axes(ax,'quantitative');
legend(ax,h,'Location','northeast','Orientation','vertical', ...
    'Interpreter','latex','Box','off','FontSize',style.font.legend);
source_data = [D1;D2];
source_data.PresentationLevel = [x;x];
end

function [D1,D2,x,x_label] = select_data(summary,perturbation)
perturbation = string(perturbation);
D1 = summary(string(summary.design_name)=="q_star" & ...
    string(summary.perturbation_type)==perturbation,:);
D2 = summary(string(summary.design_name)=="r_F0" & ...
    string(summary.perturbation_type)==perturbation,:);
[D1,x] = order_rows(D1,perturbation);
[D2,x2] = order_rows(D2,perturbation);
if height(D1) ~= 3 || height(D2) ~= 3 || any(abs(x-x2)>1e-12)
    error('fa:RobustnessCoverage','Incomplete robustness data for %s.',perturbation);
end
x_label = uncertainty_label(perturbation);
end

function [D,x] = order_rows(D,perturbation)
[level,order] = sort(D.level);
D = D(order,:);
D.level = level;
switch char(perturbation)
    case {'position','capacity','kappa'}
        x = 100*D.level;
    case 'direction'
        x = rad2deg(D.level);
    otherwise
        error('fa:RobustnessPerturbation','Unknown perturbation: %s',perturbation);
end
end

function label = uncertainty_label(type)
switch char(type)
    case 'position', label = '$\sigma_p/L\ (\%)$';
    case 'direction', label = '$\sigma_\theta\ ({}^\circ)$';
    case 'capacity', label = '$\sigma_{\mu_{\max}}/\mu_{\max}\ (\%)$';
    case 'kappa', label = '$\sigma_\kappa/\kappa\ (\%)$';
end
end

function limits = padded_x(x)
span = max(max(x)-min(x),1);
limits = [max(0,min(x)-0.08*span) max(x)+0.08*span];
end

function limits = padded_y(values)
low = min(values);
high = max(values);
span = max(high-low,0.2);
limits = [max(0,low-0.10*span) high+0.12*span];
end
