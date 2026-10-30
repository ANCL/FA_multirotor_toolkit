function output = run_preflight()
%RUN_PREFLIGHT Cheap end-to-end run using the real GA/patternsearch pathway.
root = setup_project();
[parameters,production_solver] = study_settings();
runtime = resolve_runtime(runtime_settings());
solver = production_solver;
solver.independent_runs = 1;
solver.local_refinements = 1;
solver.ga.population_size = 12;
solver.ga.max_generations = 5;
solver.ga.max_stall_generations = 3;
solver.patternsearch.max_function_evaluations = 120;
solver.pareto_points = 3;
check_study_settings(parameters,production_solver);
check_study_settings(parameters,solver);
folder = fullfile(root,'results','preflight');
if isfolder(folder), rmdir(folder,'s'); end
folder = ensure_folder(folder);
study_log('open',fullfile(folder,'run_log.txt'));
cleanup = onCleanup(@() study_log('close')); %#ok<NASGU>
runtime = verify_parallel_runtime(runtime); %#ok<NASGU>
logger = study_log('stage_start','Preflight','Reduced production-path run',8,0);
verify_candidate_selection_rules();
verify_rotorwise_coordinate_mapping(parameters,solver);
verify_parameterization_nesting(parameters,solver);
study_log('line', ...
    ['Candidate selection, rotor-wise coordinate round trips, and ' ...
     'P2/P3 nesting in P1 verified.']);
store = open_case_store(fullfile(folder,'checkpoints'),'preflight');
results = struct([]);

