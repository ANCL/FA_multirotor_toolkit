function results = run_custom_workflow_tests()
%RUN_CUSTOM_WORKFLOW_TESTS Check custom-analysis utilities without graphics.
%
% These tests exercise naming, output-path protection, and tabular source-data
% export. They do not run optimization, allocation, convex-hull construction,
% or figure generation.

root = setup_project();
checks = strings(0,1);

%% Case names become stable folder tokens.
token = safe_case_token('  Candidate A / task scale  ');
assert(strcmp(token,'Candidate_A_task_scale'));
checks(end+1) = "case_token";

%% Named folders below results/analyses are permitted.
allowed = fullfile(root,'results','analyses','test_output_guard','case_A');
resolved = validate_analysis_output_folder(root,allowed);
assert(contains(resolved,fullfile('results','analyses','test_output_guard')));
checks(end+1) = "analysis_folder_allowed";

%% Study, publication, source, and shared analysis roots are protected.
protected = { ...
    fullfile(root,'results','current','unsafe'), ...
    fullfile(root,'results','publication','unsafe'), ...
    fullfile(root,'analyses','unsafe'), ...
    fullfile(root,'results','analyses')};
for path_index = 1:numel(protected)
    assert_throws(@() validate_analysis_output_folder( ...
        root,protected{path_index}),'fa:UnsafeAnalysisOutputFolder');
end
checks(end+1) = "protected_folders_blocked";

%% External folders remain available for intentional custom exports.
temp_folder = tempname;
cleanup = onCleanup(@() remove_folder(temp_folder)); %#ok<NASGU>
resolved = validate_analysis_output_folder(root,temp_folder);
assert(~isempty(resolved));
checks(end+1) = "external_folder_allowed";

%% Figure source data retain both MAT and readable CSV forms.
source_data = table((1:3).',[0.1;0.2;0.3], ...
    'VariableNames',{'Index','Value'});
paths = write_figure_source_data(source_data,temp_folder,'source_data_test');
assert(isfile(paths.mat));
assert(isfile(paths.csv));
loaded = load(paths.mat,'source_data');
assert(isequal(loaded.source_data,source_data));
round_trip = readtable(paths.csv);
assert(isequal(round_trip,source_data));
checks(end+1) = "source_data_export";

%% Table bundles serialize vector-valued diagnostic cells safely.
vector_table = table("F_x",-1,1,{[0;1;0]}, ...
    'VariableNames',{'Component','Minimum','Maximum','Allocation'});
table_paths = write_table_bundle(vector_table,temp_folder,'vector_table_test');
assert(isfile(table_paths.mat));
assert(isfile(table_paths.csv));
assert(isfile(table_paths.tex));
csv_text = fileread(table_paths.csv);
assert(contains(csv_text,'[0;1;0]'));
checks(end+1) = "vector_table_export";

results = table(checks(:),true(numel(checks),1), ...
    'VariableNames',{'test','passed'});
disp(results);
fprintf('CUSTOM WORKFLOW TESTS PASSED: %d/%d\n', ...
    height(results),height(results));
end

function assert_throws(action,identifier)
try
    action();
catch ME
    assert(strcmp(ME.identifier,identifier), ...
        'Expected %s but received %s.',identifier,ME.identifier);
    return;
end
error('fa:ExpectedErrorNotThrown', ...
    'Expected error %s was not thrown.',identifier);
end

function remove_folder(folder)
if isfolder(folder)
    rmdir(folder,'s');
end
end
