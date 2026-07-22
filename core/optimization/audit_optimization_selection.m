function audit = audit_optimization_selection(selected,candidates)
%AUDIT_OPTIMIZATION_SELECTION Enforce the global/local selection rules.
% A feasible candidate must always outrank every infeasible candidate.
% Among feasible candidates, the lowest minimization objective is selected.
% If all candidates are infeasible, the smallest constraint violation is
% selected, with objective value used only to break a violation tie.

if isempty(candidates)
    error('fa:EmptyCandidateSet','Optimization produced no candidates.');
end
required = {'valid','maximum_constraint_violation','objective_value','solver'};
for field_index = 1:numel(required)
    field_name = required{field_index};
    if ~isfield(selected,field_name) || ~all(isfield(candidates,field_name))
        error('fa:InvalidCandidateSet', ...
            'Optimization candidates require field %s.',field_name);
    end
end

objective_tolerance = 1e-10;
violation_tolerance = 1e-12;
valid_mask = [candidates.valid];

if any(valid_mask)
    valid_candidates = candidates(valid_mask);
    best_objective = min(finite_values([valid_candidates.objective_value]));
    if ~selected.valid
        error('fa:CandidateSelectionFailure', ...
            'An infeasible candidate was selected although a feasible candidate exists.');
    end
    if finite_or_inf(selected.objective_value) > ...
            best_objective + scaled_tolerance(best_objective,objective_tolerance)
        error('fa:CandidateSelectionFailure', ...
            'The selected feasible candidate is not the best feasible objective.');
    end
    rule = 'best_feasible_objective';
    best_violation = 0;
else
    violations = arrayfun(@(x) finite_or_inf(x.maximum_constraint_violation),candidates);
    best_violation = min(violations);
    if selected.valid
        error('fa:CandidateSelectionFailure', ...
            'A candidate was marked feasible although every candidate is infeasible.');
    end
    if finite_or_inf(selected.maximum_constraint_violation) > ...
            best_violation + scaled_tolerance(best_violation,violation_tolerance)
        error('fa:CandidateSelectionFailure', ...
            'The selected infeasible candidate does not have the smallest violation.');
    end
    tied = violations <= best_violation + scaled_tolerance(best_violation,violation_tolerance);
    tied_objectives = finite_values([candidates(tied).objective_value]);
    best_objective = min(tied_objectives);
    if finite_or_inf(selected.objective_value) > ...
            best_objective + scaled_tolerance(best_objective,objective_tolerance)
        error('fa:CandidateSelectionFailure', ...
            'The selected infeasible candidate does not have the best objective among equal-violation candidates.');
    end
    rule = 'smallest_violation_then_objective';
end

selected_present = any(strcmp({candidates.solver},selected.solver));
if ~selected_present
    error('fa:CandidateSelectionFailure', ...
        'The selected candidate is not present in the evaluated candidate set.');
end

audit = struct( ...
    'passed',true, ...
    'rule',rule, ...
    'candidate_count',numel(candidates), ...
    'valid_candidate_count',sum(valid_mask), ...
    'selected_solver',selected.solver, ...
    'selected_valid',selected.valid, ...
    'selected_objective_value',selected.objective_value, ...
    'selected_constraint_violation',selected.maximum_constraint_violation, ...
    'best_eligible_objective_value',best_objective, ...
    'best_constraint_violation',best_violation);
end

function values = finite_values(values)
values(~isfinite(values)) = Inf;
end

function value = finite_or_inf(value)
if ~(isscalar(value) && isfinite(value)), value = Inf; end
end

function tolerance = scaled_tolerance(reference,base)
tolerance = base*max(1,abs(reference));
end
