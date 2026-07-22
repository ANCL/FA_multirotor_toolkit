function [logger,cleanup] = begin_output_log(folders,stage_id,description,total)
%BEGIN_OUTPUT_LOG Open or reuse the study log for reporting.
opened_here = ~study_log('is_open');
if opened_here
    study_log('open',fullfile(folders.root,'run_log.txt'));
    cleanup = onCleanup(@() study_log('close'));
else
    cleanup = onCleanup(@() false);
end
logger = study_log('stage_start',stage_id,description,total,0);
end
