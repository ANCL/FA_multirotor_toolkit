function summary = run_study_02()
%RUN_STUDY_02 Independent parallel P1 SQP with accepted-only storage.
% Each attempt directly optimizes one performance objective from a freshly
% sampled feasible random P1 start. There is no geometric target, known
% optimum seed, imposed symmetry, or saved unsuccessful-geometry file.
% Each qualifying, distinct configuration is saved once as 1.mat, 2.mat, ...

setup_project();
s = study_02_settings();
if ~strcmpi(s.solver,'sqp')
    error('fa:Study02Solver','Study 02 discovery is SQP-only; other discovery protocols require their own validation.');
end
model = default_model();
numerics = default_numerics();
validate_study_settings(s);
if exist('fmincon','file')~=2
    error('fa:Study02Fmincon','Study 02 requires fmincon (Optimization Toolbox).');
end
root = fileparts(fileparts(mfilename('fullpath')));
output = fullfile(root,'results','study_02');
if ~isfolder(output), mkdir(output); end
progress_file = fullfile(output,'progress.mat');
if isfile(progress_file)
    data = load(progress_file,'progress');
    if ~isfield(data,'progress'), error('fa:Study02Progress','Invalid progress.mat.'); end
    progress = data.progress;
else
    progress = struct();
end
fprintf('\nSTUDY 02 | unrestricted P1 | parallel direct SQP\n');
fprintf('%d objectives | %d distinct per objective | no fixed attempt cap\n', ...
    numel(s.objectives),s.target_per_objective);
fprintf('Absolute performance tolerance %.1g | distance >= %.3g | stagnation %d\n', ...
    s.constraint_tolerance,s.distinctness_distance,s.stagnation_attempts);
use_parallel = initialize_parallel(s);

for i=1:numel(s.objectives)
    objective=s.objectives{i};
    design_folder=fullfile(output,objective);
    if ~isfolder(design_folder), mkdir(design_folder); end
    accepted=load_study_02_accepted(output,objective);
    if isfield(progress,objective)
        counts=progress.(objective);
    elseif isempty(accepted)
        counts=empty_counts();
    else
        error('fa:Study02Progress', ...
            'Accepted designs exist without progress.mat for %s.',objective);
    end
    if ~isempty(accepted) && max([accepted.attempt_number])>counts.saved
        error('fa:Study02Progress', ...
            'Progress is behind accepted results for %s; do not restart until reconciled.',objective);
    end
    problems=cell(numel(s.normalization_groups),1);
    for g=1:numel(problems)
        problems{g}=make_design_problem('p1',objective,s.normalization_groups{g},model);
    end
    fprintf('\n%s: %d/%d distinct | %d SQP attempts | %d since last new\n', ...
        objective,numel(accepted),s.target_per_objective,counts.saved,counts.stagnation);

    while numel(accepted)<s.target_per_objective && ...
            counts.stagnation<s.stagnation_attempts
        n=min([s.batch_size, s.target_per_objective-numel(accepted), ...
            s.stagnation_attempts-counts.stagnation]);
        jobs=cell(n,1);
        for j=1:n
            k=counts.saved+j;
            group_index=1+mod(k-1,numel(s.normalization_groups));
            jobs{j}=struct('number',k, ...
                'seed',s.random_seed+100000*i+k,'problem',problems{group_index});
        end
        attempts=cell(n,1);
        if use_parallel && n>1
            parfor (j=1:n,s.max_workers)
                attempts{j}=solve_discovery_attempt(jobs{j},model,numerics,s);
            end
        else
            for j=1:n
                attempts{j}=solve_discovery_attempt(jobs{j},model,numerics,s);
            end
        end
        % Process in attempt-number order for deterministic acceptance IDs.
        for j=1:n
            [accepted,counts,new_entry]=incorporate_attempt( ...
                accepted,counts,attempts{j},s,objective,model,numerics);
            if ~isempty(new_entry)
                save_entry(fullfile(design_folder, ...
                    sprintf('%d.mat',numel(accepted))),new_entry);
            end
        end
        progress.(objective)=counts;
        save_progress(progress_file,progress);
        fprintf('  %-17s %3d/%d distinct | %5d attempts | %4d qualifying | stagnant %4d/%d\n', ...
            objective,numel(accepted),s.target_per_objective, ...
            counts.saved,counts.qualifying,counts.stagnation,s.stagnation_attempts);
    end
    if numel(accepted)>=s.target_per_objective
        fprintf('  %s: target reached.\n',objective);
    else
        fprintf('  %s: stopped after %d consecutive attempts without a new design.\n', ...
            objective,counts.stagnation);
    end
