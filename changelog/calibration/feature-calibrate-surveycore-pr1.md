# Changelog — calibrate-surveycore PR 1: Infrastructure helpers

**Branch:** `feature/calibrate-surveycore-infra`
**Date:** 2026-06-05
**Status:** Implemented

## Summary

Infrastructure changes enabling `@calibration` provenance and `survey_replicate`
support for the calibration family functions. This PR adds the shared helpers;
PR 2 wires them into `calibrate_greg()`, `calibrate_rake()`, and
`calibrate_poststrat()`.

## Changes

### `R/utils.R`

- **`.check_input_class()`**: Removed the `survey_replicate` branch that
  previously threw `surveywts_error_replicate_not_supported`. The remaining
  `S7::S7_inherits(data, survey_base)` check covers `survey_replicate` since it
  inherits from `survey_base`. `survey_replicate` is now a supported class for
  the four calibrate functions.

- **`.update_survey_weights()`**: Added `caldata = NULL` parameter. When
  non-`NULL`, the named list is written to `design@calibration` before returning.
  `NULL` (default) leaves `@calibration` unchanged (backward compatible).
  Updated header comment to document `survey_replicate` as a supported input
  class and the new `caldata` parameter semantics.

### `R/calibrate-utils.R`

- **`.build_calibration_provenance()` (new)**: Pure assembly function that
  builds the 12-field `@calibration` list from ingredients available after
  `.calibrate_engine()` returns. Computes `g_weights`, `discrepancy`,
  `crossproduct_inv`, and `lambda` (for "linear"/"logit"; `NULL` for
  "raking"/"poststrat"). Returns visibly so callers can assign directly:
  `caldata <- .build_calibration_provenance(...)`. No errors thrown —
  all validation is the caller's responsibility.

### `R/adjust_nonresponse.R` (deviation from write surface)

Added explicit `survey_replicate` rejection after `.check_input_class()` call.
Necessary because `.check_input_class()` no longer rejects survey_replicate,
but nonresponse adjustment does not yet support it. Error class:
`surveywts_error_replicate_not_supported`.

### `R/redistribute_weights.R` (deviation from write surface)

Same as `adjust_nonresponse.R` — added explicit `survey_replicate` rejection.

### `tests/testthat/test-02-calibrate.R`

Added "Infrastructure helpers — PR 1 tests" section with 14 new test blocks:
- Infra-1: `.check_input_class()` accepts `survey_replicate` without error
- Infra-2a: `.update_survey_weights()` with `caldata = list(...)` sets `@calibration`
- Infra-2b: `.update_survey_weights()` with `caldata = NULL` leaves `@calibration` unchanged
- Infra-3a through 3k: Direct tests for `.build_calibration_provenance()` covering
  all 12 required fields, g_weights identity, discrepancy formula, crossproduct_inv
  identity, lambda formula (linear/logit/raking/poststrat), converged, n_iterations,
  cell_factors = NULL, and visible return value.

Updated test 13 ("calibrate_greg() rejects survey_replicate input") to reflect
the new behavior where `.check_input_class()` accepts survey_replicate.

### `tests/testthat/test-03-rake.R` (deviation from write surface)

Updated test 12 to reflect that calibrate_rake() no longer rejects survey_replicate
at the class-check gate.

### `tests/testthat/test-04-poststratify.R` (deviation from write surface)

Updated test 12 to reflect that calibrate_poststrat() no longer rejects
survey_replicate at the class-check gate.

### `tests/testthat/_snaps/05-nonresponse.md`

Updated snapshot for `redistribute_weights() errors for survey_replicate input`
(message now comes from `redistribute_weights()` directly, not from
`.check_input_class()`). Added new snapshot for
`adjust_nonresponse() rejects survey_replicate input (SE-3)`.

## Deviations from stated write surface

The implementation plan listed these exact write-surface files:
- `R/utils.R`, `R/calibrate-utils.R`, `tests/testthat/test-02-calibrate.R`

The following additional files were modified to prevent test regressions:
- `R/adjust_nonresponse.R` — added explicit survey_replicate rejection
- `R/redistribute_weights.R` — added explicit survey_replicate rejection
- `tests/testthat/test-03-rake.R` — updated obsolete rejection test
- `tests/testthat/test-04-poststratify.R` — updated obsolete rejection test
- `tests/testthat/_snaps/05-nonresponse.md` — updated stale snapshots

These changes were necessary because `.check_input_class()` is a shared helper
used by functions that should NOT yet accept survey_replicate. The plan did not
account for this dependency.
