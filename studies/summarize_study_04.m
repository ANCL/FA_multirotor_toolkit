function summary = summarize_study_04()
%SUMMARIZE_STUDY_04 Recheck Study 04 designs; identify sampled nondominance.
% Reported fronts are approximate and conditional on the saved SQP sample.
setup_project();
s = study_04_settings();
cases = study_04_cases(s);
model = default_model();
numerics = default_numerics();
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root,'results','study_04');
tables_folder = fullfile(out,'tables');
if ~isfolder(tables_folder), mkdir(tables_folder); end
n = height(cases);
status = repmat({'missing'},n,1);
r_F0 = nan(n,1); sigma_min = nan(n,1);
condition_number = nan(n,1); hover_effort = nan(n,1);
max_violation = nan(n,1); seconds = nan(n,1);
for i = 1:n
    file = fullfile(out,'runs',cases.file_name{i});
    if ~isfile(file), continue; end
    saved = load(file,'result');
    if ~isfield(saved,'result') || ~isstruct(saved.result)
        error('fa:Study04Result','Invalid saved result: %s',file);
    end
    r = saved.result;
    if ~isfield(r,'problem') || ~isfield(r,'design_variables') || ...
            ~isfield(r,'seed') || ~isequaln(r.seed,cases.seed(i)) || ...
            ~strcmp(r.problem.parameterization,'p1') || ...
            ~strcmp(r.problem.objective,cases.objective{i}) || ...
            ~strcmp(r.problem.normalization_group,cases.normalization_group{i})
        error('fa:Study04Result','Unexpected case in %s',file);
    end
    status{i} = 'infeasible';
    [c,~] = design_constraints(r.design_variables,r.problem,model,numerics);
    max_violation(i) = max([0;c(:)]);
    g = decode_design(r.design_variables,r.problem);
    m = evaluate_design(g,model,numerics);
    if isfield(r,'elapsed_seconds'), seconds(i)=r.elapsed_seconds; end
    if m.valid && max_violation(i)<=s.constraint_tolerance && ...
            isfield(r,'valid') && r.valid
        status{i} = 'feasible';
        r_F0(i) = m.r_F0;
        sigma_min(i) = m.sigma_min;
        condition_number(i) = m.condition_number;
        hover_effort(i) = m.hover_effort;
    end
end
cases.status = status;
cases.r_F0 = r_F0;
cases.sigma_min = sigma_min;
cases.condition_number = condition_number;
cases.hover_effort = hover_effort;
cases.max_violation = max_violation;
cases.elapsed_seconds = seconds;
cases.nondominated = false(n,1);
for ip = 1:numel(s.pairs)
    pair_name = s.pairs{ip};
    idx = find(strcmp(cases.pair,pair_name) & strcmp(cases.status,'feasible'));
    if isempty(idx), continue; end
    F = objective_matrix(cases(idx,:),pair_name);
    cases.nondominated(idx) = is_nondominated(F);
end
nondominated = cases(cases.nondominated,:);
writetable(cases,fullfile(tables_folder,'pareto_cases.csv'));
writetable(nondominated,fullfile(tables_folder,'pareto_nondominated.csv'));

% One small progress/coverage table, with no inferred global optimum.
label = s.pairs(:); total = zeros(numel(label),1);
feasible = total; sampled_nondominated = total;
for ip = 1:numel(label)
    in_pair = strcmp(cases.pair,label{ip});
    total(ip) = sum(in_pair);
    feasible(ip) = sum(in_pair & strcmp(cases.status,'feasible'));
    sampled_nondominated(ip) = sum(in_pair & cases.nondominated);
end
coverage = table(label,total,feasible,sampled_nondominated, ...
    'VariableNames',{'pair','cases','feasible','sampled_nondominated'});
writetable(coverage,fullfile(tables_folder,'pareto_coverage.csv'));
% Report authority-effort trade-off from saved results.
ref = readtable(fullfile(root,'results','study_01', ...
    'tables','cross_objective.csv'));
ref = ref(strcmp(ref.optimized_objective,'r_F0'),:);
assert(height(ref)==1 && ref.valid, ...
    'Valid Study 01 authority reference required.');

t = cases(strcmp(cases.pair,'authority_effort') & ...
    strcmp(cases.status,'feasible'),:);

thresholds = unique(t.r_threshold);
r = zeros(numel(thresholds),1);
e = r;

for k = 1:numel(thresholds)
    rows = t(t.r_threshold==thresholds(k),:);
    [e(k),j] = min(rows.hover_effort);
    r(k) = rows.r_F0(j);
end

[r,idx] = sort(r);
e = e(idx);

authority_retained_percent = [80; 92.5];
authority_compromise_percent = 100-authority_retained_percent;
reference_authority = repmat(ref.r_F0,2,1);
reference_hover_effort = repmat(ref.hover_effort,2,1);
target_authority = reference_authority .* ...
    authority_retained_percent/100;
interpolated_hover_effort = interp1(r,e,target_authority,'linear');

assert(all(isfinite(interpolated_hover_effort)), ...
    'Trade-off interpolation outside sampled range.');

hover_effort_reduction_percent = 100 * ...
    (1-interpolated_hover_effort./reference_hover_effort);

tradeoff = table(authority_compromise_percent, ...
    authority_retained_percent,reference_authority, ...
    reference_hover_effort,target_authority, ...
    interpolated_hover_effort,hover_effort_reduction_percent);

writetable(tradeoff,fullfile(tables_folder, ...
    'authority_effort_key_points.csv'));

fprintf('\nAUTHORITY-EFFORT TRADE-OFF\n');
disp(tradeoff);
summary = struct('output_folder',out,'cases',cases, ...
    'nondominated',nondominated,'coverage',coverage);
fprintf('\nSTUDY 04 | %d/%d saved | %d feasible\n', ...
    sum(~strcmp(status,'missing')),n,sum(strcmp(status,'feasible')));
disp(coverage)
fprintf('Tables: %s\n',tables_folder);
end

function F = objective_matrix(t,pair)
% Every column is minimized; no scalar normalization is necessary for
% Pareto dominance. Use physical values from evaluate_design.
switch pair
    case 'authority_effort'
        F = [-t.r_F0,t.hover_effort];
    case 'authority_sigma'
        F = [-t.r_F0,-t.sigma_min];
    case 'authority_condition'
        F = [-t.r_F0,t.condition_number];
    case 'sigma_effort'
        F = [-t.sigma_min,t.hover_effort];
    case 'condition_effort'
        F = [t.condition_number,t.hover_effort];
    case 'sigma_condition'
        F = [-t.sigma_min,t.condition_number];
    case 'joint_three'
        F = [-t.r_F0,-t.sigma_min,t.condition_number];
end
end

function keep = is_nondominated(F)
% Tolerance is only for numerical comparisons; it is not an optimization
% constraint. A very small absolute tolerance avoids exact-equality noise.
tol = 1e-8 * max(1,max(abs(F),[],1));
n = size(F,1);
keep = true(n,1);
for i = 1:n
    for j = 1:n
        if i == j, continue; end
        if all(F(j,:) <= F(i,:) + tol) && any(F(j,:) < F(i,:) - tol)
            keep(i)=false;
            break;
        end
    end
end
end
