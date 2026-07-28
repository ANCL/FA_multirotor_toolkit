function [runtime,stats] = ensure_case_record_twins(specifications,store,runtime)
%ENSURE_CASE_RECORD_TWINS Build only missing compact twins for completed cases.
% This is the fast maintenance path when canonical stage products are already
% current: existing compact records are not loaded or rewritten.
if isempty(specifications)
    stats = struct('expected',0,'existing_records',0,'records_built',0, ...
        'elapsed_seconds',0);
    return;
end
inventory = case_store_inventory(store,specifications);
if inventory.full_count ~= inventory.expected
    error('fa:IncompleteCheckpointSet', ...
        'Compact twins require completed full checkpoints (%d/%d present).', ...
        inventory.full_count,inventory.expected);
end
missing = find(~inventory.record_exists);
stats = struct('expected',inventory.expected, ...
    'existing_records',inventory.record_count, ...
    'records_built',numel(missing),'elapsed_seconds',0);
study_log('line', ...
    'Checkpoint twins: %d/%d available | %d to build | %.1f MB to read.', ...
    inventory.record_count,inventory.expected,numel(missing), ...
    inventory.missing_record_full_bytes/1024^2);
if isempty(missing), return; end

timer = tic;
if runtime.parallel_enabled && numel(missing) > 1
    [pool,runtime] = ensure_parallel_pool(runtime);
    concurrency = min(runtime.max_in_flight,numel(missing));
    study_log('line','Checkpoint-twin build: parallel | %d workers | %d in flight.', ...
        runtime.active_workers,concurrency);
    futures = parallel.FevalFuture.empty(0,1);
    future_indices = zeros(0,1);
    next_item = 1;
    completed = 0;
    processed_bytes = 0;
    try
        while next_item <= numel(missing) || ~isempty(futures)
            while next_item <= numel(missing) && numel(futures) < concurrency
                index = missing(next_item);
                futures(end+1,1) = parfeval(pool,@build_case_record_from_checkpoint,1, ...
                    store,specifications(index)); %#ok<AGROW>
                future_indices(end+1,1) = index; %#ok<AGROW>
                next_item = next_item+1;
            end
            [done_index,~] = fetchNext(futures);
            index = future_indices(done_index);
            futures(done_index) = [];
            future_indices(done_index) = [];
            completed = completed+1;
            processed_bytes = processed_bytes+inventory.full_bytes(index);
            log_progress(completed,numel(missing),timer,processed_bytes, ...
                inventory.missing_record_full_bytes);
        end
    catch ME
        if ~isempty(futures)
            try, cancel(futures); catch, end
        end
        rethrow(ME);
    end
else
    study_log('line','Checkpoint-twin build: serial.');
    processed_bytes = 0;
    for j = 1:numel(missing)
        index = missing(j);
        build_case_record_from_checkpoint(store,specifications(index));
        processed_bytes = processed_bytes+inventory.full_bytes(index);
        log_progress(j,numel(missing),timer,processed_bytes, ...
            inventory.missing_record_full_bytes);
    end
end
stats.elapsed_seconds = toc(timer);
final = case_store_inventory(store,specifications);
if final.record_count ~= final.expected
    error('fa:IncompleteCaseRecordStore', ...
        'Expected %d compact checkpoint twins, but found %d.', ...
        final.expected,final.record_count);
end
study_log('line','Checkpoint twins complete: %d/%d | %s.', ...
    final.record_count,final.expected,format_seconds(stats.elapsed_seconds));
end

function log_progress(completed,total,timer,processed_bytes,total_bytes)
if total < 100
    stride = total;
elseif total < 1000
    stride = max(1,ceil(total/10));
else
    stride = max(1,ceil(total/20));
end
if completed ~= total && mod(completed,stride) ~= 0, return; end
elapsed = toc(timer);
rate = completed/max(elapsed,eps);
eta = max(0,total-completed)/max(rate,eps);
byte_rate = processed_bytes/max(elapsed,eps)/1024^2;
if total_bytes > 0
    byte_pct = 100*processed_bytes/total_bytes;
else
    byte_pct = 100;
end
study_log('line', ...
    ['Checkpoint twins: %d/%d | %.1f%% cases | %.1f%% bytes | ' ...
     '%.1f cases/s | %.1f MB/s | ETA %s'], ...
    completed,total,100*completed/total,byte_pct,rate,byte_rate,format_seconds(eta));
end

function text = format_seconds(seconds)
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
