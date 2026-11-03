function result = optimize_design_sqp(problem, model, numerics, settings, seed)
%OPTIMIZE_DESIGN_SQP Multistart, constraint-aware SQP design optimization.
%
% Runs fmincon with the SQP algorithm from independent P1 starting points.
% Starts are sampled from unrestricted P1 coordinates; no P2/P3 structural
% seeds are used. Each local result is checked against the complete model.
%
% All four objectives are optimized directly in their 28-variable form.
% The force-authority objective is a minimum of actuator-bound distances,
% so its derivative can be nonsmooth where limiting actuator bounds tie.
% SQP uses finite-difference gradients; no analytic derivatives are claimed.

if exist('fmincon', 'file') ~= 2
    error('fa:MissingFmincon', ...
        'Multistart SQP requires Optimization Toolbox (fmincon).');
end
validateattributes(seed, {'numeric'}, ...
    {'real', 'finite', 'scalar', 'integer', 'positive'});

lb = problem.lower_bounds(:);
ub = problem.upper_bounds(:);
n = numel(lb);
number_of_starts = settings.sqp.starts;
validateattributes(number_of_starts, {'numeric'}, ...
    {'real', 'finite', 'scalar', 'integer', 'positive'});
if any(lb >= ub)
    error('fa:VariableBounds', 'Invalid optimization-variable bounds.');
end

rng(seed, 'twister');
clock = tic;
[starts, feasible_start_count, draw_count] = ...
    sample_p1_starts(problem, model, numerics, settings, number_of_starts);

% An fmincon run is local; the independent starts are executed serially
% inside this case because the study parallelizes independent cases.
options = optimoptions('fmincon', ...
    'Algorithm', 'sqp', ...
    'Display', 'off', ...
    'MaxIterations', settings.sqp.max_iterations, ...
    'MaxFunctionEvaluations', settings.sqp.max_function_evaluations, ...
    'OptimalityTolerance', settings.sqp.optimality_tolerance, ...
    'StepTolerance', settings.sqp.step_tolerance, ...
    'ConstraintTolerance', settings.constraint_tolerance, ...
    'FiniteDifferenceType', 'forward', ...
    'UseParallel', false);

% Optimize the original scientific objective directly, including r_F0.
% No auxiliary radius and no analytical-performance bound are imposed.
sqp_lb = lb;
sqp_ub = ub;
objective = @(x) design_objective(x, problem, model);
constraints = @(x) design_constraints(x, problem, model, numerics);

local_template = struct('start_x', [], 'x', [], 'exitflag', NaN, ...
    'valid', false, 'objective_value', NaN, ...
    'maximum_constraint_violation', Inf, 'function_evaluations', NaN, ...
    'iterations', NaN, 'message', '');
local_runs = repmat(local_template, number_of_starts, 1);
best = struct([]);

for k = 1:number_of_starts
    x0 = starts(:, k);
    initial = evaluate_candidate(x0, NaN, 'initial', ...
        problem, model, numerics, settings);
    if isempty(best) || prefer_candidate(initial, best)
        best = initial;
    end
    local_runs(k).start_x = x0;

    y0 = x0;

    try
        [y, ~, exitflag, output] = fmincon(objective, y0, ...
            [], [], [], [], sqp_lb, sqp_ub, constraints, options);
        x = y(1:n);
        candidate = evaluate_candidate(x, exitflag, 'sqp', ...
            problem, model, numerics, settings);

        local_runs(k).x = x;
        local_runs(k).exitflag = exitflag;
        local_runs(k).valid = candidate.valid;
        local_runs(k).objective_value = candidate.objective_value;
        local_runs(k).maximum_constraint_violation = ...
            candidate.maximum_constraint_violation;
        if isfield(output, 'funcCount')
            local_runs(k).function_evaluations = output.funcCount;
        end
        if isfield(output, 'iterations')
            local_runs(k).iterations = output.iterations;
        end
        if isfield(output, 'message')
            local_runs(k).message = output.message;
        end
        if prefer_candidate(candidate, best)
            best = candidate;
        end
    catch exception
        % Preserve a failed start's diagnostic; the remaining starts still run.
        local_runs(k).message = sprintf('%s: %s', ...
            exception.identifier, exception.message);
    end
