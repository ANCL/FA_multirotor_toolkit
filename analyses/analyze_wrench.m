function output = analyze_wrench()
%ANALYZE_WRENCH Analyze one requested body-frame wrench.
%
% Edit only the USER INPUTS section. For several wrench requests together
% with geometry, set, task, and manifest outputs, use analyze_configuration.

root = setup_project();
[parameters,solver] = study_settings();
folder = ensure_folder(fullfile(root,'results','analyses','wrench'));
study_log('open',fullfile(folder,'run_log.txt'));
cleanup = onCleanup(@() study_log('close')); %#ok<NASGU>
logger = study_log('stage_start','Analysis','Single-wrench feasibility',1,0);
try
    %% USER INPUTS
    geometry = planar_shared_geometry([pi/6;0],parameters);
    model = build_multirotor_model(geometry,parameters.kappa, ...
        parameters.reaction_signs,parameters.actuator_bounds);
    w_desired = parameters.hover_wrench;
    analysis_options = struct('force_scale',1, ...
        'length_scale',parameters.force_moment_length, ...
        'equality_tolerance',solver.equality_tolerance, ...
        'bound_tolerance',solver.bound_tolerance, ...
        'allocation_strategy','max_margin');

    study_log('case_start',1,1,'Requested body-frame wrench');
    timer = tic;
    result = check_wrench_feasibility(model.A,model.actuator_bounds, ...
        w_desired,analysis_options);
    save(fullfile(folder,'wrench_feasibility.mat'), ...
        'model','w_desired','analysis_options','result');
    summary = table(string(result.status),result.feasible,result.scaled_error, ...
        result.saturation_margin, ...
        'VariableNames',{'Status','Feasible','ScaledError','SaturationMargin'});
    allocation = table((1:model.n_rotors).',result.mu(:), ...
        result.actuator_margins(:), ...
        'VariableNames',{'Rotor','Allocation','NormalizedMargin'});
    write_table_bundle(summary,folder,'wrench_summary');
    write_table_bundle(allocation,folder,'wrench_allocation');
    detail = sprintf('status %s | scaled error %.3g', ...
        char(string(result.status)),result.scaled_error);
    if result.feasible
        detail = sprintf('%s | margin %.8g',detail,result.saturation_margin);
    end
    logger = study_log('case_complete',logger,true,detail,toc(timer));
    study_log('stage_finish',logger);
    output = struct('model',model,'result',result,'folder',folder);
catch ME
    study_log('error',ME); rethrow(ME);
end
end
