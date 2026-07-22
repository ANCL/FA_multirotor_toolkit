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

## Sensitivity outputs

The five independent figures are `sensitivity_task_emphasis`, `sensitivity_actuator_capacity`, `sensitivity_reaction_moment`, `sensitivity_length_weakest_gain`, and `sensitivity_length_isotropy`. Each has PDF, FIG, CSV, and MAT files.

Task emphasis uses the numerical moment-emphasis fraction `rho`. The endpoint `rho=0` is the pure-force limiting task with zero moment deviations; `rho=1` is the pure-moment limiting task with zero force deviations. The baseline task is retained exactly at its resolved `rho_0`.

For task emphasis, actuator capacity, reaction moment, and directionality, `Nominal optimum` means the baseline task-oriented P1 optimum held unchanged. `Condition-specific optimum` means the optimum is recomputed under the modified physical condition.

The three task-capability figures report the minimization-form ordinate `-q-star`, and their feasibility boundary is `-q-star=-1`. For characteristic length, the weakest-gain figure reports `-sigma_min(Abar)` and holds the baseline weakest-gain P1 optimum, while the isotropy figure reports `C(Abar)` and holds the baseline isotropy P1 optimum. The condition-specific optimum is solved separately at every nonbaseline length. All figure CSV and MAT files store the same signed ordinates that are plotted.
