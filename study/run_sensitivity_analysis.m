function output = run_sensitivity_analysis()
%RUN_SENSITIVITY_ANALYSIS Physical sensitivity with case-level resume.
% Compatible case checkpoints are reused by case name and component hashes.
% Removing results/current/checkpoints/04_sensitivity explicitly starts a
% clean numerical run; removing only aggregate outputs does not delete cases.

[root,parameters,solver,runtime,cleanup] = begin_stage('sensitivity'); %#ok<NASGU>
try
    folders = output_folders(root);
    source_file = fullfile(folders.designs,'rotorwise_selected_designs.mat');
    if ~isfile(source_file)
        error('fa:MissingStage01','Run the design-comparison study first.');
    end
    design_provenance = assert_completed_stage( ...
        fullfile(folders.designs,'stage_manifest.mat'), ...
        'design_comparison',parameters,solver);
    stage_folder = ensure_folder(folders.sensitivity);
    checkpoint_folder = fullfile(ensure_folder(folders.checkpoints), ...
        '04_sensitivity');
    store = open_case_store(checkpoint_folder,'sensitivity');
    [complete,completed_provenance,~,completed_manifest] = stage_is_complete( ...
        stage_folder,'sensitivity',parameters,solver,design_provenance);

    source = load(source_file,'selected');
    selected = source.selected;
    if complete
        expected = completed_manifest.counts.optimization_cases;
        counts = case_store_counts(store);
        if counts.full == expected && counts.records == expected
            study_log('line','Stage 04 already complete and compatible. No work required.');
            output = struct('status','complete','reused',true, ...
                'provenance',completed_provenance,'folder',stage_folder);
            return;
        elseif counts.full == expected
            study_log('line', ...
                'Stage 04 products are current; reconciling missing compact checkpoint twins only.');
            plan_for_records = sensitivity_case_plan(parameters,solver,selected);
            require_current_sensitivity_store(store,plan_for_records.specifications);
            ensure_case_record_twins(plan_for_records.specifications,store,runtime);
            counts = case_store_counts(store);
            if counts.records ~= expected
                error('fa:IncompleteSensitivityRecordStore', ...
                    'Expected %d compact checkpoint records, but found %d.', ...
                    expected,counts.records);
            end
            study_log('line','Stage 04 checkpoint twins complete. Canonical stage products unchanged.');
            output = struct('status','complete','reused',true, ...
                'provenance',completed_provenance,'folder',stage_folder);
            return;
        end
        study_log('line', ...
            'Stage 04 manifest is current, but authoritative checkpoint count changed; rebuilding stage data.');
    end
    plan = sensitivity_case_plan(parameters,solver,selected);
    provenance = study_provenance('sensitivity',parameters,solver, ...
        plan.provenance,design_provenance);

    require_current_sensitivity_store(store,plan.specifications);
    invalidate_stage_manifest(stage_folder);

    inventory = case_store_inventory(store,plan.specifications);
    resumed = inventory.full_count;
    study_log('line','Sensitivity checkpoint inventory: %d/%d full | %d/%d compact.', ...
        inventory.full_count,inventory.expected, ...
        inventory.record_count,inventory.expected);
    total_cases = plan.fixed_evaluation_count+plan.optimization_case_count;
    logger = study_log('stage_start','Stage 04','Sensitivity studies', ...
        total_cases,resumed);

    %% Nominal-geometry evaluations
    rows = empty_nominal_rows();
    for case_index = 1:numel(plan.fixed_cases)
        [rows,logger] = append_nominal_evaluations( ...
            rows,logger,selected,plan.fixed_cases(case_index),solver);
    end
    nominal_summary = struct2table(rows);
    if height(nominal_summary) ~= plan.expected_summary_rows
        error('fa:IncompleteNominalSensitivity', ...
            'Expected %d nominal rows, but obtained %d.', ...
            plan.expected_summary_rows,height(nominal_summary));
    end
    write_table_bundle(nominal_summary,stage_folder, ...
        'nominal_geometry_sensitivity',provenance);

    %% Condition-specific optima
    [condition_specific_results,logger,runtime] = run_optimization_cases( ...
        plan.specifications,store,logger,solver,runtime);
    condition_specific_summary = summarize_condition_specific_results( ...
        condition_specific_results,plan.optimization_groups, ...
        plan.baseline_cases,selected,nominal_summary);
    expected_summary_rows = plan.expected_summary_rows;
    if height(condition_specific_summary) ~= expected_summary_rows
        error('fa:IncompleteSensitivityOptimization', ...
            ['Expected %d condition-specific sensitivity rows, but obtained %d. ' ...
             'No valid selected result was found for one or more cases.'], ...
            expected_summary_rows,height(condition_specific_summary));
    end
    condition_specific_repeatability = ...
        assess_condition_specific_repeatability(condition_specific_results);
    expected_cases = {plan.specifications.case_name}.';
    validate_optimization_results(condition_specific_results,expected_cases, ...
        'Stage 04 condition-specific optimization results');
    condition_specific_runs = optimization_run_table(condition_specific_results);
    write_table_bundle(condition_specific_summary,stage_folder, ...
        'condition_specific_sensitivity_summary',provenance);
    write_table_bundle(condition_specific_repeatability,stage_folder, ...
        'condition_specific_repeatability',provenance);
    write_table_bundle(condition_specific_runs, ...
        stage_folder,'condition_specific_design_runs',provenance);

    artifacts = [ ...
        "nominal_geometry_sensitivity.mat"; ...
        "condition_specific_sensitivity_summary.mat"; ...
        "condition_specific_repeatability.mat"; ...
        "condition_specific_design_runs.mat"];
    counts = struct( ...
        'fixed_geometry_evaluations',height(nominal_summary), ...
        'condition_specific_matrix_rows',height(condition_specific_summary), ...
        'optimization_cases',numel(condition_specific_results), ...
        'checkpoint_records',numel(condition_specific_results), ...
        'optimization_run_rows',height(condition_specific_runs));
    write_stage_manifest(stage_folder,provenance,artifacts,counts);

    output = struct('nominal_geometry_summary',nominal_summary, ...
        'condition_specific_summary',condition_specific_summary, ...
        'condition_specific_repeatability',condition_specific_repeatability, ...
        'fixed_evaluation_count',plan.fixed_evaluation_count, ...
        'optimization_case_count',plan.optimization_case_count, ...
        'folder',stage_folder);
    study_log('stage_finish',logger);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function require_current_sensitivity_store(store,specifications)
