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
- `04_assumption_sensitivity`: task emphasis, actuator capacity, reaction-moment ratio, directionality, characteristic length, and normalized hover load.
- `05_implementation_robustness`: perturbation summaries and trends.

## Derived values

The parameterization comparison table includes the percentage loss relative to P1 for P2 and P3. Positive values indicate lower performance.

The authority-effort table includes changes between adjacent front points and the corresponding hover-effort increase per unit force authority.

## Sensitivity outputs

The ten independent figures are `sensitivity_task_emphasis`, `sensitivity_actuator_capacity`, `sensitivity_capacity_force_authority`, `sensitivity_reaction_moment`, `sensitivity_reaction_weakest_gain`, `sensitivity_reaction_isotropy`, `sensitivity_length_weakest_gain`, `sensitivity_length_isotropy`, `sensitivity_hover_load_task_scale`, and `sensitivity_hover_load_force_authority`. Each has PDF, FIG, CSV, and MAT files.

Task emphasis uses the numerical moment-emphasis fraction `rho`. The endpoint `rho=0` is the pure-force limiting task with zero moment deviations; `rho=1` is the pure-moment limiting task with zero force deviations. The baseline task is included exactly at its resolved `rho_0`.

`Nominal geometry` means the corresponding baseline P1 optimum is evaluated without changing its geometry. `Condition-specific optimum` means the geometry is optimized under the modified condition.

The hover-load factor `chi_h` scales the complete nominal hover wrench. With fixed gravity and actuator normalization, it represents relative vehicle or payload mass. The task deviations remain fixed, so the study captures static weight loading rather than inertia, centre-of-mass offset, or acceleration-dependent task scaling.

The table `sensitivity_curve_summary` reports the sampled minima, maxima, baseline values, and largest condition-specific improvement for the ten continuous curves. `sensitivity_directionality` reports both task scale and force authority for the two actuator-bound cases. `sensitivity_all_cases` retains every evaluated case with both natural metrics and minimization-form objective values.

The task-capability figure files store both `q_star` and the plotted ordinate `minus_q`. Force-authority files store both `r_F0` and `minus_r_F0`. Weakest-gain files store both `sigma_min` and `minus_sigma_min`. Isotropy files store `condition_number`, which is also the plotted objective.
