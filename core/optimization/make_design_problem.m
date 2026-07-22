function problem = make_design_problem(parameterization, objective, normalization_case, parameters)
%MAKE_DESIGN_PROBLEM Define one readable optimization case.
if nargin < 3 || isempty(normalization_case), normalization_case = 0; end
[lower, upper] = design_variable_bounds(parameterization, normalization_case, parameters);
problem = struct('parameterization',parameterization,'objective',objective, ...
    'normalization_case',normalization_case,'lower_bounds',lower,'upper_bounds',upper, ...
    'authority_threshold',[],'initial_designs',zeros(0,numel(lower)), ...
    'case_name','');
end

function [lower, upper] = design_variable_bounds(parameterization, normalization_case, parameters)
%DESIGN_VARIABLE_BOUNDS Return explicit bounds for one parameterization.

switch parameterization
    case 'rotorwise'
        one_lower = [parameters.geometry.ell_min; ...
            parameters.geometry.rotorwise.gamma(1); parameters.geometry.rotorwise.eta(1); ...
            parameters.geometry.rotorwise.alpha(1); parameters.geometry.rotorwise.beta(1)];
        one_upper = [1; parameters.geometry.rotorwise.gamma(2); ...
            parameters.geometry.rotorwise.eta(2); parameters.geometry.rotorwise.alpha(2); ...
            parameters.geometry.rotorwise.beta(2)];
        lower = repmat(one_lower, 6, 1);
        upper = repmat(one_upper, 6, 1);
        fixed = 1 + 5 * (normalization_case - 1);
        lower(fixed) = []; upper(fixed) = [];
    case 'spatial_c3'
        lower = parameters.geometry.spatial_ranges(:,1);
        upper = parameters.geometry.spatial_ranges(:,2);
    case 'planar_shared'
        lower = parameters.geometry.planar_ranges(:,1);
        upper = parameters.geometry.planar_ranges(:,2);
    otherwise
        error('fa:UnknownParameterization', 'Unknown parameterization: %s', parameterization);
end
if any(~isfinite(lower)) || any(~isfinite(upper)) || any(lower >= upper)
    error('fa:InvalidVariableBounds', ...
        'Approved finite variable ranges are required for %s.', parameterization);
end
end
