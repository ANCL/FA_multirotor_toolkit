function geometry = selected_geometry(selected,name)
%SELECTED_GEOMETRY Return one retained geometry by objective identifier.
names = string({selected.name});
match = find(names==string(name),1);
if isempty(match)
    error('fa:MissingSelectedGeometry', ...
        'No selected geometry was found for %s.',string(name));
end
geometry = selected(match).geometry;
end
