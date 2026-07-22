function T = parameterization_summary_table(comparison)
%PARAMETERIZATION_SUMMARY_TABLE Compare P1, P2, and P3 by objective.
objectives = ["r_F0";"sigma_min";"condition_number"; ...
    "hover_effort";"q_star"];
rotor_wise = zeros(numel(objectives),1);
spatial_c3 = zeros(numel(objectives),1);
planar_shared = zeros(numel(objectives),1);
for index = 1:numel(objectives)
    metric = objectives(index);
    rotor_wise(index) = parameterization_value(comparison,'rotorwise',metric,metric);
    spatial_c3(index) = parameterization_value(comparison,'spatial_c3', ...
        "spatial_c3_"+metric,metric);
    planar_shared(index) = parameterization_value(comparison,'planar_shared', ...
        "planar_shared_"+metric,metric);
end
objective = objectives;
T = table(objective,rotor_wise,spatial_c3,planar_shared);
end

function value = parameterization_value(T,parameterization,name,metric)
rows = string(T.parameterization)==string(parameterization) & ...
    string(T.name)==string(name);
value = unique_reporting_scalar(T.(char(metric))(rows), ...
    sprintf('%s/%s/%s',parameterization,name,metric));
end
