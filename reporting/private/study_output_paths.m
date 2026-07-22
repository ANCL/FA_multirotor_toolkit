function paths = study_output_paths(root,folder_name)
%STUDY_OUTPUT_PATHS Define one study publication layout.
publication = fullfile(root,'results','publication');
study_folder = fullfile(publication,folder_name);
paths.publication = publication;
paths.root = study_folder;
paths.figures = fullfile(study_folder,'figures');
paths.tables = fullfile(study_folder,'tables');
paths.diagnostics = fullfile(study_folder,'diagnostics');
end
