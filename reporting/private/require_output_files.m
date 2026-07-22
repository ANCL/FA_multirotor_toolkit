function require_output_files(paths,study_name)
%REQUIRE_OUTPUT_FILES Require only the inputs used by one reporting study.
paths = paths(:);
missing = paths(~cellfun(@isfile,paths));
if isempty(missing)
    return
end
error('fa:IncompleteStudyResults', ...
    '%s reporting requires:\n- %s',study_name,strjoin(missing,'\n- '));
end
