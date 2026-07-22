function output = analyze_configuration(case_spec)
%ANALYZE_CONFIGURATION Analyze and export one fixed multirotor configuration.
%
% Syntax
%   output = analyze_configuration(case_spec)
%
% Required input
%   case_spec.geometry        Structure with 3-by-N fields p and u.
%
% Common optional inputs
%   case_spec.name            Readable case name.
%   case_spec.kappa           Scalar or N-vector reaction-moment ratio.
%   case_spec.reaction_signs  N-vector containing -1 or +1.
%   case_spec.actuator_bounds Common [lower upper] or N-by-2 bounds.
%   case_spec.hover_wrench    Six-element body-frame hover wrench.
%   case_spec.length_scale    Positive force-moment scaling length.
%   case_spec.task_Lambda     Optional 6-by-6 diagonal task matrix.
%   case_spec.requested_wrenches  Optional 6-by-M wrench matrix.
%   case_spec.output_folder   Optional exact output folder.
%
% The function writes figures, figure source data, tables, complete MAT
% data, diagnostics, and a reproducibility manifest. It never writes to
% results/current or results/publication.

if nargin < 1
    error('fa:MissingConfigurationCase', ...
        'analyze_configuration requires a case specification.');
end

root = setup_project();
[study_parameters,solver] = study_settings();
case_spec = complete_case_spec(case_spec,study_parameters,solver,root);
[style,graphics_cleanup] = publication_style('activate'); %#ok<ASGLU>

paths = prepare_output_paths(case_spec.output_folder);
study_log('open',fullfile(paths.diagnostics,'run_log.txt'));
log_cleanup = onCleanup(@() study_log('close')); %#ok<NASGU>
logger = study_log('stage_start','Configuration analysis', ...
    case_spec.name,1,0);

try
    study_log('case_start',1,1,'Model, metrics, and feasible sets');
    timer = tic;

    model = build_multirotor_model( ...
        case_spec.geometry,case_spec.kappa,case_spec.reaction_signs, ...
        case_spec.actuator_bounds);
    actuation = check_full_actuation( ...
        model.A,case_spec.length_scale,case_spec.sigma_threshold);

    allocation_options = struct( ...
        'force_scale',case_spec.force_scale, ...
        'length_scale',case_spec.length_scale, ...
        'equality_tolerance',case_spec.equality_tolerance, ...
        'bound_tolerance',case_spec.bound_tolerance, ...
        'allocation_strategy',case_spec.allocation_strategy, ...
        'analyze_allocation_set',case_spec.analyze_allocation_set);
    hover = check_wrench_feasibility( ...
        model.A,model.actuator_bounds,case_spec.hover_wrench, ...
        allocation_options);

    set_options = struct( ...
        'compute_force',case_spec.compute_force_set, ...
        'compute_moment',case_spec.compute_moment_set, ...
        'compute_zero_moment_force',case_spec.compute_zero_moment_force_set, ...
        'equality_tolerance',case_spec.equality_tolerance, ...
        'bound_tolerance',case_spec.bound_tolerance, ...
        'vertex_tolerance',case_spec.vertex_tolerance, ...
        'hull_tolerance',case_spec.hull_tolerance);
    sets = build_feasible_wrench_sets(model,set_options);

    force_extrema = empty_extrema_table();
    moment_extrema = empty_extrema_table();
    zero_moment_extrema = empty_extrema_table();
    if case_spec.compute_force_set
        force_extrema = wrench_set_extrema( ...
            model.A_f,model.actuator_bounds,{'F_x','F_y','F_z'});
    end
    if case_spec.compute_moment_set
        moment_extrema = wrench_set_extrema( ...
            model.A_tau,model.actuator_bounds, ...
            {'tau_x','tau_y','tau_z'});
    end
    if case_spec.compute_zero_moment_force_set
        zero_moment_extrema = extrema_from_zero_moment_set( ...
            sets.zero_moment_force,model.A_f, ...
            {'F_x','F_y','F_z'},case_spec.equality_tolerance);
    end

    authority = evaluate_zero_moment_authority( ...
        sets,case_spec.hover_wrench,case_spec.hull_tolerance);
    task = evaluate_optional_task( ...
        model,case_spec,study_parameters,solver);
    requested = evaluate_requested_wrenches( ...
        model,case_spec,allocation_options);

    tables = build_analysis_tables( ...
        model,actuation,hover,sets,authority,task,requested,case_spec, ...
        force_extrema,moment_extrema,zero_moment_extrema);
    write_analysis_tables(tables,paths.tables);
    write_matrix_tables(model,paths.tables);

    figure_files = write_analysis_figures( ...
        model,sets,case_spec,style,paths.figures);

    analysis = struct( ...
        'case_spec',case_spec, ...
        'model',model, ...
        'actuation',actuation, ...
        'hover',hover, ...
        'sets',sets, ...
        'force_extrema',force_extrema, ...
        'moment_extrema',moment_extrema, ...
        'zero_moment_force_extrema',zero_moment_extrema, ...
        'zero_moment_authority',authority, ...
        'task',task, ...
        'requested_wrenches',requested, ...
        'tables',tables, ...
        'figure_files',figure_files); %#ok<NASGU>
    save(fullfile(paths.data,'configuration_analysis.mat'), ...
        'analysis','-v7.3');

    manifest = build_manifest(root,case_spec,paths,figure_files); %#ok<NASGU>
    save(fullfile(paths.root,'analysis_manifest.mat'),'manifest');
    write_json_file(fullfile(paths.root,'analysis_manifest.json'),manifest);

    detail = sprintf( ...
        'rank(A)=%d, sigma_min=%.6g, hover=%s', ...
        actuation.rank_A,actuation.sigma_min,char(string(hover.status)));
    logger = study_log('case_complete',logger,true,detail,toc(timer));
    study_log('stage_finish',logger);

    output = analysis;
    output.folder = paths.root;
    output.manifest = manifest;
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function case_spec = complete_case_spec(case_spec,parameters,solver,root)
if ~isstruct(case_spec) || ~isscalar(case_spec)
    error('fa:InvalidConfigurationCase', ...
        'case_spec must be one scalar structure.');
