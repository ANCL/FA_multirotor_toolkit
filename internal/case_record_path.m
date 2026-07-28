function path_out = case_record_path(store,case_name)
%CASE_RECORD_PATH Return the compact twin path for one checkpoint case.
name = char(string(case_name));
if isempty(name) || isempty(regexp(name,'^[A-Za-z0-9_\-\.]+$','once'))
    error('fa:InvalidCaseName','Unsafe checkpoint case name: %s',name);
end
if ~isfield(store,'record_folder') || isempty(store.record_folder)
    error('fa:MissingCaseRecordStore','Case store has no compact-record folder.');
end
path_out = fullfile(store.record_folder,[name '.mat']);
end