end

geometry = decode_design(best.x, problem);
metrics = evaluate_design(geometry, model, numerics);
[c, ~] = design_constraints(best.x, problem, model, numerics);
maximum_violation = max([0; c(:)]);
valid = metrics.valid && maximum_violation <= settings.constraint_tolerance;
if valid
    scientific_value = metrics.(problem.objective);
    failure_reason = '';
else
    scientific_value = NaN;
    failure_reason = metrics.failure_reason;
    if isempty(failure_reason)
        failure_reason = 'SQP returned no scientifically feasible design.';
    end
end

result = struct( ...
    'problem', problem, 'model', model, 'numerics', numerics, ...
    'settings', settings, 'seed', seed, 'matlab_release', version('-release'), ...
    'parameterization', problem.parameterization, ...
    'normalization_group', problem.normalization_group, ...
    'objective', problem.objective, 'objective_value', scientific_value, ...
    'solver_cost', best.cost, 'valid', valid, ...
    'failure_reason', failure_reason, ...
    'maximum_constraint_violation', maximum_violation, ...
    'design_variables', best.x, 'geometry', geometry, 'metrics', metrics, ...
    'selected_solver', best.source, 'elapsed_seconds', toc(clock), ...
    'sqp', struct('best_exitflag', best.exitflag, ...
        'requested_starts', number_of_starts, ...
        'feasible_initial_starts', feasible_start_count, ...
        'initial_draws', draw_count, 'local_runs', local_runs));
end

function [starts, feasible_count, draws] = sample_p1_starts( ...
        problem, model, numerics, settings, number_of_starts)
%SAMPLE_P1_STARTS Prefer feasible unrestricted starts, without P2/P3 seeds.
lb = problem.lower_bounds(:);
ub = problem.upper_bounds(:);
n = numel(lb);
starts = zeros(n, number_of_starts);
feasible_count = 0;
draws = 0;

% Typically very few uniform P1 geometries are hover-feasible. Sample
% enough to obtain diverse feasible local starts without a second optimizer.
max_draws = max(2000, 750 * number_of_starts);
while feasible_count < number_of_starts && draws < max_draws
    draws = draws + 1;
    x = lb + (ub - lb) .* rand(n, 1);
    [c, ~] = design_constraints(x, problem, model, numerics);
    if any(c > settings.constraint_tolerance)
        continue;
    end
    geometry = decode_design(x, problem);
    metrics = evaluate_design(geometry, model, numerics);
    if ~metrics.valid
        continue;
    end
    feasible_count = feasible_count + 1;
    starts(:, feasible_count) = x;
end

% If the feasible rejection sampler found too few designs, still execute
% the requested number of local searches from unrestricted random points.
% SQP can sometimes restore feasibility from an infeasible initial point.
for k = feasible_count+1:number_of_starts
    starts(:, k) = lb + (ub - lb) .* rand(n, 1);
end
end

function candidate = evaluate_candidate(x, exitflag, source, ...
        problem, model, numerics, settings)
x = x(:);
[c, ~] = design_constraints(x, problem, model, numerics);
maximum_violation = max([0; c(:)]);
geometry = decode_design(x, problem);
metrics = evaluate_design(geometry, model, numerics);
valid = metrics.valid && maximum_violation <= settings.constraint_tolerance;
value = NaN;
if valid, value = metrics.(problem.objective); end
candidate = struct('x', x, ...
    'cost', design_objective(x, problem, model), ...
    'objective_value', value, ...
    'maximum_constraint_violation', maximum_violation, ...
    'valid', valid, 'source', source, 'exitflag', exitflag);
end

function yes = prefer_candidate(a, b)
%PREFER_CANDIDATE Scientific feasibility comes before solver cost.
if a.valid ~= b.valid
    yes = a.valid;
elseif a.valid
    yes = a.cost < b.cost;
elseif a.maximum_constraint_violation ~= b.maximum_constraint_violation
    yes = a.maximum_constraint_violation < b.maximum_constraint_violation;
else
    yes = a.cost < b.cost;
end
end
