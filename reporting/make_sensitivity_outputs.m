function output = make_sensitivity_outputs()
%MAKE_SENSITIVITY_OUTPUTS Generate physical sensitivity outputs only.
% Reads completed numerical results and never modifies results/current.
output = generate_sensitivity_outputs();
end
