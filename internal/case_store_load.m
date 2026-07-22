function results = case_store_load(store,specifications)
%CASE_STORE_LOAD Load compatible case payloads in plan order.
items = cell(numel(specifications),1);
for k = 1:numel(specifications)
    if ~case_store_has(store,specifications(k))
        error('fa:MissingCheckpointCase', ...
            'Missing checkpoint case: %s',specifications(k).case_name);
    end
    data = load(case_store_path(store,specifications(k).case_name),'case_result');
    items{k} = data.case_result;
end
if isempty(items)
    results = struct([]);
elseif all(cellfun(@isstruct,items))
    try
        results = reshape(horzcat(items{:}),1,[]);
    catch
        results = items;
    end
else
    results = items;
end
end
