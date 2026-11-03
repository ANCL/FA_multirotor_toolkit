function problem = make_design_problem(parameterization, objective, normalization_group, model)
%MAKE_DESIGN_PROBLEM Define one optimization case with explicit bounds.
%
% P1 uses 28 variables and either the positive or negative reference group.
% P2 and P3 have no normalization group. P1 has no structural seeds by
% default; studies may explicitly supply initial_designs when justified.
if nargin < 3, normalization_group = ''; end
if nargin < 4 || isempty(model), model = default_model(); end
parameterization = char(string(parameterization));
objective = char(string(objective));
if ~ismember(objective, {'r_F0', 'sigma_min', 'condition_number', 'hover_effort'})
    error('fa:Objective', 'Unknown scientific objective: %s', objective);
end
switch parameterization
    case 'p1'
        if isempty(normalization_group)
            error('fa:P1Group', 'P1 requires positive or negative normalization_group.');
        end
        normalization_group = char(string(normalization_group));
        [lower, upper] = p1_bounds(normalization_group, model);
    case 'p2'
        normalization_group = '';
        lower = [0; -pi/2; -pi; -pi/2; -pi; -pi/2];
        upper = [2*pi/3; pi/2; pi; pi/2; pi; pi/2];
    case 'p3'
        normalization_group = '';
        lower = [-pi; -pi/2];
        upper = [pi; pi/2];
    otherwise
        error('fa:Parameterization', 'Expected p1, p2, or p3.');
end
problem = struct('parameterization', parameterization, ...
    'objective', objective, 'normalization_group', normalization_group, ...
    'lower_bounds', lower(:), 'upper_bounds', upper(:), ...
    'authority_threshold', [], 'initial_designs', zeros(0, numel(lower)));
end
