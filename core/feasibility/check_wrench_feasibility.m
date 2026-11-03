function result = check_wrench_feasibility(A, model, wrench, numerics)
%CHECK_WRENCH_FEASIBILITY Find an actuator input reproducing a desired wrench.
%
% Square full-rank systems use direct allocation. Redundant/deficient maps
% use linprog; infeasible requests use bounded least squares (lsqlin).
% Optimization Toolbox is needed only for the latter cases.
if nargin < 4 || isempty(numerics), numerics = default_numerics(); end
validateattributes(A, {'numeric'}, {'real', 'finite', 'nrows', 6, 'nonempty'});
validateattributes(wrench, {'numeric'}, {'real', 'finite', 'numel', 6});
wrench = wrench(:);
n = size(A, 2);
[lower, upper] = parse_actuator_bounds(model.actuator_bounds, n);
result = struct('feasible', false, 'status', 'infeasible', ...
    'mu', nan(n, 1), 'wrench_requested', wrench, ...
    'wrench_achieved', nan(6, 1), 'residual', Inf, ...
    'minimum_margin', -Inf, 'solver_exitflag', NaN);
tol = numerics.equality_tolerance * max(1, norm(wrench, Inf));
if n == 6 && rank(A) == 6
    mu = A \ wrench;
    feasible = norm(A * mu - wrench, Inf) <= tol && ...
        all(mu >= lower - numerics.bound_tolerance) && ...
        all(mu <= upper + numerics.bound_tolerance);
    if feasible
        result = finish_result(result, A, wrench, mu, lower, upper, 'feasible_unique', NaN);
        return;
    end
else
    if exist('linprog', 'file') ~= 2
        error('fa:MissingLinprog', 'Non-square allocation requires linprog.');
    end
    options = optimoptions('linprog', 'Display', 'none');
    [mu, ~, flag] = linprog(zeros(n, 1), [], [], A, wrench, ...
        lower, upper, options);
    if flag > 0 && ~isempty(mu) && norm(A * mu - wrench, Inf) <= tol
        % Positive nullity does not alone prove that bounds permit multiple
        % allocations. Report existence without asserting nonuniqueness.
        result = finish_result(result, A, wrench, mu, lower, upper, 'feasible', flag);
        return;
    end
end
if exist('lsqlin', 'file') ~= 2
    error('fa:MissingLsqlin', 'Closest bounded wrench requires lsqlin.');
end
options = optimoptions('lsqlin', 'Display', 'none');
[mu, ~, ~, flag] = lsqlin(A, wrench, [], [], [], [], ...
    lower, upper, [], options);
if isempty(mu) || flag <= 0
    error('fa:ClosestWrenchFailed', 'Bounded least-squares allocation failed.');
end
result = finish_result(result, A, wrench, mu, lower, upper, 'infeasible', flag);
end

function result = finish_result(result, A, wrench, mu, lower, upper, status, flag)
result.status = status;
result.feasible = ~strcmp(status, 'infeasible');
result.mu = mu;
result.wrench_achieved = A * mu;
result.residual = norm(result.wrench_achieved - wrench, Inf);
result.minimum_margin = min(min(mu - lower, upper - mu));
result.solver_exitflag = flag;
end
