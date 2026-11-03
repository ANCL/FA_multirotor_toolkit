function result = optimize_design(problem, model, numerics, settings, seed)
%OPTIMIZE_DESIGN Run one GA search followed by patternsearch refinement.
%
% Each call represents one independent case/repeat. Geometric and hover
% constraints are explicit. A candidate is eligible as the returned optimum
% only when it also passes the complete scientific metric evaluation.
%
% Input
%   problem  - make_design_problem output; may contain initial_designs.
%   model    - Physical assumptions (default_model).
%   numerics - Tolerances (default_numerics).
%   settings - Solver budget (default_optimization_settings).
%   seed     - Positive integer random seed for this independent run.
if nargin < 2 || isempty(model), model = default_model(); end
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
if nargin < 4 || isempty(settings)
    settings = default_optimization_settings(problem.parameterization);
end
if nargin < 5 || isempty(seed), seed = 1; end
validateattributes(seed, {'numeric'}, {'real', 'finite', 'scalar', 'integer', 'positive'});
if exist('ga', 'file') ~= 2 || exist('patternsearch', 'file') ~= 2
    error('fa:MissingToolbox', 'GA and patternsearch require Global Optimization Toolbox.');
end
lb = problem.lower_bounds(:);
ub = problem.upper_bounds(:);
n = numel(lb);
if any(lb >= ub) || ~isequal(size(lb), size(ub))
    error('fa:VariableBounds', 'Invalid optimization variable bounds.');
end
starts = problem.initial_designs;
if isempty(starts), starts = zeros(0, n); end
if size(starts, 2) ~= n || any(~isfinite(starts), 'all') || ...
        any(starts < lb.' - 1e-10, 'all') || any(starts > ub.' + 1e-10, 'all')
    error('fa:InitialDesigns', 'Initial designs must be finite in-bounds row vectors.');
end
starts = unique(starts, 'rows', 'stable');
initial_population = [];
if ~isempty(starts), initial_population = starts; end
if size(starts, 1) > settings.ga.population_size
    error('fa:InitialPopulationSize', ...
        'Initial designs exceed the configured GA population size.');
end
objective = @(x) design_objective(x, problem, model);
constraints = @(x) design_constraints(x, problem, model, numerics);
clock = tic;
rng(seed, 'twister');

options = optimoptions('ga', 'Display', 'off', ...
    'PopulationSize', settings.ga.population_size, ...
    'MaxGenerations', settings.ga.max_generations, ...
    'MaxStallGenerations', settings.ga.max_stall_generations, ...
    'FunctionTolerance', settings.ga.function_tolerance, ...
    'ConstraintTolerance', settings.constraint_tolerance, ...
    'NonlinearConstraintAlgorithm', settings.ga.nonlinear_constraint_algorithm, ...
    'InitialPenalty', settings.ga.initial_penalty, ...
    'PenaltyFactor', settings.ga.penalty_factor, ...
    'InitialPopulationMatrix', initial_population, ...
    'UseParallel', settings.use_parallel);

[x_ga, ~, ga_exitflag, ga_output, population, scores] = ga( ...
    objective, n, [], [], [], [], lb, ub, constraints, options);

% Evaluate the GA output, all supplied seeds, and the final population.
% GA scores may include penalties; never select scientific optima by score.
candidates = candidate_record(x_ga, 'ga', ga_exitflag, ...
    objective, constraints, problem, model, numerics, settings);
for k = 1:size(starts, 1)
    candidates(end+1) = candidate_record(starts(k, :).', 'initial', NaN, ...
        objective, constraints, problem, model, numerics, settings); %#ok<AGROW>
end
for k = 1:size(population, 1)
    candidates(end+1) = candidate_record(population(k, :).', 'population', NaN, ...
        objective, constraints, problem, model, numerics, settings); %#ok<AGROW>
end
best = 1;
for k = 2:numel(candidates)
    if prefer_candidate(candidates(k), candidates(best))
        best = k;
    end
end

local_runs = struct('start_x', {}, 'x', {}, 'exitflag', {}, ...
    'valid', {}, 'objective_value', {}, 'maximum_constraint_violation', {});
local_options = optimoptions('patternsearch', 'Display', 'off', ...
    'MaxFunctionEvaluations', settings.patternsearch.max_function_evaluations, ...
    'FunctionTolerance', settings.patternsearch.function_tolerance, ...
    'MeshTolerance', settings.patternsearch.mesh_tolerance, ...
    'ConstraintTolerance', settings.constraint_tolerance, ...
    'UseParallel', settings.use_parallel);

