function check_study_settings(p,s)
%CHECK_STUDY_SETTINGS Reject invalid scientific or numerical settings.
issues = {};

%% Vehicle, actuation, and geometry
if p.n_rotors ~= 6
    issues{end+1} = 'n_rotors must equal six'; 
end
if ~(isnumeric(p.kappa) && all(isfinite(p.kappa)) && ...
        (isscalar(p.kappa) || numel(p.kappa) == 6) && all(p.kappa >= 0))
    issues{end+1} = 'kappa must be a finite nonnegative scalar or six-vector'; 
end
if ~(isscalar(p.kappa) && abs(p.kappa-0.03) <= s.equality_tolerance)
    issues{end+1} = 'baseline kappa must equal 0.03'; 
end
if numel(p.reaction_signs) ~= 6 || ...
        any(p.reaction_signs(:) ~= [1;1;1;-1;-1;-1])
    issues{end+1} = 'reaction_signs must be [1;1;1;-1;-1;-1]'; 
end
try
    [mu_min,mu_max] = parse_actuator_bounds(p.actuator_bounds,p.n_rotors);
    if any(abs(mu_min) > s.bound_tolerance) || ...
            any(abs(mu_max-1) > s.bound_tolerance)
        issues{end+1} = 'baseline actuator bounds must be [0,1]'; 
    end
catch ME
    issues{end+1} = ['actuator bounds: ' ME.message]; 
end
if ~finite_scalar(p.geometry.ell_min) || p.geometry.ell_min < 0 || ...
        p.geometry.ell_min > 1
    issues{end+1} = 'geometry.ell_min must lie in [0,1]'; 
end
if ~finite_scalar(p.geometry.exclusion_radius) || ...
        p.geometry.exclusion_radius < 0
    issues{end+1} = 'geometry.exclusion_radius must be nonnegative'; 
end
if abs(p.geometry.ell_min-0.30) > s.equality_tolerance || ...
        abs(p.geometry.exclusion_radius-0.15) > s.equality_tolerance
    issues{end+1} = 'baseline geometry must use ell_min=0.30 and exclusion_radius=0.15'; 
end
expected_ranges = {[-pi pi],[-pi/2 pi/2],[-pi pi],[-pi/2 pi/2]};
actual_ranges = {p.geometry.rotorwise.gamma,p.geometry.rotorwise.eta, ...
    p.geometry.rotorwise.alpha,p.geometry.rotorwise.beta};
range_names = {'gamma','eta','alpha','beta'};
for k = 1:4
    if ~valid_range(actual_ranges{k}) || ...
            any(abs(actual_ranges{k}(:)-expected_ranges{k}(:)) > s.equality_tolerance)
        issues{end+1} = sprintf('rotorwise.%s must retain its full-sphere range', ...
            range_names{k}); 
    end
end
if ~valid_range_matrix(p.geometry.spatial_ranges,6)
    issues{end+1} = 'geometry.spatial_ranges must be 6-by-2 with lower < upper'; 
end
if ~valid_range_matrix(p.geometry.planar_ranges,2)
    issues{end+1} = 'geometry.planar_ranges must be 2-by-2 with lower < upper'; 
end
expected_spatial = [0 pi/3;-pi/6 pi/6;repmat([-pi/3 pi/3],4,1)];
expected_planar = repmat([-pi/3 pi/3],2,1);
if ~isequal(size(p.geometry.spatial_ranges),size(expected_spatial)) || ...
        any(abs(p.geometry.spatial_ranges-expected_spatial) > s.equality_tolerance,'all')
    issues{end+1} = 'spatial_ranges do not match the approved P2 definition'; 
end
if ~isequal(size(p.geometry.planar_ranges),size(expected_planar)) || ...
        any(abs(p.geometry.planar_ranges-expected_planar) > s.equality_tolerance,'all')
    issues{end+1} = 'planar_ranges do not match the approved P3 definition'; 
end

%% Hover definition
if numel(p.hover_wrench) ~= 6 || any(~isfinite(p.hover_wrench)) || ...
        norm(p.hover_wrench(4:6),Inf) > s.equality_tolerance
    issues{end+1} = 'hover_wrench must contain six finite values and zero moment'; 
end
if numel(p.hover_wrench) == 6 && ...
        norm(p.hover_wrench(:)-[0;0;-1;0;0;0],Inf) > s.equality_tolerance
    issues{end+1} = 'baseline hover_wrench must equal [0;0;-1;0;0;0]'; 
end
if ~positive_scalar(p.force_moment_length) || ...
        abs(p.force_moment_length-1) > s.equality_tolerance
    issues{end+1} = 'baseline force_moment_length must equal one'; 
end

