---
pr: test/coverage-gaps
type: test
scope: utils
---

## test: fill coverage gaps across replicate, jackknife, print, and utility functions

**Date**: 2026-06-28
**Branch**: test/coverage-gaps

## Changes

- Remove unreachable `.to_svyrep_design()` from `utils.R` (zero callers;
  was dead code from a calibrate_to_survey() path that was later rewritten)
- Mark unreachable branches with `# nocov` in `utils.R`, `replicate-utils.R`,
  `calibrate_to_survey.R`, `rescale_weights.R`, and `trim_weights.R`
- Fix broken inline `# nocov` in `.get_history()` — covr requires block-form
  markers; refactored to remove the unreachable `NULL` branch
- Add calibration-only DAGJK tests (Level A and Level B) covering
  `.dagjk_single_replicate_calib()` which was at 0% coverage
- Add DAGJK variant path tests: `missing_method = "separate"`, strata
  variable, `trim = TRUE`, and `calibrate_linear()` as post-IPW calibration
- Add QR bootstrap tests replaying `calibrate_linear()` and `calibrate_logit()`
  to cover `.dispatch_calibration_replay()` linear/logit branches
- Add error test for `.dispatch_calibration_replay()` with unknown calibration
  operation
- Add tests for `.validate_weights()` error paths: column not found, column
  not numeric, column has NAs; exercised via `rescale_weights()`
- Add tests for empty-data-frame errors in `trim_weights()` and
  `rescale_weights()`
- Add print snapshot tests for `survey_nonprob` with no history, with strata,
  with IDs, and with `calibrate_linear()`/`calibrate_logit()`/`poststratify()`
  history entries
- Add print snapshot test for `survey_replicate` with no history
- Mark `.svrep_calibrate_to_sample()` with `# nocov` (test hook / mockable
  binding; not called in production code)

## Files Modified

- `R/utils.R` — remove `.to_svyrep_design()`; fix `.get_history()` nocov;
  add nocov to unreachable `.get_weight_col_name()` fallback
- `R/calibrate_to_survey.R` — add `# nocov` around `.svrep_calibrate_to_sample()`
- `R/create_jackknife_weights.R` — add nocov markers to unreachable branches
- `R/jackknife-dagjk-utils.R` — add nocov markers to unreachable branches
- `R/replicate-utils.R` — add nocov to non-positive weight guard and
  `.extract_weight_vec()` weighted_df/plain-df branches
- `R/rescale_weights.R` — add nocov to unreachable branch
- `R/trim_weights.R` — add nocov to unreachable branch
- `tests/testthat/test-nps-jackknife.R` — DAGJK calibration-only and
  variant-path tests (Phases 1 and 2)
- `tests/testthat/test-08-nps-bootstrap.R` — QR bootstrap linear/logit replay
  tests and `.dispatch_calibration_replay()` error test (Phase 3)
- `tests/testthat/test-weight-utils.R` — `.validate_weights()` error paths,
  empty-data-frame errors (Phases 4 and 5)
- `tests/testthat/test-replicate-print.R` — print snapshot tests for
  zero-history, strata, IDs, and calibration method history (Phases 4 and 6)
- `tests/testthat/_snaps/replicate-print.md` — new snapshots for print tests
- `tests/testthat/_snaps/weight-utils.md` — new snapshots for error path tests
