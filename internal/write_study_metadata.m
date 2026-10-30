function path_out = write_study_metadata(stage_folder,study_name, ...
    parameterization,parameters,solver,counts,origin)
%WRITE_STUDY_METADATA Human-readable, non-invalidation study description.
if nargin < 7 || isempty(origin), origin = 'numerical_run'; end
metadata = struct();
metadata.schema_version = 1;
metadata.study = char(string(study_name));
metadata.parameterization = char(string(parameterization));
metadata.study_id = parameters.study_id;
metadata.created_at = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
metadata.matlab_release = version('-release');
metadata.origin = char(string(origin));
metadata.compatibility_policy = ...
    'Scientific settings and case inputs only; source file edits do not invalidate results.';
metadata.numerical_protocol = 'manual-numerical-protocol-v1';
metadata.objectives = parameters.objectives;
metadata.counts = counts;
metadata.scientific_settings = parameters;
metadata.solver_settings = solver;
path_out = fullfile(stage_folder,'study_metadata.json');
write_json_file(path_out,metadata);
end
