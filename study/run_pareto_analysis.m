function output = run_pareto_analysis()
%RUN_PARETO_ANALYSIS Run/resume P2 and independent P1 authority-effort studies.
% P2 uses its existing completed cases; P1 uses only P1 initialization.
output = struct();
output.p2 = run_p2_authority_effort();
output.p1 = run_p1_pareto_analysis();
end

function output = run_p2_authority_effort()
%RUN_P2_AUTHORITY_EFFORT Epsilon-constraint authority-effort study for P2.
% Cases at one threshold run concurrently. Thresholds remain sequential so
% the best solution from one threshold can seed the next.

[root,parameters,solver,runtime,cleanup] = begin_stage('authority_effort'); %#ok<NASGU>
try
    folders = output_folders(root);
    stage_folder = ensure_folder(folders.pareto);
    source_file = fullfile(folders.parameterizations,'spatial_c3_selected_designs.mat');
    if ~isfile(source_file), error('fa:MissingStage02','Run Stage 02 first.'); end
    design_provenance = assert_completed_stage( ...
        fullfile(folders.parameterizations,'stage_manifest.mat'), ...
        'parameterization_comparison',parameters,solver);
    store = open_case_store(fullfile(ensure_folder(folders.checkpoints), ...
        '03_authority_effort'),'authority_effort');
    [complete,completed_provenance,~,completed_manifest] = stage_is_complete( ...
        stage_folder,'authority_effort',parameters,solver,design_provenance);
    record_reconcile_only = false;
    if complete
        expected = completed_manifest.counts.optimization_cases;
        counts = case_store_counts(store);
        if counts.full == expected && counts.records == expected
            study_log('line','Stage 03 already complete and compatible. No work required.');
            output = struct('status','complete','reused',true, ...
                'provenance',completed_provenance,'folder',stage_folder);
            return;
        elseif counts.full == expected
            record_reconcile_only = true;
            study_log('line', ...
                'Stage 03 products are current; reconciling missing compact checkpoint twins only.');
        else
            study_log('line', ...
                'Stage 03 manifest is current, but authoritative checkpoint count changed; rebuilding stage data.');
        end
    end
    source = load(source_file,'selected');
    selected = source.selected;
    authority_design = selected(strcmp({selected.name},'r_F0'));
    effort_design = selected(strcmp({selected.name},'hover_effort'));
    if numel(authority_design) ~= 1 || numel(effort_design) ~= 1
        error('fa:MissingParetoEndpoints', ...
            'Stage 02 P2 must contain one r_F0 and one hover_effort design.');
    end
    if ~record_reconcile_only
        invalidate_stage_manifest(stage_folder);
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
    seed_designs = initial_structured_seeds('spatial_c3',parameters);
    seed_designs = unique([ ...
        effort_design.optimization_result.design_variables(:).'; ...
        authority_design.optimization_result.design_variables(:).'; ...
        seed_designs],'rows','stable');
    expected_names = authority_effort_case_names( ...
        numel(thresholds),solver.independent_runs);
    resumed = count_resumable_pareto_cases(store,expected_names);
    logger = study_log('stage_start','Stage 03','P2 authority-effort trade-off', ...
        numel(expected_names),resumed);
    previous_incumbent = effort_design.optimization_result.design_variables(:).';
    all_specifications = struct([]);
    result_blocks = cell(numel(thresholds),1);

    for threshold_index = 1:numel(thresholds)
        specifications = authority_effort_threshold_plan( ...
            threshold_index,thresholds,seed_designs,previous_incumbent,parameters,solver);
        [threshold_results,logger,runtime] = run_optimization_cases( ...
            specifications,store,logger,solver,runtime);
        result_blocks{threshold_index} = threshold_results;
        if isempty(all_specifications)
            all_specifications = specifications;
        else
            all_specifications = [all_specifications;specifications]; %#ok<AGROW>
        end
        candidates = threshold_results([threshold_results.valid]);
        if ~isempty(candidates)
            [~,best_index] = min([candidates.objective_value]);
            previous_incumbent = candidates(best_index).design_variables(:).';
        end
    end

    runs = reshape(horzcat(result_blocks{:}),1,[]);
    expected_cases = expected_names;
    validate_optimization_results(runs,expected_cases, ...
        'Stage 03 authority-effort optimization results');
    if record_reconcile_only
        counts = case_store_counts(store);
        if counts.records ~= numel(expected_cases)
            error('fa:IncompleteParetoRecordStore', ...
                'Expected %d compact checkpoint records, but found %d.', ...
                numel(expected_cases),counts.records);
        end
        study_log('line','Stage 03 checkpoint twins complete. Canonical stage products unchanged.');
        study_log('stage_finish',logger);
        output = struct('status','complete','reused',true, ...
            'provenance',completed_provenance,'folder',stage_folder);
        return;
    end
    all_summary = summarize_all_valid_runs(runs,thresholds,solver);
    selected_summary = select_threshold_solutions(runs,thresholds,solver);
    selected_designs = selected_pareto_designs(runs,selected_summary);
    repeatability = assess_pareto_repeatability(runs,thresholds);
    if height(selected_summary) ~= solver.pareto_points
        error('fa:IncompleteParetoFront', ...
            'No valid selected solution was found for one or more authority thresholds.');
    end
    study_plan = provenance_plan(all_specifications,thresholds);
    provenance = study_provenance('authority_effort',parameters,solver, ...
        study_plan,design_provenance);
    write_table_bundle(all_summary,stage_folder,'authority_effort_all_runs',provenance);
    write_table_bundle(selected_summary,stage_folder,'authority_effort_tradeoff',provenance);
    write_table_bundle(repeatability,stage_folder,'run_repeatability',provenance);
    write_table_bundle(optimization_run_table(runs),stage_folder,'optimization_runs',provenance);
    selected = selected_designs; %#ok<NASGU>
    save(fullfile(stage_folder,'pareto_selected_designs.mat'), ...
        'selected','parameters','solver','provenance','-v7');

    artifacts = [ ...
        "authority_effort_all_runs.mat"; ...
        "authority_effort_tradeoff.mat"; ...
        "run_repeatability.mat"; ...
        "optimization_runs.mat"; ...
        "pareto_selected_designs.mat"];
    counts = struct('optimization_cases',numel(runs), ...
        'checkpoint_records',numel(runs), ...
        'selected_thresholds',height(selected_summary), ...
        'valid_scientific_runs',height(all_summary), ...
        'selected_designs',numel(selected_designs));
    write_stage_manifest(stage_folder,provenance,artifacts,counts);
    write_study_metadata(stage_folder,'authority_effort','spatial_c3', ...
        parameters,solver,counts,'fresh_numerical_run');

    output = struct('summary',selected_summary, ...
        'all_valid_runs',all_summary,'repeatability',repeatability, ...
        'selected_designs',selected_designs, ...
        'optimization_cases',numel(runs),'folder',stage_folder);
    study_log('stage_finish',logger);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function resumed = count_resumable_pareto_cases(store,expected_names)
