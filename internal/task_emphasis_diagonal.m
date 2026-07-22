function diagonal = task_emphasis_diagonal(rho,baseline_diagonal)
%TASK_EMPHASIS_DIAGONAL Physical force/moment task blend at rho.
% The relative proportions inside the force and moment subspaces are kept
% equal to the baseline task, while the complete diagonal retains the
% baseline Euclidean norm for every rho in [0,1].
validateattributes(rho,{'numeric'},{'scalar','finite','>=',0,'<=',1});
baseline_diagonal = baseline_diagonal(:);
if numel(baseline_diagonal) ~= 6 || any(~isfinite(baseline_diagonal)) || ...
        any(baseline_diagonal <= 0)
    error('fa:InvalidTaskEmphasis', ...
        'The baseline task diagonal must contain six positive finite values.');
end

lambda_f_0 = baseline_diagonal(1:3);
lambda_m_0 = baseline_diagonal(4:6);
force_norm = norm(lambda_f_0,2);
moment_norm = norm(lambda_m_0,2);
if force_norm <= 0 || moment_norm <= 0
    error('fa:InvalidTaskEmphasis', ...
        'Both baseline force and moment task components must be nonzero.');
end

lambda_norm = norm(baseline_diagonal,2);
denominator = hypot(1-rho,rho);
a_f = lambda_norm*(1-rho)/denominator;
a_m = lambda_norm*rho/denominator;
diagonal = [a_f*lambda_f_0/force_norm; a_m*lambda_m_0/moment_norm];
end
