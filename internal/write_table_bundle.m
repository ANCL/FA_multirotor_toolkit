function paths = write_table_bundle(table_data,folder,base_name)
%WRITE_TABLE_BUNDLE Save MAT, sanitized CSV, and booktabs TeX.
ensure_folder(folder);
paths.mat = fullfile(folder,[base_name '.mat']);
paths.csv = fullfile(folder,[base_name '.csv']);
paths.tex = fullfile(folder,[base_name '.tex']);
save(paths.mat,'table_data');
csv_table = sanitize_table_text(table_data);
writetable(csv_table,paths.csv);
write_tex_table(table_data,paths.tex);
end

function write_tex_table(T,path_out)
fid = fopen(path_out,'w');
if fid < 0, error('fa:TableWrite','Could not open TeX table: %s',path_out); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
columns = width(T);
variable_names = string(T.Properties.VariableNames);
solution_column = find(variable_names=="Solution",1);

if isempty(solution_column)
    column_specification = repmat('l',1,columns);
else
    column_specification = repmat('c',1,columns);
    column_specification(1) = 'l';
    column_specification(solution_column) = 'l';
    fprintf(fid,'\\resizebox{\\textwidth}{!}{%%\n');
end

fprintf(fid,'\\begin{tabular}{@{}%s@{}}\n',column_specification);
fprintf(fid,'\\toprule\n');
fprintf(fid,'%s \\\\\n',strjoin(escape_tex(T.Properties.VariableNames),' & '));
fprintf(fid,'\\midrule\n');
for row = 1:height(T)
    values = cell(1,columns);
    for col = 1:columns
        value = T{row,col};
        if iscell(value), value = value{1}; end
        values{col} = tex_text_value(table_value_text(value));
    end
    fprintf(fid,'%s \\\\\n',strjoin(values,' & '));
end
fprintf(fid,'\\bottomrule\n\\end{tabular}\n');
if ~isempty(solution_column)
    fprintf(fid,'}\n');
end
end

function value = tex_text_value(text)
lines = regexp(text,'\r\n|\n|\r','split');
if numel(lines) == 1
    value = escape_tex(lines{1});
    return;
end
escaped_lines = cellfun(@escape_tex,lines,'UniformOutput',false);
value = ['\shortstack[l]{' strjoin(escaped_lines,'\\') '}'];
end

function out = escape_tex(in)
if iscell(in)
    out = cellfun(@escape_tex,in,'UniformOutput',false);
    return;
end
text = char(in);
out = '';
for k = 1:numel(text)
    switch text(k)
        case '\', replacement = '\textbackslash{}';
        case '&', replacement = '\&';
        case '%', replacement = '\%';
        case '$', replacement = '\$';
        case '#', replacement = '\#';
        case '_', replacement = '\_';
        case '{', replacement = '\{';
        case '}', replacement = '\}';
        case '~', replacement = '\textasciitilde{}';
        case '^', replacement = '\textasciicircum{}';
        otherwise, replacement = text(k);
    end
    out = [out replacement]; %#ok<AGROW>
end
end

function T = sanitize_table_text(T)
%SANITIZE_TABLE_TEXT Flatten multiline text before CSV export.
for column = 1:width(T)
    variable_name = T.Properties.VariableNames{column};
    values = T.(variable_name);
    if isstring(values)
        T.(variable_name) = sanitize_strings(values);
    elseif iscell(values)
        converted = strings(size(values));
        for row = 1:numel(values)
            converted(row) = string(table_value_text(values{row}));
        end
        T.(variable_name) = sanitize_strings(converted);
    elseif ischar(values)
        T.(variable_name) = char(sanitize_strings(string(values)));
    end
end
end


function text = table_value_text(value)
%TABLE_VALUE_TEXT Convert one table entry to stable single-line text.
if isstring(value)
    text = char(strjoin(value(:).'," | "));
elseif ischar(value)
    text = value;
elseif isnumeric(value)
    if isscalar(value)
        text = sprintf('%.10g',value);
    else
        text = mat2str(value,10);
    end
elseif islogical(value)
    if isscalar(value)
        text = char(string(value));
    else
        text = mat2str(value);
    end
elseif iscategorical(value) || isdatetime(value) || isduration(value)
    text = char(strjoin(string(value(:).')," | "));
else
    try
        text = jsonencode(value);
    catch
        text = strtrim(evalc('disp(value)'));
    end
end
text = char(sanitize_strings(string(text)));
end

function values = sanitize_strings(values)
values = regexprep(values,'[\r\n\t]+',' ');
values = regexprep(values,'\s+',' ');
values = strtrim(values);
end
