function case_store_save(store,case_name,case_result)
%CASE_STORE_SAVE Atomically checkpoint one completed case.
if ~isfield(case_result,'case_provenance') || ...
        ~isfield(case_result.case_provenance,'case_hash')
    error('fa:MissingCaseProvenance', ...
        'Cannot checkpoint case without per-case provenance: %s',case_name);
end
path_out = case_store_path(store,case_name);
temporary = [path_out '.tmp'];
saved_case_name = char(string(case_name)); %#ok<NASGU>
case_provenance = case_result.case_provenance; %#ok<NASGU>
saved_at = datetime('now'); %#ok<NASGU>
save(temporary,'case_result','saved_case_name','case_provenance','saved_at','-v7');
movefile(temporary,path_out,'f');
end
