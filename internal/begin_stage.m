function [root,p,s,runtime,cleanup] = begin_stage(study_name)
%BEGIN_STAGE Open one study without global numerical invalidation.
if nargin < 1 || isempty(study_name)
    error('fa:MissingStudyName','begin_stage requires a numerical study name.');
end
root = setup_project();
[p,s] = study_settings();
check_study_settings(p,s);
runtime = resolve_runtime(runtime_settings());
require_preflight(root,p,s);
run = prepare_study_run(root,runtime,study_name);
if study_log('is_open')
    cleanup = onCleanup(@() false);
else
    study_log('open',run.log_file);
    cleanup = onCleanup(@() study_log('close'));
end
end

function run = prepare_study_run(root,runtime,study_name)
%PREPARE_STUDY_RUN Update workflow state without moving numerical results.
current_folder = ensure_folder(fullfile(root,'results','current'));
state_path = fullfile(current_folder,'run_state.mat');
if isfile(state_path)
    data = load(state_path,'state');
    if isfield(data,'state'), state = data.state; else, state = struct(); end
else
    state = struct('schema_version',2,'started_at',datetime('now'));
end
state.schema_version = 2;
state.status = 'running';
state.active_study = char(string(study_name));
state.updated_at = datetime('now');
state.workflow_hash = workflow_source_hash();
state.runtime_mode = char(string(runtime.mode));
state.matlab_release = version('-release');
save(state_path,'state','-v7');
run = struct('folder',current_folder, ...
    'log_file',fullfile(current_folder,'run_log.txt'),'state_file',state_path);
end