expected = string({specifications.case_name})+".mat";
check_folder(store.case_folder,'checkpoint',expected);
check_folder(store.record_folder,'compact checkpoint record',expected);
end

function check_folder(folder,label,expected)
listing = dir(fullfile(folder,'*.mat'));
if isempty(listing), return; end
actual = string({listing.name});
unknown = actual(~ismember(actual,expected));
if ~isempty(unknown)
    error('fa:UnexpectedSensitivityCheckpoint', ...
        ['The sensitivity %s folder contains %d case(s) outside the current ' ...
         'physical plan. Remove only the unexpected file(s), or delete the ' ...
         'Stage 04 checkpoint folder for an explicit clean run. Example: %s'], ...
        label,numel(unknown),char(unknown(1)));
end
end

function [rows,logger] = append_nominal_evaluations( ...
    rows,logger,designs,case_spec,solver)
for objective_index = 1:numel(case_spec.objectives)
    objective = case_spec.objectives{objective_index};
    design = designs(strcmp({designs.name},objective));
    if numel(design) ~= 1
        error('fa:MissingSensitivityBaseline', ...
            'Expected one selected nominal geometry for objective %s.',objective);
    end
    description = sprintf('%s | %s | Nominal geometry | objective %s', ...
        case_spec.analysis,case_spec.case_id,objective);
    study_log('case_start',logger.completed+1,logger.total,description);
    case_timer = tic;
    metrics = evaluate_design(design.geometry,case_spec.parameters,solver);
    if isfield(metrics,'internal_error_identifier') && ...
            ~isempty(metrics.internal_error_identifier)
        error(metrics.internal_error_identifier,'%s',metrics.failure_reason);
    end
    rows(end+1) = nominal_row(case_spec,objective,design.name,metrics); %#ok<AGROW>
    detail = sprintf('r_F0 %.8g | sigma_min %.8g',metrics.r_F0,metrics.sigma_min);
    logger = study_log('case_complete',logger,metrics.valid,detail,toc(case_timer));
end
end

function row = nominal_row(case_spec,objective,design_name,metrics)
row = struct('analysis',string(case_spec.analysis), ...
    'case_name',string(case_spec.case_id), ...
    'physical_parameter',string(case_spec.physical_parameter), ...
    'parameter_value',case_spec.physical_value, ...
    'objective',string(objective),'design_name',string(design_name), ...
    'geometry_role',"Nominal geometry", ...
    'r_F0',metrics.r_F0,'sigma_min',metrics.sigma_min, ...
    'condition_number',metrics.condition_number, ...
    'hover_effort',metrics.hover_effort,'valid',metrics.valid);
