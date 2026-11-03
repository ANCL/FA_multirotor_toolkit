function [lower, upper, bounds] = parse_actuator_bounds(actuator_bounds, n)
%PARSE_ACTUATOR_BOUNDS Expand common or per-rotor actuator bounds.
%
% actuator_bounds is [lower upper] or n-by-2. Bounds are on mu in w=A*mu.
validateattributes(n, {'numeric'}, {'scalar', 'integer', 'positive'});
validateattributes(actuator_bounds, {'numeric'}, {'real', 'finite', 'nonempty'});
if isvector(actuator_bounds) && numel(actuator_bounds) == 2
    bounds = repmat(reshape(actuator_bounds, 1, 2), n, 1);
elseif isequal(size(actuator_bounds), [n, 2])
    bounds = actuator_bounds;
else
    error('fa:ActuatorBounds', 'Bounds must be [min max] or n-by-2.');
end
lower = bounds(:, 1);
upper = bounds(:, 2);
if any(lower >= upper)
    error('fa:ActuatorBounds', 'Every actuator must have a positive input range.');
end
end
