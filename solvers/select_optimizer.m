function [optimizer, label, key] = select_optimizer(solver)
%SELECT_OPTIMIZER Resolve implemented V2 optimizers from a study setting.
key = lower(char(string(solver)));
switch key
    case 'sqp'
        optimizer = @optimize_design_sqp;
        label = 'multistart SQP';
    case 'ga_patternsearch'
        optimizer = @optimize_design;
        label = 'GA + patternsearch';
    otherwise
        error('fa:UnknownSolver', 'Unknown solver: %s', key);
end
end
