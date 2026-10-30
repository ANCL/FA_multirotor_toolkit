function output = optimize_custom_design(case_spec)
%OPTIMIZE_CUSTOM_DESIGN Run one selected design-optimization problem.
%
% Syntax
%   output = optimize_custom_design(case_spec)
%
% Required or commonly edited fields
%   case_spec.name              Readable optimization name.
%   case_spec.parameterization  rotorwise, spatial_c3, or planar_shared.
%   case_spec.objective         r_F0, sigma_min, condition_number,
%                               or hover_effort.
%
% Optional fields
%   case_spec.independent_runs  Repetitions per normalization case.
%   case_spec.master_seed       Deterministic seed basis.
%   case_spec.parameters        Partial study-parameter overrides.
%   case_spec.solver            Partial solver-setting overrides.
%   case_spec.runtime           Partial runtime-setting overrides.
%   case_spec.authority_threshold  Optional epsilon constraint.
%   case_spec.initial_designs   Numeric rows for P2/P3 or a six-cell
%                               normalization-specific seed set for P1.
%   case_spec.output_folder     Optional exact output folder.
%   case_spec.overwrite         Reset this custom output before running.
%
% Rotor-wise P1 uses all six normalization cases. P2 and P3 use one case.
% Each completed search is checkpointed independently, so rerunning the same
% compatible case resumes only missing repetitions. The selected design is
% automatically passed to analyze_configuration unless disabled.

if nargin < 1
    case_spec = struct();
end
root = setup_project();
[default_parameters,default_solver] = study_settings();
default_runtime = runtime_settings();
case_spec = complete_custom_case( ...
    case_spec,default_parameters,default_solver,default_runtime,root);

if case_spec.overwrite
    reset_custom_output(case_spec.output_folder);
end
paths = prepare_custom_paths(case_spec.output_folder);
study_log('open',fullfile(paths.diagnostics,'run_log.txt'));
log_cleanup = onCleanup(@() study_log('close')); %#ok<NASGU>

try
    specifications = custom_case_plan(case_spec);
    store = open_case_store(paths.checkpoints, ...
        ['custom_optimization_' case_spec.token]);
    resumed = sum(arrayfun(@(item) case_store_has(store,item),specifications));
    logger = study_log('stage_start','Custom optimization', ...
        case_spec.name,numel(specifications),resumed);
    runtime = resolve_runtime(case_spec.runtime);
    [runs,logger,runtime] = run_optimization_cases( ...
        specifications,store,logger,case_spec.solver,runtime);
    study_log('stage_finish',logger);

    best = select_best_solution(runs,case_spec.objective);
    repeatability = assess_run_repeatability(runs);
    run_table = optimization_run_table(runs);
    best_table = selected_design_table(best);

    all_runs = runs; %#ok<NASGU>
    save(fullfile(paths.data,'all_runs.mat'), ...
        'all_runs','case_spec','-v7.3');
    selected = best; %#ok<NASGU>
    save(fullfile(paths.data,'selected_design.mat'), ...
        'selected','case_spec','-v7.3');
    write_table_bundle(run_table,paths.tables,'optimization_runs');
    write_table_bundle(repeatability,paths.tables,'run_repeatability');
    write_table_bundle(best_table,paths.tables,'selected_design_summary');

    % The selected-design analysis owns a separate diagnostic log.
    study_log('close');
    selected_analysis = [];
    if case_spec.analyze_selected_design
        selected_analysis = analyze_selected_geometry( ...
            best,case_spec,paths.selected_design);
    end

    manifest = custom_manifest( ...
        root,case_spec,paths,specifications,best,runtime); %#ok<NASGU>
    save(fullfile(paths.root,'optimization_manifest.mat'),'manifest');
    write_json_file(fullfile(paths.root,'optimization_manifest.json'),manifest);

    output = struct( ...
        'runs',runs, ...
        'selected',best, ...
        'run_table',run_table, ...
        'repeatability',repeatability, ...
        'selected_analysis',selected_analysis, ...
        'folder',paths.root, ...
        'manifest',manifest);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function case_spec = complete_custom_case( ...
    case_spec,parameters,solver,runtime,root)
if ~isstruct(case_spec) || ~isscalar(case_spec)
    error('fa:InvalidCustomOptimization', ...
        'case_spec must be one scalar structure.');
