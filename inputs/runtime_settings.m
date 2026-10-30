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

% Console logging only: these settings do not alter optimization or hashes.
% compact: periodic case updates plus newly improved feasible incumbents.
% detailed: every case and intermediate local-refinement message.
% debug: all existing log messages, including every emitted GA update.
% The full text run log retains every emitted message in all modes.
runtime.logging.mode = 'compact';

% Compact-mode interval for Stage 03/04/05 case summaries and dispatches.
% Stage 01 always shows every completed case and its best-so-far result.
runtime.logging.case_interval = 25;

% In compact/detailed mode, show GA updates at multiples of this interval.
% The optimizer currently emits GA updates every 10 generations, and only
% in serial execution. This setting cannot create extra GA updates.
runtime.logging.ga_generation_interval = 50;
end
