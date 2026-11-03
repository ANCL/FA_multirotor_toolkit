function cases = study_04_cases(s)
%STUDY_04_CASES Enumerate deterministic unrestricted-P1 epsilon sweeps.
% Seven study labels: six objective pairs and an optional joint 3D check.
if nargin < 1 || isempty(s), s = study_04_settings(); end
[~,~,solver_key] = select_optimizer(s.solver);
all_pairs = {'authority_effort','authority_sigma','authority_condition', ...
    'sigma_effort','condition_effort','sigma_condition','joint_three'};
if ~all(ismember(s.pairs, all_pairs)) || numel(unique(s.pairs)) ~= numel(s.pairs)
    error('fa:Study04Pairs','Invalid or duplicated Study 04 pair names.');
end
validate_grid(s.authority_effort_thresholds, -1e-12, sqrt(2/3), 'authority-effort');
validate_grid(s.authority_thresholds, 0, sqrt(2/3), 'authority');
validate_grid(s.sigma_thresholds, 0, sqrt(2), 'sigma');
validate_grid(s.condition_thresholds, 1, Inf, 'condition');
validate_grid(s.joint_authority_thresholds, 0, sqrt(2/3), 'joint authority');
validate_grid(s.joint_sigma_thresholds, 0, sqrt(2), 'joint sigma');

pair = {}; normalization_group = {}; objective = {};
r_threshold = []; sigma_threshold = []; condition_ceiling = [];
seed = []; file_name = {};
for ip = 1:numel(s.pairs)
    kind = s.pairs{ip};
    switch kind
        case 'authority_effort'
            rr = s.authority_effort_thresholds(:);
            ss = nan(size(rr)); cc = nan(size(rr));
        case {'authority_sigma','authority_condition'}
            rr = s.authority_thresholds(:);
            ss = nan(size(rr)); cc = nan(size(rr));
        case {'sigma_effort','sigma_condition'}
            ss = s.sigma_thresholds(:);
            rr = nan(size(ss)); cc = nan(size(ss));
        case 'condition_effort'
            cc = s.condition_thresholds(:);
            rr = nan(size(cc)); ss = nan(size(cc));
        case 'joint_three'
            [R,S] = ndgrid(s.joint_authority_thresholds, s.joint_sigma_thresholds);
            rr = R(:); ss = S(:); cc = nan(size(rr));
    end
    switch kind
        case {'authority_effort','sigma_effort','condition_effort'}
            optimized = 'hover_effort';
        case 'authority_sigma'
            optimized = 'sigma_min';
        otherwise
            optimized = 'condition_number';
    end
    for it = 1:numel(rr)
        for ig = 1:numel(s.normalization_groups)
            group = s.normalization_groups{ig};
            if ~ismember(group, {'positive','negative'})
                error('fa:Study04Group','Unknown P1 normalization group.');
            end
            pair{end+1,1} = kind; %#ok<AGROW>
            normalization_group{end+1,1} = group; %#ok<AGROW>
            objective{end+1,1} = optimized; %#ok<AGROW>
            r_threshold(end+1,1) = rr(it); %#ok<AGROW>
            sigma_threshold(end+1,1) = ss(it); %#ok<AGROW>
            condition_ceiling(end+1,1) = cc(it); %#ok<AGROW>
            seed(end+1,1) = s.random_seed + 100000*ip + 100*it + ig; %#ok<AGROW>
            file_name{end+1,1} = sprintf('%s_r%0.6f_s%0.6f_c%0.6f_%s_%s.mat', ...
                kind, rr(it), ss(it), cc(it), group, solver_key); %#ok<AGROW>
        end
    end
end
cases = table(pair,normalization_group,objective,r_threshold, ...
    sigma_threshold,condition_ceiling,seed,file_name);
end

function validate_grid(x, lower, upper, name)
if isempty(x) || ~isnumeric(x) || ~isvector(x) || ...
        any(~isfinite(x)) || any(x <= lower) || any(x >= upper) || ...
        numel(unique(x)) ~= numel(x)
    error('fa:Study04Grid','Invalid %s threshold grid.',name);
end
end
