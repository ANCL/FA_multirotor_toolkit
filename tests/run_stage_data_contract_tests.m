function output = run_stage_data_contract_tests()
%RUN_STAGE_DATA_CONTRACT_TESTS Cheap regressions for stage product integrity.
root = setup_project(); %#ok<NASGU>
[parameters,solver] = study_settings();
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() remove_test_folder(folder)); %#ok<NASGU>

provenance = study_provenance( ...
    'design_comparison',parameters,solver,struct(),struct());
T = table((1:2).','VariableNames',{'value'});
paths = write_table_bundle(T,folder,'example',provenance);
written = load(paths.mat,'table_data','dataset_metadata','provenance');
assert(istable(written.table_data) && height(written.table_data) == 2);
assert(written.dataset_metadata.schema_version == 1);
assert(strcmp(written.provenance.study_hash,provenance.study_hash));

manifest_path = write_stage_manifest(folder,provenance,"example.mat", ...
    struct('rows',height(T)));
validated = assert_completed_stage(manifest_path,'design_comparison', ...
    parameters,solver);
assert(strcmp(validated.study_hash,provenance.study_hash));
manifest_data = load(manifest_path,'manifest');
assert(strcmp(manifest_data.manifest.data_contract_hash, ...
    provenance.data_contract_hash));

invalidate_stage_manifest(folder);
assert(~isfile(manifest_path));

output = struct('table_self_describing',true, ...
    'manifest_validated',true,'manifest_invalidation',true);
fprintf('STAGE DATA CONTRACT TESTS PASSED\n');
end

function remove_test_folder(folder)
if isfolder(folder)
    rmdir(folder,'s');
end
end
