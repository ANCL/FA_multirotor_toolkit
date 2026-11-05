# Fully Actuated Multirotor Toolkit

MATLAB tools for analyzing and optimizing fixed-configuration, six-rotor fully actuated multirotors. This repository accompanies *Design Optimization of Fixed-Configuration Fully Actuated Multirotors* and includes the source code, numerical results, and figures used in the paper.

The toolkit can be used in two ways: to analyze an individual rotor configuration or to inspect and reproduce the paper's four numerical studies.

## Getting started

Open the repository's root folder in MATLAB and run:

```matlab
setup_project();
```

Single-configuration analysis and reporting from the supplied study results do not require running an optimizer. Repeating the optimization studies requires MATLAB's **Optimization Toolbox** (`fmincon`). The **Parallel Computing Toolbox** is optional. The alternative GA/pattern-search solver requires the **Global Optimization Toolbox**.

## Analyze a configuration

The analysis functions accept a six-rotor geometry defined by rotor positions and thrust directions. You can construct one using the supplied parameterizations or work directly with a geometry structure.

```matlab
setup_project();

% Example: planar configuration (angles in radians)
geometry = make_p3_geometry([0.5; 0.2]);

% Allocation matrix, actuation, hover, and performance measures
report = analyze_configuration(geometry);
report.metrics

% Feasible force and torque sets
sets = analyze_feasible_sets(geometry);

% Geometry and feasible-set plots
plot_multirotor_configuration(geometry);
plot_feasible_set(sets, struct('mode', 'force'));
plot_feasible_set(sets, struct('mode', 'torque'));

% Feasibility of a requested body-frame wrench
wrench = [0; 0; -1; 0; 0; 0];
allocation = analyze_wrench(geometry, wrench);
```

The four performance measures are **zero-moment force authority** (`r_F0`), **minimum singular value** (`sigma_min`), **allocation condition number** (`condition_number`), and **hover effort** (`hover_effort`). The analysis also provides full-actuation and hover-feasibility information, actuator inputs, and the allocation matrix. Wrench components are ordered `[Fx; Fy; Fz; Mx; My; Mz]` in the body frame.

Three geometry families are provided:

| Family | Geometry | Design variables |
| --- | --- | ---: |
| **P1** | Unrestricted rotor-arm and thrust-direction geometry | 28 |
| **P2** | Spatially symmetric arrangement of two rotor triads | 6 |
| **P3** | Planar arrangement with shared installation angles | 2 |

The geometry constructors are in [`core/geometry/`](core/geometry/); individual-analysis functions are in [`analyses/`](analyses/). Model assumptions and numerical tolerances are set in [`config/default_model.m`](config/default_model.m) and [`config/default_numerics.m`](config/default_numerics.m).

## Numerical studies

Saved optimization results are supplied under [`results/`](results/). The studies cover unrestricted design optimization, the multiplicity of optimal geometries, reduced geometric parameterizations, and the trade-off between force authority and hover effort.

| Study | Scope | Main output |
| --- | --- | --- |
| **01 — Optimization objectives** | Optimize four performance objectives independently using unrestricted P1 geometry. | [Objective summary](results/study_01/tables/objective_summary.csv) |
| **02 — Multiple optima** | Examine geometrically distinct configurations attaining the force-authority, singular-value, and condition-number bounds within numerical tolerance. | [Geometric analysis](results/study_02/tables/study02_manuscript_summary.csv) |
| **03 — Reduced parameterizations** | Compare the six-variable spatial P2 family with the two-variable planar P3 family. | [Performance comparison](results/study_03/tables/parameterization_comparison.csv) |
| **04 — Authority–effort trade-off** | Minimize hover effort subject to increasing force-authority requirements. | [Trade-off values](results/study_04/tables/authority_effort_key_points.csv) · [Figure](results/study_04/figures/pareto_authority_effort.pdf) |

### Regenerate tables and figures

The following commands read the saved results; **they do not rerun optimization**:

```matlab
setup_project();
summarize_study_01();
summarize_study_02();
analyze_study_02();
summarize_study_03();
plot_study_03();
summarize_study_04();
plot_study_04();
```

Study 02 includes 1,000 geometrically distinct accepted configurations for each of its three objectives. Study 04's key-point report computes hover-effort reductions relative to the maximum-authority configuration selected in Study 01, including the **55.8% reduction for a 20% compromise in force authority**. Run the summaries in the order above because this report uses the Study 01 reference table.

### Run or extend an optimization study

To start or resume a numerical search deliberately, use the corresponding runner:

```matlab
run_study_01();
run_study_02();
run_study_03();
run_study_04();
```

Solver settings, design constraints, random seeds, and study-specific tolerances are defined in [`config/`](config/). The runners may be computationally expensive; the saved `.mat` archives are sufficient for inspecting the reported results.

## Repository structure

| Directory | Contents |
| --- | --- |
| [`analyses/`](analyses/) | Single-configuration, feasible-set, and wrench analysis |
| [`core/`](core/) | Geometry, allocation, feasibility, metrics, and plotting |
| [`config/`](config/) | Physical model, numerical settings, and study configurations |
| [`solvers/`](solvers/) | Numerical optimization methods |
| [`studies/`](studies/) | Study runners, summaries, and figure generation |
| [`results/`](results/) | Saved MATLAB data, numerical tables, and figures |

## Reproducibility and interpretation

The reported attainment of analytical bounds is numerical and subject to the specified tolerances. The configurations collected in Study 02 are distinct under the implemented geometry-distance criterion; this does not establish an exhaustive characterization of all optimal geometries. Study 04 provides a sampled authority–effort frontier, not a proof of the complete Pareto set. The `.mat` files preserve the numerical archives; the reporting routines regenerate derived `.csv` tables and figures.

When citing the software, please reference *Design Optimization of Fixed-Configuration Fully Actuated Multirotors*. Publication details will be added once available.

## License

MIT - see [LICENSE](LICENSE).