end
case_spec = set_default(case_spec,'name','custom_optimization');
case_spec.name = char(string(case_spec.name));
case_spec.token = safe_case_token(case_spec.name);
case_spec = set_default(case_spec,'parameterization','planar_shared');
case_spec = set_default(case_spec,'objective','r_F0');
case_spec.parameterization = char(lower(string(case_spec.parameterization)));
case_spec.objective = canonical_objective(case_spec.objective);

if isfield(case_spec,'parameters') && ~isempty(case_spec.parameters)
    parameters = recursive_merge(parameters,case_spec.parameters);
end
if isfield(case_spec,'solver') && ~isempty(case_spec.solver)
    solver = recursive_merge(solver,case_spec.solver);
end
if isfield(case_spec,'runtime') && ~isempty(case_spec.runtime)
    runtime = recursive_merge(runtime,case_spec.runtime);
end
case_spec.parameters = parameters;
case_spec.solver = solver;
case_spec.runtime = runtime;

case_spec = set_default(case_spec,'independent_runs',solver.independent_runs);
case_spec = set_default(case_spec,'master_seed',solver.master_seed);
case_spec = set_default(case_spec,'authority_threshold',[]);
case_spec = set_default(case_spec,'initial_designs',[]);
case_spec = set_default(case_spec,'overwrite',false);
case_spec = set_default(case_spec,'analyze_selected_design',true);
validateattributes(case_spec.overwrite,{'logical'}, {'scalar'});
validateattributes(case_spec.analyze_selected_design,{'logical'}, {'scalar'});
if ~isfield(case_spec,'output_folder') || isempty(case_spec.output_folder)
    case_spec.output_folder = fullfile( ...
        root,'results','analyses','optimizations',case_spec.token);
else
    case_spec.output_folder = char(string(case_spec.output_folder));
end
case_spec.output_folder = validate_analysis_output_folder( ...
    root,case_spec.output_folder);
validate_custom_settings(parameters,solver,runtime);

valid_parameterizations = {'rotorwise','spatial_c3','planar_shared'};
if ~ismember(case_spec.parameterization,valid_parameterizations)
    error('fa:CustomParameterization', ...
        'parameterization must be rotorwise, spatial_c3, or planar_shared.');
end
valid_objectives = {'r_F0','sigma_min','condition_number', ...
    'hover_effort'};
if ~ismember(case_spec.objective,valid_objectives)
    error('fa:CustomObjective', ...
        'Unknown custom optimization objective: %s',case_spec.objective);
end
if parameters.n_rotors ~= 6
    error('fa:CustomOptimizationRotorCount', ...
        'The implemented P1/P2/P3 design parameterizations require six rotors.');
end
validateattributes(case_spec.independent_runs,{'numeric'}, ...
    {'real','finite','scalar','integer','positive'});
validateattributes(case_spec.master_seed,{'numeric'}, ...
    {'real','finite','scalar','integer','positive'});
if ~isempty(case_spec.authority_threshold)
    validateattributes(case_spec.authority_threshold,{'numeric'}, ...
        {'real','finite','scalar','nonnegative'});
end
end

function objective = canonical_objective(value)
value = lower(char(string(value)));
switch value
    case 'r_f0'
        objective = 'r_F0';
    case 'sigma_min'
        objective = 'sigma_min';
    case 'condition_number'
        objective = 'condition_number';
    case 'hover_effort'
        objective = 'hover_effort';
    otherwise
        objective = value;
end
end

function validate_custom_settings(parameters,solver,runtime)
%VALIDATE_CUSTOM_SETTINGS Check editable one-off optimization inputs.
issues = strings(0,1);
if parameters.n_rotors ~= 6
    issues(end+1) = "parameters.n_rotors must equal six";
end
if ~(isnumeric(parameters.kappa) && all(isfinite(parameters.kappa),'all') && ...
        (isscalar(parameters.kappa) || numel(parameters.kappa)==6) && ...
        all(parameters.kappa>=0,'all'))
    issues(end+1) = "parameters.kappa must be a nonnegative scalar or six-vector";
end
if ~(isnumeric(parameters.reaction_signs) && ...
        numel(parameters.reaction_signs)==6 && ...
        all(ismember(parameters.reaction_signs(:),[-1 1])))
    issues(end+1) = "parameters.reaction_signs must contain six values in {-1,+1}";
end
try
    parse_actuator_bounds(parameters.actuator_bounds,6);
