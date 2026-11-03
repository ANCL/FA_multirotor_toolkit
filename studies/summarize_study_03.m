function summary = summarize_study_03()
%SUMMARIZE_STUDY_03 Summarize saved P2/P3 SQP runs without launching optimization.
%
% All four metrics are evaluated for the best feasible design of each
% objective/parameterization pair. An analytical-bound gap is descriptive;
% it is not used to select optimization candidates.
setup_project();
s = study_03_settings();
cases = study_03_cases(s);
root = fileparts(fileparts(mfilename('fullpath')));
output_folder = fullfile(root, 'results', 'study_03');
runs_folder = fullfile(output_folder, 'runs');
tables_folder = fullfile(output_folder, 'tables');
if ~isfolder(tables_folder), mkdir(tables_folder); end

n = height(cases);
status = repmat({'missing'}, n, 1);
objective_value = nan(n, 1);
max_constraint_violation = nan(n, 1);
elapsed_seconds = nan(n, 1);
selected_solver = repmat({''}, n, 1);
for k = 1:n
    file = fullfile(runs_folder, cases.file_name{k});
    if ~isfile(file), continue; end
    stored = load(file, 'result');
    if ~isfield(stored, 'result') || ~isfield(stored.result, 'sqp')
        error('fa:Study03SolverMismatch', 'Expected SQP result: %s', file);
    end
    r = stored.result;
    if ~strcmp(r.parameterization, cases.parameterization{k}) || ...
            ~strcmp(r.objective, cases.objective{k}) || r.seed ~= cases.seed(k)
        error('fa:Study03ResultMismatch', ...
            'Saved case does not match the expected identity: %s', file);
    end
    status{k} = 'infeasible';
    if r.valid
        status{k} = 'feasible';
        objective_value(k) = r.objective_value;
    end
    max_constraint_violation(k) = r.maximum_constraint_violation;
    elapsed_seconds(k) = r.elapsed_seconds;
    selected_solver{k} = r.selected_solver;
end
runs = table(cases.parameterization, cases.objective, cases.repeat, ...
    cases.seed, cases.file_name, status, objective_value, ...
    max_constraint_violation, elapsed_seconds, selected_solver, ...
    'VariableNames', {'parameterization', 'objective', 'repeat', 'seed', ...
    'file_name', 'status', 'objective_value', 'max_constraint_violation', ...
    'elapsed_seconds', 'selected_solver'});
writetable(runs, fullfile(tables_folder, 'optimization_runs.csv'));

bounds = struct('r_F0', sqrt(2/3), 'sigma_min', sqrt(2), ...
    'condition_number', 1, 'hover_effort', 1/6);
m = numel(s.parameterizations) * numel(s.objectives);
parameterization = cell(m, 1);
objective = cell(m, 1);
feasible_runs = zeros(m, 1);
best_value = nan(m, 1);
analytical_bound = nan(m, 1);
bound_gap = nan(m, 1);
relative_gap_percent = nan(m, 1);
r_F0 = nan(m, 1);
sigma_min = nan(m, 1);
condition_number = nan(m, 1);
hover_effort = nan(m, 1);
max_violation = nan(m, 1);
selected_repeat = nan(m, 1);
selected_file = repmat({''}, m, 1);
selected = struct('parameterization', {}, 'objective', {}, 'repeat', {}, ...
    'file_name', {}, 'design_variables', {}, 'geometry', {}, 'metrics', {});

row = 0;
for p = 1:numel(s.parameterizations)
    for j = 1:numel(s.objectives)
        row = row + 1;
        family = s.parameterizations{p};
        name = s.objectives{j};
        parameterization{row} = family;
        objective{row} = name;
        analytical_bound(row) = bounds.(name);
        eligible = find(strcmp(runs.parameterization, family) & ...
            strcmp(runs.objective, name) & strcmp(runs.status, 'feasible'));
        feasible_runs(row) = numel(eligible);
        if isempty(eligible), continue; end

        values = runs.objective_value(eligible);
        if ismember(name, {'r_F0', 'sigma_min'})
            [best_value(row), index] = max(values);
            bound_gap(row) = analytical_bound(row) - best_value(row);
        else
            [best_value(row), index] = min(values);
            bound_gap(row) = best_value(row) - analytical_bound(row);
        end
        relative_gap_percent(row) = 100 * bound_gap(row) / analytical_bound(row);
        k = eligible(index);
        selected_repeat(row) = cases.repeat(k);
        selected_file{row} = cases.file_name{k};
        max_violation(row) = runs.max_constraint_violation(k);
        stored = load(fullfile(runs_folder, selected_file{row}), 'result');
        result = stored.result;
        metrics = evaluate_design(result.geometry, result.model, result.numerics);
        if ~metrics.valid
            error('fa:Study03RecheckFailed', ...
                'Selected design failed metric re-evaluation: %s', selected_file{row});
        end
        r_F0(row) = metrics.r_F0;
        sigma_min(row) = metrics.sigma_min;
        condition_number(row) = metrics.condition_number;
        hover_effort(row) = metrics.hover_effort;
        selected(end+1) = struct('parameterization', family, ... %#ok<AGROW>
            'objective', name, 'repeat', cases.repeat(k), ...
            'file_name', selected_file{row}, ...
            'design_variables', result.design_variables, ...
            'geometry', result.geometry, 'metrics', metrics);
    end
end

comparison = table(parameterization, objective, feasible_runs, ...
    best_value, analytical_bound, bound_gap, relative_gap_percent, ...
    r_F0, sigma_min, condition_number, hover_effort, max_violation, ...
    selected_repeat, selected_file);
writetable(comparison, fullfile(tables_folder, 'parameterization_comparison.csv'));
save(fullfile(output_folder, 'selected_designs.mat'), 'selected');
summary = struct('output_folder', output_folder, 'runs', runs, ...
    'comparison', comparison, 'selected', selected);

fprintf('\nSTUDY 03 SQP SUMMARY | %d/%d saved | %d feasible\n', ...
    sum(~strcmp(runs.status, 'missing')), n, ...
    sum(strcmp(runs.status, 'feasible')));
for k = 1:height(comparison)
    if comparison.feasible_runs(k)
        fprintf('  %-3s %-17s %.10g | gap %.5g%% | %d feasible\n', ...
            upper(comparison.parameterization{k}), comparison.objective{k}, ...
            comparison.best_value(k), comparison.relative_gap_percent(k), ...
            comparison.feasible_runs(k));
    else
        fprintf('  %-3s %-17s no feasible result yet\n', ...
            upper(comparison.parameterization{k}), comparison.objective{k});
    end
end
fprintf('Tables: %s\n', tables_folder);
end
