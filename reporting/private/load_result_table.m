function T = load_result_table(path_in)
%LOAD_RESULT_TABLE Load the standard table_data variable.
data = load(path_in,'table_data');
if ~isfield(data,'table_data') || ~istable(data.table_data)
    error('fa:ReportingTable','Expected table_data in %s.',path_in);
end
T = data.table_data;
end
