function check = check_geometry(p, u, parameters, solver, normalization_case, options)
%CHECK_GEOMETRY Evaluate normalization, direction, and separation rules.
% Robustness trials may disable the exact max-radius normalization while
% retaining the approved radial envelope and collision checks.
if nargin < 5, normalization_case = []; end
if nargin < 6, options = struct(); end
if ~isfield(options,'enforce_normalization'), options.enforce_normalization = true; end
if ~isfield(options,'enforce_upper_length'), options.enforce_upper_length = true; end
validateattributes(p, {'numeric'}, {'real','finite','size',[3 6]});
validateattributes(u, {'numeric'}, {'real','finite','size',[3 6]});

ell = vecnorm(p, 2, 1).';
unit_error = abs(vecnorm(u, 2, 1).' - 1);
pairs = nchoosek(1:6, 2);
difference = p(:,pairs(:,1)) - p(:,pairs(:,2));
separations = vecnorm(difference,2,1).';

normalization_error = abs(max(ell) - 1);
if ~isempty(normalization_case)
    normalization_error = max(normalization_error, abs(ell(normalization_case) - 1));
end
if options.enforce_normalization
    normalization_margin = solver.equality_tolerance - normalization_error;
else
    normalization_margin = Inf;
end
if options.enforce_upper_length
    length_upper_margin = min(1 - ell);
else
    length_upper_margin = Inf;
end

check.lengths = ell;
check.separations = separations;
check.minimum_separation = min(separations);
check.length_lower_margin = min(ell - parameters.geometry.ell_min);
check.length_upper_margin = length_upper_margin;
check.normalization_margin = normalization_margin;
check.unit_direction_margin = solver.equality_tolerance - max(unit_error);
check.separation_margin = check.minimum_separation - ...
    2 * parameters.geometry.exclusion_radius;
check.normalization_enforced = options.enforce_normalization;
check.upper_length_enforced = options.enforce_upper_length;
check.valid = check.length_lower_margin >= -solver.equality_tolerance && ...
    check.length_upper_margin >= -solver.equality_tolerance && ...
    check.normalization_margin >= 0 && check.unit_direction_margin >= 0 && ...
    check.separation_margin >= -solver.equality_tolerance;
end
