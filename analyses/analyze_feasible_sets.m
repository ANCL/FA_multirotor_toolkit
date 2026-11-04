function analysis = analyze_feasible_sets(geometry, model, numerics)
%ANALYZE_FEASIBLE_SETS Analyze the bounded wrench projections for a geometry.
%
% Usage: analysis = analyze_feasible_sets(geometry, model, numerics).
% Provides force, zero-moment force and moment sets without file output.
if nargin < 2 || isempty(model), model = default_model(); end
if nargin < 3 || isempty(numerics), numerics = default_numerics(); end
metrics = evaluate_design(geometry, model, numerics);
if ~metrics.fully_actuated
    error('fa:FeasibleSets', 'Zero-moment force sets require a fully actuated geometry.');
end
sets = build_feasible_wrench_sets(geometry, model, numerics);
analysis = struct('geometry', geometry, 'model', model, ...
    'metrics', metrics, 'force', sets.force, ...
    'zero_moment_force', sets.zero_moment_force, ...
    'moment', sets.moment, 'wrench', sets.wrench, ...
    'hover_force', model.hover_wrench(1:3), ...
    'hover', metrics.hover);
end
