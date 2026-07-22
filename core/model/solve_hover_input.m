function hover = solve_hover_input( ...
    A, actuator_bounds, hover_wrench, options)
%SOLVE_HOVER_INPUT Solve and verify a unique square hover allocation.
%
% Syntax
%   hover = solve_hover_input(A, actuator_bounds, hover_wrench)
%   hover = solve_hover_input(A, actuator_bounds, hover_wrench, options)
%
% This function is intended for a nonsingular 6-by-6 allocation matrix.
% Redundant hover allocation should use check_wrench_feasibility.

if nargin < 4
    options = struct();
end
options = complete_options(options);
validateattributes(A,{'numeric'},{'real','finite','size',[6 6]});
validateattributes(hover_wrench,{'numeric'}, ...
    {'real','finite','numel',6});
[mu_min,mu_max] = parse_actuator_bounds(actuator_bounds,6);

hover = struct( ...
    'mu',nan(6,1), ...
    'residual',Inf, ...
    'feasible',false, ...
    'effort',Inf, ...
    'margins',nan(6,1), ...
    'minimum_margin',-Inf, ...
    'failure_reason','');
if rcond(A) <= eps(class(A))
    hover.failure_reason = 'allocation matrix is singular';
    return;
end

hover.mu = A\hover_wrench(:);
hover.residual = norm(A*hover.mu-hover_wrench(:),Inf);
hover.margins = min(hover.mu-mu_min,mu_max-hover.mu);
hover.minimum_margin = min(hover.margins);
hover.feasible = hover.residual <= options.equality_tolerance* ...
    max(1,norm(hover_wrench,Inf)) && ...
    all(hover.mu >= mu_min-options.bound_tolerance) && ...
    all(hover.mu <= mu_max+options.bound_tolerance);
if hover.feasible
    hover.effort = sum(hover.mu.^2);
else
    hover.failure_reason = 'hover allocation violates equality or bounds';
end
end

function options = complete_options(options)
defaults = struct('equality_tolerance',1e-8,'bound_tolerance',1e-9);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(options,fields{k})
        options.(fields{k}) = defaults.(fields{k});
    end
end
end
