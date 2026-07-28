function assert_case_provenance_compatible(actual,expected,path_in)
%ASSERT_CASE_PROVENANCE_COMPATIBLE Verify one checkpoint/twin provenance.
if nargin < 3 || isempty(path_in), path_in = '<in-memory case>'; end
if ~isstruct(expected) || ~isfield(expected,'kind') || ~isfield(expected,'case_name')
    error('fa:InvalidExpectedCaseProvenance', ...
        'Expected case provenance is incomplete for %s.',path_in);
end
if ~isstruct(actual) || ~isfield(actual,'schema_version') || actual.schema_version ~= 2
    error('fa:UnsupportedCheckpoint', ...
        ['Checkpoint has unsupported provenance: %s\n' ...
         'Delete only this checkpoint and rerun case %s.'], ...
        path_in,expected.case_name);
end
fields = case_component_fields(expected.kind);
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
