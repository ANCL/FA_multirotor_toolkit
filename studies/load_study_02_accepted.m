function accepted = load_study_02_accepted(base, objective)
%LOAD_STUDY_02_ACCEPTED Read consecutively numbered accepted configurations.
% Results are stored once: results/study_02/<objective>/1.mat, 2.mat, ...
folder = fullfile(base,objective);
accepted = struct([]);
if ~isfolder(folder), return; end
files = dir(fullfile(folder,'*.mat'));
if isempty(files), return; end
numbers = zeros(numel(files),1);
for k = 1:numel(files)
    token = regexp(files(k).name,'^([1-9]\d*)\.mat$','tokens','once');
    if isempty(token)
        error('fa:Study02NumberedFiles','Unexpected MAT file in %s: %s',folder,files(k).name);
    end
    numbers(k) = str2double(token{1});
end
if any(~isfinite(numbers)) || numel(unique(numbers))~=numel(numbers) || ...
        ~isequal(sort(numbers(:)),(1:numel(files)).')
    error('fa:Study02NumberedFiles','Expected 1.mat through %d.mat in %s.',numel(files),folder);
end
for k = 1:numel(files)
    data = load(fullfile(folder,sprintf('%d.mat',k)),'entry');
    if ~isfield(data,'entry') || ~isscalar(data.entry) || ...
            ~isfield(data.entry,'objective') || ~strcmp(data.entry.objective,objective)
        error('fa:Study02NumberedFiles','Invalid accepted entry %d for %s.',k,objective);
    end
    if k==1
        accepted = data.entry;
    else
        accepted(k,1) = data.entry;
    end
end
accepted = accepted(:);
end
