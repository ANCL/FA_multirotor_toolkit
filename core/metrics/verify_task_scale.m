function verification = verify_task_scale(A, parameters, solver, q)
%VERIFY_TASK_SCALE Independently check all prescribed task-box vertices.
%
% This LP-based verification is intended for selected designs, not for
% every optimizer evaluation.

[mu_min,mu_max] = parse_actuator_bounds( ...
    parameters.actuator_bounds,parameters.n_rotors);
[wrenches,signs] = task_vertices( ...
    parameters.hover_wrench,parameters.task.Lambda,q);
number_of_vertices = size(wrenches,2);
mu = nan(6,number_of_vertices);
exitflags = nan(number_of_vertices,1);
feasible = false(number_of_vertices,1);
if exist('linprog','file') ~= 2
    error('fa:MissingLinprog', ...
        'Optimization Toolbox linprog is required for task verification.');
end
options = optimoptions('linprog','Display','none');
for vertex = 1:number_of_vertices
    [candidate,~,exitflag] = linprog( ...
        zeros(6,1),[],[],A,wrenches(:,vertex), ...
        mu_min,mu_max,options);
    exitflags(vertex) = exitflag;
    if exitflag <= 0 || isempty(candidate)
        continue;
    end
    mu(:,vertex) = candidate;
    feasible(vertex) = norm(A*candidate-wrenches(:,vertex),Inf) <= ...
        solver.equality_tolerance*max(1,norm(wrenches(:,vertex),Inf)) && ...
        all(candidate >= mu_min-solver.bound_tolerance) && ...
        all(candidate <= mu_max+solver.bound_tolerance);
end
verification = struct( ...
    'q',q, ...
    'signs',signs, ...
    'wrenches',wrenches, ...
    'mu',mu, ...
    'exitflags',exitflags, ...
    'vertex_feasible',feasible, ...
    'all_feasible',all(feasible));
end

function [wrenches, signs] = task_vertices(hover_wrench, Lambda, scale)
%TASK_VERTICES Generate all 64 vertices of a six-dimensional task box.
%
% The vertices are hover_wrench + scale*Lambda*z for every sign vector
% z in {-1,+1}^6.

if nargin < 3
    scale = 1;
end
validateattributes(hover_wrench,{'numeric'}, ...
    {'real','finite','numel',6});
validateattributes(Lambda,{'numeric'}, ...
    {'real','finite','size',[6 6]});
validateattributes(scale,{'numeric'},{'real','finite','scalar'});
bits = dec2bin(0:63,6).'-'0';
signs = 2*bits-1;
wrenches = hover_wrench(:)+scale*Lambda*signs;
end
