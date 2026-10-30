function summary = seeded_p1_configuration_distance(p2,p1,parameters)
%SEEDED_P1_CONFIGURATION_DISTANCE Physical distances after yaw/permutation matching.
objectives = ["r_F0";"sigma_min";"condition_number"];
signs = parameters.reaction_signs(:).';
orders = perms(1:6);
orders = orders(all(signs(orders)==signs,2),:);
rows = cell(numel(objectives),5);
for k = 1:numel(objectives)
    name = objectives(k);
    a = p1(strcmp(string({p1.name}),name));
    b = p2(strcmp(string({p2.name}),name));
    if numel(a)~=1 || numel(b)~=1
        error('fa:Stage06Geometry','Missing P1/P2 optimized design for %s.',name);
    end
    a = a.geometry; b = b.geometry;
    best = inf;
    for j = 1:size(orders,1)
        order = orders(j,:);
        p = a.p(:,order); u = a.u(:,order);
        z = sum(conj(complex(p(1,:),p(2,:))).* ...
            complex(b.p(1,:),b.p(2,:)) + ...
            conj(complex(u(1,:),u(2,:))).* ...
            complex(b.u(1,:),b.u(2,:)));
        yaw = angle(z);
        R = [cos(yaw),-sin(yaw),0;sin(yaw),cos(yaw),0;0,0,1];
        dp = R*p-b.p; du = R*u-b.u;
        error_value = sum(dp.^2,'all')+sum(du.^2,'all');
        if error_value < best
            best = error_value;
            delta_p = vecnorm(dp,2,1);
            angular = acos(max(-1,min(1,sum((R*u).*b.u,1))));
            delta_ell = a.ell(order)-b.ell(:).';
            best_yaw = yaw;
        end
    end
    rows(k,:) = {char(name),sqrt(mean(delta_p.^2)), ...
        rad2deg(sqrt(mean(angular.^2))), ...
        sqrt(mean(delta_ell.^2)),rad2deg(best_yaw)};
end
summary = cell2table(rows,'VariableNames', ...
    {'objective','position_rms','thrust_angle_rms_deg', ...
    'arm_length_rms','p1_yaw_alignment_deg'});
end
