function paths = write_figure_source_data(source_data, folder, base_name)
%WRITE_FIGURE_SOURCE_DATA Save one figure's source data as MAT and CSV.
%
% Plotting functions may return a table directly or one of the documented
% structured source-data schemas used by the toolkit. The MAT file retains
% the complete source structure. The CSV file contains a readable tabular
% representation of the plotted numerical data.

ensure_folder(folder);
base_name = char(string(base_name));
paths.mat = fullfile(folder,[base_name '.mat']);
paths.csv = fullfile(folder,[base_name '.csv']);
save(paths.mat,'source_data');
source_table = source_data_table(source_data);
writetable(source_table,paths.csv);
end

function T = source_data_table(source_data)
if istable(source_data)
    T = source_data;
    return;
end
if isnumeric(source_data)
    T = array2table(source_data);
    return;
end
if ~isstruct(source_data) || ~isscalar(source_data)
    error('fa:UnsupportedFigureSourceData', ...
        'Figure source data must be a table, numeric array, or scalar structure.');
end

if isfield(source_data,'geometry')
    T = geometry_source_table(source_data.geometry);
elseif isfield(source_data,'sets')
    T = feasible_set_source_table(source_data);
elseif isfield(source_data,'result') && isfield(source_data,'time')
    T = trajectory_source_table(source_data.result,source_data.time);
elseif isfield(source_data,'selected_results')
    T = source_data.selected_results;
    if isfield(source_data,'metric')
        T.PlotMetric = repmat(string(source_data.metric),height(T),1);
    end
elseif isfield(source_data,'all_runs') && isfield(source_data,'pareto_front')
    all_runs = source_data.all_runs;
    front = source_data.pareto_front;
    all_runs.Series = repmat("all_feasible_runs",height(all_runs),1);
    front.Series = repmat("pareto_front",height(front),1);
    T = [all_runs;front];
else
    T = scalar_struct_table(source_data);
end
end

function T = geometry_source_table(geometry)
number_of_rotors = size(geometry.p,2);
Rotor = (1:number_of_rotors).';
P_x = geometry.p(1,:).';
P_y = geometry.p(2,:).';
P_z = geometry.p(3,:).';
U_x = geometry.u(1,:).';
U_y = geometry.u(2,:).';
U_z = geometry.u(3,:).';
T = table(Rotor,P_x,P_y,P_z,U_x,U_y,U_z);

angle_fields = {'ell','gamma','eta','alpha','beta'};
for field_index = 1:numel(angle_fields)
    field_name = angle_fields{field_index};
    if isfield(geometry,field_name) && numel(geometry.(field_name)) == number_of_rotors
        T.(field_name) = geometry.(field_name)(:);
    end
end
end

function T = feasible_set_source_table(source_data)
sets = source_data.sets;
if ~iscell(sets)
    sets = arrayfun(@(item) item,sets,'UniformOutput',false);
end
labels = strings(numel(sets),1);
if isfield(source_data,'options') && isfield(source_data.options,'labels')
    supplied_labels = string(source_data.options.labels(:));
    label_count = min(numel(supplied_labels),numel(labels));
    labels(1:label_count) = supplied_labels(1:label_count);
end
blocks = cell(numel(sets),1);
for set_index = 1:numel(sets)
    data = sets{set_index};
    vertices = data.vertices;
    if size(vertices,2) ~= 3 && size(vertices,1) == 3
        vertices = vertices.';
    end
    if isempty(vertices)
        vertices = nan(1,3);
    end
    rows = size(vertices,1);
    SetIndex = repmat(set_index,rows,1);
    SetLabel = repmat(labels(set_index),rows,1);
    VertexIndex = (1:rows).';
    X = vertices(:,1);
    Y = vertices(:,2);
    Z = vertices(:,3);
    AffineDimension = repmat(data.affine_dimension,rows,1);
    blocks{set_index} = table( ...
        SetIndex,SetLabel,VertexIndex,X,Y,Z,AffineDimension);
end
T = vertcat(blocks{:});
end


function T = trajectory_source_table(result,time)
time = time(:);
number_of_samples = numel(time);
T = table(time,'VariableNames',{'Time'});
for actuator = 1:size(result.mu,1)
    T.(['mu_' num2str(actuator)]) = result.mu(actuator,:).';
end
if isfield(result,'sample_feasible') && ...
        numel(result.sample_feasible) == number_of_samples
    T.Feasible = logical(result.sample_feasible(:));
end
if isfield(result,'sample_status') && ...
        numel(result.sample_status) == number_of_samples
    T.Status = string(result.sample_status(:));
end
if isfield(result,'saturation_margin') && ...
        numel(result.saturation_margin) == number_of_samples
    T.SaturationMargin = result.saturation_margin(:);
end
if isfield(result,'scaled_error') && ...
        numel(result.scaled_error) == number_of_samples
    T.ScaledError = result.scaled_error(:);
end
end

function T = scalar_struct_table(value)
fields = fieldnames(value);
row = struct();
for field_index = 1:numel(fields)
    field_name = fields{field_index};
    item = value.(field_name);
    if isnumeric(item) && isscalar(item)
        row.(field_name) = item;
    elseif islogical(item) && isscalar(item)
        row.(field_name) = item;
    elseif (ischar(item) || isstring(item)) && isscalar(string(item))
        row.(field_name) = string(item);
    end
end
if isempty(fieldnames(row))
    error('fa:UnsupportedFigureSourceData', ...
        'The figure source structure has no tabular scalar fields.');
end
T = struct2table(row);
end
