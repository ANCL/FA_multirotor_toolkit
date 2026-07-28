function path_out = write_stage_manifest(stage_folder,provenance,artifacts,counts)
%WRITE_STAGE_MANIFEST Record completion of one numerical stage.
% Canonical MAT artifacts must already exist and carry the exact same study
% provenance. CSV/TeX sidecars are deliberately not part of the numerical
% completion contract because they are derived representations of MAT data.
if nargin < 4 || isempty(counts), counts = struct(); end
artifacts = string(artifacts(:));
if isempty(artifacts)
    error('fa:EmptyStageManifest','A completed stage must declare artifacts.');
end
if numel(unique(artifacts)) ~= numel(artifacts)
    error('fa:DuplicateStageArtifact','Stage manifest artifacts must be unique.');
end
for k = 1:numel(artifacts)
    artifact = char(artifacts(k));
    if ~endsWith(artifact,'.mat') || contains(artifact,filesep) || ...
            contains(artifact,'/') || contains(artifact,char(92))
        error('fa:InvalidStageArtifact', ...
            'Stage artifacts must be MAT file names in the stage folder: %s',artifact);
    end
    path_in = fullfile(stage_folder,artifact);
    if ~isfile(path_in)
        error('fa:MissingStageArtifact', ...
            'Cannot complete stage; artifact is missing: %s',path_in);
    end
    data = load(path_in,'provenance');
    if ~isfield(data,'provenance') || ~isstruct(data.provenance) || ...
            ~isfield(data.provenance,'study_hash') || ...
            ~strcmp(char(string(data.provenance.study_hash)), ...
                char(string(provenance.study_hash)))
        error('fa:StageArtifactProvenance', ...
            'Stage artifact does not match the stage provenance: %s',path_in);
    end
end
manifest = struct();
manifest.schema_version = 1;
manifest.status = 'complete';
manifest.study_name = char(string(provenance.study_name));
manifest.study_hash = char(string(provenance.study_hash));
manifest.data_contract_hash = char(string(provenance.data_contract_hash));
manifest.completed_at = datetime('now');
manifest.artifacts = artifacts;
manifest.counts = counts;
path_out = fullfile(stage_folder,'stage_manifest.mat');
temporary = [path_out '.tmp'];
save(temporary,'manifest','provenance','-v7');
movefile(temporary,path_out,'f');
end
