function manifest = create_output_manifest(context,completed)
%CREATE_OUTPUT_MANIFEST Trace one study-organized reporting export.
manifest.study_id = context.parameters.study_id;
manifest.output_study = context.key;
manifest.output_title = context.title;
manifest.created_at = char(datetime('now', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
manifest.matlab_version = version;
manifest.matlab_release = version('-release');
manifest.numerical_core_hash = 'informational-only';
manifest.provenance_schema = 2;
manifest.completed_outputs = completed;
manifest.output_folder = context.paths.root;
manifest.source_files = reporting_source_manifest(context.root);
end
