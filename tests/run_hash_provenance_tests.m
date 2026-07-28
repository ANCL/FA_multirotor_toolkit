function results = run_hash_provenance_tests()
%RUN_HASH_PROVENANCE_TESTS Cheap isolation tests; no optimization is run.
root = setup_project();
[parameters,solver] = study_settings();
checks = strings(0,1);

%% Plotting changes do not affect numerical hashes.
temp_root = make_hash_fixture(root);
cleanup = onCleanup(@() remove_fixture(temp_root)); %#ok<NASGU>
base_core = numerical_core_hash(temp_root);
base_design_source = study_source_hash('design_comparison',temp_root);
plot_file = fullfile(temp_root,'core','plotting','hash_test_plot_only.m');
ensure_folder(fileparts(plot_file));
write_text(plot_file,"function hash_test_plot_only()"+newline+"end"+newline);
assert(strcmp(base_core,numerical_core_hash(temp_root)), ...
    'Plotting changed the shared numerical-core hash.');
assert(strcmp(base_design_source, ...
    study_source_hash('design_comparison',temp_root)), ...
    'Plotting changed a numerical study source hash.');
checks(end+1) = "plotting_isolated";

%% Adding a task-emphasis point affects sensitivity only.
changed = parameters;

rho_values = sort(unique( ...
    parameters.sensitivity.task_emphasis_values(:).'));

% Insert a point midway across the largest existing gap. This guarantees
% that the test changes the sensitivity grid without depending on any
% particular configured sample value.
rho_gaps = diff(rho_values);
[~,largest_gap_index] = max(rho_gaps);
added_rho = 0.5*( ...
    rho_values(largest_gap_index) + ...
    rho_values(largest_gap_index+1));

changed.sensitivity.task_emphasis_values = ...
    sort([rho_values,added_rho]);

base_design = study_provenance('design_comparison',parameters,solver);
new_design = study_provenance('design_comparison',changed,solver);
base_authority = study_provenance('authority_effort',parameters,solver);
new_authority = study_provenance('authority_effort',changed,solver);
base_robustness = study_provenance('robustness',parameters,solver);
new_robustness = study_provenance('robustness',changed,solver);
base_sensitivity = study_provenance('sensitivity',parameters,solver);
new_sensitivity = study_provenance('sensitivity',changed,solver);
assert(strcmp(base_design.study_hash,new_design.study_hash));
assert(strcmp(base_authority.study_hash,new_authority.study_hash));
assert(strcmp(base_robustness.study_hash,new_robustness.study_hash));
assert(~strcmp(base_sensitivity.study_hash,new_sensitivity.study_hash));
checks(end+1) = "sensitivity_study_isolated";

%% Existing sensitivity case hashes survive an added grid point.
base_case = sensitivity_example_case(parameters,solver,0.06);
changed_case = sensitivity_example_case(changed,solver,0.06);
assert(strcmp(base_case.provenance.case_hash, ...
    changed_case.provenance.case_hash), ...
    'An unrelated added sensitivity point changed an existing case hash.');
checks(end+1) = "existing_sensitivity_case_reused";

%% Solver-budget changes alter affected optimization case hashes.
solver_changed = solver;
solver_changed.ga.max_generations = solver.ga.max_generations+1;
changed_budget_case = finalize_optimization_cases(base_case,solver_changed);
assert(~strcmp(base_case.provenance.case_hash, ...
    changed_budget_case.provenance.case_hash), ...
    'Solver-budget change did not alter the optimization case hash.');
assert(~strcmp(base_case.provenance.solver_hash, ...
    changed_budget_case.provenance.solver_hash));
checks(end+1) = "solver_budget_changes_case";

%% Shared allocation-source changes affect all dependent case types.
allocation_file = fullfile(temp_root,'core','model','allocation_matrix.m');
text = fileread(allocation_file);
old_line = 'A_tau = cross(p,u,1) + u.*reaction_scale;';
new_line = 'A_tau = cross(p,u,1) + u.*reaction_scale + 1e-12*u;';
assert(contains(text,old_line),'Allocation test fixture changed unexpectedly.');
write_text(allocation_file,strrep(text,old_line,new_line));
changed_core = numerical_core_hash(temp_root);
assert(~strcmp(base_core,changed_core));
design_case_a = design_example_case(parameters,solver,base_core);
design_case_b = design_example_case(parameters,solver,changed_core);
sensitivity_case_a = sensitivity_example_case(parameters,solver,0.06,base_core);
sensitivity_case_b = sensitivity_example_case(parameters,solver,0.06,changed_core);
robustness_a = robustness_example_case(parameters,solver,base_core);
robustness_b = robustness_example_case(parameters,solver,changed_core);
assert(~strcmp(design_case_a.provenance.case_hash, ...
    design_case_b.provenance.case_hash));
assert(~strcmp(sensitivity_case_a.provenance.case_hash, ...
    sensitivity_case_b.provenance.case_hash));
assert(~strcmp(robustness_a.provenance.case_hash, ...
    robustness_b.provenance.case_hash));
checks(end+1) = "shared_core_changes_dependents";

%% Robustness settings remain isolated.
robustness_changed = parameters;
robustness_changed.robustness.trials_per_level = ...
    parameters.robustness.trials_per_level+1;
assert(strcmp(study_provenance('design_comparison',parameters,solver).study_hash, ...
    study_provenance('design_comparison',robustness_changed,solver).study_hash));
assert(strcmp(study_provenance('sensitivity',parameters,solver).study_hash, ...
    study_provenance('sensitivity',robustness_changed,solver).study_hash));
assert(~strcmp(study_provenance('robustness',parameters,solver).study_hash, ...
    study_provenance('robustness',robustness_changed,solver).study_hash));
checks(end+1) = "robustness_settings_isolated";

%% No source path archives the complete active results tree.
files = dir(fullfile(root,'**','*.m'));
for k = 1:numel(files)
    path_in = fullfile(files(k).folder,files(k).name);
    text = fileread(path_in);
    token_move = ['movefile(' 'current_folder'];
    token_archive = ['fullfile(results_root,' char(39) 'archive' char(39) ')'];
    token_message = ['Archived incompatible ' 'previous results'];
    forbidden = contains(text,token_move) || contains(text,token_archive) || ...
        contains(text,token_message);
    assert(~forbidden,'Global results/current archive behavior remains in %s.',path_in);
end
checks(end+1) = "no_global_results_archive";

checks = checks(:);
results = table(checks,true(numel(checks),1), ...
    'VariableNames',{'test','passed'});
disp(results);
fprintf('HASH/PROVENANCE TESTS PASSED: %d/%d\n',height(results),height(results));
end

function specification = design_example_case(parameters,solver,core_hash)
problem = make_design_problem('rotorwise','r_F0',1,parameters);
seeds = initial_rotorwise_seeds(parameters,solver);
problem.initial_designs = seeds{1};
problem.case_name = 'hash_test_design';
specification = make_optimization_case(1,'',problem,parameters, ...
    stable_seed(solver.master_seed,problem.case_name),struct());
specification = finalize_optimization_cases(specification,solver,core_hash);
end

function specification = sensitivity_example_case(parameters,solver,kappa,core_hash)
if nargin < 4, core_hash = numerical_core_hash(); end
case_parameters = parameters;
case_parameters.kappa = kappa;
problem = make_design_problem('rotorwise','q_star',1,case_parameters);
seeds = initial_rotorwise_seeds(parameters,solver);
problem.initial_designs = seeds{1};
problem.case_name = sprintf('hash_test_kappa_%g',kappa);
specification = make_optimization_case(1,'',problem,case_parameters, ...
    stable_seed(solver.master_seed,problem.case_name), ...
    struct('sensitivity_case',sprintf('kappa_%g',kappa)));
specification = finalize_optimization_cases(specification,solver,core_hash);
end

function specification = robustness_example_case(parameters,solver,core_hash)
geometry = planar_shared_geometry([0;0],parameters);
design = struct('name','hash_test_design','geometry',geometry);
specification = struct('index',1,'case_name','hash_test_robustness', ...
    'description','','design_index',1,'type','capacity','level_index',1, ...
    'level',0.02,'trial_numbers',1:3,'provenance',struct());
specification = finalize_robustness_cases( ...
    specification,design,parameters,solver,core_hash);
end

function temp_root = make_hash_fixture(root)
temp_root = tempname;
mkdir(temp_root);
copyfile(fullfile(root,'core'),fullfile(temp_root,'core'));
copyfile(fullfile(root,'study'),fullfile(temp_root,'study'));
mkdir(fullfile(temp_root,'internal'));
needed = {'design_comparison_case_plan.m','authority_effort_threshold_plan.m', ...
    'authority_effort_case_names.m','sensitivity_case_plan.m', ...
    'sensitivity_study_plan.m','task_emphasis_diagonal.m', ...
    'sensitivity_case_id.m','numeric_case_token.m', ...
    'robustness_case_plan.m','execute_robustness_case.m'};
for k = 1:numel(needed)
    copyfile(fullfile(root,'internal',needed{k}), ...
        fullfile(temp_root,'internal',needed{k}));
end
copyfile(fullfile(root,'run_preflight.m'),fullfile(temp_root,'run_preflight.m'));
end

function remove_fixture(folder)
if isfolder(folder), rmdir(folder,'s'); end
end

function write_text(path_out,text)
file = fopen(path_out,'w');
if file < 0, error('fa:TestWriteFailed','Cannot write %s',path_out); end
cleanup = onCleanup(@() fclose(file)); %#ok<NASGU>
fwrite(file,char(text),'char');
end
