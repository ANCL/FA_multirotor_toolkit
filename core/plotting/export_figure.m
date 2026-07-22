function paths = export_figure(fig,folder,base_name)
%EXPORT_FIGURE Save one tightly fitted PDF and one editable FIG.
%
% Every current publication figure contains one axes. Exporting that axes
% includes its labels, tick numbers, and associated legend while avoiding
% the unused outer figure canvas. No cropping, resizing, or layout changes
% are performed here.

if ~isgraphics(fig,'figure')
    error('fa:InvalidFigure','The first input must be a valid figure handle.');
end
if ~isfolder(folder)
    mkdir(folder);
end

axes_handles = findall(fig,'Type','axes');
if numel(axes_handles) ~= 1
    error('fa:UnexpectedAxesCount', ...
        'export_figure expects exactly one axes, but found %d.', ...
        numel(axes_handles));
end
ax = axes_handles(1);

set(fig,'Color',[1 1 1]);
drawnow;

paths.pdf = fullfile(folder,[char(string(base_name)) '.pdf']);
paths.fig = fullfile(folder,[char(string(base_name)) '.fig']);

exportgraphics(ax,paths.pdf, ...
    'ContentType','vector', ...
    'BackgroundColor','white');
savefig(fig,paths.fig);
end
