function result = optimize_design(problem, parameters, solver, seed, execution)
%OPTIMIZE_DESIGN Run one global search followed by local refinement.
% Candidate selection is feasibility-aware: a feasible local refinement can
% never be rejected merely because an infeasible global point has a smaller
% unconstrained objective value.

if nargin < 5 || isempty(execution), execution = struct(); end
if ~isfield(execution,'log_optimizer_progress'), execution.log_optimizer_progress = true; end
if ~isfield(execution,'case_provenance'), execution.case_provenance = struct(); end
validateattributes(seed, {'numeric'}, {'scalar','integer','positive'});
lb = problem.lower_bounds(:);
ub = problem.upper_bounds(:);
last_x = [];
last_metrics = [];
search_options = objective_evaluation_options(problem);
evaluation_count = 0;
last_ga_report = -1;
start_time = datetime('now');
timer = tic;

    function metrics = cached_evaluation(x)
        x = x(:);
        if isempty(last_x) || numel(x) ~= numel(last_x) || any(x ~= last_x)
            geometry = decode_design(x,problem.parameterization,problem.normalization_case,parameters);
            last_metrics = evaluate_design(geometry,parameters,solver,search_options);
            last_x = x;
            evaluation_count = evaluation_count+1;
        end
        metrics = last_metrics;
    end

    function value = objective(x)
        value = objective_value(cached_evaluation(x),problem.objective);
    end

    function [c,ceq] = nonlinear_constraints(x)
        [c,ceq] = design_constraints(cached_evaluation(x),problem);
    end

    function [state,options,optchanged] = ga_progress(options,state,flag)
        optchanged = false;
        if strcmp(flag,'iter')
            generation = state.Generation;
            if generation == 1 || mod(generation,10) == 0
                if generation ~= last_ga_report
                    % GA's state.Best may include constraint penalties and is
                    % therefore not a defensible scientific metric. Report only
                    % generation progress here; the evaluated metric is printed
                    % after the global/local candidate is completed.
                    study_log('optimizer','GA generation',generation, ...
                        solver.ga.max_generations,NaN,toc(timer));
                    last_ga_report = generation;
                end
            end
        end
    end

initial_designs = bounded_initial_designs(problem.initial_designs,lb,ub);
if size(initial_designs,1) > solver.ga.population_size
    selected_rows = round(linspace(1,size(initial_designs,1), ...
        solver.ga.population_size));
    initial_designs = initial_designs(selected_rows,:);
end

% Treat every supplied deterministic start as an evaluated candidate. This
% guarantees that a global search cannot return a result worse than a known
% feasible seed merely because the stochastic population later discards it.
candidate_history = struct('x',{},'objective_value',{},'valid',{}, ...
    'maximum_constraint_violation',{},'solver',{},'exitflag',{},'output',{});
incumbent = [];
for seed_index = 1:size(initial_designs,1)
    x_seed = initial_designs(seed_index,:).';
    seed_metrics = cached_evaluation(x_seed);
    [c_seed,~] = design_constraints(seed_metrics,problem);
    seed_violation = max([0;c_seed]);
    seed_valid = seed_metrics.valid && ...
        seed_violation <= solver.constraint_tolerance;
    seed_candidate = candidate_record(x_seed, ...
        objective_value(seed_metrics,problem.objective),seed_valid, ...
        seed_violation,sprintf('initial_design_%d',seed_index),NaN,struct());
    candidate_history(end+1) = seed_candidate; %#ok<AGROW>
    if isempty(incumbent) || prefer_optimization_candidate(seed_candidate,incumbent)
        incumbent = seed_candidate;
    end
end

global_exit_flag = NaN;
global_output = struct();
population_final = zeros(0,numel(lb));
scores = zeros(0,1);

if execution.log_optimizer_progress
    study_log('line','  Starting global optimization...');
