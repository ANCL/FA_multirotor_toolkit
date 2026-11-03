function figures = plot_study_04()
%PLOT_STUDY_04 Plot saved unrestricted-P1 Study 04 trade-off results.
%   The figure settings and pooled-front construction follow Toolkit 1's
%   authority-effort plotting implementation, implemented locally here.
%   Uses the V2 geometry, metric, and constraint functions unchanged.
%   No optimization is performed; no legacy toolkit is required.

setup_project();
settings = study_04_settings();
cases = study_04_cases(settings);
model = default_model();
numerics = default_numerics();
style = study_04_plot_style();

root = fileparts(fileparts(mfilename('fullpath')));
result_dir = fullfile(root, 'results', 'study_04');
figure_dir = fullfile(result_dir, 'figures');
table_dir = fullfile(result_dir, 'tables');
if ~isfolder(figure_dir), mkdir(figure_dir); end
if ~isfolder(table_dir), mkdir(table_dir); end

% Revalidate the selected solution and every stored local SQP endpoint.
points = load_feasible_endpoints(cases, result_dir, settings, model, numerics);
points.nondominated = false(height(points), 1);
points.duplicate = false(height(points), 1);

% Same tolerance-based Pareto classification and near-duplicate suppression
% as Toolkit 1's pooled authority-effort report. The original tolerance
% setting was not included in the comparison archive; set locally below.
for k = 1:numel(settings.pairs)
    pair_name = settings.pairs{k};
    rows = find(strcmp(points.pair, pair_name));
    if isempty(rows), continue; end
    minimized = objective_matrix(points(rows,:), pair_name);
    [nondominated, duplicate] = classify_pareto(minimized, style.pareto_tolerance);
    points.nondominated(rows) = nondominated;
    points.duplicate(rows) = duplicate;
end

% Plot-specific tables do not overwrite the study's optimization summaries.
writetable(points, fullfile(table_dir, 'pareto_plot_all_feasible_endpoints.csv'));
writetable(points(points.nondominated & ~points.duplicate,:), ...
    fullfile(table_dir, 'pareto_plot_nondominated.csv'));

names = cell(0,1);
feasible_points = zeros(0,1);
pareto_points = zeros(0,1);
pdf = cell(0,1);
png = cell(0,1);

for k = 1:numel(settings.pairs)
    pair_name = settings.pairs{k};
    all_rows = strcmp(points.pair, pair_name);
    if ~any(all_rows), continue; end
    front_rows = all_rows & points.nondominated & ~points.duplicate;

    fig = figure('Units', 'centimeters', ...
        'Position', style.figure_position, 'Color', [1 1 1], ...
        'Visible', 'off');
    ax = axes('Parent', fig);
    hold(ax, 'on');

    if strcmp(pair_name, 'joint_three')
        plot_joint_three(ax, points, all_rows, front_rows, style);
    else
        [x, y, x_label, y_label] = axes_for_pair(points, pair_name);
        h(1) = plot(ax, x(all_rows), y(all_rows), '.', ...
            'Color', [0 0 0], 'MarkerSize', 3.0, ...
            'DisplayName', '$\mathrm{All\ feasible\ runs}$');

        xf = x(front_rows);
        yf = y(front_rows);
        [xf, order] = sort(xf);
        yf = yf(order);

        % The original Toolkit 1 plot connected every retained front point.
        % For a jointly attainable optimum, a connecting line is misleading.
        line_style = '-o';
        if strcmp(pair_name, 'sigma_condition') || numel(xf) < 2
            line_style = 'o';
        end
        h(2) = plot(ax, xf, yf, line_style, ...
            'Color', style.blue, 'LineWidth', 0.85, ...
            'MarkerSize', 2.0, 'MarkerFaceColor', [1 1 1], ...
            'MarkerEdgeColor', style.blue, ...
            'DisplayName', '$\mathrm{Pareto\ front}$');

        xlabel(ax, x_label, 'Interpreter', 'latex');
        ylabel(ax, y_label, 'Interpreter', 'latex');
        apply_publication_axes(ax, style);
        axis(ax, 'padded');
        legend(ax, h, 'Location', 'best', 'Orientation', 'vertical', ...
            'Interpreter', 'latex', 'Box', 'off', ...
            'FontSize', style.legend_font_size);

        if strcmp(pair_name, 'authority_effort')
            plotted_front = table(xf, yf, ...
                'VariableNames', {'r_F0', 'hover_effort'});
            writetable(plotted_front, fullfile(table_dir, ...
                'pareto_authority_effort_plotted_front.csv'));
        end
    end

    output_base = fullfile(figure_dir, ['pareto_' pair_name]);
    exportgraphics(fig, [output_base '.pdf'], 'ContentType', 'vector');
    exportgraphics(fig, [output_base '.png'], 'Resolution', 300);
    close(fig);

    names{end+1,1} = pair_name; %#ok<AGROW>
    feasible_points(end+1,1) = sum(all_rows); %#ok<AGROW>
    pareto_points(end+1,1) = sum(front_rows); %#ok<AGROW>
    pdf{end+1,1} = [output_base '.pdf']; %#ok<AGROW>
    png{end+1,1} = [output_base '.png']; %#ok<AGROW>
