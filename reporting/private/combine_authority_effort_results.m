function [all_runs,selected] = combine_authority_effort_results(p1_runs,p1_front,p2_runs,p2_front,tolerance)
%COMBINE_AUTHORITY_EFFORT_RESULTS Pool actual runs and classify a joint front.
% The plotting interface remains exactly plot_pareto_runs(all_runs,selected).
all_runs = [p1_runs(:,{'r_F0','hover_effort'}); ...
    p2_runs(:,{'r_F0','hover_effort'})];
selected = [p1_front(:,{'r_F0','hover_effort'}); ...
    p2_front(:,{'r_F0','hover_effort'})];
n = height(selected);
valid = isfinite(selected.r_F0) & isfinite(selected.hover_effort);
duplicate = false(n,1);
dominated = false(n,1);
for i = 1:n
    if ~valid(i), dominated(i) = true; continue; end
    previous = find(valid(1:i-1));
    duplicate(i) = any( ...
        abs(selected.r_F0(previous)-selected.r_F0(i)) <= tolerance & ...
        abs(selected.hover_effort(previous)-selected.hover_effort(i)) <= tolerance);
    other = find(valid); other(other==i) = [];
    better_or_equal = selected.r_F0(other) >= selected.r_F0(i)-tolerance & ...
        selected.hover_effort(other) <= selected.hover_effort(i)+tolerance;
    strictly_better = selected.r_F0(other) > selected.r_F0(i)+tolerance | ...
        selected.hover_effort(other) < selected.hover_effort(i)-tolerance;
    dominated(i) = any(better_or_equal & strictly_better);
end
selected.duplicate = duplicate;
selected.nondominated = valid & ~duplicate & ~dominated;
if ~any(selected.nondominated)
    error('fa:CombinedParetoEmpty','No nondominated joint P1/P2 solutions.');
end
end
