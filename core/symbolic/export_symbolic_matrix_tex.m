function export_symbolic_matrix_tex(symbolic_matrix, file_path, command_name)
%EXPORT_SYMBOLIC_MATRIX_TEX Write a symbolic matrix as a LaTeX command.

if nargin < 3 || strlength(string(command_name)) == 0
    command_name = 'AllocationMatrix';
end
folder = fileparts(file_path);
if ~isempty(folder)
    ensure_folder(folder);
end
content = latex(symbolic_matrix);
file_id = fopen(file_path,'w');
if file_id < 0
    error('fa:FileOpenFailed','Could not open %s for writing.',file_path);
end
cleanup = onCleanup(@() fclose(file_id)); %#ok<NASGU>
fprintf(file_id,'\\newcommand{\\%s}{%s}\n',char(command_name),content);
end
