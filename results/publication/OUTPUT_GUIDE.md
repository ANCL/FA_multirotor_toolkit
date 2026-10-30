# Publication output guide

Outputs are grouped by scientific study. Figures are exported as PDF and editable FIG files, with matching source-data CSV and MAT files where applicable.

## Commands

```matlab
make_objective_design_outputs
make_parameterization_outputs
make_authority_effort_outputs
make_sensitivity_outputs
make_robustness_outputs
make_seeded_p1_outputs
make_all_outputs
```

Reporting uses completed canonical datasets under `results/current` and does not execute optimization. Numerical stages are accepted only when their completion manifests and dataset provenance are compatible with the active study settings.

## Folders

- `shared/tables`: conditions common to the comparative study.
- `01_objective_dependent_designs`: selected P1 designs and feasible-set outputs.
- `02_parameterization_comparison`: P1/P2/P3 comparison outputs (Stage 02 numerical results).
- `03_authority_effort_tradeoff`: pooled P1/P2 authority-effort trade-off, with the original completed P2 stage preserved.
- `04_assumption_sensitivity`: parameter-metric sensitivity outputs.
- `05_implementation_robustness`: perturbation summaries and trends.
- `06_p2_seeded_p1`: objective and physical configuration distances only.

## Parameterization geometry distances

Study 2 includes `configuration_geometry_distance` (one row per objective and structured family) and `configuration_rotor_differences` (matched rotor-level coordinates) as CSV, MAT, and TeX tables. P1 is aligned to P2/P3 by an optimal common yaw rotation and rotor permutations restricted to equal reaction signs. Position and thrust-axis distances use physical vectors, whereas installation-angle differences depend on coordinate conventions. No optimization is rerun.

## Stage 03 pooled Pareto outputs

The P1 Pareto optimization runs independently across 6 normalization cases and 5 repeats per threshold, with no P2 initialization. The completed P2 runs are pooled with the P1 results. The blue front is computed against all feasible runs, not only the threshold-selected solutions. The combined authority_effort_values table matches the plotted frontier; separate P1/P2 threshold tables are retained.

## Sensitivity outputs

The sensitivity study exports one raw-value figure and one baseline-relative percentage figure for each configured parameter-metric combination. Raw figure names follow `sensitivity_<analysis>_<metric>`; percentage figure names append `_relative`. Selected P2 geometries and variables are permanently archived in results/current/04_sensitivity/condition_specific_selected_designs.mat, independent of ignored checkpoints.

The configured metrics are: `r_F0`, `sigma_min`, `condition_number`, `hover_effort`.

`Nominal geometry` evaluates the corresponding baseline P2 optimum without changing its geometry. `Condition-specific optimum` uses a re-optimized P2 design when the modified condition changes that optimization problem; otherwise the nominal optimum is reused explicitly.

Baseline-relative percentages use the physical metric value, not the sign-adjusted ordinate used for maximization objectives in raw plots. Re-optimization improvement is reported separately and compares the condition-specific optimum with the fixed nominal geometry under the same modified condition.

Scientifically invalid evaluations remain part of the matrix. Design validity and metric availability are reported separately: finite metrics computed before a later feasibility failure are retained, while metrics that were not available are represented as `NaN` and appear as plot gaps. A valid condition-specific result at the same parameter value is retained independently.

The complete matrix tables include raw values, validity flags, baseline-relative percentages, re-optimization improvement, and the source of each condition-specific result. Curve summaries report the number of valid points in addition to extrema computed from finite values.
