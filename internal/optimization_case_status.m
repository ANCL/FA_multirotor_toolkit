function status = optimization_case_status(store,specification)
%OPTIMIZATION_CASE_STATUS Report missing, compatible, or incompatible case.
path_in = case_store_path(store,specification.case_name);
status = struct('case_name',string(specification.case_name), ...
    'path',string(path_in),'state',"missing",'compatible',false, ...
    'mismatches',strings(0,1));
if ~isfile(path_in), return; end
try
    data = load(path_in,'saved_case_name','case_provenance');
catch ME
    status.state = "incompatible";
    status.mismatches = "unreadable:"+string(ME.identifier);
    return;
end
if ~isfield(data,'saved_case_name') || ...
        ~strcmp(data.saved_case_name,char(string(specification.case_name)))
    status.state = "incompatible";
    status.mismatches = "saved_case_name";
    return;
end
if ~isfield(data,'case_provenance')
    status.state = "incompatible";
    status.mismatches = "case_provenance";
    return;
end
fields = {'kind','core_hash','problem_hash','parameters_hash', ...
    'solver_hash','seed_hash','context_hash','case_hash'};
for k = 1:numel(fields)
    name = fields{k};
    if ~isfield(data.case_provenance,name) || ...
            ~strcmp(char(string(data.case_provenance.(name))), ...
                char(string(specification.provenance.(name))))
        status.mismatches(end+1,1) = string(name); %#ok<AGROW>
    end
end
if isempty(status.mismatches)
    status.state = "compatible";
    status.compatible = true;
else
    status.state = "incompatible";
end
end
