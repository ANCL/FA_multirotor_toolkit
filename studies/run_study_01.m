function summary = run_study_01()
%RUN_STUDY_01 Optimize unrestricted P1 using the configured local solver.
%
% Edit config/study_01_settings.m, then call run_study_01(). Each completed
% case is saved separately and reused on subsequent calls.

setup_project();
s = study_01_settings();
model = default_model();
numerics = default_numerics();
cases = study_01_cases(s);
[optimizer, solver_label, solver_key] = select_optimizer(s.solver);
if strcmp(solver_key,'ga_patternsearch')
    legacy = default_optimization_settings('p1');
    s.ga = legacy.ga;
    s.patternsearch = legacy.patternsearch;
    s.local_refinements = legacy.local_refinements;
    s.local_start_min_distance = legacy.local_start_min_distance;
    s.use_parallel = false;
end

root = fileparts(fileparts(mfilename('fullpath')));
runs_folder = fullfile(root, 'results', 'study_01', 'runs');
if ~isfolder(runs_folder), mkdir(runs_folder); end

jobs = repmat(struct('problem', [], 'file', '', 'seed', 0, ...
    'label', '', 'optimizer', []), height(cases), 1);
for k = 1:height(cases)
    objective = cases.objective{k};
    group = cases.normalization_group{k};
    jobs(k).problem = make_design_problem('p1', objective, group, model);
    jobs(k).file = fullfile(runs_folder, cases.file_name{k});
    jobs(k).seed = cases.seed(k);
    jobs(k).optimizer = optimizer;
    jobs(k).label = sprintf('%s / %s', objective, group);
end

fprintf('\nSTUDY 01 | P1 | %d cases | %s\n', numel(jobs), solver_label);
fprintf('28 P1 variables | two normalization groups | %d SQP starts per case\n', ...
    s.sqp.starts);
run_optimization_batch(jobs, model, numerics, s);
summary = summarize_study_01();
end
