function varargout = study_log(action,varargin)
%STUDY_LOG Fixed command-window and text-file logger for the toolkit.
% Logging is informative, not computational. A temporary text-log failure
% never aborts an optimization or invalidates a scientific result. Messages
% are retained in memory and written when the network file becomes available.

persistent log_path current_stage current_case pending_lines log_unavailable
if isempty(log_path), log_path = ''; end
if isempty(current_stage), current_stage = ''; end
if isempty(current_case), current_case = ''; end
if isempty(pending_lines), pending_lines = {}; end
if isempty(log_unavailable), log_unavailable = false; end

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
        emit('');
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
        emit(varargin{:});

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
        emit('');
        emit('[%d/%d] %s',index,total,description);


    case 'case_dispatched'
        index = varargin{1};
        total = varargin{2};
        description = char(string(varargin{3}));
        emit('[%d/%d] Started | %s',index,total,description);

    case 'optimization_complete'
        state = varargin{1};
        result = varargin{2};
        seconds = varargin{3};
        state.completed = state.completed+1;
        if result.valid
            state.valid = state.valid+1;
            status = 'feasible';
        else
            state.invalid = state.invalid+1;
            status = 'infeasible';
        end
        value = reported_value(result);
        eta = estimate_eta(state,seconds);
        if isfinite(value)
            emit('Completed %d/%d | %s = %.8g | %s | %s | ETA %s', ...
                state.completed,state.total,result.objective_name,value,status, ...
                format_duration(seconds),eta);
        else
            emit('Completed %d/%d | %s | %s | ETA %s', ...
                state.completed,state.total,status,format_duration(seconds),eta);
        end
        if ~result.valid && ~isempty(result.failure_reason)
            emit('Reason: %s',result.failure_reason);
        end
        varargout{1} = state;


    case 'optimization_complete_case'
        state = varargin{1};
        result = varargin{2};
        seconds = varargin{3};
        description = char(string(varargin{4}));
        state.completed = state.completed+1;
        if result.valid
            state.valid = state.valid+1;
            status = 'feasible';
        else
            state.invalid = state.invalid+1;
            status = 'infeasible';
        end
        value = reported_value(result);
        eta = estimate_eta(state,seconds);
        if isfinite(value)
            emit('Completed %d/%d | %s | %s = %.8g | %s | %s | ETA %s', ...
                state.completed,state.total,description,result.objective_name,value, ...
                status,format_duration(seconds),eta);
        else
            emit('Completed %d/%d | %s | %s | %s | ETA %s', ...
                state.completed,state.total,description,status, ...
                format_duration(seconds),eta);
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
        if isempty(detail)
            emit('Completed %d/%d | %s | %s | ETA %s', ...
                state.completed,state.total,status,format_duration(seconds),eta);
        else
            emit('Completed %d/%d | %s | %s | %s | ETA %s', ...
                state.completed,state.total,status,detail,format_duration(seconds),eta);
        end
        varargout{1} = state;

    case 'optimizer'
        name = char(string(varargin{1}));
        iteration = varargin{2};
        maximum = varargin{3};
        best = varargin{4};
        seconds = varargin{5};
        if isfinite(best)
            emit('  %s %d/%d | best %.8g | %s', ...
                name,iteration,maximum,best,format_duration(seconds));
        else
            emit('  %s %d/%d | %s',name,iteration,maximum,format_duration(seconds));
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
        if isempty(varargin)
            text = '';
        elseif numel(varargin) == 1
            text = char(string(varargin{1}));
        else
            text = sprintf(varargin{1},varargin{2:end});
        end

        % Command-window progress must never depend on the text log.
        fprintf(1,'%s\n',text);

        if ~isempty(log_path)
            pending_lines{end+1,1} = text; %#ok<AGROW>
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
