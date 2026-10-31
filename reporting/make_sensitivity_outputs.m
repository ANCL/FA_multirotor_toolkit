function output = make_sensitivity_outputs()
%MAKE_SENSITIVITY_OUTPUTS Export optimal P2 geometry versus physical conditions.
% Reporting only: reads completed Stage 04 cases; never reoptimizes.
output = generate_sensitivity_geometry_outputs();
end
