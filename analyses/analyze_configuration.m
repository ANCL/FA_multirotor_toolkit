function result = analyze_configuration(geometry, model, numerics)
%ANALYZE_CONFIGURATION Analyze one fixed rotor geometry without file output.
%
% Usage: result = analyze_configuration(geometry, model, numerics).
if nargin < 2 || isempty(model), model = default_model(); end
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
result = struct('geometry', geometry, 'model', model, ...
    'metrics', evaluate_design(geometry, model, numerics));
end
