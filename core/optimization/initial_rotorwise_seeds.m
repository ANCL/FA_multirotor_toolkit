function seeds_by_case = initial_rotorwise_seeds(parameters, solver)
%INITIAL_ROTORWISE_SEEDS Build a small deterministic seed set for rotor-wise search.
% Approved structured geometries are used only as initial points inside the
% unrestricted domain. They do not constrain the global search or its results.

planar_variables = initial_structured_seeds('planar_shared',parameters);
spatial_variables = initial_structured_seeds('spatial_c3',parameters);
candidate_cells = cell(size(planar_variables,1)+size(spatial_variables,1),1);
next = 1;
for k = 1:size(planar_variables,1)
    candidate_cells{next} = planar_shared_geometry(planar_variables(k,:).',parameters);
    next = next+1;
end
for k = 1:size(spatial_variables,1)
    candidate_cells{next} = spatial_c3_geometry(spatial_variables(k,:).',parameters);
    next = next+1;
end

valid = false(numel(candidate_cells),1);
score = inf(numel(candidate_cells),1);
for k = 1:numel(candidate_cells)
    options = struct('compute_force_authority',false,'compute_task_scale',false);
    metrics = evaluate_design(candidate_cells{k},parameters,solver,options);
    valid(k) = metrics.valid;
    if valid(k), score(k) = -metrics.sigma_min; end
end
[~,order] = sortrows([~valid score],[1 2]);
candidate_cells = candidate_cells(order);

seeds_by_case = cell(6,1);
for normalization_case = 1:6
    seeds = zeros(numel(candidate_cells),29);
    for k = 1:numel(candidate_cells)
        seeds(k,:) = encode_rotorwise_geometry(candidate_cells{k},normalization_case,solver).';
    end
    scaled = round(seeds/max(solver.vertex_tolerance,eps));
    [~,keep] = unique(scaled,'rows','stable');
    seeds_by_case{normalization_case} = seeds(keep,:);
end
end
