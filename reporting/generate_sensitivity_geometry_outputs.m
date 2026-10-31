function output = generate_sensitivity_geometry_outputs()
%GENERATE_SENSITIVITY_GEOMETRY_OUTPUTS Twenty-four condition/angle figures.
% Four continuous condition families x six P2 angles; four objective curves.
% Read the selected Stage 04 case records directly. Do not trust a potentially
% stale condition_specific_selected_designs.mat cache from older runs.

families = { ...
    'actuator_capacity','mu_max','$\mu_{\max}$'; ...
    'reaction_moment','kappa','$\kappa$'; ...
    'characteristic_length','L','$L$'; ...
    'hover_load','hover_load_factor','$\zeta_h$'};
angles = { ...
    'delta_deg','$\delta$'; ...
    'eta_s_deg','$\eta_s$'; ...
    'alpha_plus_deg','$\alpha_+$'; ...
    'beta_plus_deg','$\beta_+$'; ...
    'alpha_minus_deg','$\alpha_-$'; ...
    'beta_minus_deg','$\beta_-$'};

figure_count = size(families,1)*size(angles,1);
table_count = 3;
context = create_output_context('sensitivity', ...
    'Study 4: Condition-specific optimal P2 geometry', ...
    '04_assumption_sensitivity','Outputs 04',figure_count+table_count);
logger = context.logger;
completed = strings(0,1);

try
    required = {context.files.design_manifest; ...
        context.files.parameterization_manifest; ...
        context.files.sensitivity_manifest; ...
        context.files.spatial_c3_designs; ...
        context.files.condition_specific_sensitivity_summary; ...
        context.files.condition_specific_sensitivity_runs; ...
        context.files.condition_specific_sensitivity_repeatability};
    require_output_files(required,context.title);

    p1 = assert_completed_stage(context.files.design_manifest, ...
        'unrestricted_optimization',context.parameters,context.solver);
    p2 = assert_completed_stage(context.files.parameterization_manifest, ...
        'parameterization_comparison',context.parameters,context.solver,p1);
    assert_completed_stage(context.files.sensitivity_manifest, ...
        'sensitivity',context.parameters,context.solver,p2);

    summary = load_result_table(context.files.condition_specific_sensitivity_summary);
    runs = load_result_table(context.files.condition_specific_sensitivity_runs);
    repeatability = load_result_table( ...
        context.files.condition_specific_sensitivity_repeatability);

    % Construct the fresh, verified angle matrix before clearing OLD
    % publication figures. The numerical results/current folder is untouched.
    optimal_angles = selected_p2_angles_from_records( ...
        summary,runs,context.files.spatial_c3_designs,context.folders);
    validate_angle_grid(optimal_angles,families,angles,context.parameters);

    context.paths = reset_study_output_paths(context.paths);

    for family_index = 1:size(families,1)
        family = families{family_index,1};
        parameter = families{family_index,2};
        x_label = families{family_index,3};
        for angle_index = 1:size(angles,1)
            angle_variable = angles{angle_index,1};
            angle_label = angles{angle_index,2};
            name = sprintf('optimal_p2_%s_%s',family,angle_variable);
            show_legend = (family_index==1 && angle_index==1);
            [logger,completed] = run_output_figure_with_data( ...
                logger,completed,sprintf('optimal %s vs %s',angle_variable,family), ...
                @() build_angle_figure(optimal_angles,family,parameter, ...
                    x_label,angle_variable,angle_label,show_legend), ...
                context.paths.figures,name);
        end
    end

    [logger,completed] = run_output_table( ...
        logger,completed,'table: optimal P2 angles in degrees', ...
        optimal_angles,context.paths.tables,'condition_specific_optimal_angles');
    [logger,completed] = run_output_table( ...
        logger,completed,'diagnostic: optimization repeatability', ...
        repeatability,context.paths.diagnostics,'condition_specific_repeatability');
    [logger,completed] = run_output_table( ...
        logger,completed,'diagnostic: all optimization runs', ...
        runs,context.paths.diagnostics,'condition_specific_design_runs');

    expected = strings(figure_count+table_count,1);
    k = 0;
    for family_index = 1:size(families,1)
        for angle_index = 1:size(angles,1)
            k = k+1;
            expected(k) = sprintf('optimal_p2_%s_%s', ...
                families{family_index,1},angles{angle_index,1});
        end
    end
    expected(k+(1:3)) = ["condition_specific_optimal_angles"; ...
        "condition_specific_repeatability";"condition_specific_design_runs"];
    require_completed_outputs(completed,expected,context.title);
    context.logger = logger;
    output = finish_output_study(context,logger,completed);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function T = selected_p2_angles_from_records(summary,runs,p2_file,folders)
% One row per condition/objective. The summary identifies the winning run.
required = {'analysis','case_name','physical_parameter','parameter_value', ...
    'objective','source','seed','normalization_case','valid'};
assert(all(ismember(required,summary.Properties.VariableNames)), ...
    'Stage 04 summary is missing selected-run identities.');
assert(all(logical(summary.valid)), ...
    'A selected condition-specific optimum is invalid.');

