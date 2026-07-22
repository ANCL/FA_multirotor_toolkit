function [mu_min, mu_max, bounds] = parse_actuator_bounds(actuator_bounds, n_actuators)
%PARSE_ACTUATOR_BOUNDS Validate and expand actuator-input bounds.
%
% Syntax
%   [mu_min, mu_max, bounds] = parse_actuator_bounds(actuator_bounds, n_actuators)
%
% Inputs
%   actuator_bounds  - Either [lower upper] for common bounds or an
%                      n_actuators-by-2 matrix of per-actuator bounds.
%   n_actuators      - Positive number of actuator columns.
%
% Outputs
%   mu_min           - n_actuators-by-1 lower-bound vector.
%   mu_max           - n_actuators-by-1 upper-bound vector.
%   bounds           - Canonical n_actuators-by-2 bound matrix.

validateattributes(n_actuators, {'numeric'}, ...
    {'real','finite','scalar','integer','positive'}, mfilename, 'n_actuators');
validateattributes(actuator_bounds, {'numeric'}, ...
    {'real','finite','nonempty'}, mfilename, 'actuator_bounds');

if isvector(actuator_bounds) && numel(actuator_bounds) == 2
    bounds = repmat(reshape(double(actuator_bounds),1,2), n_actuators, 1);
elseif isequal(size(actuator_bounds), [n_actuators, 2])
    bounds = double(actuator_bounds);
else
    error('fa:InvalidActuatorBounds', ...
        ['actuator_bounds must be [lower upper] or an ' ...
         'n_actuators-by-2 matrix.']);
end

mu_min = bounds(:,1);
mu_max = bounds(:,2);
if any(mu_min >= mu_max)
    error('fa:InvalidActuatorBounds', ...
        'Every actuator lower bound must be smaller than its upper bound.');
end
end
