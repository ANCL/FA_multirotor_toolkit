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

% P1 and P1-only Pareto results predate the expanded P2/P3 bounds.
% Accept their original provenance only when the stored settings hash
% matches the exact historical scientific settings.
if ismember(char(string(study_name)), ...
        {'unrestricted_optimization','authority_effort_p1'}) && ...
        isfield(data.provenance,'settings_hash') && ...
        ~strcmp(char(string(data.provenance.settings_hash)), ...
                char(string(expected.settings_hash)))
    legacy_parameters = parameters;
    legacy_parameters.geometry.spatial_ranges = [ ...
        0 pi/3; -pi/6 pi/6; repmat([-pi/3 pi/3],4,1)];
    legacy_parameters.geometry.planar_ranges = ...
        repmat([-pi/3 pi/3],2,1);
    legacy_expected = study_provenance( ...
        study_name,legacy_parameters,solver,struct(),upstream);
    if strcmp(char(string(data.provenance.settings_hash)), ...
              char(string(legacy_expected.settings_hash)))
        expected = legacy_expected;
    end
end

fields = {'core_hash','source_hash','settings_hash','data_contract_hash'};
if ~(isstruct(upstream) && isempty(fieldnames(upstream)))
    fields{end+1} = 'upstream_hash';
end
compare_provenance(data.provenance,expected, ...
    sprintf('Study "%s" result',study_name),path_in,fields);
provenance = data.provenance;
end
