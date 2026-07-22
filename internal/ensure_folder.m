function path_out = ensure_folder(path_in)
%ENSURE_FOLDER Create a result directory when needed.
path_out = char(path_in);
if ~isfolder(path_out), mkdir(path_out); end
end
