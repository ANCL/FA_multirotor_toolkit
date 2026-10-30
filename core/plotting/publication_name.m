function label = publication_name(category,key)
%PUBLICATION_NAME Map internal identifiers to approved publication labels.
category = lower(char(string(category)));
key = char(string(key));

switch category
    case 'parameterization'
        switch key
            case 'rotorwise', label = '$\mathcal P_1$';
            case 'spatial_c3', label = '$\mathcal P_2$';
            case 'planar_shared', label = '$\mathcal P_3$';
            otherwise, unknown_identifier(category,key);
        end
    case 'parameterization_full'
        switch key
            case 'rotorwise'
                label = 'Rotor-wise parameterization';
            case 'spatial_c3'
                label = 'Spatial $C_3$-symmetric parameterization';
            case 'planar_shared'
                label = 'Planar shared-angle parameterization';
            otherwise, unknown_identifier(category,key);
        end
    case 'procedure'
        switch key
            case 'fixed', label = '$\mathrm{Fixed\ design}$';
            case 'optimized', label = '$\mathrm{Optimized\ design}$';
            otherwise, unknown_identifier(category,key);
        end
    case 'metric'
        style = publication_style();
        if ~isfield(style.labels,key)
            unknown_identifier(category,key);
        end
        label = style.labels.(key);
    case 'objective'
        switch key
            case 'r_F0', label = '$\mathrm{Force\!\mbox{-}authority\ design}$';
            case 'sigma_min', label = '$\mathrm{Weakest\!\mbox{-}gain\ design}$';
            case 'condition_number', label = '$\mathrm{Isotropy\ design}$';
            case 'hover_effort', label = '$\mathrm{Hover\!\mbox{-}effort\ design}$';
            otherwise, unknown_identifier(category,key);
        end
    otherwise
        unknown_identifier(category,key);
end
end

function unknown_identifier(category,key)
error('fa:UnknownPublicationName', ...
    'No approved publication name exists for %s identifier "%s".', ...
    category,key);
end
