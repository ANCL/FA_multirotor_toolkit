function path_out = case_store_path(store,case_name)
%CASE_STORE_PATH Return the safe checkpoint file for one case.
name = char(string(case_name));
if isempty(name) || isempty(regexp(name,'^[A-Za-z0-9_\-\.]+$','once'))
    error('fa:InvalidCaseName','Unsafe checkpoint case name: %s',name);
end
path_out = fullfile(store.case_folder,[name '.mat']);
end
