function digest = numerical_core_hash(root)
%NUMERICAL_CORE_HASH Hash shared code that can change existing case results.
% Plotting, reporting, and study runners are excluded.
if nargin < 1 || isempty(root)
    root = fileparts(fileparts(mfilename('fullpath')));
end
folders = { ...
    fullfile(root,'core','geometry'), ...
    fullfile(root,'core','model'), ...
    fullfile(root,'core','feasibility'), ...
    fullfile(root,'core','metrics'), ...
    fullfile(root,'core','optimization'), ...
    fullfile(root,'core','sensitivity'), ...
    fullfile(root,'core','trajectory')};
files = {};
for folder_index = 1:numel(folders)
    listing = dir(fullfile(folders{folder_index},'**','*.m'));
    for file_index = 1:numel(listing)
        files{end+1,1} = fullfile(listing(file_index).folder, ... %#ok<AGROW>
            listing(file_index).name);
    end
end
files = sort(unique(cellstr(string(files))));
parts = cell(numel(files),1);
for k = 1:numel(files)
    path_in = files{k};
    relative_path = erase(path_in,[root filesep]);
    text = strrep(fileread(path_in),sprintf('\r\n'),sprintf('\n'));
    text = strrep(text,sprintf('\r'),sprintf('\n'));
    parts{k} = [relative_path,newline,text];
end
digest = settings_hash('source_manifest_v2',parts);
end