end
switch lower(string(solver.global_solver))
    case "ga"
        if exist('ga','file') ~= 2
            error('fa:MissingGA','Global Optimization Toolbox ga is required.');
        end
        rng(seed,'twister');
        ga_options = optimoptions('ga', ...
            'Display','off', ...
            'PopulationSize',solver.ga.population_size, ...
            'MaxGenerations',solver.ga.max_generations, ...
            'MaxStallGenerations',solver.ga.max_stall_generations, ...
            'ConstraintTolerance',solver.constraint_tolerance, ...
            'FunctionTolerance',solver.ga.function_tolerance, ...
            'NonlinearConstraintAlgorithm',solver.ga.nonlinear_constraint_algorithm, ...
            'InitialPenalty',solver.ga.initial_penalty, ...
            'PenaltyFactor',solver.ga.penalty_factor, ...
            'UseParallel',false, ...
            'InitialPopulationMatrix',initial_designs, ...
            'OutputFcn',progress_function(execution,@ga_progress));
        [x_global,f_global,global_exit_flag,global_output,population_final,scores] = ...
            ga(@objective,numel(lb),[],[],[],[],lb,ub,@nonlinear_constraints,ga_options);
    otherwise
        error('fa:UnknownGlobalSolver','Unknown global solver: %s',solver.global_solver);
end

global_metrics = cached_evaluation(x_global);
[c_global,~] = design_constraints(global_metrics,problem);
global_violation = max([0;c_global]);
global_valid = global_metrics.valid && global_violation <= solver.constraint_tolerance;
global_objective_value = objective_value(global_metrics,problem.objective);
global_reported_objective_value = objective_metric_value(global_metrics,problem.objective);
global_evaluation_count = read_output_count(global_output);
global_candidate = candidate_record(x_global,global_objective_value,global_valid, ...
    global_violation,char(string(solver.global_solver)),global_exit_flag,global_output);
candidate_history(end+1) = global_candidate;
if isempty(incumbent) || prefer_optimization_candidate(global_candidate,incumbent)
    incumbent = global_candidate;
end

local_results = struct('start_x',{},'start_fval',{},'x',{},'fval',{}, ...
    'improvement',{},'valid',{},'maximum_constraint_violation',{}, ...
    'exitflag',{},'output',{});

if strcmpi(solver.local_solver,'patternsearch') && solver.local_refinements > 0
    if exist('patternsearch','file') ~= 2
        error('fa:MissingPatternsearch', ...
            'Global Optimization Toolbox patternsearch is required.');
    end
    local_options = optimoptions('patternsearch', ...
        'Display','off', ...
        'MaxFunctionEvaluations',solver.patternsearch.max_function_evaluations, ...
        'ConstraintTolerance',solver.constraint_tolerance, ...
        'FunctionTolerance',solver.patternsearch.function_tolerance, ...
        'MeshTolerance',solver.patternsearch.mesh_tolerance, ...
        'UseParallel',false);
    starts = select_local_starts(incumbent.x,population_final,scores,lb,ub, ...
        solver.local_refinements,solver.local_start_min_distance, ...
        @cached_evaluation,problem,solver);
    for refinement = 1:size(starts,1)
        if execution.log_optimizer_progress
            study_log('line','  Starting local refinement %d/%d...', ...
                refinement,size(starts,1));
        end
        start_x = starts(refinement,:).';
        start_fval = objective(start_x);
        [x_local,f_local,local_exit_flag,local_output] = patternsearch( ...
            @objective,start_x,[],[],[],[],lb,ub,@nonlinear_constraints,local_options);
        local_metrics = cached_evaluation(x_local);
        [c_local,~] = design_constraints(local_metrics,problem);
        local_violation = max([0;c_local]);
        local_valid = local_metrics.valid && ...
            local_violation <= solver.constraint_tolerance;
        local_objective = objective_value(local_metrics,problem.objective);
        local_metric_value = objective_metric_value(local_metrics,problem.objective);
        if execution.log_optimizer_progress
            study_log('line','  Local refinement %d completed | %s %.8g', ...
                refinement,problem.objective,local_metric_value);
        end
        local_results(refinement) = struct( ...
            'start_x',start_x,'start_fval',start_fval,'x',x_local, ...
            'fval',local_objective,'improvement',start_fval-local_objective, ...
            'valid',local_valid,'maximum_constraint_violation',local_violation, ...
            'exitflag',local_exit_flag,'output',local_output);
        candidate = candidate_record(x_local,local_objective,local_valid, ...
            local_violation,sprintf('local_refinement_%d',refinement), ...
            local_exit_flag,local_output);
        candidate_history(end+1) = candidate; %#ok<AGROW>
        if prefer_optimization_candidate(candidate,incumbent)
            incumbent = candidate;
        end
    end
