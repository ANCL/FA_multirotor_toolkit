function status = check_full_actuation(A, characteristic_length, threshold)
%CHECK_FULL_ACTUATION Report rank and singular values of a normalized wrench map.
%
% Full actuation requires six-dimensional row rank and sigma_min >= threshold.
if nargin < 3 || isempty(threshold), threshold = 1e-4; end
[A_normalized, ~] = normalized_allocation_matrix(A, characteristic_length);
singular_values = svd(A_normalized);
rank_A = rank(A);
if numel(singular_values) < 6
    sigma_min = 0;
    condition_number = Inf;
else
    sigma_min = singular_values(end);
    if sigma_min > 0
        condition_number = singular_values(1) / sigma_min;
    else
        condition_number = Inf;
    end
end
status = struct('A_normalized', A_normalized, ...
    'singular_values', singular_values, 'sigma_min', sigma_min, ...
    'condition_number', condition_number, 'rank', rank_A, ...
    'fully_actuated', rank_A == 6 && sigma_min >= threshold, ...
    'margin', sigma_min - threshold);
end
