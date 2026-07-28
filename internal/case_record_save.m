function case_record_save(store,case_name,case_record)
%CASE_RECORD_SAVE Atomically save one compact checkpoint twin.
if ~isfield(case_record,'case_provenance') || ...
        ~isfield(case_record.case_provenance,'case_hash')
    error('fa:MissingCaseProvenance', ...
        'Cannot save compact record without provenance: %s',case_name);
end
path_out = case_record_path(store,case_name);
temporary = [path_out '.tmp'];
saved_case_name = char(string(case_name)); %#ok<NASGU>
case_provenance = case_record.case_provenance; %#ok<NASGU>
record_schema_version = 1; %#ok<NASGU>
saved_at = datetime('now'); %#ok<NASGU>
save(temporary,'case_record','saved_case_name','case_provenance', ...
    'record_schema_version','saved_at','-v7');
movefile(temporary,path_out,'f');
end
