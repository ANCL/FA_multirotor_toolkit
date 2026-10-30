function [summary, evaluations] = cross_evaluate_designs(designs, parameters, solver)
%CROSS_EVALUATE_DESIGNS Recompute every design through the common evaluator.

n=numel(designs); evaluation_cells=cell(n,1);
name=strings(n,1); parameterization=strings(n,1);
r_F0=nan(n,1); sigma_min=nan(n,1); condition_number=nan(n,1);
hover_effort=nan(n,1);
minimum_separation=nan(n,1); minimum_hover_margin=nan(n,1); valid=false(n,1);
for k=1:n
    metrics=evaluate_design(designs(k).geometry,parameters,solver);
    evaluation_cells{k}=metrics;
    name(k)=string(designs(k).name);
    parameterization(k)=string(designs(k).geometry.parameterization);
    r_F0(k)=metrics.r_F0; sigma_min(k)=metrics.sigma_min;
    condition_number(k)=metrics.condition_number; hover_effort(k)=metrics.hover_effort;
    minimum_separation(k)=metrics.geometry_check.minimum_separation;
    minimum_hover_margin(k)=metrics.hover.minimum_margin; valid(k)=metrics.valid;
end
evaluations=vertcat(evaluation_cells{:});
summary=table(name,parameterization,r_F0,sigma_min,condition_number, ...
    hover_effort,minimum_separation,minimum_hover_margin,valid);
end
