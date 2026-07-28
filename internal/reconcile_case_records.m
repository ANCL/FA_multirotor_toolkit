function [records,runtime,stats] = reconcile_case_records( ...
    specifications,store,runtime)
%RECONCILE_CASE_RECORDS Ensure every completed checkpoint has a compact twin.
% Existing twins are loaded directly. Missing twins are built once from their
% authoritative full checkpoints. Full checkpoint payloads never accumulate
% in the client process.
if isempty(specifications)
    records = struct([]);
    stats = struct('expected',0,'existing_records',0,'records_built',0, ...
        'elapsed_seconds',0);
    return;
end
inventory = case_store_inventory(store,specifications);
if inventory.full_count ~= inventory.expected
    error('fa:IncompleteCheckpointSet', ...
        'Record reconciliation requires completed full checkpoints (%d/%d present).', ...
        inventory.full_count,inventory.expected);
end

n = numel(specifications);
items = cell(n,1);
missing = find(~inventory.record_exists);
stats = struct('expected',n,'existing_records',inventory.record_count, ...
    'records_built',numel(missing),'elapsed_seconds',0);

study_log('line','Checkpoint records: %d/%d available | %d to build.', ...
    inventory.record_count,n,numel(missing));
timer = tic;

% Load records that already exist. They are small and this validates the
% permanent twin against the current case hash without touching full payloads.
existing = find(inventory.record_exists);
if ~isempty(existing)
    log_stride = max(250,ceil(numel(existing)/10));
    for j = 1:numel(existing)
        index = existing(j);
        items{index} = case_record_load_one(store,specifications(index));
        if numel(existing) >= 1000 && ...
                (mod(j,log_stride) == 0 || j == numel(existing))
            study_log('line','Loaded compact records: %d/%d.',j,numel(existing));
        end
    end
end

if ~isempty(missing)
    study_log('line', ...
        'Building missing compact records from %.1f MB of completed checkpoints.', ...
        inventory.missing_record_full_bytes/1024^2);
    if runtime.parallel_enabled && numel(missing) > 1
        [pool,runtime] = ensure_parallel_pool(runtime);
        concurrency = min(runtime.max_in_flight,numel(missing));
        study_log('line','Checkpoint-record build: parallel | %d workers | %d in flight.', ...
            runtime.active_workers,concurrency);
        futures = parallel.FevalFuture.empty(0,1);
        future_indices = zeros(0,1);
        next_item = 1;
        completed = 0;
        build_timer = tic;
        processed_bytes = 0;
        total_bytes = inventory.missing_record_full_bytes;
        try
            while next_item <= numel(missing) || ~isempty(futures)
                while next_item <= numel(missing) && numel(futures) < concurrency
                    index = missing(next_item);
                    futures(end+1,1) = parfeval(pool,@build_case_record_from_checkpoint,1, ...
                        store,specifications(index)); %#ok<AGROW>
                    future_indices(end+1,1) = index; %#ok<AGROW>
                    next_item = next_item+1;
                end
                [done_index,record] = fetchNext(futures);
                index = future_indices(done_index);
                futures(done_index) = [];
                future_indices(done_index) = [];
                items{index} = record;
                completed = completed+1;
                processed_bytes = processed_bytes+inventory.full_bytes(index);
                log_record_progress(completed,numel(missing),build_timer, ...
                    processed_bytes,total_bytes);
            end
        catch ME
            if ~isempty(futures)
                try, cancel(futures); catch, end
            end
            rethrow(ME);
        end
    else
        study_log('line','Checkpoint-record build: serial.');
        build_timer = tic;
        processed_bytes = 0;
        total_bytes = inventory.missing_record_full_bytes;
        for j = 1:numel(missing)
            index = missing(j);
            items{index} = build_case_record_from_checkpoint( ...
                store,specifications(index));
            processed_bytes = processed_bytes+inventory.full_bytes(index);
            log_record_progress(j,numel(missing),build_timer, ...
                processed_bytes,total_bytes);
        end
    end
end

records = reshape(horzcat(items{:}),1,[]);
stats.elapsed_seconds = toc(timer);
study_log('line','Checkpoint record store complete: %d/%d | %s.', ...
    n,n,format_seconds(stats.elapsed_seconds));
end

function log_record_progress(completed,total,timer,processed_bytes,total_bytes)
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
remaining = max(0,total-completed);
eta = remaining/max(rate,eps);
byte_rate = processed_bytes/max(elapsed,eps)/1024^2;
if total_bytes > 0
    byte_pct = 100*processed_bytes/total_bytes;
else
    byte_pct = 100;
end
study_log('line', ...
    ['Checkpoint records: %d/%d | %.1f%% cases | %.1f%% bytes | ' ...
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
