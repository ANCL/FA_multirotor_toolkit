function output = run_unrestricted_optimization()
%RUN_UNRESTRICTED_OPTIMIZATION Stage 01. P1 only, independent of P2/P3.
[root,parameters,solver,runtime,cleanup] = begin_stage('unrestricted_optimization'); %#ok<NASGU>
try
    folders = output_folders(root);
    stage_folder = ensure_folder(folders.designs);
    checkpoint_root = ensure_folder(folders.checkpoints);
    store = open_case_store(fullfile(checkpoint_root, ...
        '01_unrestricted_optimization'),'unrestricted_optimization');
    [complete,provenance,~,manifest] = stage_is_complete( ...
        stage_folder,'unrestricted_optimization',parameters,solver);
    if complete
        counts = case_store_counts(store);
        expected = 4*6*solver.independent_runs;
        if counts.full == expected && counts.records == expected && ...
                manifest.counts.rotorwise_optimization_cases == expected
            study_log('line','Stage 01: preserved P1 (%d cases), no optimization.',expected);
            output = struct('status','complete','reused',true, ...
                'provenance',provenance,'folder',stage_folder);
            return;
        end
        error('fa:IncompleteP1Store', ...
            'P1 checkpoint count is inconsistent. Restore from the verified backup.');
    end
    counts = case_store_counts(store);
    if counts.full > 0 || counts.records > 0
        error('fa:ProtectedP1Results', ...
            ['Stage 01 contains checkpoints but no valid final manifest. ' ...
             'Restore/regenerate reporting from the backup; P1 will not rerun implicitly.']);
    end
    p1_solver = solver;
    p1_solver.ga.population_size = solver.rotorwise_ga_population_size;
    p1_solver.ga.max_generations = solver.rotorwise_ga_max_generations;
    p1_solver.ga.max_stall_generations = solver.rotorwise_ga_max_stall_generations;
    p1_solver.patternsearch.max_function_evaluations = ...
        solver.rotorwise_patternsearch_max_function_evaluations;
    specifications = design_comparison_case_plan('rotorwise',parameters,p1_solver);
    logger = study_log('stage_start','Stage 01', ...
        'Unrestricted P1 optimization',numel(specifications),0);
    [runs,logger] = run_optimization_cases( ...
        specifications,store,logger,p1_solver,runtime);
    validate_optimization_results(runs,{specifications.case_name}.', ...
        'Stage 01 P1 optimization');
    selected = struct('name',{},'geometry',{},'optimization_result',{});
    for k = 1:numel(parameters.objectives)
        objective = parameters.objectives{k};
        best = select_best_solution(runs,objective);
        selected(end+1) = struct('name',objective, ... %#ok<AGROW>
            'geometry',best.geometry, ...
            'optimization_result',compact_optimization_result(best));
    end
    [cross,evals] = cross_evaluate_designs(selected,parameters,solver);
    evaluations = evals; %#ok<NASGU>
    provenance = study_provenance('unrestricted_optimization', ...
        parameters,solver,provenance_plan(specifications),struct());
    save(fullfile(stage_folder,'rotorwise_selected_designs.mat'), ...
        'selected','evaluations','parameters','solver','provenance','-v7');
    write_table_bundle(cross,stage_folder,'objective_cross_evaluation',provenance);
    write_table_bundle(assess_run_repeatability(runs),stage_folder, ...
        'rotorwise_repeatability',provenance);
    write_table_bundle(optimization_run_table(runs),stage_folder, ...
        'rotorwise_optimization_runs',provenance);
    artifacts = ["rotorwise_selected_designs.mat"; ...
        "objective_cross_evaluation.mat";"rotorwise_repeatability.mat"; ...
        "rotorwise_optimization_runs.mat"];
    counts = struct('rotorwise_optimization_cases',numel(runs), ...
        'rotorwise_checkpoint_records',numel(runs), ...
        'rotorwise_selected_designs',numel(selected));
    write_stage_manifest(stage_folder,provenance,artifacts,counts);
    write_study_metadata(stage_folder,'unrestricted_optimization','rotorwise', ...
        parameters,solver,counts,'fresh_numerical_run');
    output = struct('status','complete','reused',false, ...
        'provenance',provenance,'folder',stage_folder);
    study_log('stage_finish',logger);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end
