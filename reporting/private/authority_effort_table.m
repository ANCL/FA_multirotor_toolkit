function T = authority_effort_table(pareto_summary)
%AUTHORITY_EFFORT_TABLE Selected threshold solutions for the trade-off.
pareto_summary = sortrows(pareto_summary,'threshold_index');
columns = {'threshold_index','authority_threshold','r_F0','hover_effort', ...
    'nondominated'};
T = pareto_summary(:,columns);

n_points = height(T);
delta_force_authority = NaN(n_points,1);
delta_hover_effort = NaN(n_points,1);
marginal_hover_effort = NaN(n_points,1);
if n_points > 1
    delta_force_authority(2:end) = diff(T.r_F0);
    delta_hover_effort(2:end) = diff(T.hover_effort);
    marginal_hover_effort(2:end) = ...
        delta_hover_effort(2:end)./delta_force_authority(2:end);
end
T.delta_force_authority = delta_force_authority;
T.delta_hover_effort = delta_hover_effort;
T.marginal_hover_effort = marginal_hover_effort;
end
