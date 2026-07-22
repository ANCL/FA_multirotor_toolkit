function plan = provenance_plan(specifications,varargin)
%PROVENANCE_PLAN Compact deterministic study plan for provenance hashing.
plan = struct();
plan.case_names = string({specifications.case_name});
if isempty(specifications)
    plan.case_hashes = strings(0,1);
else
    plan.case_hashes = string(arrayfun( ...
        @(x) x.provenance.case_hash,specifications,'UniformOutput',false));
end
if ~isempty(varargin), plan.details = varargin; end
end
