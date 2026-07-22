function context = create_output_context(key,title,folder_name,stage_id,total)
%CREATE_OUTPUT_CONTEXT Prepare one independent reporting study.
root = setup_project();
[parameters,solver] = study_settings();
check_study_settings(parameters,solver);
require_numerical_preflight(root,parameters,solver);
folders = output_folders(root);
if ~isfolder(folders.root)
    error('fa:MissingNumericalResults', ...
        'No completed numerical result folder is available for reporting.');
end
paths = study_output_paths(root,folder_name);
[style,graphics_cleanup] = publication_style('activate');
[logger,log_cleanup] = begin_output_log(folders,stage_id,title,total);
context = struct('key',key,'title',title,'root',root, ...
    'parameters',parameters,'solver',solver,'folders',folders, ...
    'files',reporting_result_files(folders),'paths',paths,'style',style, ...
    'logger',logger,'graphics_cleanup',graphics_cleanup, ...
    'log_cleanup',log_cleanup);
end
