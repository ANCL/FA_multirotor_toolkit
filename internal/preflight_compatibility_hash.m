function digest = preflight_compatibility_hash(parameters,solver)
%PREFLIGHT_COMPATIBILITY_HASH Gate only shared numerical code and base inputs.
resolved = resolved_study_settings('preflight',parameters,solver);
% A change in source formatting must not force a new preflight.
% Scientific settings changes remain detectable.
digest = settings_hash('preflight_compatibility_v3',resolved);
end
