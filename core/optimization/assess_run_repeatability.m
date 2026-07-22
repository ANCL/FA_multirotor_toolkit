function summary = assess_run_repeatability(results)
%ASSESS_RUN_REPEATABILITY Descriptive repeated-search evidence by problem.
% For rotor-wise geometry, each independent-run value is the best valid
% objective across all six normalization cases. No binary convergence claim is produced.
if isempty(results), summary = table(); return; end
group = strings(numel(results),1);
replicate = nan(numel(results),1);
for k = 1:numel(results)
    group(k) = string(results(k).parameterization)+"__"+ ...
        string(results(k).objective_name);
    token = regexp(results(k).case_name,'(?:run_|_r)(\d+)$','tokens','once');
    if isempty(token)
        token = regexp(results(k).case_name,'run_(\d+)','tokens','once');
    end
    if ~isempty(token), replicate(k) = str2double(token{1}); end
end
groups = unique(group,'stable');
rows = repmat(row_template(),numel(groups),1);
for g = 1:numel(groups)
    group_mask = group == groups(g);
    attempted_ids = unique(replicate(group_mask & isfinite(replicate)));
    valid_ids = unique(replicate(group_mask & isfinite(replicate) & [results.valid].'));
    values = nan(numel(valid_ids),1);
    for r = 1:numel(valid_ids)
        candidates = results(group_mask & replicate == valid_ids(r) & [results.valid].');
        [~,best_index] = min([candidates.objective_value]);
        values(r) = scientific_value(candidates(best_index));
    end
    parts = split(groups(g),'__');
    rows(g) = make_row(parts(1),parts(2),numel(attempted_ids),numel(valid_ids),values);
end
summary = struct2table(rows);
end

function row = row_template()
row = struct('parameterization',"",'objective',"", ...
    'attempted_independent_runs',0,'valid_independent_runs',0, ...
    'best_objective_value',NaN,'median_objective_value',NaN, ...
    'worst_objective_value',NaN,'absolute_run_spread',NaN, ...
    'relative_run_spread',NaN);
end

function row = make_row(parameterization,objective,attempted,valid,values)
values = values(isfinite(values));
if is_maximized(objective), values = sort(values,'descend'); else, values = sort(values,'ascend'); end
if isempty(values)
    best = NaN; median_value = NaN; worst = NaN; spread = NaN; relative = NaN;
else
    best = values(1); median_value = median(values); worst = values(end);
    spread = abs(worst-best); relative = spread/max(abs(best),eps);
end
row = struct('parameterization',parameterization,'objective',objective, ...
    'attempted_independent_runs',attempted,'valid_independent_runs',valid, ...
    'best_objective_value',best,'median_objective_value',median_value, ...
    'worst_objective_value',worst,'absolute_run_spread',spread, ...
    'relative_run_spread',relative);
end

function value = scientific_value(result)
name = char(string(result.objective_name));
if isstruct(result.metrics) && isfield(result.metrics,name)
    value = result.metrics.(name);
else
    value = result.objective_value;
    if is_maximized(name), value = -value; end
end
end

function yes = is_maximized(objective)
yes = ismember(char(string(objective)),{'r_F0','sigma_min','q_star'});
end
