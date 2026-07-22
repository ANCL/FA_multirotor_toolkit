function runtime = runtime_settings()
%RUNTIME_SETTINGS Execution controls that do not change scientific results.
% Change these options to suit the computer. They are intentionally excluded
% from numerical-result compatibility hashes.

% 'auto' uses parallel workers when Parallel Computing Toolbox is available.
% Use 'serial' for one MATLAB process or 'parallel' to require a pool.
runtime.mode = 'auto';

% Leave empty to use the profile default. Set a positive integer to cap the
% number of workers created by this toolkit.
runtime.max_workers = [];

% Process workers isolate independent GA/patternsearch cases cleanly.
runtime.pool_profile = 'Processes';

% Leave empty to keep one case in flight per active worker.
runtime.max_in_flight = [];

% Robustness trials are checkpointed in batches. This changes only execution
% and storage granularity, not the trial definitions or random seeds.
runtime.robustness_batch_size = 50;

% Keep an existing pool alive after the study so later stages reuse it.
runtime.keep_pool_open = true;
end
