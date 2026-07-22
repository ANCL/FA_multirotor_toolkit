function [logger,completed] = run_output_table(logger,completed, ...
    description,T,folder,name)
%RUN_OUTPUT_TABLE Export and log one table bundle.
study_log('case_start',logger.completed+1,logger.total,description);
timer = tic;
write_table_bundle(publication_table(T),folder,name);
logger = study_log('case_complete',logger,true,'output written',toc(timer));
completed(end+1,1) = string(name);
end
