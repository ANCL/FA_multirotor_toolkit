function analysis = analyze_study_02()
%ANALYZE_STUDY_02 Audit accepted P1 optima and export concise Study 02 results.
% Read-only with respect to accepted Study 02 MAT files and the optimizer.
% All individual measurements are retained in the audit CSVs.
% The positive/negative joint-triad comparison is NOT a distinctness test or
% evidence that geometrically similar optima form a connected family.

setup_project();
model = default_model();
numerics = default_numerics();
settings = study_02_settings();
root = fileparts(fileparts(mfilename('fullpath')));
base = fullfile(root,'results','study_02');
table_dir = fullfile(base,'tables');
figure_dir = fullfile(base,'figures');
if ~isfolder(table_dir), mkdir(table_dir); end
if settings.make_figures && ~isfolder(figure_dir), mkdir(figure_dir); end
objectives = {'r_F0','sigma_min','condition_number'};
signs = model.reaction_signs(:).';
positive = find(signs==1);
negative = find(signs==-1);
if numel(signs)~=6 || numel(positive)~=3 || numel(negative)~=3
    error('fa:Study02Signs','Expected three positive- and three negative-spin rotors.');
end
if ~isscalar(model.reaction_moment_ratio)
    error('fa:Study02Reaction','This analysis expects a scalar reaction-moment ratio.');
end

% Load numbered accepted entries, not the derived CSVs. No optimization.
accepted_data = cell(3,1);
counts = zeros(3,1);
for k=1:3
    accepted_data{k} = load_study_02_accepted(base,objectives{k});
    counts(k) = numel(accepted_data{k});
    if counts(k)==0
        error('fa:Study02Empty','No accepted configurations for %s.',objectives{k});
    end
end
n_total = sum(counts);
rotor_records = cell(6*n_total,1);
configuration_records = cell(n_total,1);
summary_records = cell(3,1);
plot_data = cell(3,1);
rotor_index = 0;
config_index = 0;

