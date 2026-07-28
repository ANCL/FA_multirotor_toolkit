function counts = case_store_counts(store)
%CASE_STORE_COUNTS Cheap directory counts without loading checkpoint payloads.
full_listing = dir(fullfile(store.case_folder,'*.mat'));
record_listing = dir(fullfile(store.record_folder,'*.mat'));
counts = struct('full',numel(full_listing),'records',numel(record_listing));
end