p2 = load(p2_file,'selected');
assert(isfield(p2,'selected'),'Missing Stage 02 P2 selected geometries.');
record_folder = fullfile(folders.checkpoints,'04_sensitivity','records');
n = height(summary);
X = nan(n,6);
selected_case = strings(n,1);
for i = 1:n
    objective = string(summary.objective(i));
    source = string(summary.source(i));
    if source == "baseline"
        match = find(string({p2.selected.name}) == objective);
        assert(numel(match)==1, ...
            'Expected one baseline P2 geometry for %s.',objective);
        result = p2.selected(match).optimization_result;
        x = result.design_variables;
        selected_case(i) = string(result.case_name);
    elseif source == "checkpoint"
        mask = string(runs.objective)==objective & ...
            string(runs.analysis)==string(summary.analysis(i)) & ...
            string(runs.physical_parameter)== ...
                string(summary.physical_parameter(i)) & ...
            abs(runs.parameter_value-summary.parameter_value(i)) < 1e-10 & ...
            runs.seed==summary.seed(i) & ...
            runs.normalization_case==summary.normalization_case(i) & ...
            logical(runs.valid);
        match = find(mask);
        assert(numel(match)==1, ...
            'Selected Stage 04 run is not unique at summary row %d.',i);
        name = string(runs.case_name(match));
        record_path = fullfile(record_folder,char(name + ".mat"));
        assert(isfile(record_path),'Missing selected P2 checkpoint record: %s', ...
            record_path);
        loaded = load(record_path,'case_record');
        assert(isfield(loaded,'case_record'), ...
            'Checkpoint record is malformed: %s',record_path);
        record = loaded.case_record;
        assert(string(record.case_name)==name && ...
            string(record.objective_name)==objective, ...
            'Checkpoint record identity mismatch: %s',record_path);
        x = record.design_variables;
        selected_case(i) = name;
    else
        error('fa:SensitivitySource', ...
            'Unexpected selected-design source %s at row %d.',source,i);
    end
    x = x(:);
    assert(numel(x)==6 && all(isfinite(x)), ...
        'Invalid six-variable P2 solution at row %d.',i);
    X(i,:) = rad2deg(x(:)).';
end

T = summary(:,{'analysis','case_name','physical_parameter', ...
    'parameter_value','objective','source','valid'});
T.selected_case = selected_case;
variable_names = {'delta_deg','eta_s_deg','alpha_plus_deg', ...
    'beta_plus_deg','alpha_minus_deg','beta_minus_deg'};
for j = 1:6
    T.(variable_names{j}) = X(:,j);
end
end

function validate_angle_grid(T,families,angles,parameters)
expected = struct();
expected.actuator_capacity = parameters.sensitivity.actuator_capacity_values;
expected.reaction_moment = parameters.sensitivity.kappa_values;
expected.characteristic_length = parameters.sensitivity.characteristic_length_values;
expected.hover_load = parameters.sensitivity.hover_load_factor_values;
objectives = ["r_F0","sigma_min","condition_number","hover_effort"];
for f = 1:size(families,1)
    family = string(families{f,1});
    values = sort(expected.(char(family))(:));
    for j = 1:numel(objectives)
        rows = T(string(T.analysis)==family & ...
            string(T.objective)==objectives(j),:);
        assert(height(rows)==numel(values), ...
            'Missing or duplicate optimal P2 conditions: %s/%s.', ...
            family,objectives(j));
        assert(all(abs(sort(rows.parameter_value)-values)<1e-9), ...
            'Wrong physical condition grid: %s/%s.',family,objectives(j));
        for a = 1:size(angles,1)
            assert(all(isfinite(rows.(angles{a,1}))), ...
                'Nonfinite P2 angle: %s/%s.',family,objectives(j));
        end
    end
end
end

function [fig,data] = build_angle_figure(T,family,parameter,x_label, ...
    angle_variable,angle_label,show_legend)
rows = T(string(T.analysis)==string(family),:);
rows = sortrows(rows,{'objective','parameter_value'});
data = rows(:,{'case_name','parameter_value','objective', ...
    'source','selected_case',angle_variable});
data.Properties.VariableNames{2} = parameter;
data.Properties.VariableNames{end} = 'angle_deg';
fig = figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[2 2 16 10]);
ax = axes(fig);
hold(ax,'on');
colors = lines(4);
line_styles = {'-o','--s',':^','-.d'};
objectives = ["r_F0","sigma_min","condition_number","hover_effort"];
labels = {'$r_{\mathcal{F}_0}$','$\sigma_{\min}$', ...
    '$C(\bar A)$','$\|\mu_h\|_2^2$'};
h = gobjects(4,1);
for j = 1:4
    series = rows(string(rows.objective)==objectives(j),:);
    series = sortrows(series,'parameter_value');
    h(j) = plot(ax,series.parameter_value,series.(angle_variable), ...
        line_styles{j},'LineWidth',1.45,'MarkerSize',4, ...
        'Color',colors(j,:),'MarkerFaceColor',colors(j,:));
end
xlabel(ax,x_label,'Interpreter','latex');
ylabel(ax,[angle_label ' (deg)'],'Interpreter','latex');
set(ax,'TickLabelInterpreter','latex','FontSize',10);
grid(ax,'on'); box(ax,'on');
if show_legend
    legend(ax,h,labels,'Interpreter','latex','Location','best');
end
hold(ax,'off');
end
