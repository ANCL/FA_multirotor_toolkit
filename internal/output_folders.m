function folders = output_folders(root)
%OUTPUT_FOLDERS One explicit directory per numerical study.
base = fullfile(root,'results','current');
folders.root = base;
folders.designs = fullfile(base,'01_unrestricted_optimization');
folders.parameterizations = fullfile(base,'02_parameterization_comparison');
folders.pareto = fullfile(base,'03_authority_effort');
folders.pareto_p1 = fullfile(base,'03_authority_effort_p1');
folders.sensitivity = fullfile(base,'04_sensitivity');
folders.robustness = fullfile(base,'05_robustness');
folders.p2_seeded_p1 = fullfile(base,'06_p2_seeded_p1');
folders.publication = fullfile(root,'results','publication');
folders.checkpoints = fullfile(base,'checkpoints');
end