end
if ~isfield(case_spec,'geometry')
    error('fa:MissingConfigurationGeometry', ...
        'case_spec.geometry is required.');
end
geometry = case_spec.geometry;
if ~isstruct(geometry) || ~isfield(geometry,'p') || ~isfield(geometry,'u')
    error('fa:InvalidConfigurationGeometry', ...
        'case_spec.geometry must contain fields p and u.');
end
validateattributes(geometry.p,{'numeric'}, ...
    {'real','finite','nrows',3,'nonempty'});
validateattributes(geometry.u,{'numeric'}, ...
    {'real','finite','size',size(geometry.p)});
number_of_rotors = size(geometry.p,2);

case_spec = set_default(case_spec,'name','custom_configuration');
case_spec.name = char(string(case_spec.name));
case_spec.token = safe_case_token(case_spec.name);
case_spec = set_default(case_spec,'kappa',parameters.kappa);
if ~isfield(case_spec,'reaction_signs') || isempty(case_spec.reaction_signs)
    if number_of_rotors == parameters.n_rotors
        case_spec.reaction_signs = parameters.reaction_signs;
    else
        error('fa:MissingReactionSigns', ...
            ['reaction_signs must be supplied when the configuration has ' ...
             '%d rotors.'],number_of_rotors);
    end
end
case_spec = set_default(case_spec,'actuator_bounds',[0 1]);
case_spec = set_default(case_spec,'hover_wrench',parameters.hover_wrench);
case_spec = set_default(case_spec,'length_scale',parameters.force_moment_length);
case_spec = set_default(case_spec,'force_scale',1);
case_spec = set_default(case_spec,'sigma_threshold', ...
    solver.full_actuation_threshold);
case_spec = set_default(case_spec,'equality_tolerance', ...
    solver.equality_tolerance);
case_spec = set_default(case_spec,'bound_tolerance',solver.bound_tolerance);
case_spec = set_default(case_spec,'vertex_tolerance',solver.vertex_tolerance);
case_spec = set_default(case_spec,'hull_tolerance',solver.hull_tolerance);
case_spec = set_default(case_spec,'allocation_strategy','max_margin');
case_spec = set_default(case_spec,'analyze_allocation_set',true);
case_spec = set_default(case_spec,'compute_force_set',true);
case_spec = set_default(case_spec,'compute_moment_set',true);
case_spec = set_default(case_spec,'compute_zero_moment_force_set',true);
case_spec = set_default(case_spec,'requested_wrenches',zeros(6,0));
case_spec = set_default(case_spec,'requested_wrench_names',strings(0,1));
case_spec = set_default(case_spec,'plot_options',struct());

