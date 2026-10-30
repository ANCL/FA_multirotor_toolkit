function [all_runs,selected] = combine_authority_effort_results(p1_runs,~,p2_runs,~,tolerance)
%COMBINE_AUTHORITY_EFFORT_RESULTS Compute joint Pareto front from ALL runs.
% The original plot_pareto_runs(all_runs,selected) interface is unchanged.

all_runs = [p1_runs(:,{'r_F0','hover_effort'}); ...
    p2_runs(:,{'r_F0','hover_effort'})];

authority = all_runs.r_F0;
effort = all_runs.hover_effort;

family = [repmat("P1",height(p1_runs),1); ...
    repmat("P2",height(p2_runs),1)];

case_name = [string(p1_runs.case_name); ...
    string(p2_runs.case_name)];

n = height(all_runs);
valid = isfinite(authority) & isfinite(effort);
dominated = false(n,1);

% Compare every feasible point with every other feasible point.
for i = 1:n
    if ~valid(i)
        continue;
    end

    others = find(valid);
    others(others == i) = [];

    no_worse = ...
        authority(others) >= authority(i)-tolerance & ...
        effort(others) <= effort(i)+tolerance;

    strictly_better = ...
        authority(others) > authority(i)+tolerance | ...
        effort(others) < effort(i)-tolerance;

    dominated(i) = any(no_worse & strictly_better);
end

% Suppress near-identical frontier points using the existing tolerance.
% Prefer higher force authority within a near-duplicate group.
candidates = find(valid & ~dominated);

[~,order] = sortrows( ...
    [-authority(candidates),effort(candidates)],[1 2]);

candidates = candidates(order);
chosen = false(n,1);

for k = 1:numel(candidates)
    i = candidates(k);
    prior = find(chosen);

    if any( ...
            abs(authority(prior)-authority(i)) <= tolerance & ...
            abs(effort(prior)-effort(i)) <= tolerance)
        continue;
    end

    chosen(i) = true;
end

rows = find(chosen);

if isempty(rows)
    error('fa:CombinedParetoEmpty', ...
        'No nondominated joint P1/P2 solutions.');
end

% Sort the final blue curve by increasing force authority.
[~,order] = sortrows( ...
    [authority(rows),effort(rows)],[1 2]);

rows = rows(order);

selected = table( ...
    authority(rows), ...
    effort(rows), ...
    family(rows), ...
    case_name(rows), ...
    false(numel(rows),1), ...
    true(numel(rows),1), ...
    'VariableNames', ...
    {'r_F0','hover_effort','family','case_name', ...
    'duplicate','nondominated'});
end