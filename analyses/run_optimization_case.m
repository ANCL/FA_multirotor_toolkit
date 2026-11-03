function result = run_optimization_case(problem, file, mode, model, numerics, settings, seed)
%RUN_OPTIMIZATION_CASE Run/save or resume one independent optimization case.
%
%   result = run_optimization_case(problem, file, 'fresh', ..., seed)
%   result = run_optimization_case(problem, file, 'resume', ..., seed)
%
% A fresh run overwrites the named MAT file. Resume loads that file if it
% exists; it does not compare hashes or enforce settings compatibility.
% Every MAT contains the full result, including model/settings/seed.
if nargin < 2 || isempty(file), file = ''; end
if nargin < 3 || isempty(mode), mode = 'fresh'; end
if nargin < 4 || isempty(model), model = default_model(); end
if nargin < 5 || isempty(numerics), numerics = default_numerics(); end
if nargin < 6 || isempty(settings)
    settings = default_optimization_settings(problem.parameterization);
end
if nargin < 7 || isempty(seed), seed = 1; end
mode = char(string(mode));
if ~ismember(mode, {'fresh', 'resume'})
    error('fa:RunMode', 'Mode must be fresh or resume.');
end
if strcmp(mode, 'resume') && ~isempty(file) && isfile(file)
    loaded = load(file, 'result');
    result = loaded.result;
    return;
end
if ~isfield(settings,'solver') || isempty(settings.solver)
    settings.solver = 'ga_patternsearch'; % Legacy explicitly supplied settings.
end
[optimizer,~,~] = select_optimizer(settings.solver);
result = optimizer(problem, model, numerics, settings, seed);
if ~isempty(file)
    folder = fileparts(file);
    if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
    save(file, 'result');
end
end
