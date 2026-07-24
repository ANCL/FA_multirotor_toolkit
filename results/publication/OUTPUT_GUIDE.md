# Study-organized output guide

Publication outputs are grouped by scientific study. Every figure contains one axes and is saved as PDF and editable FIG.

## Commands

```matlab
make_objective_design_outputs
make_parameterization_outputs
make_authority_effort_outputs
make_sensitivity_outputs
make_robustness_outputs
make_all_outputs
```

Reporting reads completed files under `results/current` and never starts optimization.

## Folders

- `shared/tables`: conditions common to all studies.
- `01_objective_dependent_designs`: five P1 designs and force sets.
- `02_parameterization_comparison`: P1/P2/P3 comparisons.
- `03_authority_effort_tradeoff`: the authority-effort trade-off.
- `04_assumption_sensitivity`: task emphasis, actuator capacity, reaction-moment ratio, directionality, and characteristic length.
- `05_implementation_robustness`: perturbation summaries and trends.

## Derived values

The parameterization comparison table includes the percentage loss relative to P1 for P2 and P3. Positive values indicate lower performance.

The authority-effort table includes changes between adjacent front points and the corresponding hover-effort increase per unit force authority.

## Sensitivity outputs

The five independent figures are `sensitivity_task_emphasis`, `sensitivity_actuator_capacity`, `sensitivity_reaction_moment`, `sensitivity_length_weakest_gain`, and `sensitivity_length_isotropy`. Each has PDF, FIG, CSV, and MAT files.

Task emphasis uses the numerical moment-emphasis fraction `rho`. The endpoint `rho=0` is the pure-force limiting task with zero moment deviations; `rho=1` is the pure-moment limiting task with zero force deviations. The baseline task is included exactly at its resolved `rho_0`.

`Nominal geometry` means the corresponding baseline P1 optimum is evaluated without changing its geometry. `Condition-specific optimum` means the geometry is optimized under the modified condition.

The table `sensitivity_curve_summary` reports the sampled minima, maxima, baseline values, and largest condition-specific improvement for the five continuous curves. `sensitivity_all_cases` retains every evaluated case with both natural metrics and minimization-form objective values.

The task-capability figure files store both `q_star` and the plotted ordinate `minus_q`. The weakest-gain files store both `sigma_min` and `minus_sigma_min`. The isotropy files store `condition_number`, which is also the plotted objective.