%% Solver budgets and tolerances
if ~strcmpi(s.global_solver,'ga') || ~strcmpi(s.local_solver,'patternsearch')
    issues{end+1} = 'the study requires ga followed by patternsearch'; 
end
integer_values = [s.master_seed,s.independent_runs,s.ga.population_size, ...
    s.ga.max_generations,s.ga.max_stall_generations, ...
    s.patternsearch.max_function_evaluations,s.pareto_points, ...
    s.rotorwise_ga_population_size,s.rotorwise_ga_max_generations, ...
    s.rotorwise_ga_max_stall_generations, ...
    s.rotorwise_patternsearch_max_function_evaluations];
if any(~isfinite(integer_values)) || any(integer_values < 1) || ...
        any(integer_values ~= floor(integer_values))
    issues{end+1} = 'solver counts and budgets must be positive integers'; 
end
if ~finite_scalar(s.local_refinements) || s.local_refinements < 0 || ...
        s.local_refinements ~= floor(s.local_refinements)
    issues{end+1} = 'local_refinements must be a nonnegative integer'; 
end
if s.ga.max_stall_generations > s.ga.max_generations || ...
        s.rotorwise_ga_max_stall_generations > s.rotorwise_ga_max_generations
    issues{end+1} = 'GA stall generations cannot exceed max generations'; 
end
positive_values = [s.local_start_min_distance,s.ga.function_tolerance, ...
    s.ga.initial_penalty,s.ga.penalty_factor, ...
    s.patternsearch.function_tolerance,s.patternsearch.mesh_tolerance, ...
    s.full_actuation_threshold,s.equality_tolerance,s.bound_tolerance, ...
    s.hull_tolerance,s.vertex_tolerance,s.constraint_tolerance, ...
    s.pareto_classification_tolerance];
if any(~isfinite(positive_values)) || any(positive_values <= 0)
    issues{end+1} = 'solver tolerances and positive settings must be finite and positive'; 
end
if s.local_start_min_distance > 1
    issues{end+1} = 'local_start_min_distance must not exceed one'; 
end
if ~ismember(lower(string(s.ga.nonlinear_constraint_algorithm)),["auglag","penalty"])
    issues{end+1} = 'GA nonlinear constraint algorithm must be auglag or penalty'; 
end
if s.ga.penalty_factor <= 1
    issues{end+1} = 'GA penalty_factor must exceed one'; 
end
if s.pareto_points < 2
    issues{end+1} = 'pareto_points must be at least two'; 
end

%% Sensitivity and robustness definitions
valid_objectives = {'r_F0','sigma_min','condition_number','hover_effort'};
if ~iscellstr(p.objectives) || ~isequal(p.objectives(:),valid_objectives(:)) %#ok<ISCLSTR>
    issues{end+1} = 'objectives must contain the four approved criteria in order';
end
approved_capacity = linspace(0.8,1.2,17);
if ~same_values(p.sensitivity.actuator_capacity_values, ...
        approved_capacity,100*s.equality_tolerance)
    issues{end+1} = ...
        'actuator-capacity values do not match the approved expanded grid'; 
end

approved_kappa = linspace(0,0.06,13);
if ~same_values(p.sensitivity.kappa_values, ...
        approved_kappa,100*s.equality_tolerance)
    issues{end+1} = ...
        'reaction-moment values do not match the approved expanded grid'; 
end

approved_lengths = 2.^linspace(-1,1,17);
if any(~isfinite(p.sensitivity.characteristic_length_values)) || ...
        any(p.sensitivity.characteristic_length_values <= 0) || ...
        ~same_values(p.sensitivity.characteristic_length_values, ...
        approved_lengths,100*s.equality_tolerance)
    issues{end+1} = ...
        'characteristic-length values do not match the approved expanded grid'; 
end

approved_hover_load = linspace(0.8,1.2,17);
if any(~isfinite(p.sensitivity.hover_load_factor_values)) || ...
        any(p.sensitivity.hover_load_factor_values <= 0) || ...
        ~same_values(p.sensitivity.hover_load_factor_values, ...
        approved_hover_load,100*s.equality_tolerance)
    issues{end+1} = ...
        'hover-load factors do not match the approved expanded grid';
end
if ~any(abs(p.sensitivity.hover_load_factor_values-1) <= ...
        100*s.equality_tolerance)
    issues{end+1} = 'hover-load factors must include the exact nominal value one';
end

if ~islogical(p.sensitivity.include_bidirectional) || ...
        ~isscalar(p.sensitivity.include_bidirectional) || ...
        ~p.sensitivity.include_bidirectional
    issues{end+1} = 'the bidirectional sensitivity comparison must remain enabled'; 
end

