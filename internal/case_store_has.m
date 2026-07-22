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
compare_case_provenance(data.case_provenance,specification.provenance,path_in);
yes = true;
end

function compare_case_provenance(actual,expected,path_in)
fields = case_component_fields(expected.kind);
if ~isfield(actual,'schema_version') || actual.schema_version ~= 2
    error('fa:UnsupportedCheckpoint', ...
        ['Checkpoint has unsupported provenance: %s\n' ...
         'Delete only this checkpoint and rerun case %s.'], ...
        path_in,expected.case_name);
end
for k = 1:numel(fields)
    name = fields{k};
    if ~isfield(actual,name) || ...
            ~strcmp(char(string(actual.(name))),char(string(expected.(name))))
        error('fa:CheckpointProvenanceMismatch', ...
            ['Case "%s" is incompatible in component "%s": %s\n' ...
             'Delete only this checkpoint and rerun this case.'], ...
            expected.case_name,name,path_in);
    end
end
end

function fields = case_component_fields(kind)
switch char(string(kind))
    case 'optimization'
        fields = {'kind','core_hash','problem_hash','parameters_hash', ...
            'solver_hash','seed_hash','context_hash','case_hash'};
    case 'robustness'
        fields = {'kind','core_hash','source_hash','specification_hash','design_hash', ...
            'parameters_hash','solver_hash','seed_hash','case_hash'};
    otherwise
        error('fa:UnknownCaseProvenanceKind', ...
            'Unknown case provenance kind: %s',kind);
end
end
