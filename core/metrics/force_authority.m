function [radius, inside, facet_gaps] = force_authority( ...
    normals, offsets, hover_force, tolerance)
%FORCE_AUTHORITY Compute hover-centred authority from hull half-spaces.
%
% The hull is represented by unit outward normals and inequalities
% normals(k,:)*f <= offsets(k). The returned radius is the minimum signed
% distance from hover_force to any facet.

if isempty(normals)
    radius = -Inf;
    inside = false;
    facet_gaps = zeros(0,1);
    return;
end
validateattributes(normals,{'numeric'},{'real','finite','ncols',3});
validateattributes(offsets,{'numeric'}, ...
    {'real','finite','numel',size(normals,1)});
validateattributes(hover_force,{'numeric'},{'real','finite','numel',3});
validateattributes(tolerance,{'numeric'}, ...
    {'real','finite','scalar','positive'});
normal_length = vecnorm(normals,2,2);
if any(abs(normal_length-1) > 100*tolerance)
    error('fa:NonUnitHullNormals', ...
        'Zero-moment force-set facet normals must have unit norm.');
end
facet_gaps = offsets(:)-normals*hover_force(:);
inside = all(facet_gaps >= -tolerance);
if inside
    radius = min(facet_gaps);
else
    radius = -Inf;
end
end