catch ME
    issues(end+1) = "parameters.actuator_bounds: " + string(ME.message);
end
if ~positive_scalar(parameters.force_moment_length)
    issues(end+1) = "parameters.force_moment_length must be positive";
end
if ~(isnumeric(parameters.hover_wrench) && numel(parameters.hover_wrench)==6 && ...
        all(isfinite(parameters.hover_wrench),'all') && ...
        norm(parameters.hover_wrench(4:6),Inf)<=solver.equality_tolerance)
    issues(end+1) = "parameters.hover_wrench must be finite with zero moment";
end
if ~isfield(parameters,'geometry') || ...
        ~positive_or_zero_scalar(parameters.geometry.ell_min) || ...
        parameters.geometry.ell_min>1
    issues(end+1) = "parameters.geometry.ell_min must lie in [0,1]";
end
if ~isfield(parameters,'geometry') || ...
        ~positive_or_zero_scalar(parameters.geometry.exclusion_radius)
    issues(end+1) = "parameters.geometry.exclusion_radius must be nonnegative";
end
range_names = {'gamma','eta','alpha','beta'};
for index = 1:numel(range_names)
    name = range_names{index};
    if ~isfield(parameters.geometry,'rotorwise') || ...
            ~isfield(parameters.geometry.rotorwise,name) || ...
            ~valid_range(parameters.geometry.rotorwise.(name))
        issues(end+1) = "parameters.geometry.rotorwise." + name + ...
            " must be a finite increasing two-value range";
    end
end
if ~valid_range_matrix(parameters.geometry.spatial_ranges,6)
    issues(end+1) = "parameters.geometry.spatial_ranges must be 6-by-2";
end
if ~valid_range_matrix(parameters.geometry.planar_ranges,2)
    issues(end+1) = "parameters.geometry.planar_ranges must be 2-by-2";
end
if ~strcmpi(char(string(solver.global_solver)),'ga')
    issues(end+1) = "solver.global_solver must be ga";
end
if ~ismember(lower(string(solver.local_solver)),["patternsearch","none"])
    issues(end+1) = "solver.local_solver must be patternsearch or none";
end
if ~nonnegative_integer(solver.local_refinements)
    issues(end+1) = "solver.local_refinements must be a nonnegative integer";
end
if ~positive_or_zero_scalar(solver.local_start_min_distance)
    issues(end+1) = "solver.local_start_min_distance must be nonnegative";
end
if ~positive_integer(solver.ga.population_size) || ...
        ~positive_integer(solver.ga.max_generations) || ...
        ~positive_integer(solver.ga.max_stall_generations)
    issues(end+1) = "GA population and generation budgets must be positive integers";
end
if ~positive_integer(solver.patternsearch.max_function_evaluations)
    issues(end+1) = "pattern-search function-evaluation budget must be positive";
end
positive_tolerances = [solver.ga.function_tolerance; ...
    solver.patternsearch.function_tolerance; ...
    solver.patternsearch.mesh_tolerance;solver.full_actuation_threshold; ...
    solver.equality_tolerance;solver.bound_tolerance; ...
    solver.hull_tolerance;solver.vertex_tolerance; ...
    solver.constraint_tolerance];
if any(~isfinite(positive_tolerances)) || any(positive_tolerances<=0)
    issues(end+1) = "solver tolerances must be finite and positive";
end
try
    check_runtime_settings(runtime);
catch ME
    issues(end+1) = string(ME.message);
end
if ~isempty(issues)
    error('fa:InvalidCustomOptimizationSettings', ...
        'Custom optimization settings are invalid:\n- %s', ...
        strjoin(cellstr(issues),[newline '- ']));
end
end

function yes = valid_range(value)
yes = isnumeric(value) && numel(value)==2 && ...
    all(isfinite(value),'all') && value(1)<value(2);
end

function yes = valid_range_matrix(value,rows)
yes = isnumeric(value) && isequal(size(value),[rows 2]) && ...
    all(isfinite(value),'all') && all(value(:,1)<value(:,2));
end

function yes = positive_scalar(value)
yes = isnumeric(value) && isscalar(value) && isfinite(value) && value>0;
end

function yes = positive_or_zero_scalar(value)
yes = isnumeric(value) && isscalar(value) && isfinite(value) && value>=0;
end

function yes = positive_integer(value)
yes = positive_scalar(value) && value==floor(value);
end

