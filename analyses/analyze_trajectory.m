function output = analyze_trajectory()
%ANALYZE_TRAJECTORY Compute and export sampled trajectory feasibility.
%
% Edit only the USER INPUTS sections. The function saves the required
% wrenches, allocations, feasibility diagnostics, figures, and figure
% source data without changing comparative-study results.

root = setup_project();
[parameters,solver] = study_settings();
[~,graphics_cleanup] = publication_style('activate'); %#ok<NASGU>
folder = ensure_folder(fullfile(root,'results','analyses','trajectory'));
study_log('open',fullfile(folder,'run_log.txt'));
cleanup = onCleanup(@() study_log('close')); %#ok<NASGU>
logger = study_log('stage_start','Analysis','Trajectory-wrench feasibility',1,0);
try
    %% USER INPUTS: VEHICLE
    geometry = planar_shared_geometry([pi/6;0],parameters);
    model = build_multirotor_model(geometry,parameters.kappa, ...
        parameters.reaction_signs,parameters.actuator_bounds);

    %% USER INPUTS: TRAJECTORY
    time = linspace(0,10,201);
    linear_acceleration_I = [0.4*sin(2*pi*time/10); ...
        0.3*cos(2*pi*time/10);zeros(size(time))];
    R_IB = eye(3);
    angular_velocity_B = zeros(3,numel(time));
    angular_acceleration_B = zeros(3,numel(time));
    mass = 0.05;
    inertia_B = diag([0.002 0.002 0.003]);
    gravity_I = [0;0;9.81];
    analysis_options = struct('force_scale',1, ...
        'length_scale',parameters.force_moment_length, ...
        'equality_tolerance',solver.equality_tolerance, ...
        'bound_tolerance',solver.bound_tolerance, ...
        'allocation_strategy','feasible','store_sample_results',false);

    study_log('case_start',1,1,sprintf('Trajectory with %d samples',numel(time)));
    timer = tic;
    wrench = required_wrench_from_trajectory(linear_acceleration_I,R_IB, ...
        angular_velocity_B,angular_acceleration_B,mass,inertia_B,gravity_I);
    result = check_trajectory_wrench_feasibility(model.A,model.actuator_bounds, ...
        wrench.w_required,analysis_options);
    [figures,figure_source_data] = plot_trajectory_feasibility(result,time);
    export_figure(figures.actuators,folder,'trajectory_actuators');
    write_figure_source_data(figure_source_data,folder,'trajectory_actuators');
    export_figure(figures.margin,folder,'trajectory_margin');
    write_figure_source_data(figure_source_data,folder,'trajectory_margin');
    export_figure(figures.error,folder,'trajectory_error');
    write_figure_source_data(figure_source_data,folder,'trajectory_error');
    close(figures.actuators);
    close(figures.margin);
    close(figures.error);
    save(fullfile(folder,'trajectory_feasibility.mat'), ...
        'model','time','wrench','result','analysis_options','-v7.3');
    detail = sprintf('%d samples | %d infeasible', ...
        numel(time),numel(result.infeasible_indices));
    logger = study_log('case_complete',logger,true,detail,toc(timer));
    study_log('stage_finish',logger);
    output = struct('model',model,'wrench',wrench,'result',result,'folder',folder);
catch ME
    study_log('error',ME);
    rethrow(ME);
end
end
