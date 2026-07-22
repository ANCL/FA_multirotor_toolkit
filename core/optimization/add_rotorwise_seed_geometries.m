function seeds_by_case = add_rotorwise_seed_geometries( ...
    seeds_by_case,geometries,solver)
%ADD_ROTORWISE_SEED_GEOMETRIES Add physical geometries to every P1 case.
% Geometries with all six radii equal to one belong to every normalization
% case. Each encoded row is retained as an explicitly evaluated incumbent.
if ~iscell(seeds_by_case) || numel(seeds_by_case) ~= 6
    error('fa:RotorwiseSeedCases', ...
        'Rotor-wise seeds must be supplied as six normalization-case cells.');
end
if isstruct(geometries)
    geometries = arrayfun(@(item) item,geometries, ...
        'UniformOutput',false);
end
if ~iscell(geometries)
    error('fa:RotorwiseSeedGeometries', ...
        'Additional geometries must be a cell array or struct array.');
end
for normalization_case = 1:6
    seeds = seeds_by_case{normalization_case};
    for k = 1:numel(geometries)
        encoded = encode_rotorwise_geometry( ...
            geometries{k},normalization_case,solver).';
        seeds(end+1,:) = encoded; %#ok<AGROW>
    end
    scaled = round(seeds/max(solver.vertex_tolerance,eps));
    [~,keep] = unique(scaled,'rows','stable');
    seeds_by_case{normalization_case} = seeds(keep,:);
end
end
