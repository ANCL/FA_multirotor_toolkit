function [yes,provenance,reason,manifest] = stage_is_complete( ...
    stage_folder,study_name,parameters,solver,upstream)
%STAGE_IS_COMPLETE Cheap completed-stage fast path for numerical runners.
if nargin < 5 || isempty(upstream), upstream = struct(); end
yes = false;
provenance = struct();
manifest = struct();
reason = "manifest missing";
manifest_path = fullfile(stage_folder,'stage_manifest.mat');
if ~isfile(manifest_path), return; end
try
    provenance = assert_completed_stage( ...
        manifest_path,study_name,parameters,solver,upstream);
    data = load(manifest_path,'manifest');
    manifest = data.manifest;
    yes = true;
    reason = "complete and compatible";
catch ME
    reason = string(ME.message);
end
end
