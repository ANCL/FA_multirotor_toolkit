function output = run_pareto_analysis()
%RUN_PARETO_ANALYSIS Epsilon-constraint authority-effort study.
% Cases at one threshold run concurrently. Thresholds remain sequential so
% the best solution from one threshold can seed the next.

[root,parameters,solver,runtime,cleanup] = begin_stage('authority_effort'); %#ok<NASGU>
try
    folders = output_folders(root);
    stage_folder = ensure_folder(folders.pareto);
    source_file = fullfile(folders.designs,'rotorwise_selected_designs.mat');
    if ~isfile(source_file), error('fa:MissingStage01','Run Stage 01 first.'); end
    design_provenance = assert_compatible_result( ...
        source_file,'design_comparison',parameters,solver);
    source = load(source_file,'selected');
    selected = source.selected;
    authority_design = selected(strcmp({selected.name},'r_F0'));
    effort_design = selected(strcmp({selected.name},'hover_effort'));
    if numel(authority_design) ~= 1 || numel(effort_design) ~= 1
        error('fa:MissingParetoEndpoints', ...
            'Stage 01 must contain one r_F0 and one hover_effort design.');
    end

    authority_max = evaluate_design( ...
        authority_design.geometry,parameters,solver).r_F0;
    authority_min = evaluate_design( ...
        effort_design.geometry,parameters,solver).r_F0;
    if authority_max < authority_min-solver.pareto_classification_tolerance
        error('fa:InvalidParetoEndpoints', ...
            'The force-authority design is below the hover-effort endpoint.');
    end
    thresholds = linspace(authority_min,authority_max,solver.pareto_points);
    store = open_case_store(fullfile(ensure_folder(folders.checkpoints), ...
        '03_authority_effort'),'authority_effort');

    seed_designs = initial_rotorwise_seeds(parameters,solver);
    seed_designs = add_normalization_seed( ...
        seed_designs,effort_design.optimization_result);
    seed_designs = add_normalization_seed( ...
        seed_designs,authority_design.optimization_result);
    expected_names = authority_effort_case_names( ...
        numel(thresholds),solver.independent_runs);
    resumed = count_resumable_pareto_cases(store,expected_names);
    logger = study_log('stage_start','Stage 03','Authority-effort trade-off', ...
        numel(expected_names),resumed);

    previous_by_case = cell(6,1);
    previous_by_case{effort_design.optimization_result.normalization_case} = ...
        effort_design.optimization_result.design_variables(:).';
    previous_by_case{authority_design.optimization_result.normalization_case} = ...
        authority_design.optimization_result.design_variables(:).';

    for threshold_index = 1:numel(thresholds)
        specifications = authority_effort_threshold_plan( ...
            threshold_index,thresholds,seed_designs,previous_by_case,parameters,solver);
        [~,logger,runtime] = run_optimization_cases( ...
            specifications,store,logger,solver,runtime);
        threshold_results = case_store_load(store,specifications);
        for normalization_case = 1:6
            keep = [threshold_results.normalization_case] == normalization_case & ...
                [threshold_results.valid];
            candidates = threshold_results(keep);
            if ~isempty(candidates)
                [~,best_index] = min([candidates.objective_value]);
                previous_by_case{normalization_case} = ...
                    candidates(best_index).design_variables(:).';
            end
        end
    end

    all_specifications = rebuild_complete_pareto_plan( ...
        thresholds,seed_designs,authority_design,effort_design,store,parameters,solver);
    runs = case_store_load(store,all_specifications);
    expected_cases = expected_names;
    all_summary = summarize_all_valid_runs(runs,thresholds,solver);
    selected_summary = select_threshold_solutions(runs,thresholds,solver);
    repeatability = assess_pareto_repeatability(runs,thresholds);
    if height(selected_summary) ~= solver.pareto_points
        error('fa:IncompleteParetoFront', ...
            'No valid selected solution was found for one or more authority thresholds.');
    end
    study_plan = provenance_plan(all_specifications,thresholds);
    provenance = study_provenance('authority_effort',parameters,solver, ...
        study_plan,design_provenance);
    save(fullfile(stage_folder,'pareto_results.mat'), ...
        'runs','expected_cases','all_summary','selected_summary','repeatability','thresholds', ...
        'parameters','solver','provenance','-v7.3');
    write_table_bundle(all_summary,stage_folder,'authority_effort_all_runs');
    write_table_bundle(selected_summary,stage_folder,'authority_effort_tradeoff');
    write_table_bundle(repeatability,stage_folder,'run_repeatability');
    write_table_bundle(optimization_run_table(runs),stage_folder,'optimization_runs');
    validate_optimization_result_set(fullfile(stage_folder,'pareto_results.mat'));

    output = struct('summary',selected_summary, ...
        'all_valid_runs',all_summary,'repeatability',repeatability, ...
        'runs',runs,'folder',stage_folder);
    study_log('stage_finish',logger);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function resumed = count_resumable_pareto_cases(store,expected_names)
