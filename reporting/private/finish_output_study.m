function output = finish_output_study(context,logger,completed)
%FINISH_OUTPUT_STUDY Write traceability metadata and finish the log.
manifest = create_output_manifest(context,completed);
save(fullfile(context.paths.root,'study_manifest.mat'),'manifest');
write_json_file(fullfile(context.paths.root,'study_manifest.json'),manifest);
study_log('stage_finish',logger);
output = context.paths;
output.completed_outputs = completed;
output.manifest = manifest;
fprintf('\n%s OUTPUTS COMPLETED\n%s\n',context.title,context.paths.root);
end
