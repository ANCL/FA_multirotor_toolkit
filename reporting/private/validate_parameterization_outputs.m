function validate_parameterization_outputs(comparison)
%VALIDATE_PARAMETERIZATION_OUTPUTS Check all selected P1/P2/P3 designs.
if isempty(comparison) || any(~comparison.valid)
    error('fa:InvalidParameterizationDesign', ...
        'Every selected parameterization design must be valid.');
end
end
