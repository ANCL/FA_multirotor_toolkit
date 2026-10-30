function summary = summarize_robustness(trials)
%SUMMARIZE_ROBUSTNESS Report every trial and Wilson feasibility intervals.
metric_names={'r_F0','sigma_min','condition_number','hover_effort'};
flag_names={'evaluation_valid','geometric_feasible','numerically_fully_actuated','hover_feasible'};
summary=struct('total_trials',numel(trials),'rates',struct(),'metrics',struct());
for k=1:numel(flag_names)
    values=[trials.(flag_names{k})].';
    [lower,upper]=wilson_interval(sum(values),numel(values),0.95);
    summary.rates.(flag_names{k})=struct('proportion',mean(values), ...
        'lower_95',lower,'upper_95',upper,'successes',sum(values));
end
for k=1:numel(metric_names)
    values=[trials.(metric_names{k})].'; values=sort(values(isfinite(values)));
    summary.metrics.(metric_names{k})=struct('median',percentile(values,50), ...
        'p05',percentile(values,5),'p95',percentile(values,95), ...
        'minimum',min_or_nan(values),'maximum',max_or_nan(values), ...
        'finite_count',numel(values));
end
end

function [lower,upper]=wilson_interval(successes,n,confidence)
if n==0, lower=NaN; upper=NaN; return; end
z=-sqrt(2)*erfcinv(2*(0.5+confidence/2)); p=successes/n;
den=1+z^2/n; center=(p+z^2/(2*n))/den;
half=z*sqrt(p*(1-p)/n+z^2/(4*n^2))/den;
lower=max(0,center-half); upper=min(1,center+half);
end
function value=percentile(x,p)
if isempty(x), value=NaN; return; end
position=1+(numel(x)-1)*p/100; lo=floor(position); hi=ceil(position);
value=x(lo)+(position-lo)*(x(hi)-x(lo));
end
function v=min_or_nan(x), if isempty(x),v=NaN;else,v=min(x);end,end
function v=max_or_nan(x), if isempty(x),v=NaN;else,v=max(x);end,end
