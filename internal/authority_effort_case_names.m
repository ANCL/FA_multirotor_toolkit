function names = authority_effort_case_names(number_of_thresholds,independent_runs)
%AUTHORITY_EFFORT_CASE_NAMES Stage 03 P2 case identities.
names = cell(number_of_thresholds*independent_runs,1);
k = 0;
for i = 1:number_of_thresholds
    for j = 1:independent_runs
        k = k+1;
        names{k} = sprintf('pareto_%03d_run_%d',i,j);
    end
end
end
