function [A_bar, scale_matrix] = normalized_allocation_matrix(A, length_scale)
%NORMALIZED_ALLOCATION_MATRIX Apply force-moment scaling to a 6-by-N map.

validateattributes(A,{'numeric'},{'real','finite','nrows',6,'nonempty'});
validateattributes(length_scale,{'numeric'}, ...
    {'real','finite','scalar','positive'});
scale_matrix = blkdiag(eye(3),eye(3)/length_scale);
A_bar = scale_matrix*A;
end
