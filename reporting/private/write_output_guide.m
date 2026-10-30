function write_output_guide(publication,parameters)
%WRITE_OUTPUT_GUIDE Document the generated publication-output layout.
if nargin < 2 || isempty(parameters)
    [parameters,~] = study_settings();
end
if ~isfolder(publication), mkdir(publication); end
path_out = fullfile(publication,'OUTPUT_GUIDE.md');
fid = fopen(path_out,'w');
if fid < 0, error('fa:PublicationGuide','Could not write %s.',path_out); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'# Publication output guide\n\n');
fprintf(fid,'Outputs are grouped by scientific study. Figures are exported as PDF and editable FIG files, with matching source-data CSV and MAT files where applicable.\n\n');

fprintf(fid,'## Commands\n\n```matlab\n');
fprintf(fid,'make_objective_design_outputs\n');
fprintf(fid,'make_parameterization_outputs\n');
fprintf(fid,'make_authority_effort_outputs\n');
fprintf(fid,'make_sensitivity_outputs\n');
fprintf(fid,'make_robustness_outputs\n');
fprintf(fid,'make_all_outputs\n');
fprintf(fid,'```\n\n');
fprintf(fid,'Reporting uses completed canonical datasets under `results/current` and does not execute optimization. Numerical stages are accepted only when their completion manifests and dataset provenance are compatible with the active study settings.\n\n');

fprintf(fid,'## Folders\n\n');
fprintf(fid,'- `shared/tables`: conditions common to the comparative study.\n');
fprintf(fid,'- `01_objective_dependent_designs`: selected P1 designs and feasible-set outputs.\n');
fprintf(fid,'- `02_parameterization_comparison`: P1/P2/P3 comparison outputs (Stage 02 numerical results).\n');
fprintf(fid,'- `03_authority_effort_tradeoff`: authority-effort trade-off outputs.\n');
fprintf(fid,'- `04_assumption_sensitivity`: parameter-metric sensitivity outputs.\n');
fprintf(fid,'- `05_implementation_robustness`: perturbation summaries and trends.\n\n');

fprintf(fid,'## Parameterization geometry distances\n\n');
fprintf(fid,'Study 2 includes `configuration_geometry_distance` (one row per objective and structured family) and `configuration_rotor_differences` (matched rotor-level coordinates) as CSV, MAT, and TeX tables. P1 is aligned to P2/P3 by an optimal common yaw rotation and rotor permutations restricted to equal reaction signs. Position and thrust-axis distances use physical vectors, whereas installation-angle differences depend on coordinate conventions. No optimization is rerun.\n\n');

fprintf(fid,'## Sensitivity outputs\n\n');
fprintf(fid,'The sensitivity study exports one raw-value figure and one baseline-relative percentage figure for each configured parameter-metric combination. Raw figure names follow `sensitivity_<analysis>_<metric>`; percentage figure names append `_relative`.\n\n');
fprintf(fid,'The configured metrics are: `%s`.\n\n', ...
    char(strjoin(string(parameters.sensitivity.matrix_metrics), '`, `')));
fprintf(fid,'`Nominal geometry` evaluates the corresponding baseline P1 optimum without changing its geometry. `Condition-specific optimum` uses a re-optimized P1 design when the modified condition changes that optimization problem; otherwise the nominal optimum is reused explicitly.\n\n');
fprintf(fid,'Baseline-relative percentages use the physical metric value, not the sign-adjusted ordinate used for maximization objectives in raw plots. Re-optimization improvement is reported separately and compares the condition-specific optimum with the fixed nominal geometry under the same modified condition.\n\n');
fprintf(fid,'Scientifically invalid evaluations remain part of the matrix. Design validity and metric availability are reported separately: finite metrics computed before a later feasibility failure are retained, while metrics that were not available are represented as `NaN` and appear as plot gaps. A valid condition-specific result at the same parameter value is retained independently.\n\n');
fprintf(fid,'The complete matrix tables include raw values, validity flags, baseline-relative percentages, re-optimization improvement, and the source of each condition-specific result. Curve summaries report the number of valid points in addition to extrema computed from finite values.\n');
end