end

figures = table(names, feasible_points, pareto_points, pdf, png, ...
    'VariableNames', {'label', 'feasible_points', 'pareto_points', 'pdf', 'png'});
writetable(figures, fullfile(table_dir, 'pareto_plot_counts.csv'));
disp(figures(:, 1:3));
end

function t = load_feasible_endpoints(cases, result_dir, settings, model, numerics)
% Extract only candidate vectors recorded by the existing V2 SQP solver.
pair = cell(0,1);
group = cell(0,1);
case_file = cell(0,1);
origin = cell(0,1);
start_number = zeros(0,1);
r_F0 = zeros(0,1);
sigma_min = zeros(0,1);
condition_number = zeros(0,1);
hover_effort = zeros(0,1);

for i = 1:height(cases)
    file_path = fullfile(result_dir, 'runs', cases.file_name{i});
    if ~isfile(file_path), continue; end
    stored = load(file_path, 'result');
    if ~isfield(stored, 'result')
        error('fa:Study04PlotFile', 'Missing result in %s', file_path);
    end
    r = stored.result;
    if ~isequaln(r.seed, cases.seed(i)) || ...
            ~strcmp(r.problem.parameterization, 'p1') || ...
            ~strcmp(r.problem.objective, cases.objective{i}) || ...
            ~strcmp(r.problem.normalization_group, cases.normalization_group{i})
        error('fa:Study04PlotIdentity', 'Saved case mismatch: %s', file_path);
    end

    candidates = {r.design_variables};
    kinds = {'selected'};
    indices = 0;
    if isfield(r, 'sqp') && isfield(r.sqp, 'local_runs')
        runs = r.sqp.local_runs;
        for j = 1:numel(runs)
            if isfield(runs(j), 'x') && ~isempty(runs(j).x)
                candidates{end+1} = runs(j).x; %#ok<AGROW>
                kinds{end+1} = 'sqp'; %#ok<AGROW>
                indices(end+1) = j; %#ok<AGROW>
            end
        end
    end

    for j = 1:numel(candidates)
        x = candidates{j}(:);
        if ~isnumeric(x) || numel(x) ~= numel(r.design_variables) || ...
                any(~isfinite(x))
            continue;
        end
        try
            [c, ceq] = design_constraints(x, r.problem, model, numerics);
            violation = max([0; c(:); abs(ceq(:))]);
            geometry = decode_design(x, r.problem);
            metrics = evaluate_design(geometry, model, numerics);
        catch err
            warning('fa:Study04PlotCandidate', ...
                'Skipping case %d, start %d: %s', i, indices(j), err.message);
            continue;
        end
        measures = [metrics.r_F0, metrics.sigma_min, ...
            metrics.condition_number, metrics.hover_effort];
        if ~metrics.valid || ~isfinite(violation) || ...
                violation > settings.constraint_tolerance || ...
                any(~isfinite(measures))
            continue;
        end

        pair{end+1,1} = cases.pair{i}; %#ok<AGROW>
        group{end+1,1} = cases.normalization_group{i}; %#ok<AGROW>
        case_file{end+1,1} = cases.file_name{i}; %#ok<AGROW>
        origin{end+1,1} = kinds{j}; %#ok<AGROW>
        start_number(end+1,1) = indices(j); %#ok<AGROW>
        r_F0(end+1,1) = metrics.r_F0; %#ok<AGROW>
        sigma_min(end+1,1) = metrics.sigma_min; %#ok<AGROW>
        condition_number(end+1,1) = metrics.condition_number; %#ok<AGROW>
        hover_effort(end+1,1) = metrics.hover_effort; %#ok<AGROW>
    end
end

t = table(pair, group, case_file, origin, start_number, ...
    r_F0, sigma_min, condition_number, hover_effort);
end

function [nondominated, duplicate] = classify_pareto(F, tolerance)
% Toolkit 1 dominance test, expressed in minimization coordinates.
n = size(F, 1);
valid = all(isfinite(F), 2);
dominated = false(n, 1);
for i = 1:n
    if ~valid(i), continue; end
    others = find(valid);
    others(others == i) = [];
    no_worse = all(F(others,:) <= F(i,:) + tolerance, 2);
    strictly_better = any(F(others,:) < F(i,:) - tolerance, 2);
    dominated(i) = any(no_worse & strictly_better);
end
nondominated = valid & ~dominated;
duplicate = false(n, 1);

% Toolkit 1 suppresses points close in BOTH objective values and prefers
% higher authority in the authority-effort case (first coordinate -r_F0).
candidates = find(nondominated);
[~, order] = sortrows(F(candidates,:), 1:size(F,2));
candidates = candidates(order);
retained = false(n,1);
for k = 1:numel(candidates)
    i = candidates(k);
    prior = find(retained);
    if any(all(abs(F(prior,:) - F(i,:)) <= tolerance, 2))
        duplicate(i) = true;
    else
        retained(i) = true;
    end
end
end

