function numerics = default_numerics()
%DEFAULT_NUMERICS Return numerical tolerances shared by analyses and studies.
%
% Scientific geometry and actuator limits belong in default_model.
% Optimization budgets and methods will be defined in Stage 3.
numerics.full_actuation_threshold = 1e-4;
numerics.equality_tolerance = 1e-8;
numerics.bound_tolerance = 1e-9;
numerics.hull_tolerance = 1e-8;
numerics.vertex_tolerance = 1e-9;
numerics.compute_force_authority = true;
end
