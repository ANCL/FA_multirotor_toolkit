function geometry = decode_design(x, problem)
%DECODE_DESIGN Construct physical geometry from a design-variable vector.
switch problem.parameterization
    case 'p1'
        geometry = make_p1_geometry(x, problem.normalization_group);
    case 'p2'
        geometry = make_p2_geometry(x);
    case 'p3'
        geometry = make_p3_geometry(x);
    otherwise
        error('fa:Parameterization', 'Unknown parameterization.');
end
end