end

function rows = empty_nominal_rows()
rows = struct('analysis',{},'case_name',{},'physical_parameter',{}, ...
    'parameter_value',{}, ...
    'objective',{},'design_name',{},'geometry_role',{},'r_F0',{}, ...
    'sigma_min',{},'condition_number',{},'hover_effort',{},'valid',{});
end

function summary = summarize_condition_specific_results( ...
    results,groups,baseline_cases,selected,nominal_summary)
rows = repmat(condition_specific_row_template(),0,1);

% Exact baseline points reuse the already selected P1 optima for all four
% matrix metrics.
for baseline_index = 1:numel(baseline_cases)
    item = baseline_cases(baseline_index);
    for objective_index = 1:numel(item.objectives)
        objective = item.objectives{objective_index};
        design = selected(strcmp({selected.name},objective));
        if numel(design) ~= 1
            error('fa:MissingSensitivityBaseline', ...
                'Expected one nominal selected design for %s.',objective);
        end
        rows(end+1) = condition_specific_row_from_metrics( ... %#ok<AGROW>
            item,objective,design.optimization_result.metrics, ...
            design.optimization_result.normalization_case, ...
            design.optimization_result.seed, ...
            design.optimization_result.elapsed_seconds,"baseline");
    end
end

% Changed conditions that require re-optimization select the best valid P1
% result across normalization cases and repeats.
for group_index = 1:numel(groups)
    group = groups(group_index);
    for objective_index = 1:numel(group.objectives)
        objective = group.objectives{objective_index};
        mask = arrayfun(@(x) result_matches(x,group.case_id,objective),results);
        candidates = results(mask & [results.valid]);
        if isempty(candidates), continue; end
        [~,best_index] = min([candidates.objective_value]);
        best = candidates(best_index);
        rows(end+1) = condition_specific_row_from_metrics( ... %#ok<AGROW>
            group,objective,best.metrics,best.normalization_case,best.seed, ...
            best.elapsed_seconds,"checkpoint");
    end
end

% Some matrix cells do not define a different optimization problem. Their
% corresponding nominal P1 optimum is therefore also the condition-specific
% optimum. Add those rows explicitly instead of launching duplicate searches.
existing_keys = condition_specific_keys(rows);
for row_index = 1:height(nominal_summary)
    nominal = nominal_summary(row_index,:);
    key = sensitivity_table_key(nominal.analysis,nominal.case_name,nominal.objective);
    if any(existing_keys == key), continue; end
    objective = char(string(nominal.objective));
    design = selected(strcmp({selected.name},objective));
    if numel(design) ~= 1
        error('fa:MissingSensitivityBaseline', ...
            'Expected one nominal selected design for %s.',objective);
    end
    rows(end+1) = condition_specific_row_from_nominal( ... %#ok<AGROW>
        nominal,design.optimization_result,"reused_nominal_optimum");
    existing_keys(end+1,1) = key; %#ok<AGROW>
end

summary = struct2table(rows);
end

function keys = condition_specific_keys(rows)
if isempty(rows)
    keys = strings(0,1);
    return;
end
keys = strings(numel(rows),1);
for index = 1:numel(rows)
    keys(index) = sensitivity_table_key( ...
        rows(index).analysis,rows(index).case_name,rows(index).objective);
end
end

function key = sensitivity_table_key(analysis,case_name,objective)
key = string(analysis)+"|"+string(case_name)+"|"+string(objective);
end

function row = condition_specific_row_from_nominal(nominal,result,source)
row = struct( ...
    'analysis',string(nominal.analysis), ...
    'case_name',string(nominal.case_name), ...
    'physical_parameter',string(nominal.physical_parameter), ...
    'parameter_value',nominal.parameter_value, ...
    'objective',string(nominal.objective), ...
    'geometry_role',"Condition-specific optimum", ...
    'r_F0',nominal.r_F0, ...
    'sigma_min',nominal.sigma_min, ...
    'condition_number',nominal.condition_number, ...
    'hover_effort',nominal.hover_effort, ...
    'valid',logical(nominal.valid), ...
    'normalization_case',result.normalization_case, ...
    'seed',result.seed, ...
    'elapsed_seconds',0, ...
    'source',string(source));
end

function yes = result_matches(result,case_id,objective)
yes = strcmp(result.objective_name,objective) && ...
    isfield(result,'context') && isfield(result.context,'sensitivity_case') && ...
    strcmp(char(string(result.context.sensitivity_case)),case_id);
