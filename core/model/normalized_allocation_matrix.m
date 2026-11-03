function [A_normalized, scaling] = normalized_allocation_matrix(A, characteristic_length)
%NORMALIZED_ALLOCATION_MATRIX Normalize moment coordinates by length.
if size(A, 1) ~= 6 || ~isscalar(characteristic_length) || characteristic_length <= 0
    error('fa:AllocationScale', 'A must have six rows and characteristic_length must be positive.');
end
scaling = blkdiag(eye(3), eye(3) / characteristic_length);
A_normalized = scaling * A;
end
