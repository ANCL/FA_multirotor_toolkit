function trial = evaluate_robustness_trial(design, type, level, trial_number, parameters, solver)
%EVALUATE_ROBUSTNESS_TRIAL Evaluate one saved deterministic perturbation.
label = sprintf('%s__%s__%.12g__%d',design.name,type,level,trial_number);
seed = stable_seed(solver.master_seed,label);
perturbation = draw_robustness_perturbation(type,level,design.geometry,seed, ...
    parameters.robustness.truncation_sigma);
geometry = perturb_geometry(design.geometry,perturbation.delta_p, ...
    perturbation.rotation_vectors);
trial_parameters = parameters;
[mu_min,mu_max] = parse_actuator_bounds( ...
    parameters.actuator_bounds,parameters.n_rotors);
trial_parameters.actuator_bounds = [mu_min, ...
    mu_max.*perturbation.capacity_factors];
base_kappa = parameters.kappa(:);
if isscalar(base_kappa), base_kappa = repmat(base_kappa,6,1); end
trial_parameters.kappa = base_kappa.*perturbation.kappa_factors;

% The exact max-radius equality defines nominal scale. Position errors are
% evaluated without treating radius one as a physical manufacturing wall.
evaluation_options = robustness_evaluation_options(type);
metrics = evaluate_design(geometry,trial_parameters,solver,evaluation_options);
[sample_rms,sample_maximum] = perturbation_size(type,perturbation);
trial = struct('design_name',design.name,'perturbation_type',type,'level',level, ...
    'trial_number',trial_number,'seed',seed, ...
    'sample_rms',sample_rms,'sample_maximum',sample_maximum, ...
    'r_F0',metrics.r_F0,'sigma_min',metrics.sigma_min, ...
    'condition_number',metrics.condition_number, ...
    'hover_effort',metrics.hover_effort,'q_star',metrics.q_star, ...
    'minimum_separation',metrics.geometry_check.minimum_separation, ...
    'minimum_hover_margin',hover_margin(metrics), ...
    'geometric_feasible',metrics.geometry_check.valid, ...
    'numerically_fully_actuated',metrics.numerically_fully_actuated, ...
    'hover_feasible',metrics.hover_feasible,'task_feasible',metrics.task_feasible, ...
    'evaluation_valid',metrics.valid,'valid',metrics.valid, ...
    'failure_reason',metrics.failure_reason, ...
    'internal_error_identifier',metrics.internal_error_identifier);
end


function [rms_value,maximum_value] = perturbation_size(type,perturbation)
%PERTURBATION_SIZE Compact sample diagnostics; the seed regenerates the sample.
switch type
    case 'position'
        values = vecnorm(perturbation.delta_p,2,1);
    case 'direction'
        values = vecnorm(perturbation.rotation_vectors,2,1);
    case 'capacity'
        values = perturbation.capacity_factors(:)-1;
    case 'kappa'
        values = perturbation.kappa_factors(:)-1;
    otherwise
        error('fa:UnknownPerturbation','Unknown robustness perturbation: %s',type);
end
rms_value = sqrt(mean(values.^2));
maximum_value = max(abs(values));
end

function value = hover_margin(metrics)
if isempty(metrics.hover), value = NaN; else, value = metrics.hover.minimum_margin; end
end

function perturbation = draw_robustness_perturbation(type, level, geometry, seed, truncation_sigma)
%DRAW_ROBUSTNESS_PERTURBATION Generate one deterministic uncertainty sample.
stream = RandStream('mt19937ar','Seed',seed);
clip = @(x) max(-truncation_sigma*level,min(truncation_sigma*level,x));
perturbation = struct('delta_p',zeros(3,6),'rotation_vectors',zeros(3,6), ...
    'capacity_factors',ones(6,1),'kappa_factors',ones(6,1));
switch type
    case 'position'
        perturbation.delta_p = clip(level*randn(stream,3,6));
    case 'direction'
        angles = clip(level*randn(stream,1,6));
        random_axes = randn(stream,3,6);
        random_axes = random_axes-geometry.u.*sum(geometry.u.*random_axes,1);
        lengths = vecnorm(random_axes,2,1);
        zero = lengths < eps;
        if any(zero)
            random_axes(:,zero) = perpendicular_directions(geometry.u(:,zero));
            lengths(zero) = 1;
        end
        perturbation.rotation_vectors = random_axes./lengths.*angles;
    case 'capacity'
        deviation = clip(level*randn(stream,6,1));
        perturbation.capacity_factors = max(0.05,1+deviation);
    case 'kappa'
        deviation = clip(level*randn(stream,6,1));
        perturbation.kappa_factors = max(0.05,1+deviation);
    otherwise
        error('fa:UnknownPerturbation','Unknown robustness perturbation: %s',type);
end
end

function directions = perpendicular_directions(u)
% Choose the Cartesian basis least aligned with each input direction.
[~,index] = min(abs(u),[],1);
basis = eye(3);
reference = basis(:,index);
directions = cross(u,reference,1);
directions = directions./vecnorm(directions,2,1);
end

function perturbed = perturb_geometry(geometry, delta_p, rotation_vectors)
%PERTURB_GEOMETRY Apply position offsets and axis-angle rotations.
% Rodrigues' formula is evaluated for all six thrust directions together.
validateattributes(delta_p, {'numeric'}, {'real','finite','size',[3 6]});
validateattributes(rotation_vectors, {'numeric'}, {'real','finite','size',[3 6]});

perturbed = geometry;
perturbed.p = geometry.p + delta_p;
angles = vecnorm(rotation_vectors,2,1);
axes = zeros(3,6);
active = angles > eps;
axes(:,active) = rotation_vectors(:,active) ./ angles(active);
cosine = cos(angles);
sine = sin(angles);
axis_projection = sum(axes .* geometry.u,1);
rotated = geometry.u .* cosine + cross(axes,geometry.u,1) .* sine + ...
    axes .* axis_projection .* (1-cosine);
rotated(:,~active) = geometry.u(:,~active);
perturbed.u = rotated ./ vecnorm(rotated,2,1);

% Keep stored coordinates consistent with the perturbed p and u. Shared-angle
% variables no longer describe an independently perturbed geometry and are
% therefore removed rather than left stale.
perturbed.ell = vecnorm(perturbed.p,2,1).';
perturbed.gamma = atan2(perturbed.p(2,:),perturbed.p(1,:)).';
perturbed.eta = atan2(-perturbed.p(3,:).', ...
    hypot(perturbed.p(1,:).',perturbed.p(2,:).'));
[perturbed.alpha,perturbed.beta] = local_installation_angles( ...
    perturbed.gamma,perturbed.eta,perturbed.u);
if isfield(perturbed,'phi'), perturbed = rmfield(perturbed,'phi'); end
if isfield(perturbed,'theta'), perturbed = rmfield(perturbed,'theta'); end
if isfield(perturbed,'design_variables'), perturbed.design_variables = []; end
end

function options = robustness_evaluation_options(perturbation_type)
%ROBUSTNESS_EVALUATION_OPTIONS Geometry checks for manufactured perturbations.
% The unit maximum radius is a nominal scale normalization, not a physical
% outer boundary for rotor-position installation errors.
options = struct('enforce_normalization',false,'enforce_upper_length',true);
if strcmpi(char(string(perturbation_type)),'position')
    options.enforce_upper_length = false;
end
end
