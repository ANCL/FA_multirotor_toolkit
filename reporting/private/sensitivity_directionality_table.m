function T = sensitivity_directionality_table(nominal_results,condition_results)
%SENSITIVITY_DIRECTIONALITY_TABLE Binary actuator-direction comparison.
case_id = ["unidirectional";"bidirectional"];
case_name = ["Unidirectional bounds";"Bidirectional bounds"];
actuator_bounds = ["0 <= mu_i <= 1";"-1 <= mu_i <= 1"];
nominal_geometry = zeros(2,1);
condition_specific_optimum = zeros(2,1);
for index = 1:2
    nominal_geometry(index) = nominal_sensitivity_value( ...
        nominal_results,'directionality',case_id(index),'q_star','q_star');
    condition_specific_optimum(index) = condition_specific_sensitivity_value( ...
        condition_results,case_id(index),'q_star','q_star');
end
improvement = condition_specific_optimum-nominal_geometry;
relative_improvement_pct = 100*improvement./abs(nominal_geometry);
T = table(case_name,actuator_bounds,nominal_geometry, ...
    condition_specific_optimum,improvement,relative_improvement_pct, ...
    'VariableNames',{'Case','ActuatorBounds','NominalGeometry', ...
    'ConditionSpecificOptimum','Improvement','RelativeImprovementPct'});
end
