function specifications = finalize_optimization_cases(specifications,solver,core_hash)
%FINALIZE_OPTIMIZATION_CASES Attach deterministic per-case provenance.
if nargin < 3 || isempty(core_hash), core_hash = numerical_core_hash(); end
for k = 1:numel(specifications)
    specifications(k).provenance = optimization_case_provenance( ...
        specifications(k),solver,core_hash);
end
end
