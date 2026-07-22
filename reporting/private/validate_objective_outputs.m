function validate_objective_outputs(cross_evaluation,task_summary)
%VALIDATE_OBJECTIVE_OUTPUTS Check selected P1 designs and verification data.
if isempty(cross_evaluation) || any(~cross_evaluation.valid)
    error('fa:InvalidSelectedDesign', ...
        'Every selected objective design must be valid.');
end
if isempty(task_summary) || any(~task_summary.force_authority_verified)
    error('fa:UnverifiedForceAuthority', ...
        'Every selected force-authority value must pass verification.');
end
if any(~task_summary.q_star_verified) || ...
        any(~task_summary.larger_scale_infeasible)
    error('fa:UnverifiedTaskScale', ...
        'Every selected task scale must pass verification.');
end
end
