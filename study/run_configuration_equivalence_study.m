function output = run_configuration_equivalence_study()
%RUN_CONFIGURATION_EQUIVALENCE_STUDY Study 07: repeated P2 configurations.
% Read the five saved P2 runs for each of four objectives. No optimization.
% The saved geometry, six design variables, and four metrics are retained.
% Distances to the best-found run remove common yaw and sign-preserving
% rotor relabeling; they are numerical quantities, not classifications.

root = setup_project();
[parameters,solver] = study_settings();
check_study_settings(parameters,solver);
folders = output_folders(root);
source = fullfile(folders.checkpoints,'02_parameterization_comparison');

% The upstream studies must be complete. The source files are read only.
p1 = assert_completed_stage(fullfile(folders.designs,'stage_manifest.mat'), ...
    'unrestricted_optimization',parameters,solver);
assert_completed_stage(fullfile(folders.parameterizations, ...
    'stage_manifest.mat'),'parameterization_comparison', ...
    parameters,solver,p1);

objectives = parameters.objectives;
number_of_runs = solver.independent_runs;
records = repmat(empty_record(),number_of_runs*numel(objectives),1);
k = 0;
for j = 1:numel(objectives)
    for run = 1:number_of_runs
        k = k+1;
        name = sprintf('spatial_c3_%s_run_%d',objectives{j},run);
        records(k) = read_saved_p2_record(source,name,objectives{j}, ...
            run,parameters);
    end
end

