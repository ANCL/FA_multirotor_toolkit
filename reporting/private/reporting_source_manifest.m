function files = reporting_source_manifest(root)
%REPORTING_SOURCE_MANIFEST Hash MATLAB sources used by the toolkit.
folders = {'inputs','analyses','study','reporting','core','internal'};
entries = struct('path',{},'hash',{});
root_listing = dir(fullfile(root,'*.m'));
for index = 1:numel(root_listing)
    path = fullfile(root_listing(index).folder,root_listing(index).name);
    entries(end+1) = struct('path',root_listing(index).name, ... %#ok<AGROW>
        'hash',settings_hash(fileread(path)));
end
for folder_index = 1:numel(folders)
    listing = dir(fullfile(root,folders{folder_index},'**','*.m'));
    for index = 1:numel(listing)
        path = fullfile(listing(index).folder,listing(index).name);
        relative = erase(path,[root filesep]);
        entries(end+1) = struct('path',relative, ... %#ok<AGROW>
            'hash',settings_hash(fileread(path)));
    end
end
files = entries;
end
