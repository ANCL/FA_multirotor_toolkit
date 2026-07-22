function [logger,completed] = run_output_figure_with_data( ...
    logger,completed,description,builder,folder,name)
%RUN_OUTPUT_FIGURE_WITH_DATA Export PDF/FIG and matching CSV/MAT source data.
study_log('case_start',logger.completed+1,logger.total,description);
timer = tic;
[fig,source_data] = builder();
cleanup = onCleanup(@() close_if_valid(fig)); %#ok<NASGU>
export_figure(fig,folder,name);
write_figure_source_data(source_data,folder,name);
close(fig);
clear cleanup;
logger = study_log('case_complete',logger,true, ...
    'PDF, FIG, CSV, and MAT written',toc(timer));
completed(end+1,1) = string(name);
end

function close_if_valid(fig)
if ~isempty(fig) && isgraphics(fig), close(fig); end
end