% Existing names alone cannot prove compatibility because later thresholds
% include the selected previous-threshold incumbent. Count only existing files
% here; exact hashes are checked when each threshold plan is reconstructed.
resumed = 0;
for k = 1:numel(expected_names)
    if isfile(case_store_path(store,expected_names{k})), resumed = resumed+1; end
end
end

function specifications = rebuild_complete_pareto_plan( ...
    thresholds,seed_designs,authority_design,effort_design,store,parameters,solver)
previous_by_case = cell(6,1);
previous_by_case{effort_design.optimization_result.normalization_case} = ...
    effort_design.optimization_result.design_variables(:).';
previous_by_case{authority_design.optimization_result.normalization_case} = ...
    authority_design.optimization_result.design_variables(:).';
specifications = struct([]);
for threshold_index = 1:numel(thresholds)
    current = authority_effort_threshold_plan(threshold_index,thresholds, ...
        seed_designs,previous_by_case,parameters,solver);
    current_results = case_store_load(store,current);
    if isempty(specifications)
        specifications = current;
    else
        specifications = [specifications;current]; %#ok<AGROW>
    end
    for normalization_case = 1:6
        keep = [current_results.normalization_case] == normalization_case & ...
            [current_results.valid];
        candidates = current_results(keep);
        if ~isempty(candidates)
            [~,best_index] = min([candidates.objective_value]);
            previous_by_case{normalization_case} = ...
                candidates(best_index).design_variables(:).';
        end
    end
end
end

function summary = summarize_all_valid_runs(runs,thresholds,solver)
valid_runs = runs([runs.valid]);
if isempty(valid_runs), summary = table(); return; end
authority = arrayfun(@(x) x.metrics.r_F0,valid_runs).';
effort = arrayfun(@(x) x.metrics.hover_effort,valid_runs).';
threshold_index = arrayfun(@(x) parse_threshold(x.case_name),valid_runs).';
threshold = thresholds(threshold_index).';
classification = classify_pareto(authority,effort, ...
    solver.pareto_classification_tolerance);
summary = table(string({valid_runs.case_name}).',threshold_index,threshold, ...
    authority,effort,classification.duplicate,classification.dominated, ...
    classification.nondominated,'VariableNames',{'case_name','threshold_index', ...
    'authority_threshold','r_F0','hover_effort','duplicate','dominated','nondominated'});
end

function summary = select_threshold_solutions(runs,thresholds,solver)
row_template = struct('case_name',"",'threshold_index',0, ...
    'authority_threshold',NaN,'r_F0',NaN,'hover_effort',NaN, ...
    'normalization_case',NaN,'seed',NaN,'constraint_violation',NaN,'elapsed_seconds',NaN);
rows = repmat(row_template,0,1);
for threshold_index = 1:numel(thresholds)
    pattern = [sprintf('pareto_%03d_norm_',threshold_index),'\d+_run_\d+$'];
    keep = false(numel(runs),1);
    for k = 1:numel(runs)
        keep(k) = runs(k).valid && ~isempty(regexp(runs(k).case_name,pattern,'once'));
    end
    candidates = runs(keep);
    if isempty(candidates), continue; end
    [~,best_index] = min([candidates.objective_value]); best = candidates(best_index);
    rows(end+1) = struct('case_name',string(best.case_name), ... %#ok<AGROW>
        'threshold_index',threshold_index,'authority_threshold',thresholds(threshold_index), ...
        'r_F0',best.metrics.r_F0,'hover_effort',best.metrics.hover_effort, ...
        'normalization_case',best.normalization_case,'seed',best.seed, ...
        'constraint_violation',best.constraints.maximum_violation, ...
        'elapsed_seconds',best.elapsed_seconds);
end
if isempty(rows), summary = table(); return; end
summary = struct2table(rows);
classification = classify_pareto(summary.r_F0,summary.hover_effort, ...
    solver.pareto_classification_tolerance);
