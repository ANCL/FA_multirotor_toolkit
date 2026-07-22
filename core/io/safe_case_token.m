function token = safe_case_token(name)
%SAFE_CASE_TOKEN Convert a readable case name to a safe folder/file token.
%
% The returned token contains only letters, digits, underscores, and
% hyphens. Repeated separators are collapsed, and leading or trailing
% separators are removed.

if ~(ischar(name) && isrow(name)) && ...
        ~(isstring(name) && isscalar(name))
    error('fa:InvalidCaseName', ...
        'A case name must be one character row or string scalar.');
end
name = strtrim(char(string(name)));
if isempty(name)
    error('fa:EmptyCaseName','A nonempty case name is required.');
end

token = regexprep(name,'[^A-Za-z0-9_-]+','_');
token = regexprep(token,'_+','_');
token = regexprep(token,'^[_-]+|[_-]+$','');
if isempty(token)
    error('fa:UnsafeCaseName', ...
        'The case name must contain at least one letter or digit.');
end
end
