function provenance = assert_compatible_result( ...
    path_in,study_name,parameters,solver,upstream)
%ASSERT_COMPATIBLE_RESULT Verify one study result by isolated components.
if nargin < 5 || isempty(upstream), upstream = struct(); end
if ~isfile(path_in)
    error('fa:MissingPrerequisite','Required result file is missing: %s',path_in);
end
data = load(path_in,'provenance');
if ~isfield(data,'provenance')
    error('fa:MissingResultProvenance', ...
        ['Result file lacks study provenance: %s\n' ...
         'Regenerate only the affected study.'],path_in);
end
expected = study_provenance(study_name,parameters,solver,struct(),upstream);
fields = {'core_hash','source_hash','settings_hash','data_contract_hash'};
if ~(isstruct(upstream) && isempty(fieldnames(upstream)))
    fields{end+1} = 'upstream_hash';
end
compare_provenance(data.provenance,expected, ...
    sprintf('Study "%s" result',study_name),path_in,fields);
provenance = data.provenance;
end
