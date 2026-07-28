function output = run_cheap_tests()
%RUN_CHEAP_TESTS Run static numerical-plan and provenance regressions.
setup_project();
output = struct();
output.hash_provenance = run_hash_provenance_tests();
output.sensitivity_plan = run_sensitivity_plan_tests();
output.custom_workflows = run_custom_workflow_tests();
output.stage_data_contract = run_stage_data_contract_tests();
output.checkpoint_records = run_checkpoint_record_tests();
fprintf('CHEAP TESTS COMPLETED\n');
end
