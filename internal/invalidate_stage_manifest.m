function invalidate_stage_manifest(stage_folder)
%INVALIDATE_STAGE_MANIFEST Mark prior stage products incomplete before rebuild.
% A completed manifest is written only after every canonical stage artifact
% has been regenerated and validated. Removing it first prevents reporting
% from accepting a mixed or interrupted set of products from an earlier run.
path_out = fullfile(stage_folder,'stage_manifest.mat');
if isfile(path_out)
    delete(path_out);
end
end
