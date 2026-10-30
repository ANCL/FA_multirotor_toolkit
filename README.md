# Fully Actuated Multirotor Toolkit

MATLAB tools for constructing, analyzing, and optimizing fully actuated multirotor configurations. The toolkit evaluates allocation matrices, bounded wrench feasibility, hover effort, force authority, feasible wrench sets, and trajectory feasibility. It also contains a checkpointed six-stage comparative study and publication-output pipeline.

## Requirements

- MATLAB. The study was validated with **R2024b**; another release produces a warning because numerical optimization results can be release-dependent.
- [Global Optimization Toolbox](https://www.mathworks.com/products/global-optimization.html) for `ga` and `patternsearch`.
- [Optimization Toolbox](https://www.mathworks.com/products/optimization.html) for `linprog`.
- Parallel Computing Toolbox is optional. Independent cases run in parallel when it is available.
- Symbolic Math Toolbox is needed only for `derive_allocation_matrix`.

The implemented optimization parameterizations use six rotors. Fixed-configuration and wrench analysis can use a different rotor count when all required model inputs are supplied.

## Quick start

Open MATLAB in the repository root, then run:

```matlab
setup_project();
output = example_analyze_configuration();
```

The example analyzes three six-rotor configurations and writes each complete result package to:

```text
results/analyses/configurations/<case_name>/
```

Edit only the `USER INPUTS` section of [`examples/example_analyze_configuration.m`](examples/example_analyze_configuration.m) to analyze your own configurations.

## Choose a workflow

| Goal | Start with | Output |
|---|---|---|
| Analyze one or more fixed configurations | `example_analyze_configuration` | `results/analyses/configurations/` |
| Optimize selected designs or objectives | `example_optimize_one_design` | `results/analyses/optimizations/` |
| Check one wrench | `analyze_wrench` | `results/analyses/wrench/` |
| Check a sampled trajectory | `analyze_trajectory` | `results/analyses/trajectory/` |
| Plot force and moment sets | `analyze_feasible_sets` | `results/analyses/feasible_sets/` |
| Derive symbolic allocation matrices | `derive_allocation_matrix` | `results/analyses/allocation_matrix/` |
| Reproduce the complete comparative study | `run_full_study` | `results/current/` |
| Build publication figures and tables | `make_all_outputs` | `results/publication/` |

The files in `analyses/` and `examples/` are user-facing workflows. Functions under `core/` are reusable numerical building blocks; functions under `internal/` support execution, checkpointing, and provenance.

## Numerical studies: six-stage architecture

| Stage | MATLAB entry point | Scientific role |
|---|---|---|
| 01 | `run_unrestricted_optimization` | P1 unrestricted rotorwise optimization |
| 02 | `run_parameterization_comparison` | New P2/P3 optimization and comparison with P1 |
| 03 | `run_pareto_analysis` | P1 and P2 authority–effort analyses; pooled Pareto reporting |
| 04 | `run_sensitivity_analysis` | P2 fixed-geometry and reoptimized sensitivity |
| 05 | `run_robustness_analysis` | P2 robustness under implementation errors |
| 06 | `run_p2_seeded_p1` | P2-seeded P1 objective and geometry comparison |

### Running the numerical stages

The high-budget **P1 Stage 01 is already migrated and verified**. Its 120
completed cases and four selected designs are reused without optimization.
The original migration utility was retired after verification; do not rerun
or reconstruct P1 simply to reorganize the toolkit.

```matlab
setup_project();
run_preflight();                         % numerical environment gate
run_unrestricted_optimization();        % reuse the existing 120 P1 cases
run_parameterization_comparison();      % run 40 new P2/P3 cases (Stage 02)
```

Stage 03 runs independent P1 and P2 Pareto studies and pools their feasible
outcomes in the publication figure; P1 is not seeded from P2. Stages 04–05
use P2 geometries selected by Stage 02. Stage 06 compares P2 designs with
P2-seeded P1 refinements. Generate publication outputs only after their
corresponding numerical stages finish. The 120
full and 120 compact P1 checkpoints in
`results/current/checkpoints/01_unrestricted_optimization/` are protected.

Compatibility is based on scientific settings, case identity, and solver
inputs—not changes to source-file formatting. Human-readable
`study_metadata.json` files accompany each completed stage. A real change
to the numerical algorithm requires an explicit protocol update and review
of the affected saved results, not an automatic source-code hash cascade.

The regression tests are kept under `tests/`, separate from normal numerical
workflows. Run `run_cheap_tests()` only when checking the toolkit. The test
folder is added to the MATLAB path temporarily by that command.

## Analyze a configuration

A geometry contains rotor positions `p` and unit thrust directions `u`, both arranged as `3-by-N` matrices. You can construct it from installation angles or provide `p` and `u` directly.

```matlab
setup_project();
[parameters, ~] = study_settings();

ell   = ones(6,1);
gamma = deg2rad([0; 60; 120; 180; 240; 300]);
eta   = zeros(6,1);
alpha = parameters.reaction_signs(:).*deg2rad(30);
beta  = zeros(6,1);
geometry = angle_geometry(ell, gamma, eta, alpha, beta);

case_spec = struct();
case_spec.name = 'my_configuration';
case_spec.geometry = geometry;
case_spec.kappa = parameters.kappa;
case_spec.reaction_signs = parameters.reaction_signs;
case_spec.actuator_bounds = parameters.actuator_bounds;
case_spec.hover_wrench = parameters.hover_wrench;

output = analyze_configuration(case_spec);
```

`analyze_configuration` produces geometry and feasible-set figures, allocation and extrema tables, complete MAT data, a run log, and JSON/MAT reproducibility manifests. Its most useful optional fields are:

| Field | Meaning |
|---|---|
| `requested_wrenches` | `6-by-M` matrix; each column is one requested wrench |
| `requested_wrench_names` | One readable name per requested wrench |
| `length_scale` | Characteristic length used to compare force and moment coordinates |
| `compute_force_set` | Enable or disable the force set |
| `compute_moment_set` | Enable or disable the moment set |
| `compute_zero_moment_force_set` | Enable or disable the zero-moment force set |
| `output_folder` | Exact custom output folder |

For several requested wrenches, use columns ordered as:

```matlab
% [F_x; F_y; F_z; tau_x; tau_y; tau_z]
case_spec.requested_wrenches = [wrench_1, wrench_2];
case_spec.requested_wrench_names = ["wrench_1"; "wrench_2"];
```

For a non-six-rotor configuration, supply `reaction_signs` explicitly. The default vehicle assumptions are defined for six rotors.

### Geometry constructors

| Constructor | Inputs |
|---|---|
| `angle_geometry` | Rotor-wise `ell`, `gamma`, `eta`, `alpha`, and `beta` |
| `planar_shared_geometry` | P3 variables `[alpha; beta]` |
| `spatial_c3_geometry` | P2 variables `[delta; eta_s; alpha_+; beta_+; alpha_-; beta_-]` |
| `rotorwise_geometry` | Reduced 29-variable P1 vector and one normalization case |

All angles are in radians. `angle_geometry` uses
`Rz(gamma) Ry(eta) Rx(alpha) Ry(beta)` and applies it to the negative local z-axis. The comparative study normalizes rotor distances so that the maximum rotor radius is one.

## Optimize a design

Start with [`examples/example_optimize_one_design.m`](examples/example_optimize_one_design.m), or define one case directly:

```matlab
setup_project();

case_spec = struct();
case_spec.name = 'my_force_authority_design';
case_spec.parameterization = 'planar_shared';
case_spec.objective = 'r_F0';
case_spec.independent_runs = 1;
case_spec.overwrite = false;

output = optimize_custom_design(case_spec);
```

Supported parameterizations:

| Value | Family | Search size |
|---|---|---:|
| `rotorwise` | P1: independent rotor positions and thrust directions | 29 variables, six normalization cases |
| `spatial_c3` | P2: two C3-symmetric rotor triplets | 6 variables |
| `planar_shared` | P3: planar arms with shared installation angles | 2 variables |

Supported objectives:

| Value | Optimization goal |
|---|---|
| `r_F0` | Maximize hover-centered zero-moment force authority |
| `sigma_min` | Maximize the weakest gain of the normalized allocation matrix |
| `condition_number` | Minimize the normalized allocation-matrix condition number |
| `hover_effort` | Minimize the squared actuator effort at hover |

One independent run is suitable for exercising the workflow. Increase `independent_runs` when the result will be used scientifically. Compatible completed runs are checkpointed and reused when `overwrite` is `false`; set it to `true` to clear only that custom optimization folder. Use a distinct `name` for a different problem.

Partial overrides use the nested fields from [`inputs/study_settings.m`](inputs/study_settings.m) and [`inputs/runtime_settings.m`](inputs/runtime_settings.m):

```matlab
case_spec.solver.ga.max_generations = 30;
case_spec.runtime.mode = 'serial';
```

The selected optimum is analyzed automatically. Set `case_spec.analyze_selected_design = false` when only optimization data are needed.

## Wrench and trajectory checks

For one wrench, the reusable API is:

```matlab
model = build_multirotor_model(geometry, kappa, reaction_signs, actuator_bounds);
w_desired = [F_x; F_y; F_z; tau_x; tau_y; tau_z];
result = check_wrench_feasibility(model.A, model.actuator_bounds, w_desired);
```

`result.status` is `feasible_unique`, `feasible_multiple`, or `infeasible`. Infeasible requests include the closest bounded wrench. For redundant configurations, the default `max_margin` strategy selects an allocation away from actuator limits.

For a sampled trajectory:

```matlab
wrench = required_wrench_from_trajectory( ...
    linear_acceleration_I, R_IB, angular_velocity_B, ...
    angular_acceleration_B, mass, inertia_B, gravity_I);

result = check_trajectory_wrench_feasibility( ...
    model.A, model.actuator_bounds, wrench.w_required);
```

See [`analyses/analyze_trajectory.m`](analyses/analyze_trajectory.m) for a complete editable example with exported figures and diagnostics. The rigid-body wrench calculation does not model aerodynamic drag, rotor interference, or actuator dynamics.

## Reproduce the comparative study

The complete study is computationally expensive. The independent P1 search uses a larger budget than the structured P2/P3 searches. Validate the installation first:

```matlab
setup_project();
run_cheap_tests();   % static regressions; no optimization
run_preflight();     % reduced end-to-end solver and I/O check
```

Then run all numerical stages and generate reports:

```matlab
study_output = run_full_study();
publication_output = make_all_outputs();
```

`run_full_study` executes the five stages in dependency order:

1. `run_unrestricted_optimization` — P1-only Stage 01; reuses the verified high-budget results.
2. `run_parameterization_comparison` — P2/P3 searches and comparison against P1.
3. `run_pareto_analysis` — P1 and P2 authority–effort analyses (P1 independent of P2 initialization).
4. `run_sensitivity_analysis` — P2 model/parameter sensitivity.
5. `run_robustness_analysis` — P2 implementation robustness.

Every numerical stage requires a compatible successful preflight. Rerunning `run_full_study` resumes compatible missing cases from `results/current/checkpoints/`. Reporting reads completed numerical results and does not rerun optimization.

To run without parallel workers, edit [`inputs/runtime_settings.m`](inputs/runtime_settings.m):

```matlab
runtime.mode = 'serial';
```

Use `auto` to use a process pool when available, or `parallel` to require one. Runtime settings do not change scientific results and are excluded from scientific-input compatibility checks.

## Results

| Folder | Contents |
|---|---|
| `results/analyses/` | Independent fixed-design, optimization, wrench, trajectory, and symbolic analyses |
| `results/preflight/` | Reduced validation run and compatibility marker |
| `results/current/` | Numerical study results, checkpoints, state, and run log |
| `results/publication/` | Regenerated figures, tables, source data, and manifests |

Tables are generally written as CSV, MAT, and LaTeX. Publication figures are written as PDF and editable FIG, with matching CSV and MAT source data. Use `results/publication/OUTPUT_GUIDE.md` after `make_all_outputs` for the generated report-specific file map.

### Checkpoints and canonical stage data

Checkpointed numerical stages keep two representations of each completed case under the stage checkpoint folder:

- `cases/<case>.mat` stores the complete computational result used for restart and detailed audit.
- `records/<case>.mat` stores a compact record containing the case identity, geometry, metrics, validity, solver diagnostics, and study context needed for aggregation.

When a full checkpoint exists without its compact record, the normal stage runner recreates only the missing record. Missing numerical cases are computed normally and write both files. Canonical stage datasets under `results/current/0X_*` are built from compact records, and `stage_manifest.mat` is written after those datasets are complete. A compatible completed stage returns without bulk-loading checkpoint payloads.

Publication reporting reads only canonical stage datasets. Full checkpoints remain the authoritative restart and detailed-audit data and are not duplicated into aggregate solver archives.

Sensitivity publication tables distinguish overall design validity from metric availability. A finite metric that was computed before a later feasibility failure is retained with its validity flag; an unavailable metric is exported as `NaN` and appears as a gap in the corresponding figure.

## Model conventions

- All vectors and matrices use the body frame unless stated otherwise.
- Wrenches are ordered `[F_x; F_y; F_z; tau_x; tau_y; tau_z]`.
- Allocation follows `w = A*mu`, with rotor column
  `[u_i; cross(p_i,u_i) + kappa_i*s_i*u_i]`.
- The default body z-axis points downward; normalized hover is `[0;0;-1;0;0;0]`.
- Default actuators are unidirectional with normalized bounds `[0,1]`.
- `reaction_signs` contains one `-1` or `+1` value per rotor.
- Force and moment comparisons use the characteristic length in `force_moment_length`.

The scientific assumptions, geometry bounds, robustness levels, solver budgets, seeds, and tolerances are centralized in [`inputs/study_settings.m`](inputs/study_settings.m).

## Troubleshooting

| Message or symptom | Action |
|---|---|
| `Undefined function` for a toolkit function | Run `setup_project()` from the repository root. |
| `fa:PreflightRequired` or `fa:PreflightStale` | Run `run_preflight()` again. |
| Global Optimization or Optimization Toolbox error | Install or license the required toolbox. |
| Parallel startup fails | Set `runtime.mode = 'serial'`; use `parallel` only when a pool is required. |
| A custom run conflicts with older checkpoints | Use a new case `name`, or set `overwrite = true` for that custom case. |
| A study-stage checkpoint is incompatible | Follow the error’s named-folder instruction; do not delete unrelated completed stages. |
| A different MATLAB release warning appears | The code can continue, but record the release because optimized results may differ. |

For function-specific inputs and outputs, run MATLAB help on the public function, for example:

```matlab
help analyze_configuration
help optimize_custom_design
help check_wrench_feasibility
```


## Optional Stage 06: P2-seeded unrestricted P1 (independent experiment)

After completing Stages 01 and 02, run:

```matlab
setup_project();
run_p2_seeded_p1();
```

Stage 06 performs 90 independent unrestricted P1 optimizations: three objectives
(`r_F0`, `sigma_min`, `condition_number`), six normalization cases, and five
repeats. Hover effort is excluded because P2 already attains the nominal lower
bound of 1/6. It uses the **same GA and pattern-search budgets, random seeds,
and existing deterministic population starts as Stage 01**, replacing only
one deterministic initial population row with the corresponding optimized
P2 geometry. Seed conversion is verified to preserve physical geometry and
objective values before optimization begins. The initial P2 candidate is
retained during feasible-candidate selection.

Results are independent of the five-stage pipeline and are saved under
`results/current/06_p2_seeded_p1/` and
`results/current/checkpoints/06_p2_seeded_p1/`. The comparison table
`seeded_vs_baselines.csv` compares Stage 01, Stage 02, and Stage 06.
Re-running the command reuses completed checkpoints. This experiment tests
best-found seeded performance; it does **not** certify global optimality.
