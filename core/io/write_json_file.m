function write_json_file(path_out, data)
%WRITE_JSON_FILE Encode data as JSON and close the file reliably.

folder = fileparts(path_out);
if ~isempty(folder)
    ensure_folder(folder);
end
fid = fopen(path_out,'w');
if fid < 0
    error('fa:JsonWrite','Could not write JSON file: %s',path_out);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(data,'PrettyPrint',true));
end
