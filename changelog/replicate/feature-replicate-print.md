# feat(replicate): add print method for survey_replicate

**Date**: 2026-05-06
**Branch**: feature/replicate-print
**Phase**: Replicate

## Changes

- Add `R/replicate-print.R` with S7 print method for `surveycore::survey_replicate`:
  - Displays design type, observation count, replicate weight count (first...last column names), scale, replicate scales range (when length > 1), and MSE flag
  - Shows weight summary (min, median, mean, max, CV)
  - Renders full weighting history via `.format_history_step()`
  - Returns `invisible(x)`
- Add `tests/testthat/test-replicate-print.R` with four snapshot tests covering:
  - Bootstrap design (50 replicates)
  - JKn stratified delete-1 design
  - BRR design
  - Two-entry weighting history (bootstrap creation + synthetic calibration step)

## Files Modified

- `R/replicate-print.R` — new S7 print method
- `tests/testthat/test-replicate-print.R` — new snapshot tests
- `tests/testthat/_snaps/replicate-print.md` — recorded snapshots
- `plans/impl-replicate.md` — PR 8 marked complete
