function yes = case_store_has(store,specification)
%CASE_STORE_HAS True for a complete checkpoint with the expected case hash.
path_in = case_store_path(store,specification.case_name);
yes = false;
if ~isfile(path_in), return; end
try
    data = load(path_in,'saved_case_name','case_provenance');
catch ME
    error('fa:UnreadableCheckpoint', ...
        'Cannot read checkpoint %s: %s',path_in,ME.message);
end
if ~isfield(data,'saved_case_name') || ...
        ~strcmp(data.saved_case_name,char(string(specification.case_name)))
    error('fa:CheckpointIdentityMismatch', ...
        'Checkpoint name does not match case %s: %s', ...
        specification.case_name,path_in);
end
if ~isfield(data,'case_provenance')
    error('fa:UnsupportedCheckpoint', ...
        ['Checkpoint lacks per-case provenance: %s\n' ...
         'Delete only this checkpoint and rerun case %s.'], ...
        path_in,specification.case_name);
end
assert_case_provenance_compatible( ...
    data.case_provenance,specification.provenance,path_in);
yes = true;
end
