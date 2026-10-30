function validate_objective_outputs(cross_evaluation)
%VALIDATE_OBJECTIVE_OUTPUTS Check selected P1 designs.
if isempty(cross_evaluation) || any(~cross_evaluation.valid)
    error('fa:InvalidSelectedDesign', ...
        'Every selected objective design must be valid.');
end
end
