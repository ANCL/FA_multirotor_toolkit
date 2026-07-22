function provenance = optimization_case_provenance( ...
    specification,solver,core_hash)
%OPTIMIZATION_CASE_PROVENANCE Hash the actual inputs of one solver case.
if nargin < 3 || isempty(core_hash), core_hash = numerical_core_hash(); end
problem = specification.problem;
if isfield(problem,'case_name'), problem = rmfield(problem,'case_name'); end
provenance = struct();
provenance.schema_version = 2;
provenance.kind = 'optimization';
provenance.case_name = char(string(specification.case_name));
provenance.core_hash = core_hash;
provenance.problem_hash = settings_hash('optimization_problem_v2',problem);
provenance.parameters_hash = settings_hash('case_parameters_v2', ...
    resolved_case_parameters(specification.parameters));
provenance.solver_hash = settings_hash('optimization_solver_v2', ...
    resolved_optimization_solver(solver));
provenance.seed_hash = settings_hash('optimization_seed_v2',specification.seed);
context_for_hash = specification.context;
if isfield(context_for_hash,'hash_inputs')
    context_for_hash = context_for_hash.hash_inputs;
end
provenance.context_hash = settings_hash('optimization_context_v2',context_for_hash);
provenance.case_hash = settings_hash('optimization_case_v2', ...
    provenance.core_hash,provenance.problem_hash, ...
    provenance.parameters_hash,provenance.solver_hash,provenance.seed_hash, ...
    provenance.context_hash);
end
