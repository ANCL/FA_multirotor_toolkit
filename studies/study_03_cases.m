function cases = study_03_cases(s)
%STUDY_03_CASES Reproducible P2/P3 SQP cases (five seeds per objective).
if nargin < 1 || isempty(s), s = study_03_settings(); end
[~,~,solver_key] = select_optimizer(s.solver);
n = numel(s.parameterizations) * numel(s.objectives) * s.repeats;
parameterization = cell(n, 1);
objective = cell(n, 1);
repeat = zeros(n, 1);
seed = zeros(n, 1);
file_name = cell(n, 1);
k = 0;
for p = 1:numel(s.parameterizations)
    for j = 1:numel(s.objectives)
        for r = 1:s.repeats
            k = k + 1;
            parameterization{k} = s.parameterizations{p};
            objective{k} = s.objectives{j};
            repeat(k) = r;
            seed(k) = s.random_seed + 10000*(p-1) + 1000*(j-1) + r;
            file_name{k} = sprintf('%s_%s_%02d_%s.mat', ...
                parameterization{k}, objective{k}, r, solver_key);
        end
    end
end
cases = table(parameterization, objective, repeat, seed, file_name);
end