if ~isfield(case_spec,'task_Lambda')
    if number_of_rotors == 6
        case_spec.task_Lambda = parameters.task.Lambda;
    else
        case_spec.task_Lambda = [];
    end
end
if ~isfield(case_spec,'output_folder') || isempty(case_spec.output_folder)
    case_spec.output_folder = fullfile( ...
        root,'results','analyses','configurations',case_spec.token);
else
    case_spec.output_folder = char(string(case_spec.output_folder));
end
case_spec.output_folder = validate_analysis_output_folder( ...
    root,case_spec.output_folder);

validateattributes(case_spec.hover_wrench,{'numeric'}, ...
    {'real','finite','numel',6});
case_spec.hover_wrench = case_spec.hover_wrench(:);
validateattributes(case_spec.length_scale,{'numeric'}, ...
    {'real','finite','scalar','positive'});
validateattributes(case_spec.force_scale,{'numeric'}, ...
    {'real','finite','scalar','positive'});
validateattributes(case_spec.sigma_threshold,{'numeric'}, ...
    {'real','finite','scalar','nonnegative'});
validateattributes(case_spec.requested_wrenches,{'numeric'}, ...
    {'real','finite','nrows',6});
if ~isempty(case_spec.task_Lambda)
    validateattributes(case_spec.task_Lambda,{'numeric'}, ...
        {'real','finite','size',[6 6]});
end
case_spec.requested_wrench_names = complete_wrench_names( ...
    case_spec.requested_wrench_names,size(case_spec.requested_wrenches,2));
end

function value = set_default(value,field_name,default_value)
if ~isfield(value,field_name) || isempty(value.(field_name))
    value.(field_name) = default_value;
end
end

function names = complete_wrench_names(names,count)
if count == 0
    names = strings(0,1);
    return;
