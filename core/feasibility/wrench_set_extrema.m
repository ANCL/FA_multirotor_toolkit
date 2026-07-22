function extrema = wrench_set_extrema(A_sub, actuator_bounds, component_names)
%WRENCH_SET_EXTREMA Exact componentwise extrema of a linear-image set.
%
% Syntax
%   extrema = wrench_set_extrema(A_sub, actuator_bounds)
%   extrema = wrench_set_extrema(A_sub, actuator_bounds, component_names)
%
% For each row of A_sub, the minimizing and maximizing actuator inputs are
% selected directly from the box bounds according to coefficient signs.

validateattributes(A_sub,{'numeric'},{'real','finite','nonempty'});
n = size(A_sub,2);
[mu_min,mu_max] = parse_actuator_bounds(actuator_bounds,n);
number_of_components = size(A_sub,1);
if nargin < 3 || isempty(component_names)
    component_names = "component_"+(1:number_of_components);
end
component_names = string(component_names(:));
if numel(component_names) ~= number_of_components
    error('fa:ComponentNameCount', ...
        'component_names must contain one name per row of A_sub.');
end

minimum_input = zeros(n,number_of_components);
maximum_input = zeros(n,number_of_components);
for component = 1:number_of_components
    coefficients = A_sub(component,:).';
    minimum_input(:,component) = mu_min;
    maximum_input(:,component) = mu_max;
    minimum_input(coefficients<0,component) = mu_max(coefficients<0);
    maximum_input(coefficients<0,component) = mu_min(coefficients<0);
end
minimum_points = A_sub*minimum_input;
maximum_points = A_sub*maximum_input;
indices = (1:number_of_components).';
minimum_values = minimum_points(sub2ind( ...
    size(minimum_points),indices,indices));
maximum_values = maximum_points(sub2ind( ...
    size(maximum_points),indices,indices));

extrema = table(component_names,minimum_values,maximum_values, ...
    num2cell(minimum_input,1).',num2cell(maximum_input,1).', ...
    num2cell(minimum_points,1).',num2cell(maximum_points,1).', ...
    'VariableNames',{'component','minimum_value','maximum_value', ...
    'minimum_input','maximum_input','minimum_point','maximum_point'});
end