for k=1:3
    objective = objectives{k};
    accepted = accepted_data{k};
    n = counts(k);
    reference = analytical_reference(objective);
    for j=1:n
        entry = accepted(j);
        g = entry.geometry;
        validate_geometry(g,objective,j);
        p = g.positions;
        u = g.directions;
        ell = g.radii(:).';
        arm = p ./ ell;
        eta = rad2deg(g.elevation(:)).';
        alpha = rad2deg(g.alpha(:)).';
        beta = rad2deg(g.beta(:)).';
        gamma = rad2deg(g.azimuth(:)).';

        % Both independent constructions of the effective moment arm.
        q = ell .* abs(cos(g.beta(:).'));
        q_vector = vecnorm(cross(p,u,1),2,1);
        q_error = abs(q-q_vector);
        if max(q_error)>1e-8
            error('fa:Study02MomentArm','Moment-arm identity failed in %s/%d.',objective,j);
        end

        % Re-evaluate physical constraints without modifying the stored entry.
        problem = make_design_problem('p1',objective,entry.normalization_group,model);
        x = entry.design_variables(:);
        if numel(x)~=28 || any(~isfinite(x))
            error('fa:Study02Variables','Invalid P1 variables in %s/%d.',objective,j);
        end
        [c,ceq] = design_constraints(x,problem,model,numerics);
        physical = max([0;c(:);abs(ceq(:));problem.lower_bounds(:)-x; ...
            x-problem.upper_bounds(:)]);
        stored_physical = entry.physical_constraint_violation;
        value = entry.objective_value;
        if strcmp(objective,'condition_number')
            signed_gap = value-reference;
        else
            signed_gap = reference-value;
        end
        gap = max(0,signed_gap);
        if ~isfinite(value) || ~isfinite(physical) || ...
                ~isfinite(stored_physical)
            error('fa:Study02Nonfinite','Nonfinite accepted data in %s/%d.',objective,j);
        end

        [A,Af] = allocation_matrix(g,model);
        Abar = normalized_allocation_matrix(A,model.characteristic_length);
        force_gram = Af*Af.';
        full_gram = Abar*Abar.';
        [eigenvectors,D] = eig((force_gram+force_gram.')/2);
        [lambda,order] = sort(real(diag(D)),'ascend');
        eigenvectors = eigenvectors(:,order);
        force_gains = sqrt(max(0,lambda)).';
        weak_vertical = NaN;
        weak_vertical_deg = NaN;
        if lambda(2)-lambda(1) > 1e-8*max(1,lambda(3))
            weak_vertical = abs(eigenvectors(3,1));
            weak_vertical_deg = acosd(clamp(weak_vertical));
        end
        delta_f = norm(force_gram-2*eye(3),'fro');
        delta_A = norm(full_gram-2*eye(6),'fro');
        % Conical reference is descriptive, NOT assumed necessary for r_F0.
        conical_residual = norm(force_gram-diag([8/3 8/3 2/3]),'fro');
        q_target = sqrt(1-model.reaction_moment_ratio^2);

        ap = pair_angles(arm(:,positive));
        an = pair_angles(arm(:,negative));
        tp = pair_angles(u(:,positive));
        tn = pair_angles(u(:,negative));
        arm_shape = norm(sort(ap)-sort(an))/sqrt(3);
        thrust_shape = norm(sort(tp)-sort(tn))/sqrt(3);
        arm_spread_pos = max(ap)-min(ap);
        arm_spread_neg = max(an)-min(an);
        thrust_spread_pos = max(tp)-min(tp);
        thrust_spread_neg = max(tn)-min(tn);
        [joint_yaw,yaw_perm,yaw_deg,joint_so3,so3_perm] = ...
            compare_spin_triads(p(:,positive),u(:,positive), ...
                p(:,negative),u(:,negative));
        az_pos = azimuth_gaps(p(:,positive));
        az_neg = azimuth_gaps(p(:,negative));

        for i=1:6
            rotor_index = rotor_index+1;
            rotor_records{rotor_index} = struct( ...
                'objective',objective,'config_id',j, ...
                'attempt_number',entry.attempt_number, ...
                'rotor',i,'reaction_sign',signs(i), ...
                'ell',ell(i),'gamma_deg',gamma(i),'eta_deg',eta(i), ...
                'alpha_deg',alpha(i),'beta_deg',beta(i), ...
                'q_effective',q(i),'q_cross_product',q_vector(i), ...
                'q_identity_abs_error',q_error(i), ...
                'px',p(1,i),'py',p(2,i),'pz',p(3,i), ...
                'ux',u(1,i),'uy',u(2,i),'uz',u(3,i));
        end

        config = struct('objective',objective,'config_id',j, ...
            'attempt_number',entry.attempt_number, ...
            'normalization_group',entry.normalization_group, ...
            'objective_value',value,'analytical_bound',reference, ...
            'signed_bound_gap',signed_gap,'absolute_bound_violation',gap, ...
            'relative_bound_gap',signed_gap/reference, ...
            'stored_absolute_bound_violation',entry.performance_bound_violation, ...
            'physical_constraint_violation',physical, ...
            'stored_physical_constraint_violation',stored_physical, ...
            'physical_recheck_abs_difference',abs(physical-stored_physical), ...
            'q_min',min(q),'q_mean',mean(q),'q_max',max(q), ...
            'q_identity_max_error',max(q_error), ...
            'q_vs_exact_isotropy_target_max',max(abs(q-q_target)), ...
            'force_gain_1',force_gains(1), ...
            'force_gain_2',force_gains(2), ...
            'force_gain_3',force_gains(3), ...
            'force_gram_xx',force_gram(1,1), ...
            'force_gram_yy',force_gram(2,2), ...
            'force_gram_zz',force_gram(3,3), ...
            'force_gram_xy',force_gram(1,2), ...
            'force_gram_xz',force_gram(1,3), ...
            'force_gram_yz',force_gram(2,3), ...
            'force_vertical_coupling',norm(force_gram(1:2,3)), ...
            'force_horizontal_eigenvalue_spread', ...
                hypot(force_gram(1,1)-force_gram(2,2),2*force_gram(1,2)), ...
            'force_weak_axis_abs_vertical_cos',weak_vertical, ...
            'force_weak_axis_vertical_angle_deg',weak_vertical_deg, ...
            'force_conical_reference_residual',conical_residual, ...
            'force_isotropy_residual_F',delta_f, ...
            'full_isotropy_residual_F',delta_A, ...
            'arm_triad_shape_rms_deg',arm_shape, ...
            'thrust_triad_shape_rms_deg',thrust_shape, ...
            'arm_pos_mean_deg',mean(ap),'arm_neg_mean_deg',mean(an), ...
            'arm_pos_spread_deg',arm_spread_pos, ...
            'arm_neg_spread_deg',arm_spread_neg, ...
            'thrust_pos_mean_deg',mean(tp),'thrust_neg_mean_deg',mean(tn), ...
            'thrust_pos_spread_deg',thrust_spread_pos, ...
            'thrust_neg_spread_deg',thrust_spread_neg, ...
            'joint_triad_yaw_rms',joint_yaw, ...
            'joint_triad_yaw_deg',yaw_deg, ...
            'joint_triad_yaw_permutation',yaw_perm, ...
            'joint_triad_SO3_rms',joint_so3, ...
            'joint_triad_SO3_permutation',so3_perm, ...
            'ell_min',min(ell),'ell_max',max(ell), ...
            'eta_min_deg',min(eta),'eta_max_deg',max(eta), ...
            'alpha_min_deg',min(alpha),'alpha_max_deg',max(alpha), ...
            'beta_min_deg',min(beta),'beta_max_deg',max(beta));
        % Store ALL six effective moment arms and ALL twelve triad angles.
        for h=1:6
            config.(sprintf('q_%d',h)) = q(h);
        end
        for h=1:3
            config.(sprintf('arm_pos_pair_%d_deg',h)) = ap(h);
            config.(sprintf('arm_neg_pair_%d_deg',h)) = an(h);
            config.(sprintf('thrust_pos_pair_%d_deg',h)) = tp(h);
            config.(sprintf('thrust_neg_pair_%d_deg',h)) = tn(h);
            config.(sprintf('azimuth_pos_gap_%d_deg',h)) = az_pos(h);
            config.(sprintf('azimuth_neg_gap_%d_deg',h)) = az_neg(h);
        end
        config_index = config_index+1;
        configuration_records{config_index} = config;


    end

    % Summarize configuration-level values, not untracked pooled rotors.
    rows = configuration_records(config_index-n+1:config_index);
    local = struct2table(vertcat(rows{:}));
    % Compact manuscript summary: 1 row/objective, 8 columns total.
    % rho values are maxima over the actual accepted sample, not KDE values.
    summary_records{k} = struct( ...
        'objective',objective, ...
        'accepted',n, ...
        'median_relative_bound_gap_percent', ...
            100*median(local.absolute_bound_violation)/reference, ...
        'median_q_min',median(local.q_min), ...
        'median_force_isotropy_residual', ...
            median(local.force_isotropy_residual_F), ...
        'median_full_isotropy_residual', ...
            median(local.full_isotropy_residual_F), ...
        'max_rho_p_deg',max(local.arm_triad_shape_rms_deg), ...
        'max_rho_u_deg',max(local.thrust_triad_shape_rms_deg));
    plot_data{k} = [local.arm_triad_shape_rms_deg, ...
                    local.thrust_triad_shape_rms_deg];
    fprintf('  %-17s %d designs; max gap %.3g; max physical violation %.3g\n', ...
        objective,n,max(local.absolute_bound_violation), ...
        max(local.physical_constraint_violation));
end

rotors = struct2table(vertcat(rotor_records{:}));
configurations = struct2table(vertcat(configuration_records{:}));
summary = struct2table(vertcat(summary_records{:}));
writetable(rotors,fullfile(table_dir,'geometry_rotors.csv'));
writetable(configurations,fullfile(table_dir,'geometry_configurations.csv'));
writetable(summary,fullfile(table_dir,'study02_manuscript_summary.csv'));
if settings.make_figures
    make_lollipop_figures(plot_data,figure_dir);
end
analysis = struct('rotors',rotors,'configurations',configurations, ...
    'summary',summary);
fprintf('Study 02 analysis: %d configurations | 3 CSV tables',height(configurations));
if settings.make_figures, fprintf(' | 2 figures (PDF and PNG)'); end
fprintf('\nTables: %s\n',table_dir);
if settings.make_figures, fprintf('Figures: %s\n',figure_dir); end
end

function ref = analytical_reference(name)
switch name
    case 'r_F0', ref = sqrt(2/3);
    case 'sigma_min', ref = sqrt(2);
    case 'condition_number', ref = 1;
    otherwise, error('fa:Study02Objective','Unknown objective: %s',name);
end
end

function validate_geometry(g,objective,j)
required = {'radii','azimuth','elevation','alpha','beta'};
if ~isequal(size(g.positions),[3 6]) || ...
        ~isequal(size(g.directions),[3 6]) || ...
        any(~isfinite(g.positions(:))) || any(~isfinite(g.directions(:))) || ...
        any(abs(vecnorm(g.directions,2,1)-1)>1e-8)
    error('fa:Study02Geometry','Invalid positions/directions in %s/%d.',objective,j);
end
for h=1:numel(required)
    name = required{h};
    if ~isfield(g,name)
        error('fa:Study02Geometry','Missing %s in %s/%d.',name,objective,j);
    end
    v = g.(name);
    if numel(v)~=6 || any(~isfinite(v(:)))
        error('fa:Study02Geometry','Invalid %s in %s/%d.',name,objective,j);
    end
end
if any(g.radii(:)<=0) || ...
        max(abs(vecnorm(g.positions,2,1)-g.radii(:).'))>1e-8
    error('fa:Study02Geometry','Inconsistent arm lengths in %s/%d.',objective,j);
end
end

function values = pair_angles(v)
pairs = [1 2;1 3;2 3];
values = zeros(1,3);
for h=1:3
    values(h) = acosd(clamp(v(:,pairs(h,1)).'*v(:,pairs(h,2))));
end
end

function gaps = azimuth_gaps(p)
% Sorted cyclic gaps are yaw- and permutation-invariant. Undefined at pole.
if any(vecnorm(p(1:2,:),2,1)<1e-8)
    gaps = [NaN NaN NaN];
    return;
end
az = sort(mod(atan2(p(2,:),p(1,:)),2*pi));
gaps = sort(rad2deg([diff(az),az(1)+2*pi-az(3)]));
end

function [yaw_rms,yaw_perm,yaw_deg,so3_rms,so3_perm] = ...
        compare_spin_triads(pp,up,pn,un)
% Compare one positive and one negative triad using a SINGLE rotor pairing
% for BOTH positions and thrust directions. Proper 3D rotations only.
% This compares shape, not physical equivalence of opposite spin groups.
orders = perms(1:3);
yaw_rms = inf;
so3_rms = inf;
yaw_perm = '';
so3_perm = '';
yaw_deg = NaN;
for h=1:size(orders,1)
    order = orders(h,:);
    p = pp(:,order);
    u = up(:,order);
    % Best common yaw rotation for the complete (position,thrust) triad.
    correlation = sum(conj(complex(p(1,:),p(2,:))).* ...
        complex(pn(1,:),pn(2,:)) + ...
        conj(complex(u(1,:),u(2,:))).*complex(un(1,:),un(2,:)));
    yaw = angle(correlation);
    Rz = [cos(yaw),-sin(yaw),0;sin(yaw),cos(yaw),0;0,0,1];
    d = sqrt((norm(Rz*p-pn,'fro')^2+norm(Rz*u-un,'fro')^2)/6);
    if d<yaw_rms
        yaw_rms = d;
        yaw_perm = sprintf('%d%d%d',order);
        yaw_deg = rad2deg(yaw);
    end
    % Best proper rigid rotation (SO(3)); lengths remain in positions.
    C = [pn un]*[p u].';
    [U,~,V] = svd(C);
    R = U*diag([1 1 sign(det(U*V.'))])*V.';
    d = sqrt((norm(R*p-pn,'fro')^2+norm(R*u-un,'fro')^2)/6);
    if d<so3_rms
        so3_rms = d;
        so3_perm = sprintf('%d%d%d',order);
    end
end
end

function y = clamp(x)
y = max(-1,min(1,x));
end

function make_lollipop_figures(data,folder)
% Empirical percentage per 1-degree bin, without smoothing or toolboxes.
% Same bin edges across objectives; marker offsets only improve legibility.
colors = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.4660 0.6740 0.1880];
labels = {'$r_{\mathcal F_0}(f_h)$', ...
          '$\sigma_{\min}(\bar A)$', '$C(\bar A)$'};
axis_labels = {'$\rho_p\ ({}^\circ)$', '$\rho_u\ ({}^\circ)$'};
filenames = {'geometry_arm_triad_mismatch', ...
             'geometry_thrust_triad_mismatch'};

for metric=1:2
    max_value = max(cellfun(@(v) max(v(:,metric)),data));
    % Count every observation, including the largest value (last bin).
    edges = 0:1:max(1,ceil(max_value));
    x_limit = max(5,5*ceil(max_value/5));
    fig = figure('Visible','off','Color','w', ...
        'Units','centimeters','Position',[2 2 16 9]);
    ax = axes('Parent',fig);
    hold(ax,'on');
    handles = gobjects(3,1);
    max_percent = 0;
    for k=1:3
        values = data{k}(:,metric);
        if any(~isfinite(values)) || any(values<0)
            error('fa:Study02Plot','Expected finite nonnegative RMS angles.');
        end
        counts = histcounts(values,edges);
        if sum(counts)~=numel(values)
            error('fa:Study02Plot','Not all configurations were counted.');
        end
        percent = 100*counts/numel(values);
        max_percent = max(max_percent,max(percent));
        centers = edges(1:end-1)+0.5+(k-2)*0.20;
        visible = counts>0;
        handles(k) = stem(ax,centers(visible),percent(visible), ...
            'Color',colors(k,:),'Marker','o', ...
            'MarkerSize',3.5,'MarkerFaceColor',colors(k,:), ...
            'LineWidth',0.85,'BaseValue',0);
    end
    hold(ax,'off');
    xlim(ax,[0 x_limit]);
    ylim(ax,[0 max(1,1.1*max_percent)]);
    xlabel(ax,axis_labels{metric},'Interpreter','latex');
    ylabel(ax,'Configurations (\%)','Interpreter','latex');
    legend(ax,handles,labels,'Interpreter','latex', ...
        'Location','northeast','Box','off');
    set(ax,'FontName','Helvetica','FontSize',10, ...
        'Box','off','TickDir','out','LineWidth',0.8);
    ax.YGrid='on';
    ax.GridAlpha=0.12;
    export_plot(fig,folder,filenames{metric});
end
end

function export_plot(fig,folder,name)
try
    exportgraphics(fig,fullfile(folder,[name '.png']),'Resolution',300);
    exportgraphics(fig,fullfile(folder,[name '.pdf']),'ContentType','vector');
catch
    saveas(fig,fullfile(folder,[name '.png']));
    print(fig,fullfile(folder,[name '.pdf']),'-dpdf','-painters');
end
close(fig);
end
