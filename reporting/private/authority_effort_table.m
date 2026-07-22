function T = authority_effort_table(pareto_summary)
%AUTHORITY_EFFORT_TABLE Selected threshold solutions for the trade-off.
columns = {'threshold_index','authority_threshold','r_F0','hover_effort', ...
    'nondominated'};
T = pareto_summary(:,columns);
end
