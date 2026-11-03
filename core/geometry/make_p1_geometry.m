function geometry = make_p1_geometry(x, normalization_group)
%MAKE_P1_GEOMETRY Decode unrestricted P1 geometry from 28 variables.
%
% Reference rotor 1 (positive) or 4 (negative) has radius 1 and azimuth
% zero. This removes common yaw and equivalent maximum-radius labels,
% without constraining arm spacings, elevations, or thrust directions.

switch char(string(normalization_group))
    case 'positive', reference = 1;
    case 'negative', reference = 4;
    otherwise
        error('fa:InvalidP1Group', 'P1 normalization group must be positive or negative.');
end
x = x(:);
if numel(x) ~= 28 || any(~isfinite(x))
    error('fa:P1Variables', 'P1 requires 28 finite variables.');
end
fixed = 5 * (reference - 1) + [1 2];
full_x = zeros(30, 1);
free = true(30, 1);
free(fixed) = false;
full_x(free) = x;
full_x(fixed(1)) = 1;
full_x(fixed(2)) = 0;
angles = reshape(full_x, 5, 6);
geometry = angle_geometry(angles(1, :).', angles(2, :).', ...
    angles(3, :).', angles(4, :).', angles(5, :).');
geometry.parameterization = 'p1';
geometry.normalization_group = char(string(normalization_group));
geometry.design_variables = x;
end
