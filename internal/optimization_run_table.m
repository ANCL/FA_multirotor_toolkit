function T = optimization_run_table(results)
%OPTIMIZATION_RUN_TABLE Human-readable compact summary of optimization runs.
% Accepts either full solver results or permanent compact checkpoint records.

if isempty(results)
    T = table();
    return;
end

n = numel(results);
case_name = strings(n, 1);
objective = strings(n, 1);
analysis = strings(n,1);
physical_parameter = strings(n,1);
parameter_value = nan(n,1);
authority_threshold = nan(n,1);
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
r_F0 = nan(n,1);
sigma_min = nan(n,1);
condition_number = nan(n,1);
hover_effort = nan(n,1);



for k = 1:n
    result = results(k);
    case_name(k) = string(result.case_name);
    objective(k) = string(result.objective_name);
    if isfield(result,'context') && isstruct(result.context)
        if isfield(result.context,'analysis'), analysis(k) = string(result.context.analysis); end
        if isfield(result.context,'physical_parameter'), physical_parameter(k) = string(result.context.physical_parameter); end
        if isfield(result.context,'physical_value'), parameter_value(k) = result.context.physical_value; end
        if isfield(result.context,'authority_threshold'), authority_threshold(k) = result.context.authority_threshold; end
    end
    parameterization(k) = string(result.parameterization);
    normalization_case(k) = result.normalization_case;
    seed(k) = result.seed;
    valid(k) = logical(result.valid);
    global_exit_flag(k) = numeric_field(result,'global_exit_flag');
    global_generations(k) = numeric_or_nested( ...
        result,'global_generations','global_solver_output','generations');
    global_evaluation_count(k) = numeric_or_nested( ...
        result,'global_evaluation_count','global_solver_output','funccount');
    global_termination_message(k) = text_or_nested( ...
        result,'global_termination_message','global_solver_output','message');
    global_solver_cost(k) = numeric_field(result,'global_objective_value');
    if isfield(result,'global_reported_objective_value')
        global_objective_value(k) = result.global_reported_objective_value;
    elseif isfield(result,'metrics') && isfield(result.metrics,char(string(result.objective_name)))
        global_objective_value(k) = result.metrics.(char(string(result.objective_name)));
    end
    if isfield(result,'global_valid'), global_valid(k) = logical(result.global_valid); end
    global_constraint_violation(k) = numeric_field(result,'global_constraint_violation');
    selected_solver(k) = string(text_field(result,'selected_solver'));
    if isfield(result,'selected_constraint_violation')
        selected_constraint_violation(k) = result.selected_constraint_violation;
    elseif isfield(result,'constraints') && isfield(result.constraints,'maximum_violation')
        selected_constraint_violation(k) = result.constraints.maximum_violation;
    end
    exit_flag(k) = numeric_field(result,'exit_flag');
    selected_termination_message(k) = text_or_nested( ...
        result,'selected_termination_message','solver_output','message');
    solver_cost(k) = numeric_field(result,'objective_value');
    if isfield(result,'reported_objective_value')
        objective_value(k) = result.reported_objective_value;
    elseif isfield(result,'metrics') && isfield(result.metrics,char(string(result.objective_name)))
        objective_value(k) = result.metrics.(char(string(result.objective_name)));
    end
    local_improvement(k) = numeric_field(result,'local_improvement');
    if isfield(result,'constraints') && isfield(result.constraints,'maximum_violation')
        maximum_constraint_violation(k) = result.constraints.maximum_violation;
    end
    evaluation_count(k) = numeric_field(result,'evaluation_count');
    elapsed_seconds(k) = numeric_field(result,'elapsed_seconds');
    failure_reason(k) = string(text_field(result,'failure_reason'));
    if isfield(result,'metrics') && isstruct(result.metrics)
        if isfield(result.metrics,'r_F0'), r_F0(k) = result.metrics.r_F0; end
        if isfield(result.metrics,'sigma_min'), sigma_min(k) = result.metrics.sigma_min; end
        if isfield(result.metrics,'condition_number'), condition_number(k) = result.metrics.condition_number; end
        if isfield(result.metrics,'hover_effort'), hover_effort(k) = result.metrics.hover_effort; end
    end
end

T = table( ...
    case_name, objective, analysis, physical_parameter, parameter_value, ...
    authority_threshold, parameterization, normalization_case, seed, valid, ...
    global_exit_flag, global_generations, global_evaluation_count, ...
    global_termination_message, global_solver_cost, global_objective_value, ...
    global_valid, global_constraint_violation, ...
    selected_solver, selected_constraint_violation, exit_flag, ...
    selected_termination_message, ...
    solver_cost, objective_value, local_improvement, ...
    maximum_constraint_violation, evaluation_count, ...
    elapsed_seconds, r_F0, sigma_min, condition_number, hover_effort, ...
    failure_reason);
end

function value = numeric_field(s,name)
value = NaN;
if isfield(s,name) && isnumeric(s.(name)) && isscalar(s.(name))
    value = s.(name);
end
end

function value = numeric_or_nested(s,direct,nested,nested_name)
value = numeric_field(s,direct);
if isfinite(value), return; end
if isfield(s,nested) && isstruct(s.(nested)) && ...
        isfield(s.(nested),nested_name) && ...
        isnumeric(s.(nested).(nested_name)) && isscalar(s.(nested).(nested_name))
    value = s.(nested).(nested_name);
end
end

function value = text_field(s,name)
value = '';
if isfield(s,name) && ~isempty(s.(name)), value = char(string(s.(name))); end
end

function value = text_or_nested(s,direct,nested,nested_name)
value = text_field(s,direct);
if ~isempty(value), return; end
if isfield(s,nested) && isstruct(s.(nested)) && ...
        isfield(s.(nested),nested_name) && ~isempty(s.(nested).(nested_name))
    value = char(string(s.(nested).(nested_name)));
end
end
