function result = check_wrench_feasibility( ...
    A, actuator_bounds, w_desired, options)
%CHECK_WRENCH_FEASIBILITY Classify bounded feasibility of one wrench.
%
% Syntax
%   result = check_wrench_feasibility(A, actuator_bounds, w_desired)
%   result = check_wrench_feasibility(A, actuator_bounds, w_desired, options)
%
% Inputs
%   A                - 6-by-N force-before-moment allocation matrix.
%   actuator_bounds  - [lower upper] or N-by-2 bounds.
%   w_desired        - Six-element requested body-frame wrench.
%   options          - Optional structure with fields force_scale,
%                      length_scale, equality_tolerance,
%                      bound_tolerance, allocation_strategy, and
%                      analyze_allocation_set.
%
% Output
%   result.status is infeasible, feasible_unique, or feasible_multiple.
%   Infeasible requests include the closest bounded wrench. Redundant
%   feasible requests can use a maximum-margin allocation.

if nargin < 4
    options = struct();
end
options = complete_options(options);
validateattributes(A,{'numeric'},{'real','finite','nrows',6,'nonempty'});
n = size(A,2);
[mu_min,mu_max,bounds] = parse_actuator_bounds(actuator_bounds,n);
validateattributes(w_desired,{'numeric'},{'real','finite','numel',6});
w_desired = w_desired(:);
scale_matrix = wrench_scaling_matrix( ...
    options.force_scale,options.length_scale);
result = empty_result(n,w_desired,bounds,scale_matrix);

% The square full-rank case has one exact allocation and requires no LP.
if n == 6 && rank(A,options.equality_tolerance) == 6
    mu_exact = A\w_desired;
    residual = norm(A*mu_exact-w_desired,Inf);
    within_bounds = all(mu_exact >= mu_min-options.bound_tolerance) && ...
        all(mu_exact <= mu_max+options.bound_tolerance);
    if residual <= options.equality_tolerance*max(1,norm(w_desired,Inf)) && ...
            within_bounds
        result = populate_feasible_result( ...
            result,A,mu_exact,'feasible_unique',w_desired,bounds,scale_matrix);
        return;
    end
    result = populate_nearest_result( ...
        result,A,bounds,w_desired,scale_matrix);
    return;
end

if options.analyze_allocation_set
    allocation = describe_allocation_set( ...
        A,bounds,w_desired,scale_matrix,options.equality_tolerance);
else
    allocation = find_one_allocation( ...
        A,bounds,w_desired,scale_matrix,options.equality_tolerance);
end
result.allocation_set = allocation;
if ~allocation.feasible
    result = populate_nearest_result( ...
        result,A,bounds,w_desired,scale_matrix);
    return;
end

if allocation.is_unique
    result = populate_feasible_result(result,A,allocation.mu_particular, ...
        'feasible_unique',w_desired,bounds,scale_matrix);
    return;
end

switch lower(string(options.allocation_strategy))
    case "max_margin"
        result.margin_solution = maximize_saturation_margin( ...
            A,bounds,w_desired,scale_matrix,options.equality_tolerance);
        mu = result.margin_solution.mu;
    case "feasible"
        mu = allocation.mu_particular;
    otherwise
        error('fa:UnknownAllocationStrategy', ...
            'allocation_strategy must be max_margin or feasible.');
end
result = populate_feasible_result( ...
    result,A,mu,'feasible_multiple',w_desired,bounds,scale_matrix);
end

function result = empty_result(n,w_desired,bounds,scale_matrix)
result = struct( ...
    'status','infeasible', ...
    'feasible',false, ...
    'mu',nan(n,1), ...
    'w_requested',w_desired, ...
    'w_achieved',nan(6,1), ...
    'wrench_error',nan(6,1), ...
    'scaled_error',Inf, ...
    'nearest_mu',nan(n,1), ...
    'nearest_wrench',nan(6,1), ...
    'nearest_scaled_error',Inf, ...
    'actuator_margins',nan(n,1), ...
    'saturation_margin',NaN, ...
    'allocation_set',[], ...
    'margin_solution',[], ...
    'scale_matrix',scale_matrix, ...
    'actuator_bounds',bounds, ...
    'solver_status',struct());
end

function result = populate_feasible_result( ...
    result,A,mu,status,w_desired,bounds,scale_matrix)
