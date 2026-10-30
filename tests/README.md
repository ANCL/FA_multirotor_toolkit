# Toolkit regression tests

These tests are **development and verification tools**, not numerical study stages.
They are intentionally excluded from the normal MATLAB path.

Run from the toolkit root:

```matlab
setup_project();
run_cheap_tests();
```

The runner adds `tests/` to the path temporarily, executes architecture,
sensitivity-plan, workflow, data-contract and checkpoint-record tests, and
restores the previous MATLAB path afterwards. Temporary test data is stored
outside canonical study results.

`run_preflight()` is a separate numerical environment gate. It is **not** a
one-time migration test and must remain available for study execution.

The one-time P1 migration checker and the obsolete source-hash invalidation
tests were removed after successful Stage 01 verification. For the immutable
high-budget evidence, use the preserved external results backup and the
canonical Stage 01 MAT/checkpoint files, not legacy migration helpers.
