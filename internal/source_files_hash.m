function digest = source_files_hash(files,root)
%SOURCE_FILES_HASH Stable identifier for an explicit source-file manifest.
if nargin < 2 || isempty(root)
    root = fileparts(fileparts(mfilename('fullpath')));
end
files = cellstr(string(files));
files = sort(unique(files));
parts = cell(numel(files),1);
for k = 1:numel(files)
    path_in = files{k};
    if ~isfile(path_in)
        error('fa:MissingProvenanceSource', ...
            'Provenance source file is missing: %s',path_in);
    end
    relative_path = erase(path_in,[root filesep]);
    text = strrep(fileread(path_in),sprintf('\r\n'),sprintf('\n'));
    text = strrep(text,sprintf('\r'),sprintf('\n'));
    parts{k} = [relative_path,newline,text];
end
digest = settings_hash('source_manifest_v2',parts);
end
