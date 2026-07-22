function specifications = design_comparison_case_plan( ...
    phase,parameters,solver,structured_selected)
%DESIGN_COMPARISON_CASE_PLAN Deterministic Stage 01 case definitions.
if nargin < 4, structured_selected = struct([]); end
phase = char(string(phase));
switch phase
    case 'structured'
        families = {'spatial_c3','planar_shared'};
        count = numel(families)*numel(parameters.objectives)*solver.independent_runs;
        template_problem = make_design_problem( ...
            families{1},parameters.objectives{1},0,parameters);
        template = make_optimization_case(1,'',template_problem,parameters,1,struct());
        specifications = repmat(template,count,1);
        index = 0;
        for family_index = 1:numel(families)
            family = families{family_index};
            starting_designs = initial_structured_seeds(family,parameters);
            for objective_index = 1:numel(parameters.objectives)
                objective = parameters.objectives{objective_index};
                for run_number = 1:solver.independent_runs
                    index = index+1;
                    case_name = sprintf('%s_%s_run_%d',family,objective,run_number);
                    description = sprintf('%s | %s | repeat %d/%d', ...
                        family_label(family),objective,run_number,solver.independent_runs);
                    problem = make_design_problem(family,objective,0,parameters);
                    problem.initial_designs = starting_designs;
                    problem.case_name = case_name;
                    specifications(index) = make_optimization_case( ...
                        index,description,problem,parameters, ...
                        stable_seed(solver.master_seed,case_name),struct());
                end
            end
        end
    case 'rotorwise'
        if isempty(structured_selected)
            error('fa:MissingStructuredIncumbents', ...
                'Rotor-wise plan requires the selected structured designs.');
        end
        objectives = parameters.objectives;
        base_seeds = initial_rotorwise_seeds(parameters,solver);
        count = numel(objectives)*6*solver.independent_runs;
        template = make_optimization_case(1,'', ...
            make_design_problem('rotorwise',objectives{1},1,parameters), ...
            parameters,1,struct());
        specifications = repmat(template,count,1);
        index = 0;
        for objective_index = 1:numel(objectives)
            objective = objectives{objective_index};
            geometries = structured_geometries(structured_selected,objective);
            seeds = add_rotorwise_seed_geometries(base_seeds,geometries,solver);
            for normalization_case = 1:6
                for run_number = 1:solver.independent_runs
                    index = index+1;
                    case_name = sprintf('%s_norm_%d_run_%d', ...
                        objective,normalization_case,run_number);
                    description = sprintf( ...
                        'Rotor-wise P1 | %s | normalization case %d/6 | repeat %d/%d', ...
                        objective,normalization_case,run_number,solver.independent_runs);
                    problem = make_design_problem( ...
                        'rotorwise',objective,normalization_case,parameters);
                    problem.initial_designs = seeds{normalization_case};
                    problem.case_name = case_name;
                    specifications(index) = make_optimization_case( ...
                        index,description,problem,parameters, ...
                        stable_seed(solver.master_seed,case_name),struct());
                end
            end
        end
    otherwise
        error('fa:UnknownDesignPlanPhase','Unknown design-plan phase: %s',phase);
end
specifications = finalize_optimization_cases(specifications,solver);
end

function geometries = structured_geometries(selected,objective)
mask = endsWith(string({selected.name}),"_"+string(objective));
items = selected(mask);
if numel(items) ~= 2
    error('fa:StructuredIncumbentCount', ...
        'Expected one P2 and one P3 incumbent for objective %s.',objective);
end
geometries = {items.geometry};
end

function label = family_label(family)
switch family
    case 'spatial_c3', label = 'Spatial C3 P2';
    case 'planar_shared', label = 'Planar shared-angle P3';
    otherwise, label = family;
end
end
