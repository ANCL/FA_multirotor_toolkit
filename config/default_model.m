function model = default_model()
%DEFAULT_MODEL Return the nominal six-rotor physical model.
%
% Wrenches are [Fx; Fy; Fz; Mx; My; Mz] in the body frame.
% Body z points down; normalized hover requires force [0; 0; -1].
model.n_rotors = 6;
model.reaction_signs = [1; 1; 1; -1; -1; -1];
model.reaction_moment_ratio = 0.03;
model.actuator_bounds = [zeros(6, 1), ones(6, 1)];
model.hover_wrench = [0; 0; -1; 0; 0; 0];
model.characteristic_length = 1;
model.geometry.minimum_radius = 0.30;
model.geometry.minimum_separation = 0.30;
end
