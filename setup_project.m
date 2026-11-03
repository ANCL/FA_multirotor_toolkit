function root = setup_project()
%SETUP_PROJECT Add toolkit numerical and analysis functions to the MATLAB path.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'core', 'geometry'));
addpath(fullfile(root, 'core', 'model'));
addpath(fullfile(root, 'core', 'metrics'));
addpath(fullfile(root, 'core', 'feasibility'));
addpath(fullfile(root, 'core', 'optimization'));
addpath(fullfile(root, 'core', 'plotting'));
addpath(fullfile(root, 'solvers'));
addpath(fullfile(root, 'analyses'));
addpath(fullfile(root, 'studies'));
end
