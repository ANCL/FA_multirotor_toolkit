function output = run_cheap_tests()
%RUN_CHEAP_TESTS Test the numerical plans and scientific data contracts.
% Test utilities are loaded only while this runner is executing.
root = setup_project();
test_folder = fullfile(root,'tests');
previous_path = path;
path_cleanup = onCleanup(@() path(previous_path)); %#ok<NASGU>
addpath(test_folder);
output = struct();
output.architecture = run_architecture_tests();
output.sensitivity_plan = run_sensitivity_plan_tests();
output.custom_workflows = run_custom_workflow_tests();
output.stage_data_contract = run_stage_data_contract_tests();
output.checkpoint_records = run_checkpoint_record_tests();
fprintf('CHEAP TESTS COMPLETED\n');
end
