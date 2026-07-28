function records = case_record_load(store,specifications)
%CASE_RECORD_LOAD Load compact twins in plan order.
items = cell(numel(specifications),1);
for k = 1:numel(specifications)
    items{k} = case_record_load_one(store,specifications(k));
end
if isempty(items)
    records = struct([]);
else
    records = reshape(horzcat(items{:}),1,[]);
end
end
