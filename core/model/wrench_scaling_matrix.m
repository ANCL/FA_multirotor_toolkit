function scale_matrix = wrench_scaling_matrix(force_scale, length_scale)
%WRENCH_SCALING_MATRIX Construct force-before-moment wrench scaling.
%
% The scaled wrench is S_w*w, where force components are divided by
% force_scale and moment components by force_scale*length_scale.

validateattributes(force_scale, {'numeric'}, ...
    {'real','finite','scalar','positive'}, mfilename, 'force_scale');
validateattributes(length_scale, {'numeric'}, ...
    {'real','finite','scalar','positive'}, mfilename, 'length_scale');

scale_matrix = diag([ ...
    repmat(1/force_scale,3,1); ...
    repmat(1/(force_scale*length_scale),3,1)]);
end
