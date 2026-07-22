function force_set = zero_moment_force_set( ...
    A_f, A_tau, actuator_bounds, options)
%ZERO_MOMENT_FORCE_SET Construct forces achievable at zero body moment.
%
% Syntax
%   force_set = zero_moment_force_set(A_f, A_tau, actuator_bounds)
%   force_set = zero_moment_force_set( ...
%       A_f, A_tau, actuator_bounds, options)
%
% The actuator box is intersected with A_tau*mu = 0. Vertices of that
% bounded equality polytope are mapped through A_f and used to construct
% the force-space convex hull.

if nargin < 4
    options = struct();
end
options = complete_options(options);
validateattributes(A_f,{'numeric'},{'real','finite','nrows',3,'nonempty'});
validateattributes(A_tau,{'numeric'},{'real','finite','size',size(A_f)});
n = size(A_f,2);
[mu_min,mu_max,bounds] = parse_actuator_bounds(actuator_bounds,n);

constraint_rank = rank(A_tau,options.equality_tolerance);
number_of_active_bounds = n-constraint_rank;
if number_of_active_bounds < 0
    error('fa:InvalidMomentMap','A_tau has an invalid rank.');
end

if number_of_active_bounds == 0
    bound_sets = zeros(1,0);
    bits = zeros(0,1);
else
    bound_sets = nchoosek(1:n,number_of_active_bounds);
    bits = dec2bin(0:(2^number_of_active_bounds-1), ...
        number_of_active_bounds).'-'0';
end
maximum_candidates = max(1,size(bound_sets,1)*size(bits,2));
candidates = zeros(n,maximum_candidates);
next_column = 1;

for set_index = 1:size(bound_sets,1)
    bounded = bound_sets(set_index,:);
    free = setdiff(1:n,bounded,'stable');
    bounded_values = mu_min(bounded) + ...
        (mu_max(bounded)-mu_min(bounded)).*bits;
    rhs = -A_tau(:,bounded)*bounded_values;
    if isempty(free)
        valid = vecnorm(rhs,Inf,1) <= options.equality_tolerance;
        block = zeros(n,sum(valid));
        block(bounded,:) = bounded_values(:,valid);
    else
        free_matrix = A_tau(:,free);
        if rank(free_matrix,options.equality_tolerance) ~= constraint_rank
            continue;
        end
        free_values = free_matrix\rhs;
        block = zeros(n,size(bits,2));
        block(bounded,:) = bounded_values;
        block(free,:) = free_values;
        valid = all(block >= mu_min-options.bound_tolerance,1) & ...
            all(block <= mu_max+options.bound_tolerance,1) & ...
            vecnorm(A_tau*block,Inf,1) <= options.equality_tolerance;
        block = block(:,valid);
    end
    if isempty(block)
        continue;
    end
    required = next_column+size(block,2)-1;
    if required > size(candidates,2)
        candidates(:,end+maximum_candidates) = 0;
    end
    candidates(:,next_column:required) = block;
    next_column = required+1;
end

candidates = candidates(:,1:next_column-1);
candidates = unique_columns(candidates,options.vertex_tolerance);
force_points = unique_columns(A_f*candidates,options.vertex_tolerance);
affine_dimension = affine_dimension_of_columns( ...
    force_points,options.hull_tolerance);

force_set = struct( ...
    'actuator_bounds',bounds, ...
    'input_vertices',candidates, ...
    'vertices',force_points.', ...
    'affine_dimension',affine_dimension, ...
    'degenerate',affine_dimension<3, ...
    'triangles',zeros(0,3), ...
    'faces',struct('vertices',{},'normal',{},'support',{}), ...
    'halfspace_normals',zeros(0,3), ...
    'halfspace_offsets',zeros(0,1), ...
    'center',mean_or_zero(force_points), ...
    'validation',struct());

if ~force_set.degenerate && size(force_points,2) >= 4
    first_hull = convhulln(force_points.');
    vertices = force_points(:,unique(first_hull(:),'stable'));
    triangles = convhulln(vertices.');
    [normals,offsets,facets] = facet_planes( ...
        vertices,triangles,options.hull_tolerance);
    force_set.vertices = vertices.';
    force_set.triangles = triangles;
    force_set.halfspace_normals = normals;
    force_set.halfspace_offsets = offsets;
    force_set.faces = facets;
    force_set.center = mean(vertices,2);
end

if isempty(candidates)
    bound_violation = Inf;
    moment_residual = Inf;
else
    bound_violation = max([0, ...
        max(mu_min-candidates,[],'all'), ...
        max(candidates-mu_max,[],'all')]);
    moment_residual = max(vecnorm(A_tau*candidates,Inf,1));
end
force_set.validation.maximum_bound_violation = bound_violation;
force_set.validation.maximum_zero_moment_residual = moment_residual;
end

function options = complete_options(options)
defaults = struct( ...
    'equality_tolerance',1e-8, ...
    'bound_tolerance',1e-9, ...
    'vertex_tolerance',1e-9, ...
    'hull_tolerance',1e-8);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(options,fields{k})
        options.(fields{k}) = defaults.(fields{k});
    end
end
end

function columns = unique_columns(columns,tolerance)
if isempty(columns)
    return;
end
scaled = round(columns.'/tolerance);
[~,index] = unique(scaled,'rows','stable');
columns = columns(:,index);
end

function dimension = affine_dimension_of_columns(points,tolerance)
if isempty(points)
    dimension = 0;
else
    dimension = rank(points-points(:,1),tolerance);
end
end

function center = mean_or_zero(points)
if isempty(points)
    center = zeros(3,1);
else
    center = mean(points,2);
end
end

function [normals,offsets,facets] = facet_planes( ...
    vertices,triangles,tolerance)
center = mean(vertices,2);
raw_normals = cross( ...
    vertices(:,triangles(:,2))-vertices(:,triangles(:,1)), ...
    vertices(:,triangles(:,3))-vertices(:,triangles(:,1)),1).';
lengths = vecnorm(raw_normals,2,2);
valid = lengths > tolerance;
raw_normals = raw_normals(valid,:)./lengths(valid);
triangles = triangles(valid,:);
first_points = vertices(:,triangles(:,1)).';
inward = sum(raw_normals.*(center.'-first_points),2) > 0;
raw_normals(inward,:) = -raw_normals(inward,:);
raw_offsets = sum(raw_normals.*first_points,2);
plane_tolerance = 100*tolerance;
keys = round([raw_normals raw_offsets]/plane_tolerance);
[~,keep] = unique(keys,'rows','stable');
normals = raw_normals(keep,:);
offsets = raw_offsets(keep);
facets = struct('vertices',{},'normal',{},'support',{});
for k = 1:numel(keep)
    vertex_indices = find( ...
        abs(normals(k,:)*vertices-offsets(k)) <= plane_tolerance);
    facets(k).vertices = vertices(:,vertex_indices).';
    facets(k).normal = normals(k,:).';
    facets(k).support = offsets(k);
end
end
