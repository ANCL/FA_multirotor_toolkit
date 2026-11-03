function [distance, alignment] = geometry_distance(a, b, model)
%GEOMETRY_DISTANCE Compare geometries modulo yaw and within-spin relabeling.
%
% Returns root-mean-square combined position/direction distance, aligned
% over all 3! * 3! admissible permutations and continuous global yaw.

if nargin < 3 || isempty(model), model = default_model(); end
signs = model.reaction_signs(:).';
orders = perms(1:6);
orders = orders(all(signs(orders) == signs, 2), :);
min_cost = inf;
for k = 1:size(orders, 1)
    order = orders(k, :);
    p = a.positions(:, order);
    u = a.directions(:, order);
    bp = b.positions;
    bu = b.directions;
    correlation = sum(conj(complex(p(1, :), p(2, :))) .* ...
        complex(bp(1, :), bp(2, :)) + ...
        conj(complex(u(1, :), u(2, :))) .* complex(bu(1, :), bu(2, :)));
    yaw = angle(correlation);
    R = [cos(yaw), -sin(yaw), 0; sin(yaw), cos(yaw), 0; 0, 0, 1];
    cost = sum((R * p - bp).^2, 'all') + sum((R * u - bu).^2, 'all');
    if cost < min_cost
        min_cost = cost;
        best_order = order;
        best_yaw = yaw;
    end
end
distance = sqrt(min_cost / 12);
alignment = struct('permutation', best_order, 'yaw', best_yaw);
end
