function result = check_full_actuation( ...
    A, length_scale, sigma_threshold, rank_tolerance)
%CHECK_FULL_ACTUATION Report algebraic and numerical wrench actuation.
%
% Syntax
%   result = check_full_actuation(A, length_scale, sigma_threshold)
%   result = check_full_actuation( ...
%       A, length_scale, sigma_threshold, rank_tolerance)
%
% Inputs
%   A                - 6-by-N force-before-moment allocation matrix.
%   length_scale     - Positive characteristic length used to scale moment.
%   sigma_threshold  - Minimum accepted singular value of the scaled map.
%   rank_tolerance   - Optional absolute tolerance used by rank.
%
% Output
%   result reports algebraic ranks, scaled singular values, condition
%   number, and the numerical full-actuation decision.
%
% Numerical full actuation requires six-dimensional row rank and a scaled
% minimum singular value not smaller than sigma_threshold.

validateattributes(A,{'numeric'},{'real','finite','nrows',6,'nonempty'});
validateattributes(length_scale,{'numeric'}, ...
    {'real','finite','scalar','positive'});
validateattributes(sigma_threshold,{'numeric'}, ...
    {'real','finite','scalar','nonnegative'});
if nargin < 4 || isempty(rank_tolerance)
    rank_tolerance = max(size(A))*eps(max(1,norm(A,2)));
end
validateattributes(rank_tolerance,{'numeric'}, ...
    {'real','finite','scalar','positive'});

scale_matrix = blkdiag(eye(3),eye(3)/length_scale);
A_bar = scale_matrix*A;
singular_values = svd(A_bar,'econ');
rank_A = rank(A,rank_tolerance);

% A map with fewer than six singular values cannot span a six-dimensional
% wrench space, even when every reported singular value is nonzero.
if numel(singular_values) < 6
    sigma_min = 0;
    condition_number = Inf;
else
    sigma_min = singular_values(6);
    if sigma_min > 0
        condition_number = singular_values(1)/sigma_min;
    else
        condition_number = Inf;
    end
end

result = struct( ...
    'A',A, ...
    'A_f',A(1:3,:), ...
    'A_tau',A(4:6,:), ...
    'A_bar',A_bar, ...
    'scale_matrix',scale_matrix, ...
    'rank_tolerance',rank_tolerance, ...
    'rank_A',rank_A, ...
    'rank_A_f',rank(A(1:3,:),rank_tolerance), ...
    'rank_A_tau',rank(A(4:6,:),rank_tolerance), ...
    'algebraically_full_rank',rank_A==6, ...
    'singular_values',singular_values, ...
    'sigma_min',sigma_min, ...
    'condition_number',condition_number, ...
    'sigma_threshold',sigma_threshold, ...
    'numerically_fully_actuated', ...
        rank_A==6 && sigma_min>=sigma_threshold);
end
