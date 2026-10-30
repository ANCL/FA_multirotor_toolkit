function root = setup_project()
%SETUP_PROJECT Add all toolkit source folders to the MATLAB path.
%
% The function returns the workspace root and adds only source folders.
% Generated result and test folders are never added to the normal path.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'inputs'));
addpath(fullfile(root,'examples'));
addpath(fullfile(root,'analyses'));
addpath(fullfile(root,'study'));
addpath(fullfile(root,'reporting'));
addpath(genpath(fullfile(root,'core')));
addpath(fullfile(root,'internal'));
end
