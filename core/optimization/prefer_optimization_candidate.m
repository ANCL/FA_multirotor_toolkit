function preferred = prefer_optimization_candidate(candidate, incumbent)
%PREFER_OPTIMIZATION_CANDIDATE Lexicographic feasibility-aware comparison.
% Feasible candidates always outrank infeasible candidates. Among feasible
% candidates, lower minimization objective wins. If both are infeasible, the
% smaller maximum constraint violation wins, followed by objective value.
required = {'valid','maximum_constraint_violation','objective_value'};
for k = 1:numel(required)
    if ~isfield(candidate,required{k}) || ~isfield(incumbent,required{k})
        error('fa:InvalidCandidate','Optimization candidates require %s.',required{k});
    end
end
if candidate.valid ~= incumbent.valid
    preferred = candidate.valid;
    return;
end
if candidate.valid
    preferred = candidate.objective_value < incumbent.objective_value;
    return;
end
candidate_violation = finite_or_inf(candidate.maximum_constraint_violation);
incumbent_violation = finite_or_inf(incumbent.maximum_constraint_violation);
if candidate_violation ~= incumbent_violation
    preferred = candidate_violation < incumbent_violation;
else
    preferred = finite_or_inf(candidate.objective_value) < ...
        finite_or_inf(incumbent.objective_value);
end
end

function value = finite_or_inf(value)
if ~(isscalar(value) && isfinite(value)), value = Inf; end
end
