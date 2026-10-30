function varargout = study_log(action,varargin)
%STUDY_LOG Configurable console summaries with full text-file history.
% Runtime-only logging preferences are read from runtime_settings.m.
% Logging is informative, not computational. A temporary text-log failure
% never aborts an optimization or invalidates a scientific result. Messages
% are retained in memory and written when the network file becomes available.

persistent log_path current_stage current_case pending_lines log_unavailable
persistent logging best_keys best_costs best_values
if isempty(log_path), log_path = ''; end
if isempty(current_stage), current_stage = ''; end
if isempty(current_case), current_case = ''; end
if isempty(pending_lines), pending_lines = {}; end
if isempty(log_unavailable), log_unavailable = false; end
if isempty(logging), logging = default_logging(); end
if isempty(best_keys), best_keys = {}; end
if isempty(best_costs), best_costs = zeros(0,1); end
if isempty(best_values), best_values = zeros(0,1); end

action = lower(char(string(action)));
switch action
    case 'is_open'
        varargout{1} = ~isempty(log_path);

    case 'open'
        path_out = char(string(varargin{1}));
        ensure_folder(fileparts(path_out));
        log_path = path_out;
        pending_lines = {};
        log_unavailable = false;
        logging = read_logging_settings();
        best_keys = {};
        best_costs = zeros(0,1);
        best_values = zeros(0,1);
        emit('');
        emit('Console logging: %s | compact interval: %d cases | GA interval: %d generations', ...
            logging.mode,logging.case_interval,logging.ga_generation_interval);
        emit('Run opened: %s',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        emit('Log: %s',path_out);

    case 'close'
        if ~isempty(log_path)
            emit('Run closed: %s',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
            flush_pending_lines();
            if ~isempty(pending_lines)
                fprintf(2,['WARNING: %d run-log line(s) could not be written to:\n' ...
                    '  %s\nThe numerical results and checkpoints are unaffected.\n'], ...
                    numel(pending_lines),log_path);
            end
        end
        log_path = '';
        current_stage = '';
        current_case = '';
        pending_lines = {};
        log_unavailable = false;

    case 'line'
        % Every line is preserved in the file. Compact console output
        % suppresses repetitive per-case GA/local-refinement chatter.
        if numel(varargin) == 1
            message = char(string(varargin{1}));
        else
            message = sprintf(varargin{1},varargin{2:end});
        end
        chatter = startsWith(strtrim(message),'Starting global optimization') || ...
            startsWith(strtrim(message),'Starting local refinement') || ...
            startsWith(strtrim(message),'Local refinement ');
        emit_controlled(~chatter || verbose_console(),'%s',message);

    case 'stage_start'
        stage = char(string(varargin{1}));
        title_text = char(string(varargin{2}));
        total = varargin{3};
        resumed = varargin{4};
        current_stage = stage;
        current_case = '';
        state = struct('stage',stage,'title',title_text,'total',total, ...
            'completed',resumed,'resumed',resumed,'valid',0,'invalid',0, ...
            'concurrency',1,'timer',tic);
        emit('============================================================');
        emit('%s - %s',upper(stage),upper(title_text));
        emit('Cases: %d total | %d completed | %d remaining', ...
            total,resumed,max(0,total-resumed));
        emit('============================================================');
        varargout{1} = state;

    case 'case_start'
        index = varargin{1};
        total = varargin{2};
        description = char(string(varargin{3}));
        current_case = description;
        show = verbose_console() || is_preflight() || ...
            (is_stage_01() && milestone(index,total,5)) || ...
            milestone(index,total,logging.case_interval);
        emit_controlled(show,'');
        emit_controlled(show,'[%d/%d] %s',index,total,description);

    case 'case_dispatched'
        index = varargin{1};
        total = varargin{2};
        description = char(string(varargin{3}));
        show = verbose_console() || ...
            milestone(index,total,logging.case_interval);
        emit_controlled(show,'[%d/%d] Started | %s',index,total,description);

    case {'optimization_complete','optimization_complete_case'}
        state = varargin{1};
        result = varargin{2};
        seconds = varargin{3};
        if strcmp(action,'optimization_complete_case')
            description = char(string(varargin{4}));
        else
            description = current_case;
        end
        state.completed = state.completed+1;
        if result.valid
            state.valid = state.valid+1;
            status = 'feasible';
        else
            state.invalid = state.invalid+1;
            status = 'infeasible';
        end
        value = reported_value(result);
        [best_value,improved] = update_best(result,value);
        eta = estimate_eta(state,seconds);
        show = verbose_console() || is_stage_01() || is_preflight() || improved || ...
            milestone(state.completed,state.total,logging.case_interval) || ~result.valid;
        if isfinite(value)
            emit_controlled(show, ...
                'Completed %d/%d | %s | %s = %.8g | %s | %s | ETA %s', ...
                state.completed,state.total,description,result.objective_name, ...
                value,status,format_duration(seconds),eta);
        else
            emit_controlled(show, ...
                'Completed %d/%d | %s | %s | %s | ETA %s', ...
                state.completed,state.total,description,status, ...
                format_duration(seconds),eta);
        end
        if isfinite(best_value) && (show || improved)
            if improved
                emit_controlled(true,'  NEW BEST feasible %s = %.8g (this session, comparable group)', ...
                    result.objective_name,best_value);
            elseif is_stage_01()
                emit_controlled(true,'  Best feasible %s this session = %.8g', ...
                    result.objective_name,best_value);
            end
        end
        if ~result.valid && ~isempty(result.failure_reason)
            emit('Reason: %s',result.failure_reason);
        end
        varargout{1} = state;

    case 'case_complete'
        state = varargin{1};
        is_valid = logical(varargin{2});
        detail = char(string(varargin{3}));
        seconds = varargin{4};
        state.completed = state.completed+1;
        if is_valid
            state.valid = state.valid+1;
            status = 'completed';
        else
            state.invalid = state.invalid+1;
            status = 'scientifically infeasible/invalid';
        end
        eta = estimate_eta(state,seconds);
        show = verbose_console() || is_preflight() || ...
            milestone(state.completed,state.total,logging.case_interval) || ~is_valid;
        if isempty(detail)
            emit_controlled(show,'Completed %d/%d | %s | %s | ETA %s', ...
                state.completed,state.total,status,format_duration(seconds),eta);
        else
            % In serial robustness runs, show the associated batch name as
            % well as the numeric trial count in the periodic console line.
            if show && strcmpi(current_stage,'Stage 05') && ...
                    ~contains(detail,' | ') && ~isempty(current_case)
                detail = [current_case ' | ' detail];
            end
            emit_controlled(show,'Completed %d/%d | %s | %s | %s | ETA %s', ...
                state.completed,state.total,status,detail,format_duration(seconds),eta);
        end
        varargout{1} = state;

    case 'optimizer'
        name = char(string(varargin{1}));
        iteration = varargin{2};
        maximum = varargin{3};
        best = varargin{4};
        seconds = varargin{5};
        show = strcmp(logging.mode,'debug') || iteration == maximum || ...
            (mod(iteration,logging.ga_generation_interval) == 0);
        if isfinite(best)
            emit_controlled(show,'  %s %d/%d | best %.8g | %s', ...
                name,iteration,maximum,best,format_duration(seconds));
        else
            emit_controlled(show,'  %s %d/%d | %s', ...
                name,iteration,maximum,format_duration(seconds));
        end

    case 'stage_finish'
        state = varargin{1};
        emit('');
        emit('============================================================');
        emit('%s COMPLETED',upper(state.stage));
        emit('Completed: %d/%d | resumed: %d | new valid: %d | new invalid: %d', ...
            state.completed,state.total,state.resumed,state.valid,state.invalid);
        emit('Runtime: %s',format_duration(toc(state.timer)));
        emit('============================================================');
        current_case = '';

    case 'error'
        ME = varargin{1};
        emit('');
        emit('============================================================');
        emit('RUN STOPPED - SOFTWARE ERROR');
        if ~isempty(current_stage), emit('Stage: %s',current_stage); end
        if ~isempty(current_case), emit('Case: %s',current_case); end
        emit('Error: %s',ME.message);
        if ~isempty(ME.identifier), emit('Identifier: %s',ME.identifier); end
        emit('Completed cases were preserved. The failed case was not marked complete.');
        emit('============================================================');

    otherwise
        error('fa:UnknownLogAction','Unknown study_log action: %s',action);
end

    function emit(varargin)
        emit_controlled(true,varargin{:});
    end

    function emit_controlled(show_console,varargin)
        if isempty(varargin)
            line = '';
        elseif numel(varargin) == 1
            line = char(string(varargin{1}));
        else
            line = sprintf(varargin{1},varargin{2:end});
        end

        % Filtering is for the command window only. Never discard audit logs.
        if show_console
            fprintf(1,'%s\n',line);
        end

        if ~isempty(log_path)
            pending_lines{end+1,1} = line; %#ok<AGROW>
            flush_pending_lines();
        end
    end

    function flush_pending_lines()
        if isempty(log_path) || isempty(pending_lines)
            return;
        end

        delays = [0,0.05,0.20];
        written = false;
        for attempt = 1:numel(delays)
            if delays(attempt) > 0
                pause(delays(attempt));
            end

            file_id = -1;
            try
                file_id = fopen(log_path,'a');
                if file_id >= 0
                    write_ok = true;
                    for line_index = 1:numel(pending_lines)
                        if fprintf(file_id,'%s\n',pending_lines{line_index}) < 0
                            write_ok = false;
                            break;
                        end
                    end
                    close_ok = fclose(file_id) == 0;
                    file_id = -1;
                    written = write_ok && close_ok;
                end
            catch
                if file_id >= 0
                    try
                        fclose(file_id);
                    catch
                    end
                end
                written = false;
            end

            if written
                break;
            end
        end

        if written
            pending_lines = {};
            if log_unavailable
                fprintf(1,'Run-log writing recovered.\n');
                log_unavailable = false;
            end
        elseif ~log_unavailable
            fprintf(2,['WARNING: The run log is temporarily unavailable:\n' ...
                '  %s\nComputation will continue; completed cases are still checkpointed.\n'], ...
                log_path);
            log_unavailable = true;
        end
    end

    function yes = verbose_console()
        yes = ~strcmp(logging.mode,'compact');
    end

    function yes = is_stage_01()
        yes = startsWith(current_stage,'Stage 01');
    end

    function yes = is_preflight()
        yes = strcmpi(current_stage,'Preflight');
    end

    function [value,improved] = update_best(result,reported)
        % Compare only feasible completed candidates under identical
        % objectives and constraints; never compare different Pareto
        % thresholds or different sensitivity conditions.
        value = NaN;
        improved = false;
        if ~result.valid || ~isfinite(reported) || ...
                ~isfield(result,'objective_value') || ...
                ~isfinite(result.objective_value)
            return;
        end
        family = char(string(result.parameterization));
        objective = char(string(result.objective_name));
        group = '';
        if strcmpi(current_stage,'Stage 03') && ...
                isfield(result,'context') && ...
                isfield(result.context,'authority_threshold')
            group = sprintf('threshold:%.16g',result.context.authority_threshold);
        elseif strcmpi(current_stage,'Stage 04') && ...
                isfield(result,'context') && ...
                isfield(result.context,'sensitivity_case')
            group = char(string(result.context.sensitivity_case));
        elseif ~is_stage_01()
            return;
        end
        key = sprintf('%s|%s|%s|%s',current_stage,family,objective,group);
        position = find(strcmp(best_keys,key),1);
        if isempty(position)
            best_keys{end+1} = key;
            best_costs(end+1,1) = result.objective_value;
            best_values(end+1,1) = reported;
            value = reported;
            improved = true;
        elseif result.objective_value < best_costs(position) - ...
                1e-12*max(1,abs(best_costs(position)))
            best_costs(position) = result.objective_value;
            best_values(position) = reported;
            value = reported;
            improved = true;
        else
            value = best_values(position);
        end
    end
end


function config = default_logging()
config = struct('mode','compact','case_interval',25, ...
    'ga_generation_interval',50);
end

function config = read_logging_settings()
config = default_logging();
try
    runtime = runtime_settings();
    if ~isfield(runtime,'logging') || ~isstruct(runtime.logging)
        return;
    end
    proposed = runtime.logging;
    if isfield(proposed,'mode') && isscalar(string(proposed.mode)) && ...
            ismember(lower(string(proposed.mode)),["compact","detailed","debug"])
        config.mode = char(lower(string(proposed.mode)));
    end
    if isfield(proposed,'case_interval') && ...
            valid_interval(proposed.case_interval)
        config.case_interval = proposed.case_interval;
    end
    if isfield(proposed,'ga_generation_interval') && ...
            valid_interval(proposed.ga_generation_interval)
        config.ga_generation_interval = proposed.ga_generation_interval;
    end
catch ME
    fprintf(2,'WARNING: logging settings unavailable (%s); using defaults.\n',ME.message);
end
end

function yes = valid_interval(value)
yes = isnumeric(value) && isscalar(value) && isfinite(value) && ...
    value >= 1 && value == fix(value);
end

function yes = milestone(count,total,interval)
yes = count == 1 || count == total || mod(count,interval) == 0;
end

function value = reported_value(result)
if isfield(result,'reported_objective_value') && ...
        isfinite(result.reported_objective_value)
    value = result.reported_objective_value;
elseif isfield(result,'metrics') && isstruct(result.metrics) && ...
        isfield(result,'objective_name') && ...
        isfield(result.metrics,char(string(result.objective_name)))
    value = result.metrics.(char(string(result.objective_name)));
else
    value = NaN;
end
end


function text = estimate_eta(state,last_case_seconds)
remaining = max(0,state.total-state.completed);
if remaining == 0
    text = '0.0 s';
    return;
end
concurrency = 1;
if isfield(state,'concurrency') && isfinite(state.concurrency)
    concurrency = max(1,state.concurrency);
end
elapsed = toc(state.timer);
new_completed = max(1,state.completed-state.resumed);
mean_seconds = elapsed/new_completed;
if isfinite(last_case_seconds) && last_case_seconds > 0
    mean_seconds = 0.7*mean_seconds+0.3*last_case_seconds;
end
text = format_duration(mean_seconds*remaining/concurrency);
end

function text = format_duration(seconds)
if ~isfinite(seconds) || seconds < 0
    text = '--';
elseif seconds < 60
    text = sprintf('%.1f s',seconds);
elseif seconds < 3600
    text = sprintf('%.1f min',seconds/60);
else
    text = sprintf('%.2f h',seconds/3600);
end
end
