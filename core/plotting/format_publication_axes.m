function format_publication_axes(ax,profile)
%FORMAT_PUBLICATION_AXES Apply the central style to one axes object.
if nargin < 2
    profile = 'quantitative';
end
style = publication_style();
set(ax,'FontSize',style.font.axes, ...
    'TickLabelInterpreter','latex', ...
    'LineWidth',style.axes.line_width, ...
    'TickDir','out','Layer','top');
ax.XLabel.Interpreter = 'latex';
ax.YLabel.Interpreter = 'latex';
ax.ZLabel.Interpreter = 'latex';
ax.Title.Interpreter = 'latex';
ax.XLabel.FontSize = style.font.label;
ax.YLabel.FontSize = style.font.label;
ax.ZLabel.FontSize = style.font.label;

switch lower(char(string(profile)))
    case 'quantitative'
        set(ax,'Box','off','XGrid','off','YGrid','on', ...
            'GridAlpha',style.axes.grid_alpha, ...
            'MinorGridAlpha',style.axes.minor_grid_alpha);
    case 'three_dimensional'
        set(ax,'Box','on','XGrid','on','YGrid','on','ZGrid','on', ...
            'GridAlpha',style.axes.grid_alpha, ...
            'MinorGridAlpha',style.axes.minor_grid_alpha);
    case 'schematic'
        grid(ax,'off');
        box(ax,'off');
        axis(ax,'off');
    otherwise
        error('fa:UnknownAxesProfile','Unknown axes profile: %s',profile);
end
end
