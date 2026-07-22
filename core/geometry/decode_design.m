function geometry = decode_design(x, parameterization, normalization_case, parameters)
%DECODE_DESIGN Dispatch among the three supported design parameterizations.

switch parameterization
    case 'rotorwise'
        geometry = rotorwise_geometry(x, normalization_case, parameters);
    case 'spatial_c3'
        geometry = spatial_c3_geometry(x, parameters);
    case 'planar_shared'
        geometry = planar_shared_geometry(x, parameters);
    otherwise
        error('fa:UnknownParameterization', 'Unknown parameterization: %s', parameterization);
end
end
