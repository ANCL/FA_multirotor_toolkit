function best = select_best_solution(results, objective)
%SELECT_BEST_SOLUTION Select the best valid result for one objective.
if isempty(results), error('fa:NoResults','No optimization results were supplied.'); end
matches = strcmp({results.objective_name},objective) & [results.valid];
if ~any(matches)
    error('fa:NoValidResult','No valid result was found for objective %s.',objective);
end
candidates = results(matches);
[~,index] = min([candidates.objective_value]);
best = candidates(index);
end
