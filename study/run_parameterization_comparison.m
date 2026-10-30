function output = run_parameterization_comparison()
%RUN_PARAMETERIZATION_COMPARISON Stage 02: optimize P2 and P3, compare with P1.
[root,parameters,solver,runtime,cleanup] = begin_stage('parameterization_comparison'); %#ok<NASGU>
try
    folders = output_folders(root);
    stage_folder = ensure_folder(folders.parameterizations);
    p1_provenance = assert_completed_stage( ...
        fullfile(folders.designs,'stage_manifest.mat'), ...
        'unrestricted_optimization',parameters,solver);
    p1 = load(fullfile(folders.designs,'rotorwise_selected_designs.mat'),'selected');
    rotorwise_selected = p1.selected;
    store = open_case_store(fullfile(ensure_folder(folders.checkpoints), ...
        '02_parameterization_comparison'),'parameterization_comparison');
    [complete,provenance,~,manifest] = stage_is_complete( ...
        stage_folder,'parameterization_comparison',parameters,solver,p1_provenance);
    if complete
        counts = case_store_counts(store);
        expected = 2*numel(parameters.objectives)*solver.independent_runs;
        if counts.full == expected && counts.records == expected && ...
                manifest.counts.structured_optimization_cases == expected
            study_log('line','Stage 02: completed P2/P3 products reused.');
            output = struct('status','complete','reused',true, ...
                'provenance',provenance,'folder',stage_folder);
            return;
        end
    end
    invalidate_stage_manifest(stage_folder);
    specifications = design_comparison_case_plan('structured',parameters,solver);
    inventory = case_store_inventory(store,specifications);
    logger = study_log('stage_start','Stage 02','P2/P3 parameterizations', ...
        numel(specifications),inventory.full_count);
    [runs,logger,runtime] = run_optimization_cases( ...
        specifications,store,logger,solver,runtime);
    study_log('stage_finish',logger);
    validate_optimization_results(runs,{specifications.case_name}.', ...
        'Stage 02 structured optimization');
    structured_selected = select_structured_designs(runs, ...
        {'spatial_c3','planar_shared'},parameters.objectives);
    nested_domain_audit = compare_nested_best_found_results( ...
        rotorwise_selected,structured_selected,parameters.objectives);
    all_selected = [rotorwise_selected structured_selected];
    [comparison,all_evaluations] = cross_evaluate_designs( ...
        all_selected,parameters,solver);
    provenance = study_provenance('parameterization_comparison', ...
        parameters,solver,provenance_plan(specifications),p1_provenance);
    selected = all_selected; evaluations = all_evaluations; %#ok<NASGU>
    save(fullfile(stage_folder,'all_selected_designs.mat'), ...
        'selected','evaluations','nested_domain_audit', ...
        'parameters','solver','provenance','-v7');
    selected = structured_selected( ...
        startsWith(string({structured_selected.name}),"spatial_c3_")); %#ok<NASGU>
    for k = 1:numel(selected)
        selected(k).name = char(erase(string(selected(k).name),'spatial_c3_'));
    end
    save(fullfile(stage_folder,'spatial_c3_selected_designs.mat'), ...
        'selected','parameters','solver','provenance','-v7');
    write_table_bundle(comparison,stage_folder, ...
        'parameterization_comparison',provenance);
    write_table_bundle(assess_run_repeatability(runs),stage_folder, ...
        'structured_repeatability',provenance);
    write_table_bundle(optimization_run_table(runs),stage_folder, ...
        'structured_optimization_runs',provenance);
    write_table_bundle(nested_domain_audit,stage_folder, ...
        'nested_domain_audit',provenance);
    artifacts = ["all_selected_designs.mat"; ...
        "spatial_c3_selected_designs.mat"; ...
        "parameterization_comparison.mat"; ...
        "structured_repeatability.mat"; ...
        "structured_optimization_runs.mat";"nested_domain_audit.mat"];
    counts = struct('structured_optimization_cases',numel(runs), ...
        'structured_checkpoint_records',numel(runs), ...
        'all_selected_designs',numel(all_selected));
    write_stage_manifest(stage_folder,provenance,artifacts,counts);
    write_study_metadata(stage_folder,'parameterization_comparison', ...
        'spatial_c3 and planar_shared',parameters,solver,counts,'fresh_numerical_run');
    output = struct('status','complete','reused',false, ...
        'structured_optimization_cases',numel(runs), ...
        'provenance',provenance,'folder',stage_folder);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function selected = select_structured_designs(runs,families,objectives)
selected = struct('name',{},'geometry',{},'optimization_result',{});
for family_index = 1:numel(families)
    family = families{family_index};
    family_runs = runs(strcmp({runs.parameterization},family));
    for objective_index = 1:numel(objectives)
        objective = objectives{objective_index};
        best = select_best_solution(family_runs,objective);
        selected(end+1) = struct( ... %#ok<AGROW>
            'name',[family '_' objective], ...
            'geometry',best.geometry, ...
            'optimization_result',compact_optimization_result(best));
    end
end
end

function audit = compare_nested_best_found_results( ...
    rotorwise_selected,structured_selected,objectives)
objective = strings(numel(objectives),1);
rotorwise_cost = nan(numel(objectives),1);
best_structured_cost = nan(numel(objectives),1);
margin = nan(numel(objectives),1);
passed = false(numel(objectives),1);
for k = 1:numel(objectives)
    objective(k) = string(objectives{k});
    p1 = rotorwise_selected(strcmp({rotorwise_selected.name},objectives{k}));
    structured = structured_selected(endsWith( ...
        string({structured_selected.name}),"_"+objective(k)));
    if numel(p1) ~= 1 || numel(structured) ~= 2
        error('fa:NestedDomainSelection', ...
            'Nested-domain selections are incomplete for %s.',objective(k));
    end
    rotorwise_cost(k) = p1.optimization_result.objective_value;
    best_structured_cost(k) = min(arrayfun( ...
        @(x) x.optimization_result.objective_value,structured));
    margin(k) = best_structured_cost(k)-rotorwise_cost(k);
    tolerance = 1e-9*max(1,abs(best_structured_cost(k)));
    passed(k) = margin(k) >= -tolerance;
end
audit = table(objective,rotorwise_cost,best_structured_cost,margin,passed);
end
