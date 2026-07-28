function output = make_all_outputs()
%MAKE_ALL_OUTPUTS Regenerate every publication output from completed results.
% This function performs no optimization and never modifies results/current.
root = setup_project();
[parameters,solver] = study_settings();
check_study_settings(parameters,solver);
require_numerical_preflight(root,parameters,solver);
validate_all_reporting_results(root,parameters,solver);

publication = fullfile(root,'results','publication');
if isfolder(publication)
    [ok,message] = rmdir(publication,'s');
    if ~ok
        error('fa:PublicationCleanup', ...
            'Could not reset %s: %s',publication,message);
    end
end
mkdir(publication);
shared_tables = fullfile(publication,'shared','tables');
mkdir(shared_tables);
write_table_bundle(study_conditions_table(parameters,solver), ...
    shared_tables,'study_conditions');
write_output_guide(publication,parameters);

output = struct();
output.objective_designs = make_objective_design_outputs();
output.parameterizations = make_parameterization_outputs();
output.authority_effort = make_authority_effort_outputs();
output.sensitivity = make_sensitivity_outputs();
output.robustness = make_robustness_outputs();
output.shared = struct('root',fullfile(publication,'shared'), ...
    'tables',shared_tables);
write_combined_manifest(publication,parameters,solver,output);
output.root = publication;
fprintf('\nALL PUBLICATION OUTPUTS COMPLETED\n%s\n',publication);
end
