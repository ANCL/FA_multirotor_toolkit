function token = numeric_case_token(value,decimal_places)
%NUMERIC_CASE_TOKEN Stable filename token for a nonnegative physical value.
if nargin < 2, decimal_places = 6; end
validateattributes(value,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(decimal_places,{'numeric'}, ...
    {'scalar','integer','nonnegative','<=',12});
format = sprintf('%%.%df',decimal_places);
text = sprintf(format,value);
text = regexprep(text,'0+$','');
text = regexprep(text,'\.$','');
if isempty(text), text = '0'; end
token = strrep(text,'.','p');
end
