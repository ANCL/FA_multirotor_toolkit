function record = build_case_record_from_checkpoint(store,specification)
%BUILD_CASE_RECORD_FROM_CHECKPOINT Create one missing compact twin.
path_in = case_store_path(store,specification.case_name);
if ~isfile(path_in)
    error('fa:MissingCheckpointCase','Missing checkpoint case: %s',specification.case_name);
end
try
    data = load(path_in,'case_result','saved_case_name','case_provenance');
catch ME
    error('fa:UnreadableCheckpoint', ...
        'Cannot read checkpoint %s: %s',path_in,ME.message);
end
if ~isfield(data,'saved_case_name') || ...
        ~strcmp(data.saved_case_name,char(string(specification.case_name))) || ...
        ~isfield(data,'case_provenance') || ~isfield(data,'case_result')
    error('fa:UnsupportedCheckpoint', ...
        'Checkpoint is incomplete or unsupported: %s',path_in);
end
assert_case_provenance_compatible( ...
    data.case_provenance,specification.provenance,path_in);
validate_case_result_identity(data.case_result,specification,path_in);
record = case_record_from_result(data.case_result);
case_record_save(store,specification.case_name,record);
end
