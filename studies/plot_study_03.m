function plots = plot_study_03()
%PLOT_STUDY_03 Export the eight selected P2/P3 SQP configurations.
% Uses the existing V2 renderer, adapted from Toolkit 1. No optimization.
setup_project();
root = fileparts(fileparts(mfilename('fullpath')));
output_folder = fullfile(root, 'results', 'study_03');
source_file = fullfile(output_folder, 'selected_designs.mat');
if ~isfile(source_file)
    error('fa:Study03Plots', ...
        'Missing selected_designs.mat. Run summarize_study_03 first.');
end
saved = load(source_file, 'selected');
if ~isfield(saved, 'selected') || numel(saved.selected) ~= 8
    error('fa:Study03Plots', 'Expected eight selected P2/P3 SQP designs.');
end
selected = saved.selected;
figures_folder = fullfile(output_folder, 'figures');
if ~isfolder(figures_folder), mkdir(figures_folder); end

n = numel(selected);
parameterization = cell(n, 1);
objective = cell(n, 1);
pdf_file = cell(n, 1);
png_file = cell(n, 1);
options = struct('visible', 'off', 'view', [38 24], ...
    'axis_limits', [-1.45 1.45 -1.45 1.45 -1.45 1.45], ...
    'show_legend', false, 'labels', true);

for k = 1:n
    item = selected(k);
    parameterization{k} = item.parameterization;
    objective{k} = item.objective;
    stem = sprintf('geometry_%s_%s', item.parameterization, item.objective);
    pdf_file{k} = fullfile(figures_folder, [stem '.pdf']);
    png_file{k} = fullfile(figures_folder, [stem '.png']);

    [fig, ~] = plot_multirotor_configuration(item.geometry, options);
    try
        drawnow;
        exportgraphics(fig, pdf_file{k}, 'ContentType', 'vector');
        exportgraphics(fig, png_file{k}, 'Resolution', 300);
    catch err
        close(fig);
        rethrow(err);
    end
    close(fig);
    fprintf('  %-3s %-17s PDF and PNG saved\n', ...
        upper(item.parameterization), item.objective);
end
plots = table(parameterization, objective, pdf_file, png_file);
fprintf('Study 03 | %d configurations | figures: %s\n', n, figures_folder);
end