function yes = nonnegative_integer(value)
yes = positive_or_zero_scalar(value) && value==floor(value);
end

function value = set_default(value,field_name,default_value)
if ~isfield(value,field_name) || isempty(value.(field_name))
    value.(field_name) = default_value;
end
end

function output = recursive_merge(base,overrides)
output = base;
fields = fieldnames(overrides);
for field_index = 1:numel(fields)
    name = fields{field_index};
    if isfield(output,name) && isstruct(output.(name)) && ...
            isstruct(overrides.(name)) && isscalar(output.(name)) && ...
            isscalar(overrides.(name))
        output.(name) = recursive_merge(output.(name),overrides.(name));
    else
        output.(name) = overrides.(name);
    end
end
end

function reset_custom_output(root_folder)
ensure_folder(root_folder);
folder_names = {'checkpoints','tables','data','diagnostics', ...
    'selected_design_analysis'};
for folder_index = 1:numel(folder_names)
    path_in = fullfile(root_folder,folder_names{folder_index});
    if isfolder(path_in)
        rmdir(path_in,'s');
    end
end
file_names = {'optimization_manifest.mat','optimization_manifest.json'};
for file_index = 1:numel(file_names)
    path_in = fullfile(root_folder,file_names{file_index});
    if isfile(path_in)
        delete(path_in);
    end
end
end

function paths = prepare_custom_paths(root_folder)
paths.root = ensure_folder(root_folder);
paths.checkpoints = ensure_folder(fullfile(paths.root,'checkpoints'));
paths.tables = ensure_folder(fullfile(paths.root,'tables'));
paths.data = ensure_folder(fullfile(paths.root,'data'));
paths.diagnostics = ensure_folder(fullfile(paths.root,'diagnostics'));
paths.selected_design = fullfile(paths.root,'selected_design_analysis');
end

function specifications = custom_case_plan(case_spec)
parameterization = case_spec.parameterization;
if strcmp(parameterization,'rotorwise')
    normalization_cases = 1:6;
    default_seeds = initial_rotorwise_seeds( ...
        case_spec.parameters,case_spec.solver);
else
    normalization_cases = 0;
    default_seeds = initial_structured_seeds( ...
        parameterization,case_spec.parameters);
end

number_of_cases = numel(normalization_cases)*case_spec.independent_runs;
items = cell(number_of_cases,1);
next_case = 1;
for normalization_case = normalization_cases
    initial_designs = select_initial_designs( ...
        case_spec.initial_designs,default_seeds, ...
        parameterization,normalization_case);
    for run_index = 1:case_spec.independent_runs
        problem = make_design_problem( ...
            parameterization,case_spec.objective, ...
            normalization_case,case_spec.parameters);
        problem.authority_threshold = case_spec.authority_threshold;
        problem.initial_designs = initial_designs;
        problem.case_name = sprintf('%s_%s_%s_n%d_run_%02d', ...
            case_spec.token,parameterization,case_spec.objective, ...
            normalization_case,run_index);
        seed_label = sprintf('%s|%s|%s|n%d|run%d', ...
            case_spec.token,parameterization,case_spec.objective, ...
            normalization_case,run_index);
        seed = stable_seed(case_spec.master_seed,seed_label);
        description = sprintf('%s, normalization %d, run %d/%d', ...
            case_spec.objective,normalization_case,run_index, ...
            case_spec.independent_runs);
        context = struct( ...
            'workflow','custom_optimization', ...
            'case_token',case_spec.token, ...
            'run_index',run_index, ...
            'hash_inputs',struct( ...
                'workflow','custom_optimization_v1', ...
                'case_token',case_spec.token, ...
                'run_index',run_index));
        specification = make_optimization_case( ...
            next_case,description,problem,case_spec.parameters,seed,context);
        specification.provenance = optimization_case_provenance( ...
            specification,case_spec.solver);
        items{next_case} = specification;
        next_case = next_case+1;
    end
end
specifications = vertcat(items{:});
end

function initial_designs = select_initial_designs( ...
    supplied,defaults,parameterization,normalization_case)
if isempty(supplied)
    if strcmp(parameterization,'rotorwise')
        initial_designs = defaults{normalization_case};
    else
        initial_designs = defaults;
    end
    return;
