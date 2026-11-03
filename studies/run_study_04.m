function summary = run_study_04()
%RUN_STUDY_04 P1-only epsilon-constraint tradeoffs; restartable case files.
% All cases use existing V2 metrics, physical constraints, and optimizers.
setup_project();
s = study_04_settings();
[optimizer, label, key] = select_optimizer(s.solver);
cases = study_04_cases(s);
model = default_model();
numerics = default_numerics();
root = fileparts(fileparts(mfilename('fullpath')));
runs_folder = fullfile(root,'results','study_04','runs');
if ~isfolder(runs_folder), mkdir(runs_folder); end
jobs = repmat(struct('problem',[],'file','','seed',0, ...
    'label','','optimizer',[]), height(cases), 1);
for i = 1:height(cases)
    problem = make_design_problem('p1', cases.objective{i}, ...
        cases.normalization_group{i}, model);
    if ~isnan(cases.r_threshold(i))
        problem.authority_threshold = cases.r_threshold(i);
    end
    if ~isnan(cases.sigma_threshold(i))
        problem.sigma_threshold = cases.sigma_threshold(i);
    end
    if ~isnan(cases.condition_ceiling(i))
        problem.condition_ceiling = cases.condition_ceiling(i);
    end
    jobs(i).problem = problem;
    jobs(i).file = fullfile(runs_folder, cases.file_name{i});
    jobs(i).seed = cases.seed(i);
    jobs(i).optimizer = optimizer;
    jobs(i).label = sprintf('%s / %s / %s', ...
        cases.pair{i}, cases.normalization_group{i}, cases.file_name{i});
    % run_optimization_batch skips files based on existence. Check saved
    % identity here so a changed solver/seed/threshold is not silently reused.
    if isfile(jobs(i).file)
        saved = load(jobs(i).file,'result');
        if ~isfield(saved,'result') || ~isstruct(saved.result) || ...
                ~matches_case(saved.result, jobs(i), s, key)
            error('fa:Study04SavedMismatch', ...
                'Incompatible saved run: %s. Preserve it and investigate.', jobs(i).file);
        end
    end
end
fprintf('\nSTUDY 04 | unrestricted P1 | %s | %d cases\n',label,height(cases));
fprintf('Authority-effort Pareto; two P1 normalization groups.\n');
if strcmp(key,'sqp')
    fprintf('%d independent SQP starts per case.\n',s.sqp.starts);
end
run_optimization_batch(jobs,model,numerics,s);
summary = summarize_study_04();
end

function yes = matches_case(r,job,s,key)
p = job.problem;
yes = isfield(r,'problem') && isfield(r,'settings') && ...
    isfield(r,'seed') && isequaln(r.seed,job.seed) && ...
    isfield(r,'design_variables') && ...
    isfield(r.problem,'parameterization') && ...
    strcmp(r.problem.parameterization,'p1') && ...
    isfield(r.problem,'objective') && strcmp(r.problem.objective,p.objective) && ...
    isfield(r.problem,'normalization_group') && ...
    strcmp(r.problem.normalization_group,p.normalization_group) && ...
    isequaln(value_or_empty(r.problem,'authority_threshold'), value_or_empty(p,'authority_threshold')) && ...
    isequaln(value_or_empty(r.problem,'sigma_threshold'), value_or_empty(p,'sigma_threshold')) && ...
    isequaln(value_or_empty(r.problem,'condition_ceiling'), value_or_empty(p,'condition_ceiling')) && ...
    isfield(r.settings,'constraint_tolerance') && ...
    isequaln(r.settings.constraint_tolerance,s.constraint_tolerance);
if ~yes, return; end
switch key
    case 'sqp'
        yes = isfield(r,'sqp') && ~isfield(r,'ga') && ...
            isfield(r.settings,'sqp') && isequaln(r.settings.sqp,s.sqp);
    case 'ga_patternsearch'
        yes = isfield(r,'ga') && ~isfield(r,'sqp') && ...
            isfield(r.settings,'ga') && isfield(r.settings,'patternsearch') && ...
            isequaln(r.settings.ga,s.ga) && ...
            isequaln(r.settings.patternsearch,s.patternsearch) && ...
            isequaln(r.settings.local_refinements,s.local_refinements);
end
end

function v = value_or_empty(p,field)
v = [];
if isfield(p,field), v = p.(field); end
end
