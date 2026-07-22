function output = run_task_evaluation()
%RUN_TASK_EVALUATION Independently verify r_F0, q*, and all 64 task vertices.

[root,parameters,solver,~,cleanup] = begin_stage('task_evaluation'); %#ok<NASGU>
try
    folders = output_folders(root);
    stage_folder = ensure_folder(folders.task);
    source_file = fullfile(folders.designs,'rotorwise_selected_designs.mat');
    if ~isfile(source_file), error('fa:MissingStage01','Run Stage 01 first.'); end
    design_provenance = assert_compatible_result( ...
        source_file,'design_comparison',parameters,solver);
    source = load(source_file,'selected');
    selected = source.selected;

    n = numel(selected);
    logger = study_log('stage_start','Stage 02','Selected-design verification',n,0);
    verification_template = struct('name',"",'metrics',struct(), ...
        'force_authority_hull',struct(),'force_authority_verified',false, ...
        'at_q_star',struct(),'above_q_star',struct());
    verification = repmat(verification_template,n,1);
    name = strings(n,1); q_star = nan(n,1); task_feasible = false(n,1);
    limiting_actuator = nan(n,1); limiting_bound = strings(n,1);
    force_authority_verified = false(n,1);
    q_star_verified = false(n,1); larger_scale_infeasible = false(n,1);

    for k = 1:n
        case_id = char(string(selected(k).name));
        study_log('case_start',k,n,sprintf('Design %s',case_id));
        case_timer = tic;
        metrics = evaluate_design(selected(k).geometry,parameters,solver);
        force_authority_hull = struct();
        at_q_star = struct(); above_q_star = struct();
        if metrics.valid
            [force_authority_hull,force_authority_verified(k)] = ...
                verify_force_authority(metrics,parameters,solver);
            at_q_star = verify_task_scale(metrics.A,parameters,solver,metrics.q_star);
            above_q_star = verify_task_scale(metrics.A,parameters,solver, ...
                metrics.q_star+solver.task_verification_increment);
            q_star_verified(k) = at_q_star.all_feasible;
            larger_scale_infeasible(k) = ~above_q_star.all_feasible;
        end
        verification(k).name = string(selected(k).name);
        verification(k).metrics = metrics;
        verification(k).force_authority_hull = force_authority_hull;
        verification(k).force_authority_verified = force_authority_verified(k);
        verification(k).at_q_star = at_q_star;
        verification(k).above_q_star = above_q_star;
        name(k) = string(selected(k).name);
        q_star(k) = metrics.q_star;
        task_feasible(k) = metrics.task_feasible;
        if isstruct(metrics.task) && ~isempty(metrics.task)
            limiting_actuator(k) = metrics.task.limiting_actuator;
            limiting_bound(k) = string(metrics.task.limiting_bound);
        end
        case_valid = metrics.valid && force_authority_verified(k) && ...
            q_star_verified(k) && larger_scale_infeasible(k);
        detail = sprintf( ...
            'r_F0 verified %d | q_star %.8g | at limit %d | above limit infeasible %d', ...
            force_authority_verified(k),metrics.q_star,q_star_verified(k), ...
            larger_scale_infeasible(k));
        logger = study_log('case_complete',logger,case_valid,detail,toc(case_timer));
    end

    summary = table(name,q_star,task_feasible,limiting_actuator,limiting_bound, ...
        force_authority_verified,q_star_verified,larger_scale_infeasible);
    study_plan = struct('selected_designs',string({selected.name}), ...
        'verification_increment',solver.task_verification_increment);
    provenance = study_provenance('task_evaluation',parameters,solver, ...
        study_plan,design_provenance);
    save(fullfile(stage_folder,'task_verification.mat'), ...
        'verification','parameters','solver','provenance','-v7.3');
    write_table_bundle(summary,stage_folder,'task_capability');
    if any(~summary.force_authority_verified)
        error('fa:ForceAuthorityVerificationFailed', ...
            'One or more selected designs failed independent F0-radius verification.');
    end
    if any(~summary.q_star_verified) || any(~summary.larger_scale_infeasible)
        error('fa:TaskVerificationFailed', ...
            'One or more selected designs failed q-star verification.');
    end
    output = struct('summary',summary,'verification',verification,'folder',stage_folder);
    study_log('stage_finish',logger);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end

function [verification,passed] = verify_force_authority(metrics,parameters,solver)
%VERIFY_FORCE_AUTHORITY Compare the fast square-map formula with an F0 hull.
options = struct('equality_tolerance',solver.equality_tolerance, ...
    'bound_tolerance',solver.bound_tolerance, ...
    'vertex_tolerance',solver.vertex_tolerance, ...
    'hull_tolerance',solver.hull_tolerance);
force_set = zero_moment_force_set(metrics.A_f,metrics.A_tau, ...
    parameters.actuator_bounds,options);
if force_set.degenerate
    verification = struct('radius',NaN,'inside',false,'force_set',force_set, ...
        'absolute_error',Inf,'tolerance',NaN);
    passed = false;
    return;
end
[radius,inside] = force_authority(force_set.halfspace_normals, ...
    force_set.halfspace_offsets,parameters.hover_wrench(1:3), ...
    solver.hull_tolerance);
absolute_error = abs(radius-metrics.r_F0);
tolerance = max(100*solver.hull_tolerance, ...
    100*eps(max(1,abs(metrics.r_F0))));
passed = inside && absolute_error <= tolerance;
verification = struct('radius',radius,'inside',inside,'force_set',force_set, ...
    'absolute_error',absolute_error,'tolerance',tolerance);
end
