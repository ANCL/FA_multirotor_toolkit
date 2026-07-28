function store = open_case_store(folder,study_name)
%OPEN_CASE_STORE Open one study-local checkpoint and compact-record store.
store.folder = ensure_folder(folder);
store.case_folder = ensure_folder(fullfile(store.folder,'cases'));
store.record_folder = ensure_folder(fullfile(store.folder,'records'));
store.metadata_path = fullfile(store.folder,'metadata.mat');
store.study_name = char(string(study_name));
store.core_hash = numerical_core_hash();
if isfile(store.metadata_path)
    data = load(store.metadata_path,'metadata');
    if ~isfield(data,'metadata') || ~isfield(data.metadata,'schema_version') || ...
            data.metadata.schema_version ~= 2
        error('fa:UnsupportedCaseStore', ...
            ['Case store uses unsupported metadata: %s\n' ...
             'Delete only this study-local checkpoint folder and rerun the ' ...
             'affected study.'],store.folder);
    end
    if ~strcmp(char(string(data.metadata.study_name)),store.study_name)
        error('fa:CaseStoreStudyMismatch', ...
            ['Checkpoint folder belongs to study "%s", not "%s": %s\n' ...
             'Delete or move only this checkpoint folder.'], ...
            data.metadata.study_name,store.study_name,store.folder);
    end
else
    metadata = struct('schema_version',2,'study_name',store.study_name, ...
        'created_at',datetime('now'),'updated_at',datetime('now'), ...
        'matlab_release',version('-release'),'toolbox_versions',ver); %#ok<NASGU>
    atomic_save(store.metadata_path,'metadata',metadata);
end
end

function atomic_save(path_out,variable_name,value)
temporary = [path_out '.tmp'];
payload = struct(); payload.(variable_name) = value;
save(temporary,'-struct','payload','-v7');
movefile(temporary,path_out,'f');
end