approved_matrix_metrics = ...
    {'r_F0','sigma_min','condition_number','hover_effort'};
if ~iscellstr(p.sensitivity.matrix_metrics) || ... %#ok<ISCLSTR>
        ~isequal(p.sensitivity.matrix_metrics,approved_matrix_metrics)
    issues{end+1} = ...
        'sensitivity matrix metrics do not match the approved complete matrix';
end

fields = fieldnames(p.sensitivity.optimized_objectives);
for k = 1:numel(fields)
    objectives = p.sensitivity.optimized_objectives.(fields{k});
    if ~iscellstr(objectives) || any(~ismember(objectives,valid_objectives)) %#ok<ISCLSTR>
        issues{end+1} = sprintf('invalid sensitivity objective list: %s',fields{k}); 
    end
end
approved_optimized_objectives = struct();
approved_optimized_objectives.characteristic_length = approved_matrix_metrics;
approved_optimized_objectives.reaction_moment = approved_matrix_metrics;
approved_optimized_objectives.actuator_capacity = approved_matrix_metrics;
approved_optimized_objectives.bidirectional = approved_matrix_metrics;
approved_optimized_objectives.hover_load = approved_matrix_metrics;
if ~isequal(p.sensitivity.optimized_objectives,approved_optimized_objectives)
    issues{end+1} = 'sensitivity objective lists do not match the approved protocol'; 
end
if ~iscellstr(p.robustness.design_objectives) || ... %#ok<ISCLSTR>
        any(~ismember(p.robustness.design_objectives,valid_objectives))
    issues{end+1} = 'robustness design objectives are invalid'; 
end
if ~isequal(p.robustness.design_objectives(:),valid_objectives(:))
    issues{end+1} = 'robustness must evaluate all four objective-dependent designs';
end
levels = {p.robustness.position_sigma,p.robustness.direction_sigma_rad, ...
    p.robustness.capacity_sigma,p.robustness.kappa_sigma};
for k = 1:numel(levels)
    if isempty(levels{k}) || any(~isfinite(levels{k})) || any(levels{k} < 0)
        issues{end+1} = sprintf('robustness level set %d is invalid',k); 
    end
end
approved_levels = {[0.005 0.010 0.020],deg2rad([0.5 1 2]), ...
    [0.02 0.05 0.10],[0.05 0.10 0.20]};
for k = 1:numel(levels)
    if ~same_values(levels{k},approved_levels{k},s.equality_tolerance)
        issues{end+1} = sprintf('robustness level set %d differs from the approved protocol',k); 
    end
end
if ~positive_integer(p.robustness.trials_per_level) || ...
        ~positive_scalar(p.robustness.truncation_sigma)
    issues{end+1} = 'robustness trial and truncation settings are invalid'; 
end
if p.robustness.trials_per_level ~= 500 || ...
        abs(p.robustness.truncation_sigma-3) > s.equality_tolerance
    issues{end+1} = 'robustness must use 500 trials and three-sigma truncation'; 
end

%% Required MATLAB environment
if exist('ga','file') ~= 2 || exist('patternsearch','file') ~= 2
    issues{end+1} = 'Global Optimization Toolbox is required'; 
end
if exist('linprog','file') ~= 2
    issues{end+1} = 'Optimization Toolbox is required'; 
end
if ~isfield(s,'validated_release') || strlength(string(s.validated_release)) == 0
    issues{end+1} = 'validated_release must be recorded'; 
elseif ~strcmp(version('-release'),s.validated_release)
    warning('fa:DifferentMatlabRelease', ...
        ['MATLAB %s is being used; the toolkit was validated with %s. ' ...
         'Results remain release-dependent and should record the active release.'], ...
        version('-release'),s.validated_release);
end

if ~isempty(issues)
    error('fa:InvalidSettings','Study settings are invalid:\n- %s', ...
        strjoin(issues,'\n- '));
end
end

function yes = finite_scalar(value)
yes = isnumeric(value) && isscalar(value) && isfinite(value);
end

function yes = positive_scalar(value)
yes = finite_scalar(value) && value > 0;
end

function yes = positive_integer(value)
yes = positive_scalar(value) && value == floor(value);
end

function yes = same_values(actual,expected,tolerance)
yes = isnumeric(actual) && numel(actual) == numel(expected) && ...
    all(abs(actual(:)-expected(:)) <= tolerance);
end

function yes = valid_range(value)
yes = isnumeric(value) && numel(value) == 2 && all(isfinite(value)) && ...
    value(1) < value(2);
end

function yes = valid_range_matrix(value,rows)
yes = isnumeric(value) && isequal(size(value),[rows 2]) && ...
    all(isfinite(value),'all') && all(value(:,1) < value(:,2));
end