end

function row = condition_specific_row_from_metrics( ...
    item,objective,metrics,normalization_case,seed,elapsed_seconds,source)
row = struct('analysis',string(item.analysis), ...
    'case_name',string(item.case_id), ...
    'physical_parameter',string(item.physical_parameter), ...
    'parameter_value',item.physical_value, ...
    'objective',string(objective), ...
    'geometry_role',"Condition-specific optimum", ...
    'r_F0',metrics.r_F0,'sigma_min',metrics.sigma_min, ...
    'condition_number',metrics.condition_number, ...
    'hover_effort',metrics.hover_effort,'valid',metrics.valid, ...
    'normalization_case',normalization_case,'seed',seed, ...
    'elapsed_seconds',elapsed_seconds,'source',string(source));
end

function row = condition_specific_row_template()
row = struct('analysis',"",'case_name',"",'physical_parameter',"", ...
    'parameter_value',NaN, ...
    'objective',"",'geometry_role',"Condition-specific optimum", ...
    'r_F0',NaN,'sigma_min',NaN,'condition_number',NaN, ...
    'hover_effort',NaN,'valid',false, ...
    'normalization_case',NaN,'seed',NaN,'elapsed_seconds',NaN,'source',"");
end

function summary = assess_condition_specific_repeatability(results)
%ASSESS_CONDITION_SPECIFIC_REPEATABILITY Descriptive spread across repeats.
if isempty(results), summary = table(); return; end
keys = sensitivity_keys(results);
unique_keys = unique(keys,'stable');
rows = repmat(repeatability_row_template(),numel(unique_keys),1);
for k = 1:numel(unique_keys)
    subset = results(keys == unique_keys(k));
    repeat_number = nan(numel(subset),1);
    for j = 1:numel(subset)
        token = regexp(subset(j).case_name,'_run_(\d+)$','tokens','once');
        if ~isempty(token), repeat_number(j) = str2double(token{1}); end
    end
    attempted_ids = unique(repeat_number(isfinite(repeat_number)));
    valid_ids = unique(repeat_number(isfinite(repeat_number) & [subset.valid].'));
    values = nan(numel(valid_ids),1);
    for j = 1:numel(valid_ids)
        candidates = subset(repeat_number == valid_ids(j) & [subset.valid].');
        [~,best_index] = min([candidates.objective_value]);
        values(j) = scientific_value(candidates(best_index));
    end
    rows(k) = make_repeatability_row( ...
        subset(1),numel(attempted_ids),numel(valid_ids),values);
end
summary = struct2table(rows);
end

function keys = sensitivity_keys(results)
keys = strings(numel(results),1);
for k = 1:numel(results)
    case_name = "unknown";
    if isfield(results(k).context,'sensitivity_case')
        case_name = string(results(k).context.sensitivity_case);
    end
    keys(k) = case_name+"|"+string(results(k).objective_name);
end
end

function row = repeatability_row_template()
row = struct('sensitivity_case',"",'objective',"", ...
    'attempted_independent_runs',0,'valid_independent_runs',0, ...
    'best_objective_value',NaN,'median_objective_value',NaN, ...
    'worst_objective_value',NaN,'absolute_run_spread',NaN, ...
    'relative_run_spread',NaN);
end

function row = make_repeatability_row(first,attempted,valid,values)
values = values(isfinite(values));
if is_maximized(first.objective_name)
    values = sort(values,'descend');
else
    values = sort(values,'ascend');
end
if isempty(values)
    best = NaN; med = NaN; worst = NaN; spread = NaN; relative = NaN;
else
    best = values(1); med = median(values); worst = values(end);
    spread = abs(worst-best); relative = spread/max(abs(best),eps);
end
row = struct('sensitivity_case',string(first.context.sensitivity_case), ...
    'objective',string(first.objective_name), ...
    'attempted_independent_runs',attempted,'valid_independent_runs',valid, ...
    'best_objective_value',best,'median_objective_value',med, ...
    'worst_objective_value',worst,'absolute_run_spread',spread, ...
    'relative_run_spread',relative);
end

function value = scientific_value(result)
name = char(string(result.objective_name));
if isstruct(result.metrics) && isfield(result.metrics,name)
    value = result.metrics.(name);
else
    value = result.objective_value;
    if is_maximized(name), value = -value; end
end
end

function yes = is_maximized(objective)
yes = ismember(char(string(objective)),{'r_F0','sigma_min'});
end