result.status = status;
result.feasible = true;
result.mu = mu;
result.w_achieved = A*mu;
result.wrench_error = result.w_achieved-w_desired;
result.scaled_error = norm(scale_matrix*result.wrench_error,2);
result.actuator_margins = normalized_actuator_margins(mu,bounds);
result.saturation_margin = min(result.actuator_margins);
result.nearest_mu = mu;
result.nearest_wrench = result.w_achieved;
result.nearest_scaled_error = result.scaled_error;
end

function result = populate_nearest_result( ...
    result,A,bounds,w_desired,scale_matrix)
[mu,exitflag,output] = nearest_allocation( ...
    A,bounds,w_desired,scale_matrix);
result.mu = mu;
result.w_achieved = A*mu;
result.wrench_error = result.w_achieved-w_desired;
result.scaled_error = norm(scale_matrix*result.wrench_error,2);
result.nearest_mu = mu;
result.nearest_wrench = result.w_achieved;
result.nearest_scaled_error = result.scaled_error;
result.actuator_margins = normalized_actuator_margins(mu,bounds);
result.saturation_margin = min(result.actuator_margins);
result.solver_status.nearest_exitflag = exitflag;
result.solver_status.nearest_output = output;
end

function allocation = find_one_allocation( ...
    A,bounds,w_desired,scale_matrix,tolerance)
if exist('linprog','file') ~= 2
    error('fa:MissingLinprog', ...
        'Optimization Toolbox linprog is required for bounded allocation.');
end
n = size(A,2);
[mu_min,mu_max] = parse_actuator_bounds(bounds,n);
options = optimoptions('linprog','Display','none');
[mu,~,exitflag,output] = linprog(zeros(n,1),[],[], ...
    scale_matrix*A,scale_matrix*w_desired,mu_min,mu_max,options);
feasible = exitflag > 0 && ~isempty(mu) && ...
    norm(A*mu-w_desired,Inf) <= tolerance*max(1,norm(w_desired,Inf));
nullity = max(0,n-rank(A,tolerance));
allocation = struct( ...
    'feasible',feasible, ...
    'is_unique',feasible && nullity==0, ...
    'is_multiple',feasible && nullity>0, ...
    'mu_particular',mu, ...
    'null_basis',[], ...
    'nullity',nullity, ...
    'mu_min',[], ...
    'mu_max',[], ...
    'actuator_bounds',bounds, ...
    'equality_residual',Inf, ...
    'exitflag',exitflag, ...
    'solver_output',output);
if feasible
    allocation.equality_residual = norm(A*mu-w_desired,Inf);
end
end

function options = complete_options(options)
defaults = struct( ...
    'force_scale',1, ...
    'length_scale',1, ...
    'equality_tolerance',1e-8, ...
    'bound_tolerance',1e-9, ...
    'allocation_strategy','max_margin', ...
    'analyze_allocation_set',true);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(options,fields{k})
        options.(fields{k}) = defaults.(fields{k});
    end
end
end

function [mu,exitflag,output] = nearest_allocation( ...
    A,bounds,w_desired,scale_matrix)
if exist('lsqlin','file') ~= 2
    error('fa:MissingLsqlin', ...
        'Optimization Toolbox lsqlin is required for closest-wrench analysis.');
end
[mu_min,mu_max] = parse_actuator_bounds(bounds,size(A,2));
options = optimoptions('lsqlin','Display','none');
[mu,~,~,exitflag,output] = lsqlin( ...
    scale_matrix*A,scale_matrix*w_desired, ...
    [],[],[],[],mu_min,mu_max,[],options);
if exitflag <= 0 || isempty(mu)
    error('fa:ClosestWrenchFailed', ...
        'The bounded least-squares problem did not return a solution.');
end
end

function allocation = describe_allocation_set( ...
    A, actuator_bounds, w_desired, scale_matrix, tolerance)
%DESCRIBE_ALLOCATION_SET Characterize exact bounded wrench allocations.
%
% Syntax
%   allocation = describe_allocation_set( ...
%       A, actuator_bounds, w_desired, scale_matrix, tolerance)
%
% The function solves bounded linear programs to determine feasibility and
% the attainable interval of every actuator while reproducing w_desired.

validateattributes(A,{'numeric'},{'real','finite','nrows',6,'nonempty'});
n = size(A,2);
[mu_min,mu_max] = parse_actuator_bounds(actuator_bounds,n);
validateattributes(w_desired,{'numeric'},{'real','finite','numel',6});
validateattributes(scale_matrix,{'numeric'},{'real','finite','size',[6 6]});
validateattributes(tolerance,{'numeric'}, ...
    {'real','finite','scalar','positive'});
