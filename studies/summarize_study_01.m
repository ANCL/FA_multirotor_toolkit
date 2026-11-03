function summary = summarize_study_01()
%SUMMARIZE_STUDY_01 Summarize saved unrestricted P1 solutions.
%
% Reads existing MAT files only. Never launches an optimization.

setup_project();
s = study_01_settings();
cases = study_01_cases(s);
root = fileparts(fileparts(mfilename('fullpath')));
output_folder = fullfile(root, 'results', 'study_01');
runs_folder = fullfile(output_folder, 'runs');
tables_folder = fullfile(output_folder, 'tables');
if ~isfolder(tables_folder), mkdir(tables_folder); end

run_rows = cell(height(cases), 12);
for k = 1:height(cases)
    name = cases.objective{k};
    group = cases.normalization_group{k};
    status = 'missing';
    value = NaN;
    violation = NaN;
    seconds = NaN;
    selected_solver = '';
    metrics_values = num2cell(nan(1, 4));
    file = fullfile(runs_folder, cases.file_name{k});
    if isfile(file)
        stored = load(file, 'result');
        r = stored.result;
        status = 'infeasible';
        if r.valid
            status = 'feasible';
            value = r.objective_value;
        end
        violation = r.maximum_constraint_violation;
        seconds = r.elapsed_seconds;
        selected_solver = r.selected_solver;
        metrics_values = {r.metrics.r_F0, r.metrics.sigma_min, ...
            r.metrics.condition_number, r.metrics.hover_effort};
    end
    run_rows(k, :) = [{name, group, cases.seed(k), status, value, ...
        violation, seconds, selected_solver}, metrics_values];
end

run_table = cell2table(run_rows, 'VariableNames', { ...
    'objective', 'normalization_group', 'seed', 'status', ...
    'objective_value', 'max_constraint_violation', 'elapsed_seconds', ...
    'selected_solver', 'r_F0', 'sigma_min', 'condition_number', 'hover_effort'});
writetable(run_table, fullfile(tables_folder, 'optimization_runs.csv'));

reference_bounds = struct('r_F0', sqrt(2/3), 'sigma_min', sqrt(2), ...
    'condition_number', 1, 'hover_effort', 1/6);
best_rows = cell(numel(s.objectives), 8);
cross_rows = cell(0, 9);
selected = struct('objective', {}, 'case_id', {}, 'result', {});
for i = 1:numel(s.objectives)
    name = s.objectives{i};
    in_objective = strcmp(run_table.objective, name);
    feasible = find(in_objective & strcmp(run_table.status, 'feasible'));
    group = '';
    best = NaN;
    gap_percent = NaN;
    selected_file = '';
    reference = reference_bounds.(name);
    if ~isempty(feasible)
        values = run_table.objective_value(feasible);
        if ismember(name, {'r_F0', 'sigma_min'})
            [best, best_position] = max(values);
            gap_percent = 100*(reference-best)/reference;
        else
            [best, best_position] = min(values);
            gap_percent = 100*(best-reference)/reference;
        end
        k = feasible(best_position);
        group = run_table.normalization_group{k};
        selected_file = cases.file_name{k};
        stored = load(fullfile(runs_folder, selected_file), 'result');
        result = stored.result;
        selected(end+1) = struct('objective', name, ... %#ok<AGROW>
            'case_id', selected_file, 'result', result);
        metrics = evaluate_design(result.geometry, result.model, result.numerics);
        cross_rows(end+1, :) = {name, group, metrics.valid, ... %#ok<AGROW>
            metrics.r_F0, metrics.sigma_min, metrics.condition_number, ...
            metrics.hover_effort, metrics.constraint_margins.full_actuation, ...
            metrics.constraint_margins.hover};
    end
    best_rows(i, :) = {name, ~isempty(feasible), group, best, reference, ...
        gap_percent, numel(feasible), selected_file};
end

best_table = cell2table(best_rows, 'VariableNames', { ...
    'objective', 'found', 'normalization_group', 'objective_value', ...
    'analytical_bound', 'relative_gap_percent', 'feasible_cases', 'selected_file'});
writetable(best_table, fullfile(tables_folder, 'objective_summary.csv'));

cross_table = cell2table(cross_rows, 'VariableNames', { ...
    'optimized_objective', 'normalization_group', 'valid', 'r_F0', ...
    'sigma_min', 'condition_number', 'hover_effort', ...
    'full_actuation_margin', 'hover_margin'});
writetable(cross_table, fullfile(tables_folder, 'cross_objective.csv'));
save(fullfile(output_folder, 'selected_designs.mat'), 'selected');

summary = struct('output_folder', output_folder, 'runs', run_table, ...
    'best', best_table, 'cross_objective', cross_table, 'selected', selected);
completed = sum(~strcmp(run_table.status, 'missing'));
feasible_count = sum(strcmp(run_table.status, 'feasible'));
fprintf('\nSTUDY 01 SUMMARY | %d/%d completed | %d feasible\n', ...
    completed, height(run_table), feasible_count);
for k = 1:height(best_table)
    name = best_table.objective{k};
    if best_table.found(k)
        fprintf('  %-17s %.12g | %s | bound gap %.5g%%\n', ...
            name, best_table.objective_value(k), ...
            best_table.normalization_group{k}, ...
            best_table.relative_gap_percent(k));
    else
        fprintf('  %-17s no feasible result\n', name);
    end
end
fprintf('Tables: %s\n', tables_folder);
end
