function planar = substitute_planar_shared_geometry(model, reaction_signs)
%SUBSTITUTE_PLANAR_SHARED_GEOMETRY Match the numerical planar-shared family.
%
% The six rotor labels follow the numerical implementation:
% gamma = [0, 120, 240, 60, 180, 300] deg.  With the standard sign vector
% [1,1,1,-1,-1,-1], reaction signs alternate around the physical azimuth.
% The shared installation law is alpha_i = s_i*alpha_s and beta_i = beta_s.

if model.n_rotors ~= 6
    error('fa:PlanarSharedRotorCount', ...
        'The toolkit planar-shared symbolic family requires six rotors.');
end
reaction_signs = reaction_signs(:);
validateattributes(reaction_signs,{'numeric'}, ...
    {'real','finite','numel',6});
if any(abs(abs(reaction_signs)-1) > 1e-12)
    error('fa:InvalidReactionSigns', ...
        'reaction_signs must contain only -1 or +1.');
end

alpha_s = sym('alpha_s','real');
beta_s = sym('beta_s','real');
kappa_s = sym('kappa_s','real');
ell_values = sym(ones(6,1));
gamma_values = sym([0;2;4;1;3;5])*sym(pi)/3;
eta_values = sym(zeros(6,1));
alpha_values = sym(reaction_signs)*alpha_s;
beta_values = sym(ones(6,1))*beta_s;
kappa_values = sym(ones(6,1))*kappa_s;
sign_values = sym(reaction_signs);

variables = [model.ell;model.gamma;model.eta;model.alpha;model.beta; ...
    model.kappa;model.reaction_signs];
values = [ell_values;gamma_values;eta_values;alpha_values;beta_values; ...
    kappa_values;sign_values];
planar = substitute_symbolic_model(model,variables,values);
planar.shared_alpha = alpha_s;
planar.shared_beta = beta_s;
planar.shared_kappa = kappa_s;
planar.ell_values = ell_values;
planar.gamma_values = gamma_values;
planar.eta_values = eta_values;
planar.alpha_values = alpha_values;
planar.beta_values = beta_values;
planar.kappa_values = kappa_values;
planar.reaction_sign_values = sign_values;
planar.planar_ordering = 'toolkit_planar_shared';
end
