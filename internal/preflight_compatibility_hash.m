function digest = preflight_compatibility_hash(parameters,solver)
%PREFLIGHT_COMPATIBILITY_HASH Gate only shared numerical code and base inputs.
resolved = resolved_study_settings('preflight',parameters,solver);
digest = settings_hash('preflight_compatibility_v2', ...
    numerical_core_hash(),study_source_hash('preflight'),resolved);
end
