function output = run_p2_seeded_p1()
%RUN_P2_SEEDED_P1 Stage 06: unrestricted P1 GA with optimized P2 starts.
% The only change relative to Stage 01 is replacement of the first
% deterministic initial-population row by the objective-matched P2 optimum.
% Stage 01 case names and random seeds, all six radius normalizations,
% high GA budget, and local refinements remain identical.
[root,parameters,solver,runtime,cleanup] = begin_stage('p2_seeded_p1');
try
    folders = output_folders(root);
    p1_provenance = assert_completed_stage( ...
        fullfile(folders.designs,'stage_manifest.mat'), ...
        'unrestricted_optimization',parameters,solver);
    p2_provenance = assert_completed_stage( ...
        fullfile(folders.parameterizations,'stage_manifest.mat'), ...
        'parameterization_comparison',parameters,solver,p1_provenance);

    stage_folder = ensure_folder(folders.p2_seeded_p1);
    store = open_case_store(fullfile(ensure_folder(folders.checkpoints), ...
        '06_p2_seeded_p1'),'p2_seeded_p1');
    objectives = {'r_F0','sigma_min','condition_number'};
    expected = numel(objectives)*6*solver.independent_runs;
    [complete,provenance,~,manifest] = stage_is_complete( ...
        stage_folder,'p2_seeded_p1',parameters,solver,p2_provenance);
    if complete
        counts = case_store_counts(store);
        if counts.full == expected && counts.records == expected && ...
                manifest.counts.optimization_cases == expected
            study_log('line', ...
                'Stage 06: completed P2-seeded P1 results reused (%d cases).',expected);
            output = struct('status','complete','reused',true, ...
                'provenance',provenance,'folder',stage_folder);
            return;
        end
        error('fa:Stage06IncompleteStore', ...
            'Stage 06 manifest exists but checkpoint counts do not match.');
    end

    p1_data = load(fullfile(folders.designs, ...
        'rotorwise_selected_designs.mat'),'selected');
    p2_data = load(fullfile(folders.parameterizations, ...
        'spatial_c3_selected_designs.mat'),'selected');
    p1_reference = p1_data.selected;
    p2_reference = p2_data.selected;

    p1_solver = solver;
    p1_solver.ga.population_size = solver.rotorwise_ga_population_size;
    p1_solver.ga.max_generations = solver.rotorwise_ga_max_generations;
    p1_solver.ga.max_stall_generations = solver.rotorwise_ga_max_stall_generations;
    p1_solver.patternsearch.max_function_evaluations = ...
        solver.rotorwise_patternsearch_max_function_evaluations;

    % Build the same original P1 plan. Retain the three non-hover objectives,
    % all six normalization cases, and the exact Stage 01 random seeds.
    specifications = design_comparison_case_plan( ...
        'rotorwise',parameters,p1_solver);
    keep = arrayfun(@(s) ismember(s.problem.objective,objectives), ...
        specifications);
    specifications = specifications(keep);
    assert(numel(specifications)==expected, ...
        'Stage 06 must contain exactly 90 P2-seeded P1 cases.');

    % Before dispatching anything, confirm that P2 -> P1 preserves both
    % physical geometry and objective performance in every normalization.
    for k = 1:numel(specifications)
        objective = specifications(k).problem.objective;
        normal = specifications(k).problem.normalization_case;
        match = find(strcmp({p2_reference.name},objective));
        assert(numel(match)==1, ...
            'Expected one Stage 02 P2 design for %s.',objective);
        source = p2_reference(match);
        x_seed = encode_rotorwise_geometry(source.geometry,normal,p1_solver);
        x_seed = x_seed(:).';
        problem = specifications(k).problem;
        assert(numel(x_seed)==29 && all(isfinite(x_seed)), ...
            'Stage 06 P2-to-P1 seed is not a finite 29-vector.');
        assert(all(x_seed >= problem.lower_bounds(:).'-1e-10) && ...
            all(x_seed <= problem.upper_bounds(:).'+1e-10), ...
            'Stage 06 P2 seed is outside P1 variable bounds.');
        geometry = decode_design(x_seed(:),'rotorwise',normal,parameters);
        assert(norm(geometry.p-source.geometry.p,'fro') <= 1e-8 && ...
            norm(geometry.u-source.geometry.u,'fro') <= 1e-8, ...
            'Stage 06 P2-to-P1 geometry round trip failed.');
        % Evaluate once per objective/normalization pair (not per repeat).
        if k == 1 || ~strcmp(specifications(k-1).problem.objective,objective) || ...
                specifications(k-1).problem.normalization_case ~= normal
            seed_metrics = evaluate_design(geometry,parameters,p1_solver);
            reference_value = source.optimization_result.metrics.(objective);
            assert(seed_metrics.valid && isfinite(seed_metrics.(objective)) && ...
                abs(seed_metrics.(objective)-reference_value) <= ...
                1e-6*max(1,abs(reference_value)), ...
                'Stage 06 P2-to-P1 objective or feasibility changed.');
        end
        % Match Stage 01 initial-population count by replacing ONE seed.
        % The other deterministic starts and the random seed are unchanged.
        assert(~isempty(problem.initial_designs), ...
            'Stage 01 initial seed list must not be empty.');
        problem.initial_designs(1,:) = x_seed;
        specifications(k).problem = problem;
        specifications(k).context = struct( ...
            'analysis','P2_seeded_P1','initialization','optimized_P2');
    end
    specifications = finalize_optimization_cases(specifications,p1_solver);
    inventory = case_store_inventory(store,specifications);
    invalidate_stage_manifest(stage_folder);
    logger = study_log('stage_start','Stage 06', ...
        'P2-seeded unrestricted P1',expected,inventory.full_count);
    [runs,logger,runtime] = run_optimization_cases( ...
        specifications,store,logger,p1_solver,runtime); %#ok<ASGLU>
    study_log('stage_finish',logger);
    validate_optimization_results(runs,{specifications.case_name}.', ...
        'Stage 06 P2-seeded unrestricted optimization');
    if ~all([runs.valid])
        error('fa:Stage06InvalidResult', ...
            'At least one P2-seeded run failed feasibility. Inspect its checkpoint.');
    end

    selected = struct('name',{},'geometry',{},'optimization_result',{});
    comparison = table('Size',[numel(objectives),6], ...
        'VariableTypes',{'string','double','double','double','double','double'}, ...
        'VariableNames',{'objective','stage01_p1','stage02_p2', ...
        'stage06_seeded_p1','improvement_over_p2','improvement_over_stage01'});
    for j = 1:numel(objectives)
        name = objectives{j};
        best = select_best_solution(runs,name);
        p1 = p1_reference(strcmp({p1_reference.name},name));
        p2 = p2_reference(strcmp({p2_reference.name},name));
        assert(numel(p1)==1 && numel(p2)==1);
        p1_value = p1.optimization_result.metrics.(name);
        p2_value = p2.optimization_result.metrics.(name);
        new_value = best.metrics.(name);
        if strcmp(name,'condition_number')
            gain_p2 = p2_value-new_value;
            gain_p1 = p1_value-new_value;
        else
            gain_p2 = new_value-p2_value;
            gain_p1 = new_value-p1_value;
        end
        if gain_p2 < -1e-6*max(1,abs(p2_value))
            error('fa:Stage06LostSeed', ...
                'Stage 06 failed to retain the feasible P2 seed for %s.',name);
        end
        selected(end+1) = struct('name',name, ... %#ok<AGROW>
            'geometry',best.geometry, ...
            'optimization_result',compact_optimization_result(best));
        comparison.objective(j) = string(name);
        comparison.stage01_p1(j) = p1_value;
        comparison.stage02_p2(j) = p2_value;
        comparison.stage06_seeded_p1(j) = new_value;
        comparison.improvement_over_p2(j) = gain_p2;
        comparison.improvement_over_stage01(j) = gain_p1;
    end
    provenance = study_provenance('p2_seeded_p1', ...
        parameters,solver,provenance_plan(specifications),p2_provenance);
    save(fullfile(stage_folder,'seeded_selected_designs.mat'), ...
        'selected','parameters','solver','provenance','-v7');
    write_table_bundle(comparison,stage_folder, ...
        'seeded_vs_baselines',provenance);
    write_table_bundle(optimization_run_table(runs),stage_folder, ...
        'seeded_optimization_runs',provenance);
    write_table_bundle(assess_run_repeatability(runs),stage_folder, ...
        'seeded_repeatability',provenance);
    artifacts = ["seeded_selected_designs.mat"; ...
        "seeded_vs_baselines.mat"; ...
        "seeded_optimization_runs.mat"; ...
        "seeded_repeatability.mat"];
    counts = struct('optimization_cases',numel(runs), ...
        'selected_designs',numel(selected));
    write_stage_manifest(stage_folder,provenance,artifacts,counts);
    write_study_metadata(stage_folder,'p2_seeded_p1', ...
        'rotorwise with optimized spatial_c3 initial seed', ...
        parameters,solver,counts,'seeded_numerical_run');
    disp(comparison);
    output = struct('status','complete','reused',false, ...
        'optimization_cases',numel(runs), ...
        'comparison',comparison,'provenance',provenance,'folder',stage_folder);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end
