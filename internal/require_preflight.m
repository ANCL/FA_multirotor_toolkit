function require_preflight(root,parameters,solver)
%REQUIRE_PREFLIGHT Require the current shared numerical preflight gate.
marker = fullfile(root,'results','preflight','preflight_passed.mat');
if ~isfile(marker)
    error('fa:PreflightRequired','Run run_preflight before numerical studies.');
end
data = load(marker,'preflight_hash');
expected = preflight_compatibility_hash(parameters,solver);
if ~isfield(data,'preflight_hash') || ~strcmp(data.preflight_hash,expected)
    error('fa:PreflightStale', ...
        ['Preflight is stale for the shared numerical core or base solver ' ...
         'inputs. Run run_preflight again. Completed study results are not ' ...
         'moved or invalidated by this gate.']);
end
end