end
summary=summarize_study_02();
end

function attempt=solve_discovery_attempt(job,model,numerics,s)
clock=tic;
problem=job.problem;
rng(job.seed,'twister');
lb=problem.lower_bounds(:);
ub=problem.upper_bounds(:);
[start,start_draws]=sample_feasible_p1_start(problem,model,numerics,s);
reference=analytical_bound(problem.objective);
options=optimoptions('fmincon','Algorithm','sqp','Display','off', ...
    'MaxIterations',s.sqp.max_iterations, ...
    'MaxFunctionEvaluations',s.sqp.max_function_evaluations, ...
    'OptimalityTolerance',s.sqp.optimality_tolerance, ...
    'StepTolerance',s.sqp.step_tolerance, ...
    'ConstraintTolerance',s.constraint_tolerance, ...
    'FiniteDifferenceType','forward','UseParallel',false);
attempt=struct('attempt_number',job.number,'seed',job.seed, ...
    'objective',problem.objective,'normalization_group',problem.normalization_group, ...
    'start_design_variables',start,'start_draws',start_draws, ...
    'design_variables',[],'geometry',[],'metrics',[], ...
    'objective_value',NaN,'relative_bound_gap',NaN, ...
    'performance_bound_violation',Inf,'physical_constraint_violation',Inf, ...
    'exitflag',NaN,'elapsed_seconds',NaN,'valid',false);
try
    [x,~,exitflag]=fmincon( ...
        @(z) design_objective(z,problem,model),start, ...
        [],[],[],[],lb,ub, ...
        @(z) design_constraints(z,problem,model,numerics),options);
    geometry=decode_design(x,problem);
    metrics=evaluate_design(geometry,model,numerics);
    [c,ceq]=design_constraints(x,problem,model,numerics);
    physical_violation=max([0;c(:);abs(ceq(:));lb-x(:);x(:)-ub]);
    if metrics.valid
        value=metrics.(problem.objective);
        gap=objective_relative_gap(problem.objective,value,reference);
        if ismember(problem.objective,{'r_F0','sigma_min'})
            bound_violation=max(0,reference-value);
        else
            bound_violation=max(0,value-reference);
        end
    else
        value=NaN; gap=NaN; bound_violation=Inf;
    end
    attempt.design_variables=x;
    attempt.geometry=geometry;
    attempt.metrics=metrics;
    attempt.objective_value=value;
    attempt.relative_bound_gap=gap;
    attempt.performance_bound_violation=bound_violation;
    attempt.physical_constraint_violation=physical_violation;
    attempt.exitflag=exitflag;
    attempt.valid=metrics.valid && isfinite(value) && ...
        isfinite(physical_violation) && physical_violation<=s.constraint_tolerance && ...
        bound_violation<=s.constraint_tolerance;
catch
    % Failed SQP attempts are counted but no failed geometries are stored.
end
attempt.elapsed_seconds=toc(clock);
end

function [start,draws]=sample_feasible_p1_start(problem,model,numerics,s)
% Feasible random P1 starts, without any previously optimized geometry.
lb=problem.lower_bounds(:);
ub=problem.upper_bounds(:);
for draws=1:5000
    candidate=lb+(ub-lb).*rand(size(lb));
    [c,ceq]=design_constraints(candidate,problem,model,numerics);
    if max([0;c(:);abs(ceq(:))])>min(s.constraint_tolerance,1e-6)
        continue;
    end
    m=evaluate_design(decode_design(candidate,problem),model,numerics);
    if m.valid
        start=candidate;
        return;
    end
end
% Fallback remains an independent unrestricted P1 random sample.
start=lb+(ub-lb).*rand(size(lb));
end

function [accepted,counts,entry]=incorporate_attempt(accepted,counts,a,s,objective,model,numerics)
entry=[];
counts.saved=counts.saved+1;
if numel(accepted)>=s.target_per_objective
    return;
