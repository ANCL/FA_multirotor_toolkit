function require_completed_outputs(completed,expected,study_name)
%REQUIRE_COMPLETED_OUTPUTS Check the declared study output list.
if ~isequal(sort(string(completed)),sort(string(expected)))
    error('fa:StudyOutputList', ...
        '%s outputs do not match the planned list.',study_name);
end
end
