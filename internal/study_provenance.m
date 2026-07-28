function provenance = study_provenance( ...
    study_name,parameters,solver,study_plan,upstream,root)
%STUDY_PROVENANCE Component-wise provenance for one numerical study.
if nargin < 4 || isempty(study_plan), study_plan = struct(); end
if nargin < 5 || isempty(upstream), upstream = struct(); end
if nargin < 6 || isempty(root)
    root = fileparts(fileparts(mfilename('fullpath')));
end
study_name = char(string(study_name));
provenance = struct();
provenance.schema_version = 2;
provenance.study_name = study_name;
provenance.core_hash = numerical_core_hash(root);
provenance.source_hash = study_source_hash(study_name,root);
provenance.settings_hash = settings_hash( ...
    'resolved_study_settings_v2', ...
    resolved_study_settings(study_name,parameters,solver));
provenance.data_contract_hash = stage_data_contract_hash();
provenance.plan_hash = settings_hash('study_plan_v2',study_plan);
provenance.upstream_hash = upstream_provenance_hash(upstream);
provenance.study_hash = settings_hash('study_provenance_v3', ...
    provenance.study_name,provenance.core_hash,provenance.source_hash, ...
    provenance.settings_hash,provenance.data_contract_hash, ...
    provenance.plan_hash,provenance.upstream_hash);
end

function digest = upstream_provenance_hash(upstream)
if isempty(upstream) || (isstruct(upstream) && isempty(fieldnames(upstream)))
    digest = settings_hash('no_upstream_v2');
    return;
end
if isstruct(upstream) && isfield(upstream,'study_hash')
    digest = settings_hash('upstream_v2',upstream.study_name,upstream.study_hash);
elseif iscell(upstream)
    hashes = cell(size(upstream));
    for k = 1:numel(upstream)
        item = upstream{k};
        if ~isstruct(item) || ~isfield(item,'study_hash')
            error('fa:InvalidUpstreamProvenance', ...
                'Every upstream item must contain a study_hash.');
        end
        hashes{k} = {item.study_name,item.study_hash};
    end
    digest = settings_hash('upstream_v2',hashes);
else
    digest = settings_hash('upstream_value_v2',upstream);
end
end
