function digest = workflow_source_hash()
%WORKFLOW_SOURCE_HASH Identify execution and checkpointing code.
% Changes to numerical code are tracked by numerical_core_hash().
% Plotting, table formatting, and publication post-processing are excluded
% so they can be revised without requiring a new numerical preflight.
root = fileparts(fileparts(mfilename('fullpath')));

folders = {fullfile(root,'internal')};
files = { ...
    fullfile(root,'inputs','runtime_settings.m'), ...
    fullfile(root,'run_preflight.m'), ...
    fullfile(root,'run_full_study.m'), ...
    fullfile(root,'setup_project.m')};

% These internal helpers only format or export completed results and do not
% alter optimization, checkpointing, or scientific case calculations.
excluded_internal_files = { ...
    'write_table_bundle.m'};

for folder_index = 1:numel(folders)
    listing = dir(fullfile(folders{folder_index},'**','*.m'));
    for file_index = 1:numel(listing)
        if ismember(listing(file_index).name,excluded_internal_files)
            continue
        end
        files{end+1} = fullfile( ...
            listing(file_index).folder,listing(file_index).name); %#ok<AGROW>
    end
end

files = sort(unique(files));
parts = cell(numel(files),1);
for file_index = 1:numel(files)
    relative_path = erase(files{file_index},[root filesep]);
    parts{file_index} = [relative_path,newline,fileread(files{file_index})];
end
digest = settings_hash(strjoin(parts,newline));
end