try
    %% 1. Rotor-wise force-authority optimization through the real case queue
    seeds = initial_rotorwise_seeds(parameters,solver);
    problem = make_design_problem('rotorwise','r_F0',1,parameters);
    problem.initial_designs = seeds{1};
    problem.case_name = 'preflight_rotorwise_r_F0';
    specification = make_optimization_case(1, ...
        'Rotor-wise geometry | r_F0 | queue and checkpoint path', ...
        problem,parameters,stable_seed(solver.master_seed,problem.case_name),struct());
    specification = finalize_optimization_cases(specification,solver);
    [queued,logger,runtime] = run_optimization_cases( ...
        specification,store,logger,solver,runtime);
    % The production queue returns the permanent compact checkpoint twin.
    % Preflight intentionally inspects the one full result for deeper checks.
    checkpoint_data = load(case_store_path(store,specification.case_name),'case_result');
    rotorwise_result = checkpoint_data.case_result;
    require_valid_optimization(rotorwise_result);
    verify_initial_incumbent_retained(rotorwise_result,seeds{1},problem,parameters,solver);
    verify_fast_force_authority(rotorwise_result.metrics,parameters,solver);
    results = append_result(results,rotorwise_result);

    %% 2. Planar hover-effort optimization
    study_log('case_start',2,8,'Planar shared geometry | hover_effort');
    problem = make_design_problem('planar_shared','hover_effort',0,parameters);
    problem.initial_designs = initial_structured_seeds('planar_shared',parameters);
    problem.case_name = 'preflight_planar_hover_effort';
    timer = tic;
    planar_specification = make_optimization_case(2,'',problem,parameters, ...
        stable_seed(solver.master_seed,problem.case_name),struct());
    planar_specification = finalize_optimization_cases(planar_specification,solver);
    planar_result = execute_optimization_case( ...
        planar_specification,solver,struct('log_optimizer_progress',true));
    case_store_save(store,planar_result.case_name,planar_result);
    logger = study_log('optimization_complete',logger,planar_result,toc(timer));
    require_valid_optimization(planar_result);
    verify_geometry_in_rotorwise(planar_result.geometry,parameters,solver,'P3');
    results = append_result(results,planar_result);

    %% 3. Spatial parameterization optimization
    study_log('case_start',3,8,'Spatial C3 geometry | sigma_min');
    problem = make_design_problem('spatial_c3','sigma_min',0,parameters);
    problem.initial_designs = initial_structured_seeds('spatial_c3',parameters);
    problem.case_name = 'preflight_spatial_sigma_min';
    timer = tic;
    spatial_specification = make_optimization_case(3,'',problem,parameters, ...
        stable_seed(solver.master_seed,problem.case_name),struct());
    spatial_specification = finalize_optimization_cases(spatial_specification,solver);
    spatial_result = execute_optimization_case( ...
        spatial_specification,solver,struct('log_optimizer_progress',true));
    case_store_save(store,spatial_result.case_name,spatial_result);
    logger = study_log('optimization_complete',logger,spatial_result,toc(timer));
    require_valid_optimization(spatial_result);
    verify_geometry_in_rotorwise(spatial_result.geometry,parameters,solver,'P2');
    results = append_result(results,spatial_result);

    %% 4. Pareto epsilon-constraint optimization
    study_log('case_start',4,8,'Rotor-wise geometry | authority-effort Pareto case');
    problem = make_design_problem('rotorwise','hover_effort',1,parameters);
    problem.authority_threshold = max(0,0.5*rotorwise_result.metrics.r_F0);
    problem.initial_designs = [rotorwise_result.design_variables(:).';seeds{1}];
    problem.case_name = 'preflight_pareto';
    timer = tic;
    pareto_specification = make_optimization_case(4,'',problem,parameters, ...
        stable_seed(solver.master_seed,problem.case_name),struct());
    pareto_specification = finalize_optimization_cases(pareto_specification,solver);
    pareto_result = execute_optimization_case( ...
        pareto_specification,solver,struct('log_optimizer_progress',true));
    case_store_save(store,pareto_result.case_name,pareto_result);
    logger = study_log('optimization_complete',logger,pareto_result,toc(timer));
    require_valid_optimization(pareto_result);
    results = append_result(results,pareto_result);

    %% 5. Nominal-geometry sensitivity evaluation
    study_log('case_start',5,8,'Nominal geometry | characteristic-length sensitivity');
    timer = tic;
    p_case = parameters;
    p_case.force_moment_length = parameters.sensitivity.characteristic_length_values(1);
    fixed_metrics = evaluate_design(rotorwise_result.geometry,p_case,solver);
    assert_no_internal_error(fixed_metrics);
    logger = study_log('case_complete',logger,fixed_metrics.valid, ...
        sprintf('r_F0 %.8g',fixed_metrics.r_F0), ...
        toc(timer));
    if ~fixed_metrics.valid
        error('fa:PreflightNominalSensitivityInvalid','Nominal-geometry sensitivity evaluation was invalid.');
    end

    %% 6. Sensitivity optimization
    study_log('case_start',6,8,'Rotor-wise geometry | sensitivity optimization');
    p_case = parameters;
    p_case.kappa = parameters.sensitivity.kappa_values(end);
    problem = make_design_problem('rotorwise','sigma_min',1,p_case);
    problem.initial_designs = [rotorwise_result.design_variables(:).';seeds{1}];
    problem.case_name = 'preflight_sensitivity_optimization';
    timer = tic;
    sensitivity_specification = make_optimization_case(6,'',problem,p_case, ...
        stable_seed(solver.master_seed,problem.case_name),struct());
    sensitivity_specification = finalize_optimization_cases( ...
        sensitivity_specification,solver);
    sensitivity_result = execute_optimization_case( ...
        sensitivity_specification,solver,struct('log_optimizer_progress',true));
    case_store_save(store,sensitivity_result.case_name,sensitivity_result);
    logger = study_log('optimization_complete',logger,sensitivity_result,toc(timer));
    require_valid_optimization(sensitivity_result);
    results = append_result(results,sensitivity_result);

    %% 7. Small robustness batch through the real batch queue
    design = struct('name','preflight_rotorwise','geometry',rotorwise_result.geometry);
    robustness_case = struct('index',7, ...
        'case_name','preflight_robustness_position_trials_0001_0003', ...
        'description','Robustness queue | three position perturbations', ...
        'design_index',1,'type','position','level_index',1, ...
        'level',parameters.robustness.position_sigma(1), ...
        'trial_numbers',1:3,'provenance',struct());
    robustness_case = finalize_robustness_cases( ...
        robustness_case,design,parameters,solver);
    [robustness_result,logger,runtime] = run_robustness_cases( ...
        robustness_case,store,logger,design,parameters,solver,runtime);
    robustness_trials = robustness_result(1).trials;
    robustness_summary = summarize_robustness(robustness_trials);

    %% 8. Save, reload, table, figure, and restart checks
    study_log('case_start',8,8,'Save, reload, table, figure, and restart verification');
    timer = tic;
    optimization_checks = arrayfun(@(x) struct( ...
        'case_name',x.case_name,'provenance',x.case_provenance),results);
    restart_ok = all(arrayfun(@(x) case_store_has(store,x),optimization_checks)) && ...
        case_store_has(store,robustness_case);
    if ~restart_ok
        error('fa:PreflightRestartFailed','Checkpoint reload did not preserve completed cases.');
    end
    names = string({results.case_name}).';
    objectives = string({results.objective_name}).';
    objective_values = [results.reported_objective_value].';
    valid = [results.valid].';
    summary = table(names,objectives,objective_values,valid);
    publication_summary = publication_table(summary);
    write_table_bundle(publication_summary,folder,'preflight_summary');
    expected_cases = {results.case_name}.'; %#ok<NASGU>
    all_runs = results; %#ok<NASGU>
    validator_path = fullfile(folder,'preflight_optimization_result_set.mat');
    save(validator_path,'all_runs','expected_cases');
    validated_results = validate_optimization_result_set(validator_path);
    if numel(validated_results) ~= numel(results)
        error('fa:PreflightResultValidationFailed', ...
            'Optimization result-set validation returned an unexpected count.');
    end
    fig = plot_multirotor_configuration(rotorwise_result.geometry);
    export_figure(fig,folder,'preflight_geometry');
    close(fig);
    save(fullfile(folder,'preflight_results.mat'),'results','fixed_metrics', ...
        'robustness_trials','robustness_summary','summary','publication_summary', ...
        'parameters','solver','-v7.3');
    logger = study_log('case_complete',logger,true,'all outputs reloaded and written',toc(timer));

    preflight_hash = preflight_compatibility_hash( ...
        parameters,production_solver); %#ok<NASGU>
    workflow_hash = 'informational-only'; %#ok<NASGU>
    passed_at = datetime('now'); %#ok<NASGU>
    save(fullfile(folder,'preflight_passed.mat'), ...
        'preflight_hash','workflow_hash','passed_at');
    study_log('stage_finish',logger);
    study_log('line','PREFLIGHT PASSED - targeted numerical commands are enabled.');
    output = struct('results',results,'summary',summary,'folder',folder);
catch ME
    marker = fullfile(folder,'preflight_passed.mat');
    if isfile(marker), delete(marker); end
    study_log('error',ME);
    rethrow(ME);
end
end

function results = append_result(results,result)
if isempty(results), results = result; else, results(end+1) = result; end
end

function require_valid_optimization(result)
if ~result.valid
    error('fa:PreflightOptimizationInvalid', ...
        'Preflight case %s did not return a feasible design: %s', ...
        result.case_name,result.failure_reason);
end
end

function assert_no_internal_error(metrics)
if isfield(metrics,'internal_error_identifier') && ...
        ~isempty(metrics.internal_error_identifier)
    error(metrics.internal_error_identifier,'%s',metrics.failure_reason);
end
end


function verify_initial_incumbent_retained(result,initial_designs,problem,parameters,solver)
%VERIFY_INITIAL_INCUMBENT_RETAINED Ensure deterministic seeds cannot be lost.
best_cost = Inf;
for k = 1:size(initial_designs,1)
    geometry = decode_design(initial_designs(k,:).',problem.parameterization, ...
        problem.normalization_case,parameters);
    metrics = evaluate_design(geometry,parameters,solver);
    [c,~] = preflight_constraints(metrics,problem);
    if metrics.valid && all(c <= solver.constraint_tolerance)
        best_cost = min(best_cost,objective_value(metrics,problem.objective));
    end
end
if isfinite(best_cost)
    tolerance = 1e-9*max(1,abs(best_cost));
    if result.objective_value > best_cost+tolerance
        error('fa:PreflightIncumbentLost', ...
            'Optimization returned a result worse than a feasible deterministic seed.');
    end
end
end

function [c,ceq] = preflight_constraints(metrics,problem)
%PREFLIGHT_CONSTRAINTS Mirror the public admissibility margins for a seed check.
if isempty(metrics.geometry_check)
    margin = -ones(7,1);
else
    g = metrics.geometry_check;
    margin = [g.length_lower_margin;g.length_upper_margin; ...
        g.normalization_margin;g.unit_direction_margin;g.separation_margin; ...
        field_or(metrics.constraint_margins,'full_actuation',-1); ...
        field_or(metrics.constraint_margins,'hover',-1)];
end
c = -margin;
if ~isempty(problem.authority_threshold)
    c(end+1,1) = problem.authority_threshold-metrics.r_F0;
end
ceq = zeros(0,1);
end

function value = field_or(s,name,fallback)
if isstruct(s) && isfield(s,name), value = s.(name); else, value = fallback; end
end

function verify_fast_force_authority(metrics,parameters,solver)
%VERIFY_FAST_FORCE_AUTHORITY Independent hull check for the fast formula.
options = struct('equality_tolerance',solver.equality_tolerance, ...
    'bound_tolerance',solver.bound_tolerance, ...
    'vertex_tolerance',solver.vertex_tolerance, ...
    'hull_tolerance',solver.hull_tolerance);
force_set = zero_moment_force_set(metrics.A_f,metrics.A_tau, ...
    parameters.actuator_bounds,options);
if force_set.degenerate
    error('fa:PreflightForceAuthorityDegenerate', ...
        'The preflight zero-moment force set is degenerate.');
end
[radius,inside] = force_authority(force_set.halfspace_normals, ...
    force_set.halfspace_offsets,parameters.hover_wrench(1:3), ...
    solver.hull_tolerance);
tolerance = max(100*solver.hull_tolerance, ...
    100*eps(max(1,abs(metrics.r_F0))));
if ~inside || abs(radius-metrics.r_F0) > tolerance
    error('fa:PreflightForceAuthorityMismatch', ...
        'The fast and hull-based zero-moment force radii disagree.');
end
end

function verify_candidate_selection_rules()
%VERIFY_CANDIDATE_SELECTION_RULES Deterministic preflight safety check.
% This is a compact guard for the global/local decision logic, not a user
% test suite.

feasible_good = candidate(true,0,2,'feasible_good');
feasible_better = candidate(true,0,1,'feasible_better');
infeasible_low_cost = candidate(false,0.2,-100,'infeasible_low_cost');
infeasible_low_violation = candidate(false,0.1,50,'infeasible_low_violation');
infeasible_tie_better = candidate(false,0.1,40,'infeasible_tie_better');

assert_preferred(feasible_good,infeasible_low_cost,true, ...
    'Feasible candidate must outrank infeasible candidate.');
assert_preferred(infeasible_low_cost,feasible_good,false, ...
    'Infeasible candidate must not outrank feasible candidate.');
assert_preferred(feasible_better,feasible_good,true, ...
    'Better feasible objective must be preferred.');
assert_preferred(infeasible_low_violation,infeasible_low_cost,true, ...
    'Smaller infeasible constraint violation must be preferred.');
assert_preferred(infeasible_tie_better,infeasible_low_violation,true, ...
    'Objective may break a tie only when violations are equal.');

audit_optimization_selection(feasible_better, ...
    [infeasible_low_cost feasible_good feasible_better]);
audit_optimization_selection(infeasible_tie_better, ...
    [infeasible_low_cost infeasible_low_violation infeasible_tie_better]);
end

function item = candidate(valid,violation,objective,solver_name)
item = struct('x',0,'objective_value',objective,'valid',logical(valid), ...
    'maximum_constraint_violation',violation,'solver',solver_name, ...
    'exitflag',1,'output',struct());
end

function assert_preferred(candidate_value,incumbent,expected,message)
actual = prefer_optimization_candidate(candidate_value,incumbent);
if actual ~= expected
    error('fa:CandidateSelectionRuleFailed','%s',message);
end
end

function verify_rotorwise_coordinate_mapping(parameters,solver)
%VERIFY_ROTORWISE_COORDINATE_MAPPING Guard the P1 local-angle encoding.
% The deterministic samples include nonplanar arms and wide installation
% angles, including values outside the structured-family +/-60 deg limits.
base_ell = [0.79;0.82;0.67;0.95;0.74;0.58];
gamma = [-2.4;-1.1;0.2;1.3;2.2;2.9];
eta = [-0.7;0.4;-0.2;0.6;-0.5;0.1];
alpha = [-2.7;-1.4;-0.3;0.8;1.9;2.8];
beta = [-1.2;-0.8;-0.1;0.5;1.0;1.35];
for normalization_case = 1:6
    ell = base_ell;
    ell(normalization_case) = 1;
    reference = angle_geometry(ell,gamma,eta,alpha,beta);
    x = encode_rotorwise_geometry(reference,normalization_case,solver);
    decoded = rotorwise_geometry(x,normalization_case,parameters);
    if max(abs(decoded.p-reference.p),[],'all') > 1e-10 || ...
            max(abs(decoded.u-reference.u),[],'all') > 1e-10
        error('fa:RotorwiseCoordinateRoundTrip', ...
            'Rotor-wise local-angle encoding failed its round-trip check.');
    end
end
end

function verify_parameterization_nesting(parameters,solver)
%VERIFY_PARAMETERIZATION_NESTING Ensure P2 and P3 use the same physical map as P1.
families = {'spatial_c3','planar_shared'};
for family_index = 1:numel(families)
    family = families{family_index};
    seeds = initial_structured_seeds(family,parameters);
    sample_rows = unique([1;ceil(size(seeds,1)/2);size(seeds,1)]);
    for sample_index = 1:numel(sample_rows)
        original = decode_design(seeds(sample_rows(sample_index),:).', ...
            family,0,parameters);
        original_metrics = evaluate_design(original,parameters,solver);
        if ~original_metrics.valid
            continue;
        end
        for normalization_case = 1:6
            x = encode_rotorwise_geometry(original,normalization_case,solver);
            nested = rotorwise_geometry(x,normalization_case,parameters);
            if max(abs(nested.p-original.p),[],'all') > 1e-10 || ...
                    max(abs(nested.u-original.u),[],'all') > 1e-10
                error('fa:ParameterizationNestingGeometry', ...
                    '%s is not represented identically inside P1.',family);
            end
            nested_metrics = evaluate_design(nested,parameters,solver);
            if ~nested_metrics.valid || ...
                    max(abs(nested_metrics.A-original_metrics.A),[],'all') > 1e-10 || ...
                    abs(nested_metrics.r_F0-original_metrics.r_F0) > 1e-9 || ...
                    abs(nested_metrics.hover_effort-original_metrics.hover_effort) > 1e-9
                error('fa:ParameterizationNestingMetrics', ...
                    '%s changes physical metrics when encoded in P1.',family);
            end
        end
    end
end
end

function verify_geometry_in_rotorwise(original,parameters,solver,label)
%VERIFY_GEOMETRY_IN_ROTORWISE Check one valid structured design in every P1 case.
original_metrics = evaluate_design(original,parameters,solver);
if ~original_metrics.valid
    error('fa:ParameterizationNestingReference', ...
        '%s nesting reference is not a valid design.',label);
end
for normalization_case = 1:6
    x = encode_rotorwise_geometry(original,normalization_case,solver);
    nested = rotorwise_geometry(x,normalization_case,parameters);
    nested_metrics = evaluate_design(nested,parameters,solver);
    if ~nested_metrics.valid || ...
            max(abs(nested.p-original.p),[],'all') > 1e-10 || ...
            max(abs(nested.u-original.u),[],'all') > 1e-10 || ...
            max(abs(nested_metrics.A-original_metrics.A),[],'all') > 1e-10 || ...
            abs(nested_metrics.r_F0-original_metrics.r_F0) > 1e-9 || ...
            abs(nested_metrics.hover_effort-original_metrics.hover_effort) > 1e-9
        error('fa:ParameterizationNestingOptimizedDesign', ...
            '%s changes geometry or metrics when represented in P1.',label);
    end
end
end

