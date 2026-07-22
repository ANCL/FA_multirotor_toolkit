function zero_angles = substitute_zero_installation_angles(model)
%SUBSTITUTE_ZERO_INSTALLATION_ANGLES Set alpha_i = beta_i = 0.

n = model.n_rotors;
variables = [model.alpha;model.beta];
values = sym(zeros(2*n,1));
zero_angles = substitute_symbolic_model(model,variables,values);
zero_angles.alpha_values = sym(zeros(n,1));
zero_angles.beta_values = sym(zeros(n,1));
end
