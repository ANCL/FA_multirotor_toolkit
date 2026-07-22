function extrema = zero_moment_force_extrema( ...
    A_f, A_tau, actuator_bounds, component_names, tolerance)
%ZERO_MOMENT_FORCE_EXTREMA Exact component extrema under zero moment.
%
% Syntax
%   extrema = zero_moment_force_extrema( ...
%       A_f, A_tau, actuator_bounds)
%   extrema = zero_moment_force_extrema( ...
%       A_f, A_tau, actuator_bounds, component_names, tolerance)
%
% Inputs
%   A_f              - 3-by-N force allocation block.
%   A_tau            - 3-by-N moment allocation block.
%   actuator_bounds  - [lower upper] or N-by-2 actuator bounds.
%   component_names  - Optional three labels for the force components.
%   tolerance        - Optional equality-verification tolerance.
%
% Output
%   One table row per force component. Each row contains the exact minimum
%   and maximum value, the associated actuator input, and the complete
%   three-dimensional zero-moment force point.
%
% Each extremum is obtained through a bounded linear program with
% A_tau*mu = 0. Optimization Toolbox is required.

validateattributes(A_f,{'numeric'}, ...
    {'real','finite','nrows',3,'nonempty'});
validateattributes(A_tau,{'numeric'}, ...
    {'real','finite','size',size(A_f)});
number_of_actuators = size(A_f,2);
[mu_min,mu_max] = parse_actuator_bounds( ...
    actuator_bounds,number_of_actuators);
if nargin < 4 || isempty(component_names)
    component_names = {'F_x','F_y','F_z'};
end
component_names = string(component_names(:));
if numel(component_names) ~= 3
    error('fa:ComponentNameCount', ...
        'component_names must contain three force-component labels.');
end
if nargin < 5 || isempty(tolerance)
    tolerance = 1e-8;
end
validateattributes(tolerance,{'numeric'}, ...
    {'real','finite','scalar','positive'});
if exist('linprog','file') ~= 2
    error('fa:MissingLinprog', ...
        'Optimization Toolbox linprog is required for F_0 extrema.');
end

minimum_value = nan(3,1);
maximum_value = nan(3,1);
minimum_input = cell(3,1);
maximum_input = cell(3,1);
minimum_point = cell(3,1);
maximum_point = cell(3,1);
options = optimoptions('linprog','Display','none');

for component = 1:3
    objective = A_f(component,:).';
    [mu_low,value_low,flag_low] = linprog( ...
        objective,[],[],A_tau,zeros(3,1), ...
        mu_min,mu_max,options);
    [mu_high,negative_value_high,flag_high] = linprog( ...
        -objective,[],[],A_tau,zeros(3,1), ...
        mu_min,mu_max,options);
    if flag_low <= 0 || flag_high <= 0 || ...
            isempty(mu_low) || isempty(mu_high)
        error('fa:ZeroMomentExtremaFailed', ...
            'The F_0 extremum LP failed for component %s.', ...
            component_names(component));
    end
    if norm(A_tau*mu_low,Inf) > tolerance || ...
            norm(A_tau*mu_high,Inf) > tolerance
        error('fa:ZeroMomentExtremaResidual', ...
            'An F_0 extremum violates the zero-moment equality.');
    end
    minimum_value(component) = value_low;
    maximum_value(component) = -negative_value_high;
    minimum_input{component} = mu_low;
    maximum_input{component} = mu_high;
    minimum_point{component} = A_f*mu_low;
    maximum_point{component} = A_f*mu_high;
end

extrema = table(component_names,minimum_value,maximum_value, ...
    minimum_input,maximum_input,minimum_point,maximum_point, ...
    'VariableNames',{'component','minimum_value','maximum_value', ...
    'minimum_input','maximum_input','minimum_point','maximum_point'});
end
