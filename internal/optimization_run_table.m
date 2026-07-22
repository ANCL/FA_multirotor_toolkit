function T = optimization_run_table(results)
%OPTIMIZATION_RUN_TABLE Human-readable summary of saved optimization runs.

if isempty(results)
    T = table();
    return;
end

n = numel(results);
case_name = strings(n, 1);
objective = strings(n, 1);
parameterization = strings(n, 1);
normalization_case = nan(n, 1);
seed = nan(n, 1);
valid = false(n, 1);
global_exit_flag = nan(n, 1);
global_generations = nan(n, 1);
global_evaluation_count = nan(n, 1);
global_termination_message = strings(n, 1);
global_solver_cost = nan(n, 1);
global_objective_value = nan(n, 1);
global_valid = false(n,1);
global_constraint_violation = nan(n,1);
selected_solver = strings(n, 1);
selected_constraint_violation = nan(n,1);
exit_flag = nan(n, 1);
selected_termination_message = strings(n, 1);
solver_cost = nan(n, 1);
objective_value = nan(n, 1);
local_improvement = nan(n, 1);
maximum_constraint_violation = nan(n, 1);
evaluation_count = nan(n, 1);
elapsed_seconds = nan(n, 1);
failure_reason = strings(n, 1);

for k = 1:n
    result = results(k);

    case_name(k) = string(result.case_name);
    objective(k) = string(result.objective_name);
    parameterization(k) = string(result.parameterization);
    normalization_case(k) = result.normalization_case;
    seed(k) = result.seed;
    valid(k) = result.valid;
    global_exit_flag(k) = result.global_exit_flag;

    if isfield(result.global_solver_output, 'generations')
        global_generations(k) = ...
            result.global_solver_output.generations;
    end

    if isfield(result, 'global_evaluation_count')
        global_evaluation_count(k) = result.global_evaluation_count;
    elseif isfield(result.global_solver_output, 'funccount')
        global_evaluation_count(k) = ...
            result.global_solver_output.funccount;
    end

    global_termination_message(k) = ...
        output_message(result.global_solver_output);

    if isfield(result, 'global_objective_value')
        global_solver_cost(k) = result.global_objective_value;
    end
    if isfield(result,'global_reported_objective_value')
        global_objective_value(k) = result.global_reported_objective_value;
    elseif isfield(result,'metrics') && isfield(result.metrics,char(string(result.objective_name)))
        global_objective_value(k) = result.metrics.(char(string(result.objective_name)));
    end
    if isfield(result,'global_valid'), global_valid(k) = result.global_valid; end
    if isfield(result,'global_constraint_violation')
        global_constraint_violation(k) = result.global_constraint_violation;
    end

    selected_solver(k) = string(result.selected_solver);
    if isfield(result,'selected_constraint_violation')
        selected_constraint_violation(k) = result.selected_constraint_violation;
    else
        selected_constraint_violation(k) = result.constraints.maximum_violation;
    end
    exit_flag(k) = result.exit_flag;
    selected_termination_message(k) = output_message(result.solver_output);
    solver_cost(k) = result.objective_value;
    if isfield(result,'reported_objective_value')
        objective_value(k) = result.reported_objective_value;
    elseif isfield(result,'metrics') && isfield(result.metrics,char(string(result.objective_name)))
        objective_value(k) = result.metrics.(char(string(result.objective_name)));
    end

    if isfield(result, 'local_improvement')
        local_improvement(k) = result.local_improvement;
    end

    maximum_constraint_violation(k) = ...
        result.constraints.maximum_violation;
    evaluation_count(k) = result.evaluation_count;
    elapsed_seconds(k) = result.elapsed_seconds;
    failure_reason(k) = string(result.failure_reason);
end

T = table( ...
    case_name, objective, parameterization, normalization_case, seed, valid, ...
    global_exit_flag, global_generations, global_evaluation_count, ...
    global_termination_message, global_solver_cost, global_objective_value, ...
    global_valid, global_constraint_violation, ...
    selected_solver, selected_constraint_violation, exit_flag, ...
    selected_termination_message, ...
    solver_cost, objective_value, local_improvement, ...
    maximum_constraint_violation, evaluation_count, ...
    elapsed_seconds, failure_reason);
end


function message = output_message(output)
message = "";
if isstruct(output) && isfield(output, 'message') && ...
        ~isempty(output.message)
    message = string(output.message);
end
end