function F = objective_matrix(t, pair_name)
% Every column is expressed in the minimize direction.
switch pair_name
    case 'authority_effort'
        F = [-t.r_F0, t.hover_effort];
    case 'authority_sigma'
        F = [-t.r_F0, -t.sigma_min];
    case 'authority_condition'
        F = [-t.r_F0, t.condition_number];
    case 'sigma_effort'
        F = [-t.sigma_min, t.hover_effort];
    case 'condition_effort'
        F = [t.condition_number, t.hover_effort];
    case 'sigma_condition'
        F = [-t.sigma_min, t.condition_number];
    case 'joint_three'
        F = [-t.r_F0, -t.sigma_min, t.condition_number];
    otherwise
        error('fa:Study04UnknownPair', 'Unknown objective pair: %s', pair_name);
end
end

function [x, y, x_label, y_label] = axes_for_pair(t, pair_name)
switch pair_name
    case 'authority_effort'
        x = t.r_F0; y = t.hover_effort;
        x_label = '$r_{\mathcal F_0}(f_h)$';
        y_label = '$\|\mu_h\|_2^2$';
    case 'authority_sigma'
        x = t.r_F0; y = t.sigma_min;
        x_label = '$r_{\mathcal F_0}(f_h)$';
        y_label = '$\sigma_{\min}(\bar A)$';
    case 'authority_condition'
        x = t.r_F0; y = t.condition_number;
        x_label = '$r_{\mathcal F_0}(f_h)$';
        y_label = '$C(\bar A)$';
    case 'sigma_effort'
        x = t.sigma_min; y = t.hover_effort;
        x_label = '$\sigma_{\min}(\bar A)$';
        y_label = '$\|\mu_h\|_2^2$';
    case 'condition_effort'
        x = t.condition_number; y = t.hover_effort;
        x_label = '$C(\bar A)$';
        y_label = '$\|\mu_h\|_2^2$';
    case 'sigma_condition'
        x = t.sigma_min; y = t.condition_number;
        x_label = '$\sigma_{\min}(\bar A)$';
        y_label = '$C(\bar A)$';
    otherwise
        error('fa:Study04UnknownPair', 'Unknown 2-D pair: %s', pair_name);
end
end

function plot_joint_three(ax, t, all_rows, front_rows, style)
% A color scale is necessary to show the third objective; do not join 3-D
% nondominated points with a misleading 2-D frontier line.
h(1) = scatter(ax, t.r_F0(all_rows), t.sigma_min(all_rows), 8, ...
    t.condition_number(all_rows), 'filled', ...
    'DisplayName', '$\mathrm{All\ feasible\ runs}$');
h(1).MarkerFaceAlpha = 0.40;
h(2) = plot(ax, t.r_F0(front_rows), t.sigma_min(front_rows), 'o', ...
    'Color', style.blue, 'LineWidth', 0.85, 'MarkerSize', 2.0, ...
    'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', style.blue, ...
    'DisplayName', '$\mathrm{Nondominated}$');
cb = colorbar(ax);
cb.Label.Interpreter = 'none';
cb.Label.String = 'Condition number';
xlabel(ax, '$r_{\mathcal F_0}(f_h)$', 'Interpreter', 'latex');
ylabel(ax, '$\sigma_{\min}(\bar A)$', 'Interpreter', 'latex');
apply_publication_axes(ax, style);
axis(ax, 'padded');
legend(ax, h, 'Location', 'best', 'Orientation', 'vertical', ...
    'Interpreter', 'latex', 'Box', 'off', ...
    'FontSize', style.legend_font_size);
end

function apply_publication_axes(ax, style)
% Same quantitative-axes settings as Toolkit 1's format_publication_axes.
set(ax, 'FontSize', style.axes_font_size, ...
    'TickLabelInterpreter', 'latex', ...
    'LineWidth', style.axes_line_width, ...
    'TickDir', 'out', 'Layer', 'top', ...
    'Box', 'off', 'XGrid', 'off', 'YGrid', 'on', ...
    'GridAlpha', style.grid_alpha, ...
    'MinorGridAlpha', style.minor_grid_alpha);
ax.XLabel.Interpreter = 'latex';
ax.YLabel.Interpreter = 'latex';
ax.ZLabel.Interpreter = 'latex';
ax.Title.Interpreter = 'latex';
ax.XLabel.FontSize = style.label_font_size;
ax.YLabel.FontSize = style.label_font_size;
ax.ZLabel.FontSize = style.label_font_size;
end

function style = study_04_plot_style()
% Figure values transcribed from Toolkit 1's publication_style.m and
% plot_pareto_runs.m; kept local to avoid adding style-file dependencies.
style.figure_position = [2 2 8.8 6.2];  % centimeters
style.axes_font_size = 8.0;
style.label_font_size = 8.6;
style.legend_font_size = 7.8;
style.axes_line_width = 0.75;
style.grid_alpha = 0.12;
style.minor_grid_alpha = 0.06;
style.blue = [0.18 0.40 0.61];
style.pareto_tolerance = 1e-6;  % Legacy value unavailable in source archive.
end
