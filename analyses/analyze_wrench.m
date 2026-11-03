function result = analyze_wrench(geometry, wrench, model, numerics)
%ANALYZE_WRENCH Analyze bounded achievability of one body-frame wrench.
%
% Wrench order is [Fx;Fy;Fz;Mx;My;Mz]. Returns allocation or nearest input.
if nargin < 3 || isempty(model), model = default_model(); end
if nargin < 4 || isempty(numerics), numerics = default_numerics(); end
A = allocation_matrix(geometry, model);
result = check_wrench_feasibility(A, model, wrench, numerics);
end