% Compare each saved configuration with the best-found run for its
% objective. Keep all five runs, including those far from the best value.
signs = parameters.reaction_signs(:).';
orders = perms(1:numel(signs));
orders = orders(all(signs(orders)==signs,2),:);
row_blocks = cell(numel(objectives),1);
distance_blocks = cell(numel(objectives),1);
for j = 1:numel(objectives)
    idx = (j-1)*number_of_runs+(1:number_of_runs);
    subset = records(idx);
    primary = [subset.primary].';
    if ismember(objectives{j},{'r_F0','sigma_min'})
        [best,best_index] = max(primary);
        gap = 100*(best-primary)/max(abs(best),eps);
    else
        [best,best_index] = min(primary);
        gap = 100*(primary-best)/max(abs(best),eps);
    end
    gap = max(0,gap);
    objective = repmat(string(objectives{j}),number_of_runs,1);
    run_number = [subset.run].';
    primary_value = primary;
    gap_pct = gap;
    values = reshape([subset.metrics],4,[]).';
    x_deg = rad2deg(reshape([subset.x],6,[]).');
    run_table = table(objective,run_number,primary_value,gap_pct, ...
        values(:,1),values(:,2),values(:,3),values(:,4), ...
        x_deg(:,1),x_deg(:,2),x_deg(:,3), ...
        x_deg(:,4),x_deg(:,5),x_deg(:,6), ...
        'VariableNames',{'Objective','Run','Primary','GapPct', ...
        'r_F0','sigma_min','condition_number','hover_effort', ...
        'delta_deg','eta_s_deg','alpha_plus_deg','beta_plus_deg', ...
        'alpha_minus_deg','beta_minus_deg'});
    row_blocks{j} = run_table;

    position_rms = zeros(number_of_runs,1);
    thrust_rms_deg = zeros(number_of_runs,1);
    common_yaw_deg = zeros(number_of_runs,1);
    matched_rotors = strings(number_of_runs,1);
    for i = 1:number_of_runs
        compared = align_multirotor_configurations( ...
            subset(i).geometry,subset(best_index).geometry,orders);
        position_rms(i) = compared.position_rms;
        thrust_rms_deg(i) = compared.angle_rms_deg;
        common_yaw_deg(i) = rad2deg(compared.yaw);
        matched_rotors(i) = strtrim(sprintf('%d ',compared.order));
    end
    best_run = repmat(subset(best_index).run,number_of_runs,1);
    distance_blocks{j} = table(objective,run_number,best_run, ...
        position_rms,thrust_rms_deg,common_yaw_deg,matched_rotors, ...
        'VariableNames',{'Objective','Run','ReferenceRun', ...
        'PositionRMS','ThrustAngleRMSDeg','CommonYawDeg', ...
        'MatchedRotorOrder'});
end
runs = vertcat(row_blocks{:});
alignment_to_best = vertcat(distance_blocks{:});

% Only Study 07's derived outputs are replaced. Source results/checkpoints
% and the other six studies are not modified.
out = fullfile(folders.root,'07_configuration_equivalence');
if isfolder(out)
    [ok,message] = rmdir(out,'s');
    if ~ok, error('fa:Study07Reset','%s',message); end
end
mkdir(out);
save(fullfile(out,'configuration_equivalence.mat'), ...
    'runs','alignment_to_best','records','-v7.3');
writetable(runs,fullfile(out,'p2_runs.csv'));
writetable(alignment_to_best,fullfile(out,'p2_alignment_to_best.csv'));

output = struct('folder',out,'runs',runs, ...
    'alignment_to_best',alignment_to_best,'records',records);
fprintf('STUDY 07: %d P2 runs, four objectives.\n%s\n', ...
    numel(records),out);
disp(runs(:,{'Objective','Run','Primary','GapPct', ...
    'delta_deg','eta_s_deg','alpha_plus_deg','beta_plus_deg', ...
    'alpha_minus_deg','beta_minus_deg'}));
end

function a = read_saved_p2_record(folder,name,objective,run,parameters)
compact = fullfile(folder,'records',[name '.mat']);
complete = fullfile(folder,'cases',[name '.mat']);
if isfile(compact)
    payload = load(compact,'case_record','saved_case_name', ...
        'case_provenance');
    if ~isfield(payload,'case_record')
        error('fa:Study07Record','Missing case_record in %s.',compact);
    end
    item = payload.case_record;
    path_in = compact;
elseif isfile(complete)
    payload = load(complete,'case_result','saved_case_name', ...
        'case_provenance');
    if ~isfield(payload,'case_result')
        error('fa:Study07Record','Missing case_result in %s.',complete);
    end
    item = payload.case_result;
    path_in = complete;
else
    error('fa:Study07MissingRecord','Missing optimization record %s.',name);
end
if ~isfield(payload,'saved_case_name') || ...
        ~strcmp(char(string(payload.saved_case_name)),name) || ...
        ~isfield(payload,'case_provenance') || ...
        ~isfield(item,'case_provenance') || ...
        ~isfield(item.case_provenance,'case_hash') || ...
        ~isequal(payload.case_provenance,item.case_provenance)
    error('fa:Study07Provenance','Saved record provenance mismatch: %s.',path_in);
end
if ~strcmp(char(string(item.case_name)),name) || ...
        ~strcmp(char(string(item.objective_name)),objective) || ...
        ~strcmp(char(string(item.parameterization)),'spatial_c3') || ...
        ~logical(item.valid) || ~logical(item.metrics.valid)
    error('fa:Study07Identity','Unexpected or invalid record: %s.',path_in);
end
x = item.design_variables(:);
geom = item.geometry;
if ~isequal(size(x),[6 1]) || any(~isfinite(x)) || ...
        ~isequal(size(geom.p),[3 6]) || ...
        ~isequal(size(geom.u),[3 6]) || ...
        any(~isfinite([geom.p(:);geom.u(:)]))
    error('fa:Study07Geometry','Invalid saved geometry: %s.',path_in);
end
% Check that the six saved P2 variables reproduce the saved physical
% geometry. This does not call evaluate_design or any optimizer.
reference = spatial_c3_geometry(x,parameters);
if max(abs(reference.p(:)-geom.p(:)))>1e-9 || ...
        max(abs(reference.u(:)-geom.u(:)))>1e-9
    error('fa:Study07GeometryMismatch', ...
        'Saved variables do not reproduce geometry: %s.',path_in);
end
m = item.metrics;
values = [m.r_F0,m.sigma_min,m.condition_number,m.hover_effort];
if any(~isfinite(values))
    error('fa:Study07Metrics','Nonfinite saved metrics in %s.',path_in);
end
a = struct('objective',objective,'run',run,'case_name',name, ...
    'seed',double(item.seed),'primary',double(m.(objective)), ...
    'x',x,'geometry',geom,'metrics',double(values), ...
    'case_hash',char(string(item.case_provenance.case_hash)));
end

function a = empty_record()
a = struct('objective','','run',0,'case_name','', ...
    'seed',NaN,'primary',NaN,'x',zeros(6,1), ...
    'geometry',struct(),'metrics',zeros(1,4),'case_hash','');
end
