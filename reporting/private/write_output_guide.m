function write_output_guide(publication)
%WRITE_OUTPUT_GUIDE Explain the study-based publication layout.
if ~isfolder(publication), mkdir(publication); end
path_out = fullfile(publication,'OUTPUT_GUIDE.md');
fid = fopen(path_out,'w');
if fid < 0, error('fa:PublicationGuide','Could not write %s.',path_out); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Study-organized output guide\n\n');
fprintf(fid,'Publication outputs are grouped by scientific study. ');
fprintf(fid,'Every figure contains one axes and is saved as PDF and editable FIG.\n\n');
fprintf(fid,'## Commands\n\n```matlab\n');
fprintf(fid,'make_objective_design_outputs\n');
fprintf(fid,'make_parameterization_outputs\n');
fprintf(fid,'make_authority_effort_outputs\n');
fprintf(fid,'make_sensitivity_outputs\n');
fprintf(fid,'make_robustness_outputs\n');
fprintf(fid,'make_all_outputs\n');
fprintf(fid,'```\n\n');
fprintf(fid,'Reporting reads completed files under `results/current` and never starts optimization.\n\n');
fprintf(fid,'## Folders\n\n');
fprintf(fid,'- `shared/tables`: conditions common to all studies.\n');
fprintf(fid,'- `01_objective_dependent_designs`: five P1 designs and force sets.\n');
fprintf(fid,'- `02_parameterization_comparison`: P1/P2/P3 comparisons.\n');
fprintf(fid,'- `03_authority_effort_tradeoff`: the authority-effort trade-off.\n');
fprintf(fid,'- `04_assumption_sensitivity`: task emphasis, actuator capacity, reaction-moment ratio, directionality, and characteristic length.\n');
fprintf(fid,'- `05_implementation_robustness`: perturbation summaries and trends.\n\n');
fprintf(fid,'## Sensitivity outputs\n\n');
fprintf(fid,'The five independent figures are `sensitivity_task_emphasis`, `sensitivity_actuator_capacity`, `sensitivity_reaction_moment`, `sensitivity_length_weakest_gain`, and `sensitivity_length_isotropy`. Each has PDF, FIG, CSV, and MAT files.\n\n');
fprintf(fid,'Task emphasis uses the numerical moment-emphasis fraction `rho`. The endpoint `rho=0` is the pure-force limiting task with zero moment deviations; `rho=1` is the pure-moment limiting task with zero force deviations. The baseline task is retained exactly at its resolved `rho_0`.\n\n');
fprintf(fid,'For task emphasis, actuator capacity, reaction moment, and directionality, `Nominal optimum` means the baseline task-oriented P1 optimum held unchanged. `Condition-specific optimum` means the optimum is recomputed under the modified physical condition.\n\n');
fprintf(fid,'The three task-capability figures report the minimization-form ordinate `-q-star`, and their feasibility boundary is `-q-star=-1`. For characteristic length, the weakest-gain figure reports `-sigma_min(Abar)` and holds the baseline weakest-gain P1 optimum, while the isotropy figure reports `C(Abar)` and holds the baseline isotropy P1 optimum. The condition-specific optimum is solved separately at every nonbaseline length. All figure CSV and MAT files store the same signed ordinates that are plotted.\n');
end