% Local searches start from the best available candidate, then distinct
% alternatives. This retains valid seeds even when GA discards them.
ordered = candidate_order(candidates);
local_starts = zeros(0, n);
scale = max(ub - lb, eps);
for index = ordered
    x = candidates(index).x(:).';
    if isempty(local_starts) || ...
            all(max(abs((local_starts - x) ./ scale.'), [], 2) ...
                >= settings.local_start_min_distance)
        local_starts(end+1, :) = x; %#ok<AGROW>
    end
    if size(local_starts, 1) >= settings.local_refinements
        break;
    end
end
for k = 1:size(local_starts, 1)
    x_start = local_starts(k, :).';
    [x_local, ~, exitflag] = patternsearch(objective, x_start, ...
        [], [], [], [], lb, ub, constraints, local_options);
    candidate = candidate_record(x_local, 'patternsearch', exitflag, ...
        objective, constraints, problem, model, numerics, settings);
    local_runs(k) = struct('start_x', x_start, 'x', x_local, ...
        'exitflag', exitflag, 'valid', candidate.valid, ...
        'objective_value', candidate.objective_value, ...
        'maximum_constraint_violation', candidate.maximum_constraint_violation);
    candidates(end+1) = candidate; %#ok<AGROW>
    if prefer_candidate(candidate, candidates(best))
        best = numel(candidates);
    end
end

selected = candidates(best);
geometry = decode_design(selected.x, problem);
metrics = evaluate_design(geometry, model, numerics);
[c, ~] = constraints(selected.x);
maximum_violation = max([0; c(:)]);
valid = metrics.valid && maximum_violation <= settings.constraint_tolerance;
if valid
    objective_value = metrics.(problem.objective);
else
    objective_value = NaN;
end
result = struct( ...
    'problem', problem, 'model', model, 'numerics', numerics, ...
    'settings', settings, 'seed', seed, 'matlab_release', version('-release'), ...
    'parameterization', problem.parameterization, ...
    'normalization_group', problem.normalization_group, ...
    'objective', problem.objective, 'objective_value', objective_value, ...
    'solver_cost', selected.cost, ...
    'valid', valid, 'failure_reason', metrics.failure_reason, ...
    'maximum_constraint_violation', maximum_violation, ...
    'design_variables', selected.x, 'geometry', geometry, 'metrics', metrics, ...
    'selected_solver', selected.origin, 'elapsed_seconds', toc(clock), ...
    'ga', struct('exitflag', ga_exitflag, 'output', ga_output, ...
                 'final_population', population, 'final_scores', scores), ...
    'local_runs', local_runs);
if ~valid && isempty(result.failure_reason)
    result.failure_reason = 'Numerical constraints were not met.';
end
end

function candidate = candidate_record(x, origin, exitflag, objective, ...
        constraints, problem, model, numerics, settings)
x = x(:);
[c, ~] = constraints(x);
violation = max([0; c(:)]);
geometry = decode_design(x, problem);
metrics = evaluate_design(geometry, model, numerics);
valid = metrics.valid && violation <= settings.constraint_tolerance;
value = NaN;
if valid, value = metrics.(problem.objective); end
candidate = struct('x', x, 'cost', objective(x), 'objective_value', value, ...
    'maximum_constraint_violation', violation, 'valid', valid, ...
    'origin', origin, 'exitflag', exitflag);
end

function take = prefer_candidate(a, b)
% Prefer feasibility, then scientific cost; otherwise least violation.
if a.valid ~= b.valid
    take = a.valid;
elseif a.valid
    take = a.cost < b.cost;
else
    if a.maximum_constraint_violation ~= b.maximum_constraint_violation
        take = a.maximum_constraint_violation < b.maximum_constraint_violation;
    else
        take = a.cost < b.cost;
    end
end
end

function order = candidate_order(candidates)
% Sort by repeated feasibility-aware selection (usually <= 400 records).
order = 1:numel(candidates);
for i = 1:numel(order)
    best = i;
    for j = i+1:numel(order)
        if prefer_candidate(candidates(order(j)), candidates(order(best)))
            best = j;
        end
    end
    order([i best]) = order([best i]);
end
end
