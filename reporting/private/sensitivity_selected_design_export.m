function export = sensitivity_selected_design_export(context,summary,runs)
%SENSITIVITY_SELECTED_DESIGN_EXPORT Save selected P2 geometries for every condition.
% Derived from authoritative compact case records; no optimizer is invoked.
p2_data = load(context.files.spatial_c3_designs,'selected');
nominal = p2_data.selected;
selected = struct('condition',{},'objective',{},'source',{}, ...
    'geometry',{},'design_variables',{},'case_name',{});
record_root = fullfile(context.folders.checkpoints,'04_sensitivity','records');
for k = 1:height(summary)
    objective = char(string(summary.objective(k)));
    source = char(string(summary.source(k)));
    if strcmp(source,'checkpoint')
        mask = string(runs.objective)==string(objective) & ...
            string(runs.analysis)==string(summary.analysis(k)) & ...
            string(runs.physical_parameter)==string(summary.physical_parameter(k)) & ...
            abs(runs.parameter_value-summary.parameter_value(k))<1e-10 & ...
            runs.seed==summary.seed(k) & ...
            runs.normalization_case==summary.normalization_case(k) & ...
            logical(runs.valid);
        matches = find(mask);
        if numel(matches) ~= 1
            error('fa:SensitivitySelectedRecord', ...
                'Cannot uniquely match sensitivity row %d to its case.',k);
        end
        name = char(string(runs.case_name(matches)));
        path_in = fullfile(record_root,[name '.mat']);
        if ~isfile(path_in)
            error('fa:SensitivitySelectedRecord','Missing compact record: %s',path_in);
        end
        data = load(path_in,'case_record');
        record = data.case_record;
        if ~strcmp(string(record.case_name),string(name)) || ...
                ~strcmp(string(record.objective_name),string(objective))
            error('fa:SensitivitySelectedRecord','Unexpected record identity: %s',name);
        end
        geometry = record.geometry;
        variables = record.design_variables;
    else
        matched = nominal(strcmp(string({nominal.name}),string(objective)));
        if numel(matched) ~= 1
            error('fa:SensitivityNominalSelection','Missing %s design.',objective);
        end
        name = char(string(matched.optimization_result.case_name));
        geometry = matched.geometry;
        variables = matched.optimization_result.design_variables;
    end
    selected(end+1) = struct( ... %#ok<AGROW>
        'condition',string(summary.analysis(k))+":"+string(summary.case_name(k)), ...
        'objective',string(objective),'source',string(source), ...
        'geometry',geometry,'design_variables',variables,'case_name',string(name));
end
export = selected;
end
