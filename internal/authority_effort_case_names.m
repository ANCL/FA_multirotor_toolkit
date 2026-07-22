function names = authority_effort_case_names(number_of_thresholds,independent_runs)
%AUTHORITY_EFFORT_CASE_NAMES Ordered checkpoint names for the Pareto study.
names = cell(number_of_thresholds*6*independent_runs,1);
index = 0;
for threshold_index = 1:number_of_thresholds
    for normalization_case = 1:6
        for run_number = 1:independent_runs
            index = index+1;
            names{index} = sprintf('pareto_%03d_norm_%d_run_%d', ...
                threshold_index,normalization_case,run_number);
        end
    end
end
end
