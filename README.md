# Fully Actuated Multirotor Toolkit

MATLAB implementation for modeling, analyzing, and optimizing **fixed-configuration, six-rotor fully actuated multirotors**. The toolkit supports an unrestricted geometry family (**P1**), a six-variable structured family (**P2**), and a two-variable planar subfamily (**P3**). It includes the completed numerical Studies 01–04 and their saved results.

The repository is intended to support reproducibility of the numerical investigations accompanying the associated research manuscript. Numerical attainment of an analytical bound and a sampled Pareto frontier do **not** by themselves establish global optimality or exhaustive characterization of all attaining geometries.

## Requirements

- MATLAB with **Optimization Toolbox** (`fmincon`) for the SQP study runners.
- **Parallel Computing Toolbox** is optional for parallel execution of independent cases/attempts. See each `config/study_XX_settings.m` file.
- **Global Optimization Toolbox** (`ga`, `patternsearch`) is required **only** for the optional GA implementation and `verify_stage_03.m`. The completed scientific studies use SQP.
- A MATLAB release supporting the language features used in the source (tables, local functions, `exportgraphics`, etc.). No specific release has been independently certified.

Run commands from the repository root in MATLAB:

```matlab
setup_project();
verify_stage_01();   % Geometry and allocation invariants
verify_stage_02();   % Metrics, hover, feasibility and invariance
```

`verify_stage_03()` additionally tests the optional GA + pattern-search solver; it is **not necessary** to inspect or summarize the saved SQP studies.

## Geometry and metrics

- **P1**: 28 independent design variables with positive/negative normalization groups. One reference rotor has radius 1 and position azimuth 0; the remaining geometry is unrestricted within the stated design bounds. See `core/geometry/` and `p1_bounds.m`.
- **P2**: Structured six-variable geometry (`make_p2_geometry`).
- **P3**: Reduced planar two-variable geometry (`make_p3_geometry`).
- **Metrics**: zero-moment force authority `r_F0`, minimum singular value `sigma_min`, allocation condition number `condition_number`, and hover effort `hover_effort`.
- **Physical checks**: allocation matrix, full actuation, admissible geometry, hover feasibility and force/wrench feasibility are implemented under `core/`.

For a single configuration:

```matlab
setup_project();
model = default_model();
numerics = default_numerics();
geometry = make_p3_geometry([0.5; 0.2]);
metrics = evaluate_design(geometry, model, numerics);
```

## Completed numerical studies

| Study | Scope | Saved numerical investigation |
| --- | --- | --- |
| **01** | Unrestricted P1, four objectives × two normalization groups | Eight independent multistart SQP cases, 16 starts per case |
| **02** | Unrestricted P1 attainment/discovery | 1,000 accepted, geometrically distinct near-bound configurations for **each** of `r_F0`, `sigma_min`, and `condition_number` (3,000 total) |
| **03** | Structured P2 versus P3 | Eight reported cases: four objectives × two parameterizations, 16 SQP starts per case |
| **04** | Unrestricted P1 force-authority/hover-effort trade-off only | 41 authority thresholds × two normalization groups = **82** saved cases; saved report has **80 feasible** cases |

Study 02 uses independently randomized SQP attempts and a physical distinctness threshold of `0.05`; see `config/study_02_settings.m` for acceptance and stopping criteria. Study 04's saved authority–effort plot reports **406 feasible endpoint records and 50 plotted frontier representatives**. These are records/representatives, not 406 independent globally optimal designs. Study 04's reported feasible-case counts and plotted-front counts are generated with different candidate pools and filtering rules.

All studies use the existing `config/`, `core/`, `solvers/`, and `studies/` APIs. Their current study settings select `sqp`; the generic GA/pattern-search engine remains as an optional, reusable solver, **not** as a separate Study 02 GA experiment.

## Inspect saved results without rerunning optimizations

```matlab
setup_project();

s01 = summarize_study_01();
s02 = summarize_study_02();
a02 = analyze_study_02();
s03 = summarize_study_03();
f03 = plot_study_03();
s04 = summarize_study_04();
f04 = plot_study_04();
```

The summarizers and plotters read saved results and export CSVs and figures. They can overwrite **derived** report files, but they do not relaunch optimization. `summarize_study_01()` and `summarize_study_03()` also refresh `selected_designs.mat` from saved run files. The `analyze_study_02()` function performs additional analysis of the accepted geometry archive.

To rerun or extend numerical studies **deliberately**, use:

```matlab
run_study_01();
run_study_02();
run_study_03();
run_study_04();
```

The runners are restartable and use saved results where their consistency checks permit. Rerunning them may initiate optimization if cases are missing or settings have changed; preserve `results/` and avoid changing seeds, thresholds, solver settings, or case names when seeking to reproduce the existing archive. In particular, Study 02 is a substantial randomized search and should not be restarted casually.

## Directory layout

```text
config/               Model, numerical defaults and study settings
core/geometry/        Geometry families, parameterization and equivalence
core/model/           Allocation and hover models
core/metrics/         Performance metrics
core/feasibility/     Feasible wrenches and force sets
core/optimization/    Objective, constraints and solver orchestration
core/plotting/        Multirotor configuration drawings
solvers/              SQP implementation and optional GA selection
analyses/             Single-design analysis functions
studies/              Study runners, summaries and publication plots
results/study_01/     Saved P1 optimization cases, selections and CSVs
results/study_02/     3,000 accepted P1 configurations, analysis and figures
results/study_03/     Saved P2/P3 cases and selected-geometry figures
results/study_04/     Authority–effort P1 cases, tables and Pareto figure
```

`results/` includes scientific `.mat` archives, derived `.csv` summaries, and PDF/PNG figures. The `.gitignore` **does not exclude** these results. Do not replace original MAT files with derived CSVs: the MAT archive contains the saved optimization states.

## Numerical interpretation and reproducibility

- The solver is randomized multistart SQP (`solvers/optimize_design_sqp.m`) with deterministic seed specifications in the corresponding study configurations.
- Feasibility and objective values are reevaluated by the reporting functions using `core/` utilities; different studies intentionally use different validation tolerances.
- Study 02's accepted designs are distinct under the implemented geometric equivalence/distance criterion, not necessarily members of different connected optimality families.
- Study 04's front is a **numerically sampled** force-authority/hover-effort trade-off, not a proof of a globally complete Pareto set. Its plot is generated by the standalone `studies/plot_study_04.m`, which uses local plotting helpers.
- CSV files generated before a local directory rename can contain absolute output paths; regenerate *derived* CSVs from the final repository directory if portable paths are needed. Do not edit saved MAT results for that purpose.

## Source of truth

Study settings and MATLAB source govern computational behavior. The README documents the snapshot at preparation time; if settings change in later experiments, update this table and regenerate the relevant reports. Citation, license and associated-manuscript metadata should be supplied by the repository maintainers before a public release.
