function metrics = evaluate_design(geometry, parameters, solver, options)
%EVALUATE_DESIGN Compute all study metrics through one shared pathway.
% By default every metric is computed. Optimization may request only the
% expensive metric needed by its current objective; every returned optimum is
% then reevaluated here with the complete default pathway.
if nargin < 4, options = struct(); end
options = complete_options(options);

metrics = empty_metrics();
metrics.geometry = geometry;
metrics.evaluation_options = options;
normalization_case = [];
if isfield(geometry,'normalization_case'), normalization_case = geometry.normalization_case; end
metrics.geometry_check = check_geometry(geometry.p,geometry.u,parameters, ...
    solver,normalization_case,options);
metrics.constraint_margins.geometry = [metrics.geometry_check.length_lower_margin; ...
    metrics.geometry_check.length_upper_margin; metrics.geometry_check.normalization_margin; ...
    metrics.geometry_check.unit_direction_margin; metrics.geometry_check.separation_margin];
if ~metrics.geometry_check.valid
    metrics.failure_reason = 'geometric admissibility failed';
    return;
end

[metrics.A,metrics.A_f,metrics.A_tau] = allocation_matrix(geometry.p,geometry.u, ...
    parameters.kappa,parameters.reaction_signs);
[metrics.A_bar,metrics.scale_matrix] = normalized_allocation_matrix( ...
    metrics.A,parameters.force_moment_length);
metrics.singular_values = svd(metrics.A_bar);
metrics.sigma_min = metrics.singular_values(end);
metrics.condition_number = metrics.singular_values(1)/metrics.sigma_min;
metrics.algebraic_rank = rank(metrics.A);
metrics.numerically_fully_actuated = metrics.sigma_min >= ...
    solver.full_actuation_threshold;
metrics.constraint_margins.full_actuation = metrics.sigma_min - ...
    solver.full_actuation_threshold;
if ~metrics.numerically_fully_actuated
    metrics.condition_number = Inf;
    metrics.failure_reason = 'numerical full-actuation threshold failed';
    return;
end

metrics.hover = solve_hover_input( ...
    metrics.A,parameters.actuator_bounds,parameters.hover_wrench, ...
    struct('equality_tolerance',solver.equality_tolerance, ...
    'bound_tolerance',solver.bound_tolerance));
metrics.mu_hover = metrics.hover.mu;
metrics.hover_effort = metrics.hover.effort;
metrics.hover_feasible = metrics.hover.feasible;
metrics.constraint_margins.hover = metrics.hover.minimum_margin;
if ~metrics.hover_feasible
    metrics.failure_reason = 'hover is infeasible';
    return;
end

if options.compute_force_authority
    metrics.force_authority = zero_moment_force_authority( ...
        metrics.A,parameters.actuator_bounds,parameters.hover_wrench(1:3),solver);
    metrics.r_F0 = metrics.force_authority.radius;
    metrics.hover_force_in_F0 = metrics.force_authority.inside;
    if ~metrics.force_authority.valid
        metrics.failure_reason = metrics.force_authority.failure_reason;
        return;
    end
    metrics.force_authority_computed = true;
end

if options.compute_task_scale
    metrics.task = task_scale(metrics.A,parameters,solver);
    metrics.q_star = metrics.task.q_star;
    metrics.task_feasible = metrics.task.valid && ...
        metrics.q_star >= 1-solver.task_tolerance;
    if ~metrics.task.valid
        metrics.failure_reason = metrics.task.failure_reason;
        return;
    end
    metrics.task_scale_computed = true;
end

metrics.valid = true;
metrics.failure_reason = '';
end

function options = complete_options(options)
defaults = struct('compute_force_authority',true,'compute_task_scale',true, ...
    'enforce_normalization',true,'enforce_upper_length',true);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(options,fields{k}), options.(fields{k}) = defaults.(fields{k}); end
end
end

function metrics = empty_metrics()
metrics = struct('geometry',[],'evaluation_options',struct(),'geometry_check',[], ...
    'A',nan(6),'A_f',nan(3,6),'A_tau',nan(3,6),'A_bar',nan(6), ...
    'scale_matrix',nan(6),'singular_values',nan(6,1),'sigma_min',-Inf, ...
    'condition_number',Inf,'algebraic_rank',0, ...
    'numerically_fully_actuated',false,'hover',[],'mu_hover',nan(6,1), ...
    'hover_effort',Inf,'hover_feasible',false,'F0',[], ...
    'force_authority',struct(),'r_F0',-Inf, ...
    'hover_force_in_F0',false,'F0_facet_gaps',[], ...
    'force_authority_computed',false,'task',[],'q_star',-Inf, ...
    'task_feasible',false,'task_scale_computed',false, ...
    'constraint_margins',struct(),'valid',false,'failure_reason','', ...
    'internal_error_identifier','');
end
