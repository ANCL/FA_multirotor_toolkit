function cases = study_01_cases(settings)
%STUDY_01_CASES Define the eight unrestricted P1 optimization cases.
%
% There is one case per objective and reference-sign group. Multiple
% starting points are handled inside the chosen local optimizer.

n = numel(settings.objectives) * numel(settings.normalization_groups);
objective = cell(n, 1);
normalization_group = cell(n, 1);
seed = zeros(n, 1);
file_name = cell(n, 1);
k = 0;
for i = 1:numel(settings.objectives)
    for j = 1:numel(settings.normalization_groups)
        k = k + 1;
        objective{k} = settings.objectives{i};
        normalization_group{k} = settings.normalization_groups{j};
        % Preserve the original first-repeat random-seed convention.
        seed(k) = settings.random_seed + 10000*(i-1) + 1000*(j-1) + 1;
        file_name{k} = sprintf('%s_%s_%s.mat', ...
            objective{k}, normalization_group{k}, lower(settings.solver));
    end
end
cases = table(objective, normalization_group, seed, file_name);
end
