function [lower, upper] = p1_bounds(normalization_group, model)
%P1_BOUNDS Return bounds for the 28 free P1 angle/radius variables.
%
% The selected reference rotor has radius 1 and azimuth 0. Both entries
% are omitted, leaving every other rotor variable unrestricted.
if nargin < 2 || isempty(model)
    model = default_model();
end
reference = p1_reference(normalization_group);
one_lower = [model.geometry.minimum_radius; -pi; -pi/2; -pi; -pi/2];
one_upper = [1; pi; pi/2; pi; pi/2];
lower = repmat(one_lower, 6, 1);
upper = repmat(one_upper, 6, 1);
fixed = 5 * (reference - 1) + [1 2];
lower(fixed) = [];
upper(fixed) = [];
end

function reference = p1_reference(group)
switch char(string(group))
    case 'positive', reference = 1;
    case 'negative', reference = 4;
    otherwise
        error('fa:InvalidP1Group', 'P1 normalization group must be positive or negative.');
end
end
