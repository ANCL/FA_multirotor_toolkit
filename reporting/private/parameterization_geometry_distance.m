function [summary,details] = parameterization_geometry_distance(selected,parameters)
%PARAMETERIZATION_GEOMETRY_DISTANCE Compare independently selected P1/P2/P3.
% Compare physical rotor positions and thrust axes, not unaligned angle
% vectors. Relabel only equal-reaction-sign rotors and remove common yaw.

objectives = string(parameters.objectives);
families = ["spatial_c3","planar_shared"];
signs = parameters.reaction_signs(:).';
permutations = perms(1:6);
permutations = permutations(all(signs(permutations)==signs,2),:);

summary_rows = cell(numel(objectives)*numel(families),9);
detail_rows = cell(numel(objectives)*numel(families)*6,22);
s = 0;
d = 0;
for objective = objectives
    p1 = selected_geometry(selected,objective);
    for family = families
        p2 = selected_geometry(selected,family+"_"+objective);
        [order,yaw,p1p,p1u] = best_alignment(p1,p2,permutations);
        position_error = vecnorm(p1p-p2.p,2,1).';
        angle_error = acos(max(-1,min(1,sum(p1u.*p2.u,1).')));
        radii1 = p1.ell(order);
        radii2 = p2.ell(:);
        s = s+1;
        summary_rows(s,:) = {char(objective),char(family), ...
            sqrt(mean((radii1-radii2).^2)), ...
            sqrt(mean(position_error.^2)),max(position_error), ...
            rad2deg(sqrt(mean(angle_error.^2))),rad2deg(max(angle_error)), ...
            sqrt(mean(position_error.^2+2*(1-cos(angle_error)))),rad2deg(yaw)};
        for rotor = 1:6
            j = order(rotor);
            gamma1 = atan2(sin(p1.gamma(j)+yaw),cos(p1.gamma(j)+yaw));
            d = d+1;
            detail_rows(d,:) = {char(objective),char(family),rotor,j,signs(rotor), ...
                radii1(rotor),radii2(rotor),radii1(rotor)-radii2(rotor), ...
                rad2deg(gamma1),rad2deg(p2.gamma(rotor)), ...
                wrapped_difference_deg(gamma1,p2.gamma(rotor)), ...
                rad2deg(p1.eta(j)),rad2deg(p2.eta(rotor)), ...
                wrapped_difference_deg(p1.eta(j),p2.eta(rotor)), ...
                rad2deg(p1.alpha(j)),rad2deg(p2.alpha(rotor)), ...
                wrapped_difference_deg(p1.alpha(j),p2.alpha(rotor)), ...
                rad2deg(p1.beta(j)),rad2deg(p2.beta(rotor)), ...
                wrapped_difference_deg(p1.beta(j),p2.beta(rotor)), ...
                position_error(rotor),rad2deg(angle_error(rotor))};
        end
    end
end

summary = cell2table(summary_rows,'VariableNames', ...
    {'objective','parameterization','arm_length_rms','position_rms', ...
     'position_max','thrust_angle_rms_deg','thrust_angle_max_deg', ...
     'combined_rms','p1_yaw_alignment_deg'});
details = cell2table(detail_rows,'VariableNames', ...
    {'objective','parameterization','structured_rotor','p1_rotor','reaction_sign', ...
     'p1_ell','structured_ell','ell_difference', ...
     'p1_gamma_aligned_deg','structured_gamma_deg','gamma_difference_deg', ...
     'p1_eta_deg','structured_eta_deg','eta_difference_deg', ...
     'p1_alpha_deg','structured_alpha_deg','alpha_difference_deg', ...
     'p1_beta_deg','structured_beta_deg','beta_difference_deg', ...
     'position_error','thrust_angle_error_deg'});
end

function [best_order,best_yaw,best_p,best_u] = best_alignment(p1,p2,permutations)
best_cost = inf;
for row = 1:size(permutations,1)
    order = permutations(row,:);
    p = p1.p(:,order);
    u = p1.u(:,order);
    a = complex(p(1,:),p(2,:));
    b = complex(p2.p(1,:),p2.p(2,:));
    c = complex(u(1,:),u(2,:));
    d = complex(p2.u(1,:),p2.u(2,:));
    yaw = angle(sum(conj(a).*b+conj(c).*d));
    R = [cos(yaw),-sin(yaw),0;sin(yaw),cos(yaw),0;0,0,1];
    p_aligned = R*p;
    u_aligned = R*u;
    cost = sum((p_aligned-p2.p).^2,'all') + ...
        sum((u_aligned-p2.u).^2,'all');
    if cost < best_cost
        best_cost = cost;
        best_order = order;
        best_yaw = yaw;
        best_p = p_aligned;
        best_u = u_aligned;
    end
end
end

function degrees = wrapped_difference_deg(a,b)
degrees = rad2deg(atan2(sin(a-b),cos(a-b)));
end
