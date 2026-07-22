function folder = validate_analysis_output_folder(root,folder)
%VALIDATE_ANALYSIS_OUTPUT_FOLDER Resolve and protect a custom-output folder.
%
% Custom analyses may write anywhere outside the toolkit. Inside the toolkit,
% they may write only below results/analyses and never directly to that shared
% parent. This prevents an editable example or user override from modifying
% source files, completed numerical results, or publication outputs.

root = canonical_path(root);
folder = canonical_path(folder);
analysis_root = canonical_path(fullfile(root,'results','analyses'));

if paths_equal(folder,root)
    error('fa:UnsafeAnalysisOutputFolder', ...
        'A custom analysis cannot use the toolkit root as its output folder.');
end
if is_descendant_or_equal(folder,root)
    if paths_equal(folder,analysis_root) || ...
            ~is_descendant_or_equal(folder,analysis_root)
        error('fa:UnsafeAnalysisOutputFolder', ...
            ['Custom outputs inside the toolkit must use a named folder ' ...
             'below results/analyses. The requested folder was: %s'],folder);
    end
end
end

function path_out = canonical_path(path_in)
if ~(ischar(path_in) || (isstring(path_in) && isscalar(path_in)))
    error('fa:InvalidAnalysisOutputFolder', ...
        'The output folder must be one character vector or string scalar.');
end
path_in = char(string(path_in));
if isempty(strtrim(path_in))
    error('fa:InvalidAnalysisOutputFolder', ...
        'The output folder cannot be empty.');
end
path_out = char(java.io.File(path_in).getCanonicalPath());
end

function tf = is_descendant_or_equal(candidate,parent)
candidate = comparison_path(candidate);
parent = comparison_path(parent);
tf = strcmp(candidate,parent) || ...
    startsWith([candidate filesep],[parent filesep]);
end

function tf = paths_equal(left,right)
tf = strcmp(comparison_path(left),comparison_path(right));
end

function value = comparison_path(value)
value = strrep(char(value),'/',filesep);
value = strrep(value,'\',filesep);
while numel(value) > 1 && endsWith(value,filesep)
    value(end) = [];
end
if ispc
    value = lower(value);
end
end
