function seeds = initial_structured_seeds(parameterization, parameters)
%INITIAL_STRUCTURED_SEEDS Deterministic interior starts for restricted families.
fractions = [0.25 0.5 0.75];
switch parameterization
    case 'planar_shared'
        ranges = parameters.geometry.planar_ranges;
        values = ranges(:,1)+(ranges(:,2)-ranges(:,1)).*fractions;
        [first,second] = ndgrid(values(1,:),values(2,:));
        seeds = [first(:) second(:)];
    case 'spatial_c3'
        ranges = parameters.geometry.spatial_ranges;
        center = mean(ranges,2);
        seeds = center.';
        for coordinate = 1:size(ranges,1)
            for fraction = [0.25 0.75]
                x = center;
                x(coordinate) = ranges(coordinate,1)+fraction* ...
                    (ranges(coordinate,2)-ranges(coordinate,1));
                seeds(end+1,:) = x.'; %#ok<AGROW>
            end
        end
    otherwise
        error('fa:StructuredSeedFamily', ...
            'Structured seeds are defined only for spatial_c3 and planar_shared.');
end
end