elseif ~strcmpi(solver.local_solver,'none') && ~isempty(solver.local_solver) && ...
        solver.local_refinements > 0
    error('fa:UnknownLocalSolver','Unknown local solver: %s',solver.local_solver);
end

selection_audit = audit_optimization_selection(incumbent,candidate_history);

final_geometry = decode_design(incumbent.x,problem.parameterization, ...
    problem.normalization_case,parameters);
final_metrics = evaluate_design(final_geometry,parameters,solver);
[c_final,~,constraint_labels] = design_constraints(final_metrics,problem);
maximum_violation = max([0;c_final]);

result = empty_optimization_result();
result.case_name = problem.case_name;
result.objective_name = problem.objective;
result.parameterization = problem.parameterization;
result.normalization_case = problem.normalization_case;
result.seed = seed;
result.design_variables = incumbent.x;
result.geometry = final_geometry;
result.metrics = final_metrics;
result.objective_value = objective_value(final_metrics,problem.objective);
result.reported_objective_value = objective_metric_value(final_metrics,problem.objective);
result.constraints.values = c_final;
result.constraints.labels = constraint_labels;
result.constraints.maximum_violation = maximum_violation;
result.valid = final_metrics.valid && maximum_violation <= solver.constraint_tolerance;
result.global_exit_flag = global_exit_flag;
result.global_solver_output = global_output;
result.global_objective_value = global_objective_value;
result.global_reported_objective_value = global_reported_objective_value;
result.global_valid = global_valid;
result.global_constraint_violation = global_violation;
result.global_evaluation_count = global_evaluation_count;
result.selected_solver = incumbent.solver;
result.selected_constraint_violation = maximum_violation;
result.selection_audit = selection_audit;
result.exit_flag = incumbent.exitflag;
result.solver_output = incumbent.output;
result.local_refinements = local_results;
if global_valid && result.valid && startsWith(result.selected_solver,'local_refinement_')
    result.local_improvement = global_objective_value-result.objective_value;
else
    result.local_improvement = NaN;
end
result.evaluation_count = evaluation_count;
result.elapsed_seconds = toc(timer);
result.started_at = start_time;
result.ended_at = datetime('now');
result.failure_reason = final_metrics.failure_reason;
if ~result.valid && isempty(result.failure_reason)
    result.failure_reason = ...
        'The selected design violates one or more optimization constraints.';
end
if isempty(fieldnames(execution.case_provenance))
    specification = make_optimization_case(1,'',problem,parameters,seed,struct());
    result.case_provenance = optimization_case_provenance(specification,solver);
else
    result.case_provenance = execution.case_provenance;
end
end

function output = progress_function(execution,function_handle)
%PROGRESS_FUNCTION Disable worker-side optimizer chatter during case parallelism.
if execution.log_optimizer_progress
    output = function_handle;
else
    output = [];
end
end

function candidate = candidate_record(x,objective_value,valid,violation,solver_name,exitflag,output)
candidate = struct('x',x(:),'objective_value',objective_value,'valid',logical(valid), ...
    'maximum_constraint_violation',violation,'solver',solver_name, ...
    'exitflag',exitflag,'output',output);
end

function initial_designs = bounded_initial_designs(initial_designs,lb,ub)
if isempty(initial_designs)
    initial_designs = zeros(0,numel(lb));
    return;
end
if size(initial_designs,2) ~= numel(lb) || any(~isfinite(initial_designs),'all')
    error('fa:InitialDesignShape', ...
        'Initial designs must be finite rows with exactly %d variables.',numel(lb));
