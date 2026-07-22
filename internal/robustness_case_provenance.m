function provenance = robustness_case_provenance( ...
    specification,design,parameters,solver,core_hash)
%ROBUSTNESS_CASE_PROVENANCE Hash one deterministic perturbation batch.
if nargin < 5 || isempty(core_hash), core_hash = numerical_core_hash(); end
case_spec = specification;
case_spec = remove_if_present(case_spec,{'index','description','provenance'});
provenance = struct();
provenance.schema_version = 2;
provenance.kind = 'robustness';
provenance.case_name = char(string(specification.case_name));
provenance.core_hash = core_hash;
root = fileparts(fileparts(mfilename('fullpath')));
provenance.source_hash = source_files_hash( ...
    {fullfile(root,'internal','execute_robustness_case.m')},root);
provenance.specification_hash = settings_hash('robustness_specification_v2',case_spec);
provenance.design_hash = settings_hash('robustness_design_v2', ...
    design.name,design.geometry);
provenance.parameters_hash = settings_hash('case_parameters_v2', ...
    resolved_case_parameters(parameters));
provenance.solver_hash = settings_hash('evaluation_solver_v2', ...
    resolved_evaluation_solver(solver));
provenance.seed_hash = settings_hash('robustness_seed_basis_v2',solver.master_seed);
provenance.case_hash = settings_hash('robustness_case_v2', ...
    provenance.core_hash,provenance.source_hash,provenance.specification_hash, ...
    provenance.design_hash,provenance.parameters_hash,provenance.solver_hash, ...
    provenance.seed_hash);
end

function value = remove_if_present(value,names)
for k = 1:numel(names)
    if isfield(value,names{k}), value = rmfield(value,names{k}); end
end
end