summary.duplicate = classification.duplicate;
summary.dominated = classification.dominated;
summary.nondominated = classification.nondominated;
end

function index = parse_threshold(case_name)
tokens = regexp(case_name,'pareto_(\d+)_norm','tokens','once');
index = str2double(tokens{1});
end

function seeds = add_normalization_seed(seeds,optimization_result)
%ADD_NORMALIZATION_SEED Add a known design to its compatible case seeds.
normalization_case = optimization_result.normalization_case;
if ~(isscalar(normalization_case) && normalization_case >= 1 && normalization_case <= numel(seeds) && normalization_case == fix(normalization_case))
    error('fa:InvalidNormalizationSeed','Optimization result has an invalid normalization case.');
end
variables = optimization_result.design_variables(:).';
seeds{normalization_case} = unique([variables;seeds{normalization_case}],'rows','stable');
end

function summary = assess_pareto_repeatability(results,thresholds)
%ASSESS_PARETO_REPEATABILITY Descriptive effort spread by Pareto threshold.
rows = repmat(row_template(),numel(thresholds),1);
for threshold_index = 1:numel(thresholds)
    run_ids = nan(numel(results),1);
    matches = false(numel(results),1);
    pattern = sprintf('pareto_%03d_norm_\\d+_run_(\\d+)$',threshold_index);
    for k = 1:numel(results)
        token = regexp(results(k).case_name,pattern,'tokens','once');
        if ~isempty(token)
            matches(k) = true;
            run_ids(k) = str2double(token{1});
        end
    end
    attempted_ids = unique(run_ids(matches & isfinite(run_ids)));
    valid_ids = unique(run_ids(matches & isfinite(run_ids) & [results.valid].'));
    values = nan(numel(valid_ids),1);
    for r = 1:numel(valid_ids)
        candidates = results(matches & run_ids == valid_ids(r) & [results.valid].');
        values(r) = min(arrayfun(@(x) x.metrics.hover_effort,candidates));
    end
    rows(threshold_index) = make_row(threshold_index,thresholds(threshold_index), ...
        numel(attempted_ids),numel(valid_ids),values);
end
summary = struct2table(rows);
end

function row = row_template()
row = struct('threshold_index',0,'authority_threshold',NaN, ...
    'attempted_independent_runs',0,'valid_independent_runs',0, ...
    'best_hover_effort',NaN,'median_hover_effort',NaN, ...
    'worst_hover_effort',NaN,'absolute_run_spread',NaN, ...
    'relative_run_spread',NaN);
end

function row = make_row(index,threshold,attempted,valid,values)
values = sort(values(isfinite(values)),'ascend');
if isempty(values)
    best = NaN; med = NaN; worst = NaN; spread = NaN; relative = NaN;
else
    best = values(1); med = median(values); worst = values(end);
    spread = worst-best; relative = spread/max(abs(best),eps);
end
row = struct('threshold_index',index,'authority_threshold',threshold, ...
    'attempted_independent_runs',attempted,'valid_independent_runs',valid, ...
    'best_hover_effort',best,'median_hover_effort',med, ...
    'worst_hover_effort',worst,'absolute_run_spread',spread, ...
    'relative_run_spread',relative);
end

function classification = classify_pareto(authority, effort, tolerance)
%CLASSIFY_PARETO Identify duplicate, dominated, and nondominated points.
authority=authority(:); effort=effort(:); n=numel(authority);
valid=isfinite(authority)&isfinite(effort); duplicate=false(n,1); dominated=false(n,1);
for i=1:n
    if ~valid(i), dominated(i)=true; continue; end
    previous=find(valid(1:i-1));
    if any(abs(authority(previous)-authority(i))<=tolerance & ...
            abs(effort(previous)-effort(i))<=tolerance)
        duplicate(i)=true;
    end
    competitors=find(valid); competitors(competitors==i)=[];
    no_worse=authority(competitors)>=authority(i)-tolerance & ...
        effort(competitors)<=effort(i)+tolerance;
    strict=authority(competitors)>authority(i)+tolerance | ...
        effort(competitors)<effort(i)-tolerance;
    dominated(i)=any(no_worse & strict);
end
classification=struct('valid',valid,'duplicate',duplicate,'dominated',dominated, ...
    'nondominated',valid & ~duplicate & ~dominated);
end