end
valid = all(initial_designs >= lb(:).'-eps,2) & ...
    all(initial_designs <= ub(:).'+eps,2);
initial_designs = unique(initial_designs(valid,:),'rows','stable');
end

function starts = select_local_starts(x_best,population,scores,lb,ub,requested, ...
    min_distance,evaluator,problem,solver)
starts = x_best(:).';
if requested <= 1 || isempty(population)
    starts = starts(1:min(requested,size(starts,1)),:);
    return;
end
finite_mask = isfinite(scores);
candidates = population(finite_mask,:);
candidate_scores = scores(finite_mask);
[~,order] = sort(candidate_scores,'ascend');
candidates = candidates(order,:);
scale = (ub-lb).';
scale(scale <= eps) = 1;
for k = 1:size(candidates,1)
    candidate = candidates(k,:);
    if ~is_distinct(candidate,starts,scale,min_distance), continue; end
    metrics = evaluator(candidate.');
    [c,~] = design_constraints(metrics,problem);
    if metrics.valid && all(c <= solver.constraint_tolerance)
        starts(end+1,:) = candidate; %#ok<AGROW>
    end
    if size(starts,1) >= requested, break; end
end
if size(starts,1) < requested
    for k = 1:size(candidates,1)
        candidate = candidates(k,:);
        if is_distinct(candidate,starts,scale,min_distance)
            starts(end+1,:) = candidate; %#ok<AGROW>
        end
        if size(starts,1) >= requested, break; end
    end
end
starts = starts(1:min(requested,size(starts,1)),:);
end

function yes = is_distinct(candidate,starts,scale,min_distance)
if isempty(starts), yes = true; return; end
normalized_distance = max(abs((starts-candidate)./scale),[],2);
yes = all(normalized_distance >= min_distance);
end

function count = read_output_count(output)
count = NaN;
if isstruct(output) && isfield(output,'funccount'), count = output.funccount; end
end

function options = objective_evaluation_options(problem)
options = struct('compute_force_authority', ...
    strcmp(problem.objective,'r_F0') || ~isempty(problem.authority_threshold), ...
    'compute_task_scale',strcmp(problem.objective,'q_star'));
end

function value = objective_metric_value(metrics, objective)
%OBJECTIVE_METRIC_VALUE Return the physical/scientific value of an objective.
% This is the value reported to the researcher. objective_value.m converts
% the same quantity to an internal minimization cost for the solvers.
name = char(string(objective));
if ~isstruct(metrics) || ~isfield(metrics,name)
    value = NaN;
    return;
end
value = metrics.(name);
end

function [c, ceq, labels] = design_constraints(metrics, problem)
%DESIGN_CONSTRAINTS Common admissibility constraints and optional epsilon rule.
labels = {'length_lower','length_upper','normalization_case','unit_direction', ...
    'separation','full_actuation','hover_bounds'};
if isempty(metrics.geometry_check)
    margin = -ones(7,1);
else
    g = metrics.geometry_check;
    margin = [g.length_lower_margin; g.length_upper_margin; g.normalization_margin; ...
        g.unit_direction_margin; g.separation_margin; ...
        value_or(metrics.constraint_margins,'full_actuation',-1); ...
        value_or(metrics.constraint_margins,'hover',-1)];
end
c = -margin;
if ~isempty(problem.authority_threshold)
    c(end+1,1) = problem.authority_threshold - metrics.r_F0;
    labels{end+1} = 'authority_threshold';
end
ceq = zeros(0,1);
end

function value = value_or(s, field, fallback)
if isstruct(s) && isfield(s,field), value=s.(field); else, value=fallback; end
end

function result = empty_optimization_result()
%EMPTY_OPTIMIZATION_RESULT Stable schema for completed optimization runs.
result = struct( ...
    'case_name', '', ...
    'objective_name', '', ...
    'parameterization', '', ...
    'normalization_case', 0, ...
    'seed', NaN, ...
    'design_variables', [], ...
    'geometry', [], ...
    'metrics', [], ...
    'objective_value', Inf, ... % internal minimization cost
    'reported_objective_value', NaN, ...
    'constraints', struct( ...
        'values', [], ...
        'labels', {{}}, ...
        'maximum_violation', Inf), ...
    'valid', false, ...
    'global_exit_flag', NaN, ...
    'global_solver_output', struct(), ...
    'global_objective_value', Inf, ... % internal minimization cost
    'global_reported_objective_value', NaN, ...
    'global_valid', false, ...
    'global_constraint_violation', Inf, ...
    'global_evaluation_count', NaN, ...
    'selected_solver', '', ...
    'selected_constraint_violation', Inf, ...
    'selection_audit', struct(), ...
    'exit_flag', NaN, ...
    'solver_output', struct(), ...
    'local_refinements', struct([]), ...
    'local_improvement', NaN, ...
    'evaluation_count', 0, ...
    'elapsed_seconds', NaN, ...
    'started_at', NaT, ...
    'ended_at', NaT, ...
    'failure_reason', '', ...
    'matlab_release', version('-release'), ...
    'case_provenance', struct(), ...
    'context', struct());
end
