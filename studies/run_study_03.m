function summary = run_study_03()
%RUN_STUDY_03 Optimize P2/P3 with the existing multistart SQP solver.
% Separate SQP results from any previously generated legacy GA runs.
% Finished SQP cases are reused; no Study 02 files are accessed.
setup_project();
s = study_03_settings();
[optimizer, solver_label, solver_key] = select_optimizer(s.solver);
saved_solver_field = 'sqp';
if strcmp(solver_key,'ga_patternsearch')
    saved_solver_field = 'ga';
end
if exist('fmincon', 'file') ~= 2
    error('fa:Study03Fmincon', 'Study 03 requires fmincon (Optimization Toolbox).');
end
model = default_model();
numerics = default_numerics();
cases = study_03_cases(s);
root = fileparts(fileparts(mfilename('fullpath')));
runs_folder = fullfile(root, 'results', 'study_03', 'runs');
if ~isfolder(runs_folder), mkdir(runs_folder); end

jobs = repmat(struct('problem', [], 'file', '', 'seed', 0, ...
    'label', '', 'optimizer', []), height(cases), 1);
for k = 1:height(cases)
    family = cases.parameterization{k};
    objective = cases.objective{k};
    jobs(k).problem = make_design_problem(family, objective, '', model);
    jobs(k).file = fullfile(runs_folder, cases.file_name{k});
    jobs(k).seed = cases.seed(k);
    jobs(k).label = sprintf('%s / %s / repeat %02d', ...
        upper(family), objective, cases.repeat(k));
    jobs(k).optimizer = optimizer;

    % Batch restart checks file existence only: reject any incompatible
    % saved result before it could be silently skipped.
    if isfile(jobs(k).file)
        saved = load(jobs(k).file, 'result');
        if ~isfield(saved, 'result') || ~isstruct(saved.result)
            error('fa:Study03SavedResult', 'Invalid saved run: %s', jobs(k).file);
        end
        r = saved.result;
        if ~isfield(r, saved_solver_field) || ~isfield(r, 'seed') || ...
                ~isfield(r, 'parameterization') || ~isfield(r, 'objective') || ...
                r.seed ~= jobs(k).seed || ...
                ~strcmp(r.parameterization, family) || ...
                ~strcmp(r.objective, objective)
            error('fa:Study03SavedResult', ...
                'Saved file is not the expected SQP case: %s', jobs(k).file);
        end
    end
end

fprintf('\nSTUDY 03 | P2/P3 | %d independent randomized SQP cases\n', numel(jobs));
fprintf('%d starts per case | %d iteration / %d evaluation limits per start\n', ...
    s.sqp.starts, s.sqp.max_iterations, s.sqp.max_function_evaluations);
fprintf('SQP outputs: %s\n', runs_folder);
run_optimization_batch(jobs, model, numerics, s);
summary = summarize_study_03();
end