end
if strcmp(parameterization,'rotorwise')
    if ~iscell(supplied) || numel(supplied) ~= 6
        error('fa:CustomRotorwiseSeeds', ...
            ['Rotor-wise initial_designs must be a six-element cell array, ' ...
             'one matrix for each normalization case.']);
    end
    initial_designs = supplied{normalization_case};
else
    if ~isnumeric(supplied)
        error('fa:CustomStructuredSeeds', ...
            'P2/P3 initial_designs must be a numeric row matrix.');
    end
    initial_designs = supplied;
end
end

function T = selected_design_table(result)
metrics = result.metrics;
T = table( ...
    string(result.case_name), ...
    string(result.parameterization), ...
    string(result.objective_name), ...
    result.normalization_case, ...
    result.seed, ...
    result.valid, ...
    string(result.selected_solver), ...
    result.reported_objective_value, ...
    metrics.r_F0, ...
    metrics.sigma_min, ...
    metrics.condition_number, ...
    metrics.hover_effort, ...
    result.constraints.maximum_violation, ...
    result.elapsed_seconds, ...
    'VariableNames',{ ...
        'CaseName','Parameterization','Objective','NormalizationCase', ...
        'Seed','Valid','SelectedSolver','ObjectiveValue', ...
        'ForceAuthority','SigmaMin','ConditionNumber','HoverEffort', ...
        'MaximumConstraintViolation','ElapsedSeconds'});
end

function analysis = analyze_selected_geometry(best,case_spec,output_folder)
analysis_spec = struct();
analysis_spec.name = [case_spec.name ' selected design'];
analysis_spec.geometry = best.geometry;
analysis_spec.kappa = case_spec.parameters.kappa;
analysis_spec.reaction_signs = case_spec.parameters.reaction_signs;
analysis_spec.actuator_bounds = case_spec.parameters.actuator_bounds;
analysis_spec.hover_wrench = case_spec.parameters.hover_wrench;
analysis_spec.length_scale = case_spec.parameters.force_moment_length;
analysis_spec.sigma_threshold = case_spec.solver.full_actuation_threshold;
analysis_spec.equality_tolerance = case_spec.solver.equality_tolerance;
analysis_spec.bound_tolerance = case_spec.solver.bound_tolerance;
analysis_spec.vertex_tolerance = case_spec.solver.vertex_tolerance;
analysis_spec.hull_tolerance = case_spec.solver.hull_tolerance;
analysis_spec.output_folder = output_folder;
analysis = analyze_configuration(analysis_spec);
end

function manifest = custom_manifest( ...
    root,case_spec,paths,specifications,best,runtime)
manifest = struct();
manifest.schema_version = 1;
manifest.kind = 'custom_optimization';
manifest.case_name = case_spec.name;
manifest.case_token = case_spec.token;
manifest.parameterization = case_spec.parameterization;
manifest.objective = case_spec.objective;
manifest.independent_runs = case_spec.independent_runs;
problems = [specifications.problem];
manifest.normalization_cases = unique([problems.normalization_case]);
manifest.created_at = char(datetime('now', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
manifest.matlab_version = version;
manifest.matlab_release = version('-release');
manifest.execution_mode = runtime.execution_label;
manifest.numerical_core_hash = numerical_core_hash(root);
manifest.workflow_source_hash = workflow_source_hash();
manifest.custom_source_hash = source_files_hash( ...
    {fullfile(root,'analyses','optimize_custom_design.m'), ...
     fullfile(root,'analyses','analyze_configuration.m'), ...
     fullfile(root,'core','io','safe_case_token.m'), ...
     fullfile(root,'core','io','validate_analysis_output_folder.m')},root);
manifest.plan_hash = settings_hash('custom_optimization_plan_v1', ...
    provenance_plan(specifications));
manifest.selected_case = best.case_name;
manifest.selected_case_hash = best.case_provenance.case_hash;
manifest.selected_objective_value = best.reported_objective_value;
manifest.output_folder = paths.root;
manifest.files = sort(unique([relative_file_list(paths.root); ...
    "optimization_manifest.mat";"optimization_manifest.json"]));
end

function files = relative_file_list(root_folder)
listing = dir(fullfile(root_folder,'**','*'));
listing = listing(~[listing.isdir]);
files = strings(numel(listing),1);
for index = 1:numel(listing)
    full_path = fullfile(listing(index).folder,listing(index).name);
    files(index) = string(erase(full_path,[root_folder filesep]));
end
files = sort(files);
end