end
qualified=false;
if isfield(a,'design_variables') && numel(a.design_variables)==28 && ...
        all(isfinite(a.design_variables))
    problem=make_design_problem('p1',objective,a.normalization_group,model);
    x=a.design_variables(:);
    g=decode_design(x,problem);
    m=evaluate_design(g,model,numerics);
    [c,ceq]=design_constraints(x,problem,model,numerics);
    phys=max([0;c(:);abs(ceq(:));problem.lower_bounds(:)-x; ...
        x-problem.upper_bounds(:)]);
    reference=analytical_bound(objective);
    if m.valid
        value=m.(objective);
        if ismember(objective,{'r_F0','sigma_min'})
            bound_loss=max(0,reference-value);
        else
            bound_loss=max(0,value-reference);
        end
        qualified=isfinite(bound_loss) && ...
            phys<=s.constraint_tolerance && bound_loss<=s.constraint_tolerance;
    end
end
if ~qualified
    counts.failed=counts.failed+1;
    counts.stagnation=counts.stagnation+1;
    return;
end
counts.qualifying=counts.qualifying+1;
nearest=Inf;
for j=1:numel(accepted)
    nearest=min(nearest,geometry_distance(g,accepted(j).geometry,model));
    if nearest<s.distinctness_distance, break; end
end
if nearest<s.distinctness_distance
    counts.duplicates=counts.duplicates+1;
    counts.stagnation=counts.stagnation+1;
    return;
end
entry=struct('attempt_number',a.attempt_number,'objective',objective, ...
    'normalization_group',a.normalization_group, ...
    'design_variables',x,'geometry',g,'metrics',m, ...
    'objective_value',value, ...
    'relative_bound_gap',objective_relative_gap(objective,value,reference), ...
    'performance_bound_violation',bound_loss, ...
    'physical_constraint_violation',phys, ...
    'nearest_previous_distance',nearest, ...
    'exitflag',a.exitflag,'elapsed_seconds',a.elapsed_seconds);
if isempty(accepted), accepted=entry; else, accepted(end+1,1)=entry; end
counts.stagnation=0;
end

function save_entry(filename,entry)
if isfile(filename)
    error('fa:Study02Overwrite','Will not overwrite accepted configuration: %s',filename);
end
[tempfolder,basename,~]=fileparts(filename);
tmp=fullfile(tempfolder,[basename '.saving.mat']);
save(tmp,'entry','-v7');
[ok,message]=movefile(tmp,filename);
if ~ok, error('fa:Study02Save','Could not save accepted configuration: %s',message); end
end

function save_progress(filename,progress)
[folder,~,~]=fileparts(filename);
tmp=fullfile(folder,'progress.saving.mat');
save(tmp,'progress','-v7');
[ok,message]=movefile(tmp,filename,'f');
if ~ok, error('fa:Study02Progress','Could not save progress: %s',message); end
end

function counts=empty_counts()
counts=struct('saved',0,'qualifying',0,'duplicates',0,'failed',0,'stagnation',0);
end

function ref=analytical_bound(objective)
switch objective
    case 'r_F0', ref=sqrt(2/3);
    case 'sigma_min', ref=sqrt(2);
    case 'condition_number', ref=1;
    otherwise, error('fa:Study02Objective','Unknown objective: %s',objective);
end
end

function gap=objective_relative_gap(objective,value,ref)
if ismember(objective,{'r_F0','sigma_min'})
    gap=(ref-value)/ref;
else
    gap=(value-ref)/ref;
end
end

function validate_study_settings(s)
if s.target_per_objective<1 || s.stagnation_attempts<1 || ...
        s.batch_size<1 || s.distinctness_distance<=0 || ...
        s.constraint_tolerance<=0 || s.max_workers<1
    error('fa:Study02Settings','Study 02 settings must be positive.');
end
if ~isequal(s.normalization_groups,{'positive','negative'}) || ...
        ~isequal(s.objectives,{'r_F0','sigma_min','condition_number'})
    error('fa:Study02Settings','Unexpected objective or normalization-group specification.');
end
end

function enabled=initialize_parallel(s)
enabled=s.parallel && s.batch_size>1;
if ~enabled, return; end
if exist('parpool','file')~=2 || ~license('test','Distrib_Computing_Toolbox')
    warning('fa:ParallelUnavailable','No Parallel Computing Toolbox; running serially.');
    enabled=false;
    return;
end
try
    pool=gcp('nocreate');
    if isempty(pool)
        cluster=parcluster('Processes');
        pool=parpool('Processes',min(s.max_workers,cluster.NumWorkers));
    end
    fprintf('Parallel execution: %d workers.\n',pool.NumWorkers);
catch exception
    warning('fa:ParallelUnavailable','Pool unavailable: %s',exception.message);
    enabled=false;
end
end