if exist('linprog','file') ~= 2
    error('fa:MissingLinprog', ...
        'Optimization Toolbox linprog is required for allocation-set analysis.');
end

Aeq = scale_matrix*A;
beq = scale_matrix*w_desired(:);
options = optimoptions('linprog','Display','none');
[mu0,~,exitflag,output] = linprog( ...
    zeros(n,1),[],[],Aeq,beq,mu_min,mu_max,options);

allocation = struct( ...
    'feasible',false, ...
    'is_unique',false, ...
    'is_multiple',false, ...
    'mu_particular',[], ...
    'null_basis',null(A), ...
    'nullity',n-rank(A), ...
    'mu_min',[], ...
    'mu_max',[], ...
    'actuator_bounds',[mu_min mu_max], ...
    'equality_residual',Inf, ...
    'exitflag',exitflag, ...
    'solver_output',output);
if exitflag <= 0 || isempty(mu0)
    return;
end

component_min = zeros(n,1);
component_max = zeros(n,1);
for actuator = 1:n
    c = zeros(n,1);
    c(actuator) = 1;
    [mu_low,~,flag_low] = linprog( ...
        c,[],[],Aeq,beq,mu_min,mu_max,options);
    [mu_high,~,flag_high] = linprog( ...
        -c,[],[],Aeq,beq,mu_min,mu_max,options);
    if flag_low <= 0 || flag_high <= 0
        error('fa:AllocationSetLPFailed', ...
            'Allocation-range LP failed for actuator %d.',actuator);
    end
    component_min(actuator) = mu_low(actuator);
    component_max(actuator) = mu_high(actuator);
end

range_tolerance = max(tolerance, ...
    1e-9*max(1,norm(mu_max-mu_min,Inf)));
allocation.feasible = true;
allocation.is_unique = all(component_max-component_min <= range_tolerance);
allocation.is_multiple = ~allocation.is_unique;
allocation.mu_particular = mu0(:);
allocation.mu_min = component_min;
allocation.mu_max = component_max;
allocation.equality_residual = norm(A*mu0-w_desired(:),Inf);
end

function margin = maximize_saturation_margin( ...
    A, actuator_bounds, w_desired, scale_matrix, tolerance)
%MAXIMIZE_SATURATION_MARGIN Find the exact allocation furthest from bounds.
%
% The linear program maximizes the minimum normalized distance from every
% lower and upper actuator limit while exactly reproducing w_desired.

validateattributes(A,{'numeric'},{'real','finite','nrows',6,'nonempty'});
n = size(A,2);
[mu_min,mu_max] = parse_actuator_bounds(actuator_bounds,n);
validateattributes(w_desired,{'numeric'},{'real','finite','numel',6});
validateattributes(scale_matrix,{'numeric'},{'real','finite','size',[6 6]});
validateattributes(tolerance,{'numeric'}, ...
    {'real','finite','scalar','positive'});
if exist('linprog','file') ~= 2
    error('fa:MissingLinprog', ...
        'Optimization Toolbox linprog is required for margin allocation.');
end

range = mu_max-mu_min;
f = [zeros(n,1); -1];
Aineq = [-eye(n), range; eye(n), range];
bineq = [-mu_min; mu_max];
Aeq = [scale_matrix*A, zeros(6,1)];
beq = scale_matrix*w_desired(:);
lower = [mu_min;0];
upper = [mu_max;0.5];
options = optimoptions('linprog','Display','none');
[x,~,exitflag,output] = linprog( ...
    f,Aineq,bineq,Aeq,beq,lower,upper,options);
if exitflag <= 0 || isempty(x)
    error('fa:MarginAllocationFailed', ...
        'Saturation-margin LP did not return a feasible allocation.');
end

mu = x(1:n);
actuator_margins = normalized_actuator_margins(mu,[mu_min mu_max]);
scaled_error = norm(scale_matrix*(A*mu-w_desired(:)),2);
if scaled_error > tolerance*max(1,norm(beq,2))
    error('fa:MarginAllocationResidual', ...
        'The margin-optimal allocation does not reproduce the wrench.');
end

margin = struct( ...
    'mu',mu, ...
    'value',min(actuator_margins), ...
    'actuator_margins',actuator_margins, ...
    'w_achieved',A*mu, ...
    'scaled_error',scaled_error, ...
    'exitflag',exitflag, ...
    'solver_output',output);
end