end
names = string(names(:));
if isempty(names)
    names = "wrench_" + string((1:count).');
elseif numel(names) ~= count
    error('fa:RequestedWrenchNames', ...
        'One requested_wrench_names entry is required per wrench column.');
end
end

function paths = prepare_output_paths(root_folder)
reset_known_output(root_folder, ...
    {'figures','tables','data','diagnostics'}, ...
    {'analysis_manifest.mat','analysis_manifest.json'});
paths.root = ensure_folder(root_folder);
paths.figures = ensure_folder(fullfile(paths.root,'figures'));
paths.tables = ensure_folder(fullfile(paths.root,'tables'));
paths.data = ensure_folder(fullfile(paths.root,'data'));
paths.diagnostics = ensure_folder(fullfile(paths.root,'diagnostics'));
end

function reset_known_output(root_folder,folder_names,file_names)
ensure_folder(root_folder);
for folder_index = 1:numel(folder_names)
    path_in = fullfile(root_folder,folder_names{folder_index});
    if isfolder(path_in)
        rmdir(path_in,'s');
    end
end
for file_index = 1:numel(file_names)
    path_in = fullfile(root_folder,file_names{file_index});
    if isfile(path_in)
        delete(path_in);
    end
end
end

function authority = evaluate_zero_moment_authority(sets,hover_wrench,tolerance)
authority = struct( ...
    'defined',false, ...
    'radius',NaN, ...
    'hover_force_inside',false, ...
    'facet_gaps',zeros(0,1), ...
    'reason','');
if isempty(sets.zero_moment_force)
    authority.reason = 'zero-moment force set was not requested';
    return;
end
if norm(hover_wrench(4:6),Inf) > tolerance
    authority.reason = 'hover wrench has nonzero moment';
    return;
end
if sets.zero_moment_force.affine_dimension < 3 || ...
        isempty(sets.zero_moment_force.halfspace_normals)
    authority.reason = 'zero-moment force set is lower-dimensional';
    return;
end
[radius,inside,gaps] = force_authority( ...
    sets.zero_moment_force.halfspace_normals, ...
    sets.zero_moment_force.halfspace_offsets, ...
    hover_wrench(1:3),tolerance);
authority.defined = true;
authority.radius = radius;
authority.hover_force_inside = inside;
authority.facet_gaps = gaps;
if ~inside
    authority.reason = 'hover force lies outside the zero-moment force set';
end
end

function task = evaluate_optional_task(model,case_spec,parameters,solver)
task = struct( ...
    'requested',~isempty(case_spec.task_Lambda), ...
    'supported',false, ...
    'result',[], ...
    'verification',[], ...
    'reason','');
if isempty(case_spec.task_Lambda)
    task.reason = 'no task matrix supplied';
    return;
end
if model.n_rotors ~= 6 || size(model.A,2) ~= 6
    task.reason = 'analytic task scale requires a square 6-by-6 allocation map';
    return;
end
local_parameters = parameters;
local_parameters.n_rotors = 6;
local_parameters.kappa = case_spec.kappa;
local_parameters.reaction_signs = case_spec.reaction_signs;
local_parameters.actuator_bounds = model.actuator_bounds;
local_parameters.hover_wrench = case_spec.hover_wrench;
local_parameters.force_moment_length = case_spec.length_scale;
local_parameters.task.Lambda = case_spec.task_Lambda;
result = task_scale(model.A,local_parameters,solver);
task.supported = true;
task.result = result;
if result.valid && isfinite(result.q_star)
    task.verification = verify_task_scale( ...
        model.A,local_parameters,solver,result.q_star);
end
end

function requested = evaluate_requested_wrenches(model,case_spec,options)
number_of_wrenches = size(case_spec.requested_wrenches,2);

% Build one scalar container. Passing cell(number_of_wrenches,1) directly
% to struct would create a structure array, which cannot be indexed through
% requested.results{...} as a scalar analysis record.
requested = struct();
requested.names = case_spec.requested_wrench_names;
requested.wrenches = case_spec.requested_wrenches;
requested.results = cell(number_of_wrenches,1);

for wrench_index = 1:number_of_wrenches
    requested.results{wrench_index} = check_wrench_feasibility( ...
        model.A,model.actuator_bounds, ...
        case_spec.requested_wrenches(:,wrench_index),options);
end
end

function tables = build_analysis_tables( ...
    model,actuation,hover,sets,authority,task,requested,case_spec, ...
    force_extrema,moment_extrema,zero_moment_extrema)
tables.geometry = geometry_table(model);
tables.actuation = actuation_table( ...
    model,actuation,hover,sets,authority,task,case_spec);
tables.hover_allocation = allocation_table( ...
    hover,model.n_rotors,'hover');
tables.set_dimensions = set_dimension_table(sets);
tables.force_extrema = force_extrema;
tables.moment_extrema = moment_extrema;
tables.zero_moment_force_extrema = zero_moment_extrema;
tables.requested_wrenches = requested_wrench_table(requested);
tables.requested_allocations = requested_allocation_table( ...
    requested,model.n_rotors);
if task.supported
    tables.task = task_table(task);
else
    tables.task = table(string(task.reason), ...
        'VariableNames',{'Reason'});
end
end

function T = geometry_table(model)
number_of_rotors = model.n_rotors;
Rotor = (1:number_of_rotors).';
P_x = model.p(1,:).';
P_y = model.p(2,:).';
P_z = model.p(3,:).';
U_x = model.u(1,:).';
U_y = model.u(2,:).';
U_z = model.u(3,:).';
Kappa = model.kappa(:);
ReactionSign = model.reaction_signs(:);
MuMin = model.mu_min(:);
MuMax = model.mu_max(:);
T = table(Rotor,P_x,P_y,P_z,U_x,U_y,U_z, ...
    Kappa,ReactionSign,MuMin,MuMax);

angle_fields = {'ell','gamma','eta','alpha','beta'};
for field_index = 1:numel(angle_fields)
    field_name = angle_fields{field_index};
    if isfield(model,field_name) && numel(model.(field_name)) == number_of_rotors
        values = model.(field_name)(:);
        if strcmp(field_name,'ell')
            T.ell = values;
        else
            T.([field_name '_rad']) = values;
            T.([field_name '_deg']) = rad2deg(values);
        end
    end
end
end

function T = actuation_table( ...
    model,actuation,hover,sets,authority,task,case_spec)
force_dimension = set_dimension(sets.force);
moment_dimension = set_dimension(sets.moment);
zero_moment_dimension = set_dimension(sets.zero_moment_force);
hover_effort = NaN;
if hover.feasible
    hover_effort = sum(hover.mu.^2);
end
task_scale_value = NaN;
task_scale_valid = false;
task_vertices_verified = false;
if task.supported
    task_scale_value = task.result.q_star;
    task_scale_valid = task.result.valid;
    if ~isempty(task.verification)
        task_vertices_verified = task.verification.all_feasible;
    end
end
T = table( ...
    model.n_rotors, ...
    actuation.rank_A, ...
    actuation.rank_A_f, ...
    actuation.rank_A_tau, ...
    actuation.algebraically_full_rank, ...
    actuation.sigma_min, ...
    actuation.condition_number, ...
    case_spec.length_scale, ...
    case_spec.sigma_threshold, ...
    actuation.numerically_fully_actuated, ...
    string(hover.status), ...
    hover.feasible, ...
    hover_effort, ...
    hover.saturation_margin, ...
    force_dimension, ...
    moment_dimension, ...
    zero_moment_dimension, ...
    authority.radius, ...
    authority.hover_force_inside, ...
    task_scale_value, ...
    task_scale_valid, ...
    task_vertices_verified, ...
    'VariableNames',{ ...
        'NumberOfRotors','RankA','RankAf','RankAtau', ...
        'AlgebraicallyFullRank','SigmaMin','ConditionNumber', ...
        'LengthScale','SigmaThreshold','NumericallyFullyActuated', ...
        'HoverStatus','HoverFeasible','HoverEffort', ...
        'HoverSaturationMargin','ForceSetDimension', ...
        'MomentSetDimension','ZeroMomentForceSetDimension', ...
        'ZeroMomentForceAuthority','HoverForceInsideF0', ...
        'TaskScale','TaskScaleValid','TaskVerticesVerified'});
end

function value = set_dimension(set_data)
if isempty(set_data)
    value = NaN;
else
    value = set_data.affine_dimension;
end
end

function T = allocation_table(result,number_of_rotors,label)
Rotor = (1:number_of_rotors).';
Allocation = result.mu(:);
NormalizedMargin = result.actuator_margins(:);
Case = repmat(string(label),number_of_rotors,1);
T = table(Case,Rotor,Allocation,NormalizedMargin);
end

function T = set_dimension_table(sets)
Set = ["force";"moment";"zero_moment_force"];
AffineDimension = [ ...
    set_dimension(sets.force); ...
    set_dimension(sets.moment); ...
    set_dimension(sets.zero_moment_force)];
VertexCount = [ ...
    set_vertex_count(sets.force); ...
    set_vertex_count(sets.moment); ...
    set_vertex_count(sets.zero_moment_force)];
T = table(Set,AffineDimension,VertexCount);
end

function count = set_vertex_count(set_data)
if isempty(set_data)
    count = 0;
else
    count = size(set_data.vertices,1);
end
end

function T = requested_wrench_table(requested)
number_of_wrenches = numel(requested.results);
if number_of_wrenches == 0
    T = table();
    return;
end
Name = requested.names;
Status = strings(number_of_wrenches,1);
Feasible = false(number_of_wrenches,1);
ScaledError = nan(number_of_wrenches,1);
SaturationMargin = nan(number_of_wrenches,1);
W = requested.wrenches.';
for wrench_index = 1:number_of_wrenches
    result = requested.results{wrench_index};
    Status(wrench_index) = string(result.status);
    Feasible(wrench_index) = result.feasible;
    ScaledError(wrench_index) = result.scaled_error;
    SaturationMargin(wrench_index) = result.saturation_margin;
end
T = table(Name,W(:,1),W(:,2),W(:,3),W(:,4),W(:,5),W(:,6), ...
    Status,Feasible,ScaledError,SaturationMargin, ...
    'VariableNames',{'Name','F_x','F_y','F_z','tau_x','tau_y','tau_z', ...
    'Status','Feasible','ScaledError','SaturationMargin'});
end

function T = requested_allocation_table(requested,number_of_rotors)
number_of_wrenches = numel(requested.results);
if number_of_wrenches == 0
    T = table();
    return;
end
rows = number_of_wrenches*number_of_rotors;
Name = strings(rows,1);
Rotor = zeros(rows,1);
Allocation = nan(rows,1);
NormalizedMargin = nan(rows,1);
next_row = 1;
for wrench_index = 1:number_of_wrenches
    indices = next_row:(next_row+number_of_rotors-1);
    result = requested.results{wrench_index};
    Name(indices) = requested.names(wrench_index);
    Rotor(indices) = (1:number_of_rotors).';
    Allocation(indices) = result.mu(:);
    NormalizedMargin(indices) = result.actuator_margins(:);
    next_row = next_row+number_of_rotors;
end
T = table(Name,Rotor,Allocation,NormalizedMargin);
end

function T = task_table(task)
result = task.result;
verified = false;
if ~isempty(task.verification)
    verified = task.verification.all_feasible;
end
T = table( ...
    result.q_star, ...
    result.valid, ...
    result.limiting_actuator, ...
    string(result.limiting_bound), ...
    verified, ...
    string(result.failure_reason), ...
    'VariableNames',{ ...
        'TaskScale','Valid','LimitingActuator','LimitingBound', ...
        'AllVerticesVerified','FailureReason'});
end

function write_analysis_tables(tables,folder)
fields = fieldnames(tables);
for field_index = 1:numel(fields)
    name = fields{field_index};
    if istable(tables.(name)) && width(tables.(name)) > 0
        write_table_bundle(tables.(name),folder,name);
    end
end
end

function write_matrix_tables(model,folder)
write_table_bundle(matrix_table(model.A,model.wrench_order,'mu'), ...
    folder,'allocation_matrix');
write_table_bundle(matrix_table(model.A_f,{'F_x','F_y','F_z'},'mu'), ...
    folder,'allocation_force_block');
write_table_bundle(matrix_table(model.A_tau, ...
    {'tau_x','tau_y','tau_z'},'mu'),folder,'allocation_moment_block');
end

function T = matrix_table(matrix,row_labels,column_prefix)
Component = string(row_labels(:));
T = table(Component);
for column = 1:size(matrix,2)
    T.([column_prefix '_' num2str(column)]) = matrix(:,column);
end
end

function files = write_analysis_figures(model,sets,case_spec,style,folder)
files = struct();
geometry_options = plot_option(case_spec.plot_options,'geometry');
[fig,source_data] = plot_multirotor_configuration(model,geometry_options);
files.configuration = export_with_source( ...
    fig,source_data,folder,'configuration');

if ~isempty(sets.force)
    force_sets = {sets.force};
    labels = string(style.labels.force_set);
    colors = style.colors.gray;
    alpha = style.alpha.surface_full;
    if ~isempty(sets.zero_moment_force)
        force_sets{end+1} = sets.zero_moment_force; %#ok<AGROW>
        labels(end+1,1) = string(style.labels.zero_moment_force_set); %#ok<AGROW>
        colors(end+1,:) = style.colors.blue; %#ok<AGROW>
        alpha(end+1,1) = style.alpha.surface_restricted; %#ok<AGROW>
    end
    force_options = struct( ...
        'labels',labels, ...
        'axis_labels',{{'$F_x$','$F_y$','$F_z$'}}, ...
        'colors',colors, ...
        'face_alpha',alpha, ...
        'reference_point',case_spec.hover_wrench(1:3), ...
        'reference_label',string(style.labels.hover_force));
    force_options = merge_struct(force_options, ...
        plot_option(case_spec.plot_options,'force'));
    [fig,source_data] = plot_feasible_set(force_sets,force_options);
    files.force_sets = export_with_source( ...
        fig,source_data,folder,'force_sets');
end

if ~isempty(sets.moment)
    moment_options = struct( ...
        'labels',string(style.labels.moment_set), ...
        'axis_labels',{{'$\tau_x$','$\tau_y$','$\tau_z$'}}, ...
        'colors',style.colors.gray, ...
        'face_alpha',0.20);
    moment_options = merge_struct(moment_options, ...
        plot_option(case_spec.plot_options,'moment'));
    [fig,source_data] = plot_feasible_set(sets.moment,moment_options);
    files.moment_set = export_with_source( ...
        fig,source_data,folder,'moment_set');
end
end

function options = plot_option(plot_options,name)
options = struct();
if isstruct(plot_options) && isfield(plot_options,name)
    options = plot_options.(name);
end
end

function output = merge_struct(base,overrides)
output = base;
if isempty(overrides)
    return;
end
fields = fieldnames(overrides);
for field_index = 1:numel(fields)
    output.(fields{field_index}) = overrides.(fields{field_index});
end
end

function paths = export_with_source(fig,source_data,folder,name)
cleanup = onCleanup(@() close_if_valid(fig)); %#ok<NASGU>
paths = export_figure(fig,folder,name);
source_paths = write_figure_source_data(source_data,folder,name);
paths.source_mat = source_paths.mat;
paths.source_csv = source_paths.csv;
close(fig);
clear cleanup;
end

function close_if_valid(fig)
if ~isempty(fig) && isgraphics(fig)
    close(fig);
end
end

function manifest = build_manifest(root,case_spec,paths,figure_files)
manifest = struct();
manifest.schema_version = 1;
manifest.kind = 'configuration_analysis';
manifest.case_name = case_spec.name;
manifest.case_token = case_spec.token;
manifest.created_at = char(datetime('now', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
manifest.matlab_version = version;
manifest.matlab_release = version('-release');
manifest.numerical_core_hash = numerical_core_hash(root);
manifest.analysis_source_hash = source_files_hash( ...
    {fullfile(root,'analyses','analyze_configuration.m'), ...
     fullfile(root,'core','io','safe_case_token.m'), ...
     fullfile(root,'core','io','validate_analysis_output_folder.m'), ...
     fullfile(root,'core','io','write_figure_source_data.m'), ...
     fullfile(root,'core','io','write_json_file.m'), ...
     fullfile(root,'internal','write_table_bundle.m')},root);
case_for_hash = rmfield(case_spec, ...
    intersect(fieldnames(case_spec),{'name','token','output_folder'}));
manifest.case_hash = settings_hash( ...
    'configuration_analysis_v2',case_for_hash);
manifest.output_folder = paths.root;
manifest.figure_files = figure_files;
manifest.files = sort(unique([relative_file_list(paths.root); ...
    "analysis_manifest.mat";"analysis_manifest.json"]));
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


function extrema = extrema_from_zero_moment_set( ...
    force_set,A_f,component_names,tolerance)
%EXTREMA_FROM_ZERO_MOMENT_SET Read exact extrema from the constructed set.
%
% The zero-moment force-set builder retains every actuator-space vertex of
% the bounded equality polytope A_tau*mu = 0. A linear force component
% reaches its minimum and maximum at one of those vertices. Reusing the
% retained vertices keeps the extrema and plotted F_0 set numerically
% consistent and avoids a second LP solve with a looser solver tolerance.

component_names = string(component_names(:));
if numel(component_names) ~= 3
    error('fa:ComponentNameCount', ...
        'component_names must contain three force-component labels.');
end
validateattributes(tolerance,{'numeric'}, ...
    {'real','finite','scalar','positive'});
if isempty(force_set) || ~isstruct(force_set) || ...
        ~isfield(force_set,'input_vertices') || ...
        isempty(force_set.input_vertices)
    error('fa:EmptyZeroMomentForceSet', ...
        'The zero-moment actuator set contains no feasible vertices.');
end
if isfield(force_set,'validation') && ...
        isfield(force_set.validation,'maximum_zero_moment_residual') && ...
        force_set.validation.maximum_zero_moment_residual > tolerance
    error('fa:ZeroMomentSetResidual', ...
        ['The constructed zero-moment force set exceeds the requested ' ...
         'equality tolerance.']);
end

inputs = force_set.input_vertices;
force_points = A_f*inputs;
minimum_value = nan(3,1);
maximum_value = nan(3,1);
minimum_input = cell(3,1);
maximum_input = cell(3,1);
minimum_point = cell(3,1);
maximum_point = cell(3,1);

for component = 1:3
    [minimum_value(component),minimum_index] = ...
        min(force_points(component,:));
    [maximum_value(component),maximum_index] = ...
        max(force_points(component,:));
    minimum_input{component} = inputs(:,minimum_index);
    maximum_input{component} = inputs(:,maximum_index);
    minimum_point{component} = force_points(:,minimum_index);
    maximum_point{component} = force_points(:,maximum_index);
end

extrema = table(component_names,minimum_value,maximum_value, ...
    minimum_input,maximum_input,minimum_point,maximum_point, ...
    'VariableNames',{'component','minimum_value','maximum_value', ...
    'minimum_input','maximum_input','minimum_point','maximum_point'});
end

function T = empty_extrema_table()
T = table();
end
