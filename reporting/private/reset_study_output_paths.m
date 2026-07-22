function paths = reset_study_output_paths(paths)
%RESET_STUDY_OUTPUT_PATHS Reset only one current study output folder.
remove_combined_manifests(paths.publication);
if ~isfolder(paths.publication), mkdir(paths.publication); end
if isfolder(paths.root)
    [ok,message] = rmdir(paths.root,'s');
    if ~ok
        error('fa:StudyOutputCleanup', ...
            'Could not reset %s: %s',paths.root,message);
    end
end
mkdir(paths.root);
make_folder(paths.figures);
make_folder(paths.tables);
make_folder(paths.diagnostics);
write_output_guide(paths.publication);
end

function remove_combined_manifests(publication)
% A combined manifest becomes stale whenever one study is regenerated.
root_manifests = {'FIGURE_GUIDE.md','study_manifest.json','study_manifest.mat'};
for index = 1:numel(root_manifests)
    target = fullfile(publication,root_manifests{index});
    if isfile(target), delete(target); end
end
end

function make_folder(folder)
if ~isfolder(folder), mkdir(folder); end
end
