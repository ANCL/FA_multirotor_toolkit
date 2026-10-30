function folders = output_folders(root)
%OUTPUT_FOLDERS Human-readable result layout for the active study run.
base = fullfile(root,'results','current');
folders.root = base;
folders.designs = fullfile(base,'01_design_comparison');
folders.pareto = fullfile(base,'03_authority_effort');
folders.sensitivity = fullfile(base,'04_sensitivity');
folders.robustness = fullfile(base,'05_robustness');
folders.publication = fullfile(root,'results','publication');
folders.checkpoints = fullfile(base,'checkpoints');
end
