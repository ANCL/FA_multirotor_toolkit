function [style,cleanup] = publication_style(action)
%PUBLICATION_STYLE Central visual standard for publication outputs.
% Activated graphics defaults are scoped to the caller and restored automatically.

if nargin < 1
    action = 'settings';
end
style = build_style();
cleanup = [];

switch lower(char(string(action)))
    case 'settings'
        return;
    case 'activate'
        root = groot;
        names = { ...
            'DefaultFigureColor', ...
            'DefaultTextInterpreter', ...
            'DefaultAxesTickLabelInterpreter', ...
            'DefaultLegendInterpreter', ...
            'DefaultColorbarTickLabelInterpreter', ...
            'DefaultAxesFontSize', ...
            'DefaultAxesLineWidth', ...
            'DefaultAxesTickDir', ...
            'DefaultAxesBox', ...
            'DefaultAxesColorOrder', ...
            'DefaultLineLineWidth', ...
            'DefaultLineMarkerSize'};
        values = { ...
            style.colors.white, ...
            'latex', ...
            'latex', ...
            'latex', ...
            'latex', ...
            style.font.axes, ...
            style.axes.line_width, ...
            'out', ...
            'off', ...
            style.color_order, ...
            style.line.width, ...
            style.marker.size};
        previous = cell(size(names));
        for index = 1:numel(names)
            previous{index} = get(root,names{index});
            set(root,names{index},values{index});
        end
        cleanup = onCleanup(@() restore_defaults(root,names,previous));
    otherwise
        error('fa:PublicationStyleAction', ...
            'Unknown publication-style action: %s',char(string(action)));
end
end

function style = build_style()
style.dimensions.column = [2 2 8.8 6.2];
style.dimensions.column_short = [2 2 8.8 5.4];
style.dimensions.column_tall = [2 2 8.8 7.4];
style.dimensions.subfigure_half = [2 2 8.6 5.8];
style.dimensions.subfigure_third = [2 2 5.7 4.8];
style.dimensions.force_set = [2 2 9.0 8.2];
style.dimensions.geometry = [2 2 8.8 5.6];
style.dimensions.double_column = [2 2 18.0 7.0];

% Fixed figure dimensions are defined above. Plotting functions own
% their axes positions; the exporter performs no layout adjustment.
style.font.axes = 8.0;
style.font.label = 8.6;
style.font.legend = 7.8;
style.font.annotation = 7.4;

style.axes.line_width = 0.75;
style.axes.grid_alpha = 0.12;
style.axes.minor_grid_alpha = 0.06;
style.line.width = 1.20;
style.line.emphasis_width = 1.65;
style.line.reference_width = 0.95;
style.marker.size = 5.5;
style.marker.emphasis_size = 6.5;

style.colors.white = [1.00 1.00 1.00];
style.colors.black = [0.00 0.00 0.00];
style.colors.charcoal = [0.16 0.17 0.18];
style.colors.dark_gray = [0.34 0.35 0.36];
style.colors.gray = [0.58 0.59 0.60];
style.colors.light_gray = [0.80 0.81 0.82];
style.colors.pale_gray = [0.90 0.91 0.92];
style.colors.blue = [0.18 0.40 0.61];
style.colors.blue_light = [0.63 0.76 0.86];
style.colors.ochre = [0.73 0.45 0.12];
style.colors.ochre_light = [0.88 0.73 0.51];
style.colors.green = [0.24 0.53 0.42];
style.colors.P1 = style.colors.dark_gray;
style.colors.P2 = style.colors.blue;
style.colors.P3 = style.colors.ochre;

% Geometry schematics use a soft, low-contrast palette.
style.colors.geometry_arm = [0.40 0.42 0.43];
style.colors.geometry_center = [0.27 0.28 0.28];
style.colors.rotor_fill = [0.72 0.78 0.80];
style.colors.thrust_direction = [0.20 0.21 0.21];

style.color_order = [style.colors.blue;style.colors.ochre; ...
    style.colors.charcoal;style.colors.green;style.colors.gray];

style.alpha.surface_full = 0.12;
style.alpha.surface_restricted = 0.28;
style.alpha.rotor_disc = 1.00;
style.alpha.mesh_edge = 0.24;

style.markers.task = 'o';
style.markers.authority = 's';
style.markers.fixed = 'o';
style.markers.optimized = 's';

style.labels.r_F0 = '$r_{\mathcal F_0}(f_h)$';
style.labels.sigma_min = '$\sigma_{\min}(\bar A)$';
style.labels.condition_number = '$C(\bar A)$';
style.labels.hover_effort = '$\|\mu_h\|_2^2$';
style.labels.q_star = '$q^\star$';
style.labels.force_set = '$\mathcal F$';
style.labels.zero_moment_force_set = '$\mathcal F_0$';
style.labels.moment_set = '$\mathcal T$';
style.labels.hover_force = '$f_h$';
end

function restore_defaults(root,names,previous)
for index = 1:numel(names)
    try
        set(root,names{index},previous{index});
    catch
    end
end
end
