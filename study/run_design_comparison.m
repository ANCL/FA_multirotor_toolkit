function output = run_design_comparison()
%RUN_DESIGN_COMPARISON Optimize P2/P3, then the containing rotor-wise P1 domain.
% Optimized structured designs are supplied as deterministic P1 incumbents.
% This enforces the physical nesting relation in the reported best-found
% results: P1 cannot be reported as worse than a contained P2 or P3 design.

[root,parameters,solver,runtime,cleanup] = begin_stage('design_comparison'); %#ok<NASGU>
try
    folders = output_folders(root);
    stage_folder = ensure_folder(folders.designs);
    checkpoint_root = ensure_folder(folders.checkpoints);

    %% Structured P2/P3 searches
    families = {'spatial_c3','planar_shared'};
    structured_specifications = design_comparison_case_plan( ...
        'structured',parameters,solver);
    structured_store = open_case_store(fullfile(checkpoint_root, ...
        '01_design_comparison_structured'),'design_comparison');
    resumed = sum(arrayfun(@(x) case_store_has( ...
        structured_store,x),structured_specifications));
    structured_logger = study_log('stage_start','Stage 01A', ...
        'Structured P2/P3 optimization',numel(structured_specifications),resumed);
    [structured_runs,structured_logger,runtime] = run_optimization_cases( ...
        structured_specifications,structured_store,structured_logger,solver,runtime);
    study_log('stage_finish',structured_logger);
    expected_structured_cases = {structured_specifications.case_name}.';
    structured_selected = select_structured_designs( ...
        structured_runs,families,parameters.objectives);

    %% Rotor-wise P1 searches with guaranteed structured incumbents
    rotorwise_specifications = design_comparison_case_plan( ...
        'rotorwise',parameters,solver,structured_selected);
    rotorwise_store = open_case_store(fullfile(checkpoint_root, ...
        '01_design_comparison_rotorwise'),'design_comparison');
    resumed = sum(arrayfun(@(x) case_store_has( ...
        rotorwise_store,x),rotorwise_specifications));
    rotorwise_logger = study_log('stage_start','Stage 01B', ...
        'Rotor-wise P1 optimization',numel(rotorwise_specifications),resumed);
    [rotorwise_runs,rotorwise_logger] = run_optimization_cases( ...
        rotorwise_specifications,rotorwise_store,rotorwise_logger,solver,runtime);
    study_log('stage_finish',rotorwise_logger);
    expected_rotorwise_cases = {rotorwise_specifications.case_name}.';

    rotorwise_selected = select_rotorwise_designs( ...
        rotorwise_runs,parameters.objectives);
    nested_domain_audit = verify_nested_best_found_results( ...
        rotorwise_selected,structured_selected,parameters.objectives);

    %% Shared evaluation and saved evidence
    [objective_cross_evaluation,rotorwise_evaluations] = ...
        cross_evaluate_designs(rotorwise_selected,parameters,solver);
    all_selected = [rotorwise_selected structured_selected];
    [parameterization_comparison,all_evaluations] = ...
        cross_evaluate_designs(all_selected,parameters,solver);
    rotorwise_repeatability = assess_run_repeatability(rotorwise_runs);
    structured_repeatability = assess_run_repeatability(structured_runs);
    study_plan = struct( ...
        'structured',provenance_plan(structured_specifications), ...
        'rotorwise',provenance_plan(rotorwise_specifications));
    provenance = study_provenance( ...
        'design_comparison',parameters,solver,study_plan,struct());

    all_runs = structured_runs; %#ok<NASGU>
    expected_cases = expected_structured_cases; %#ok<NASGU>
    save(fullfile(stage_folder,'structured_all_runs.mat'), ...
        'all_runs','expected_cases','parameters','solver','provenance','-v7.3');
    all_runs = rotorwise_runs; %#ok<NASGU>
    expected_cases = expected_rotorwise_cases; %#ok<NASGU>
    save(fullfile(stage_folder,'rotorwise_all_runs.mat'), ...
        'all_runs','expected_cases','parameters','solver','provenance','-v7.3');

    selected = rotorwise_selected; %#ok<NASGU>
    evaluations = rotorwise_evaluations; %#ok<NASGU>
    save(fullfile(stage_folder,'rotorwise_selected_designs.mat'), ...
        'selected','evaluations','parameters','solver','provenance');
    selected = all_selected; %#ok<NASGU>
    evaluations = all_evaluations; %#ok<NASGU>
    save(fullfile(stage_folder,'all_selected_designs.mat'), ...
        'selected','evaluations','nested_domain_audit', ...
        'parameters','solver','provenance');

    write_table_bundle(objective_cross_evaluation,stage_folder, ...
        'objective_cross_evaluation');
    write_table_bundle(parameterization_comparison,stage_folder, ...
        'parameterization_comparison');
    write_table_bundle(rotorwise_repeatability,stage_folder, ...
        'rotorwise_repeatability');
    write_table_bundle(structured_repeatability,stage_folder, ...
        'structured_repeatability');
    write_table_bundle(optimization_run_table(rotorwise_runs),stage_folder, ...
        'rotorwise_optimization_runs');
    write_table_bundle(optimization_run_table(structured_runs),stage_folder, ...
        'structured_optimization_runs');
    write_table_bundle(nested_domain_audit,stage_folder, ...
        'nested_domain_audit');

    validate_optimization_result_set( ...
        fullfile(stage_folder,'structured_all_runs.mat'));
    validate_optimization_result_set( ...
        fullfile(stage_folder,'rotorwise_all_runs.mat'));

    output = struct( ...
        'rotorwise_runs',rotorwise_runs, ...
        'structured_runs',structured_runs, ...
        'rotorwise_selected',rotorwise_selected, ...
        'structured_selected',structured_selected, ...
        'objective_cross_evaluation',objective_cross_evaluation, ...
        'parameterization_comparison',parameterization_comparison, ...
        'nested_domain_audit',nested_domain_audit, ...
        'folder',stage_folder);
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
            'optimization_result',best);
    end
end
end

function selected = select_rotorwise_designs(runs,objectives)
selected = struct('name',{},'geometry',{},'optimization_result',{});
for objective_index = 1:numel(objectives)
    objective = objectives{objective_index};
    best = select_best_solution(runs,objective);
    selected(end+1) = struct( ... %#ok<AGROW>
        'name',objective,'geometry',best.geometry,'optimization_result',best);
end
end

function audit = verify_nested_best_found_results( ...
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
if any(~passed)
    failed = strjoin(cellstr(objective(~passed)),', ');
    error('fa:NestedDomainDominance', ...
        ['P1 was reported worse than a contained structured incumbent for: %s. ' ...
         'The deterministic seed or selection pathway is inconsistent.'],failed);
end
end

function label = family_label(family)
switch family
    case 'spatial_c3'
        label = 'Spatial C3 P2';
    case 'planar_shared'
        label = 'Planar shared-angle P3';
    otherwise
        label = family;
end
end