% Existing names alone cannot prove compatibility because later thresholds
% include the selected previous-threshold incumbent. Count filenames only;
% exact hashes are checked when each threshold plan is reconstructed.
listing = dir(fullfile(store.case_folder,'*.mat'));
actual = string({listing.name});
expected = string(expected_names)+".mat";
resumed = sum(ismember(expected,actual));
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
    pattern = [sprintf('pareto_%03d_run_',threshold_index),'\d+$'];
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

function selected = selected_pareto_designs(runs,summary)
%SELECTED_PARETO_DESIGNS Compact selected geometry at every threshold.
selected = struct('name',{},'threshold_index',{},'authority_threshold',{}, ...
    'geometry',{},'optimization_result',{});
for k = 1:height(summary)
    match = strcmp(string({runs.case_name}),string(summary.case_name(k)));
    item = runs(match);
    if numel(item) ~= 1
        error('fa:ParetoSelectedDesignIdentity', ...
            'Expected exactly one selected Pareto run for %s.',summary.case_name(k));
    end
    selected(end+1) = struct( ... %#ok<AGROW>
        'name',string(summary.case_name(k)), ...
        'threshold_index',summary.threshold_index(k), ...
        'authority_threshold',summary.authority_threshold(k), ...
        'geometry',item.geometry, ...
        'optimization_result',compact_optimization_result(item));
end
end

function index = parse_threshold(case_name)
tokens = regexp(case_name,'pareto_(\d+)_run_','tokens','once');
index = str2double(tokens{1});
end

function summary = assess_pareto_repeatability(results,thresholds)
%ASSESS_PARETO_REPEATABILITY Descriptive effort spread by Pareto threshold.
rows = repmat(row_template(),numel(thresholds),1);
for threshold_index = 1:numel(thresholds)
    run_ids = nan(numel(results),1);
    matches = false(numel(results),1);
    pattern = [sprintf('pareto_%03d_run_',threshold_index),'(\d+)$'];
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
