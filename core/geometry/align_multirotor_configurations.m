function aligned = align_multirotor_configurations(a,b,orders)
%ALIGN_MULTIROTOR_CONFIGURATIONS Align physical rotor positions and thrust axes.
% The caller must supply ONLY rotor permutations that preserve reaction signs.
% A single common rotation about body z is optimized analytically for each
% permutation. The winner minimizes the sum of squared position and unit
% thrust-direction discrepancies. This is not an installation-angle match.
% All outputs are in the original normalized physical units.
best_cost = inf;
for i = 1:size(orders,1)
    order = orders(i,:);
    p = a.p(:,order); u = a.u(:,order);
    z = sum(conj(complex(p(1,:),p(2,:))).* ...
        complex(b.p(1,:),b.p(2,:)) + ...
        conj(complex(u(1,:),u(2,:))).* ...
        complex(b.u(1,:),b.u(2,:)));
    yaw = angle(z);
    R = [cos(yaw),-sin(yaw),0;sin(yaw),cos(yaw),0;0,0,1];
    pp = R*p; uu = R*u;
    cost = sum((pp-b.p).^2,'all')+sum((uu-b.u).^2,'all');
    if cost < best_cost
        best_cost = cost;
        aligned.order = order;
        aligned.yaw = yaw;
        aligned.p_aligned = pp;
        aligned.u_aligned = uu;
        aligned.position_error = vecnorm(pp-b.p,2,1);
        % atan2 avoids precision loss for nearly coincident axes.
        angles = atan2(vecnorm(cross(uu,b.u,1),2,1), ...
            sum(uu.*b.u,1));
        aligned.angle_deg = rad2deg(angles);
        aligned.arm_length_rms = sqrt(mean(( ...
            a.ell(order(:))-b.ell(:)).^2));
        aligned.position_rms = sqrt(mean(aligned.position_error.^2));
        aligned.angle_rms_deg = sqrt(mean(aligned.angle_deg.^2));
        aligned.combined_rms = sqrt(cost/6);
    end
end
end
