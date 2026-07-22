function specifications = finalize_robustness_cases( ...
    specifications,designs,parameters,solver,core_hash)
%FINALIZE_ROBUSTNESS_CASES Attach deterministic batch provenance.
if nargin < 5 || isempty(core_hash), core_hash = numerical_core_hash(); end
for k = 1:numel(specifications)
    design = designs(specifications(k).design_index);
    specifications(k).provenance = robustness_case_provenance( ...
        specifications(k),design,parameters,solver,core_hash);
end
end
