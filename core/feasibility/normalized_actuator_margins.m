function margins = normalized_actuator_margins(mu, actuator_bounds)
%NORMALIZED_ACTUATOR_MARGINS Distance from each actuator input to its bounds.
%
% The margin is normalized by the actuator interval and equals 0.5 at the
% interval midpoint and zero at either bound.

[mu_min,mu_max] = parse_actuator_bounds(actuator_bounds,size(mu,1));
range = mu_max-mu_min;
margins = min((mu-mu_min)./range,(mu_max-mu)./range);
end
