# Implementation — PR 1: calibrate_greg + calibrate_rake

## Summary

- Added `calibrate_greg()` as a direct replacement for old `calibrate()`. The
  `variables` (tidy-select) + `population` (named list) arguments are unified
  into a single `targets` argument; `method` renamed to `model`. Added
  `reference_design` parameter.
- Added `calibrate_rake()` as a direct replacement for old `rake()`. The
  `margins` argument renamed to `targets`; `method` renamed to `algorithm`.
  Added `reference_design` parameter.
- Added `R/calibrate-utils.R` with `.parse_margins()` (moved from `R/rake.R`)
  and two new helpers: `.validate_reference_design()` and
  `.validate_count_marginal_consistency()`.
- Deleted `R/calibrate.R` and `R/rake.R`. Rewrote `test-02-calibrate.R` and
  `test-03-rake.R` for the new API.
- Patched 5 incidental regressions in `test-04`, `test-05`, `test-06` caused by
  the deletion of `calibrate()`.

## Write surface

**Files created:**
- `R/calibrate-utils.R`
- `R/calibrate_greg.R`
- `R/calibrate_rake.R`
- `changelog/calibration/feature-calibration-api-pr1.md`
- `.surveywts-workspace/runs/2026-06-03-calibration-api/prs/pr-1-calibrate-greg-rake/implementation.md`

**Files modified:**
- `plans/error-messages.md` — updated "Thrown by" column; renamed sections;
  added `surveywts_error_targets_variable_not_found` replacing both old classes;
  updated `surveywts_warning_control_param_ignored` and
  `surveywts_message_already_calibrated` to reference new function names
- `R/utils.R` — updated `.format_history_step()` for new operation strings and
  `.validate_calibration_variables()` to reference new function names
- `tests/testthat/test-02-calibrate.R` — full rewrite for `calibrate_greg()`
- `tests/testthat/test-03-rake.R` — full rewrite for `calibrate_rake()`
- `tests/testthat/test-04-poststratify.R` — patched 1 call to use `calibrate_greg()`
- `tests/testthat/test-05-nonresponse.R` — patched 1 call to use `calibrate_greg()`
- `tests/testthat/test-06-diagnostics.R` — patched 3 calls to use `calibrate_greg()`
- `tests/testthat/_snaps/00-classes.md` — updated for "raking (targets: ...)" label
- `tests/testthat/_snaps/replicate-print.md` — updated for current date

**Files deleted:**
- `R/calibrate.R`
- `R/rake.R`
- `tests/testthat/_snaps/02-calibrate.md`
- `tests/testthat/_snaps/03-rake.md`

## Task checklist

- [x] Update `plans/error-messages.md`
- [x] Write tests for `calibrate_greg()` (test-02-calibrate.R rewrite)
- [x] Write tests for `calibrate_rake()` (test-03-rake.R rewrite)
- [x] Create `R/calibrate-utils.R` with `.parse_margins()` + new helpers
- [x] Create `R/calibrate_greg.R`
- [x] Create `R/calibrate_rake.R`
- [x] Delete old `R/calibrate.R` and `R/rake.R`
- [x] Run `devtools::document()`
- [x] Run tests (0 failures)
- [x] Run `devtools::check()` (0 errors, 0 warnings, 2 pre-approved notes)
- [x] Create changelog entry

## R CMD check result

0 errors, 0 warnings, 2 notes (pre-approved):
- `.git` hidden directory
- Non-standard top-level files (`VENDORED.md`, `archive`, `changelog`)

## Test results

- test-02-calibrate.R: 135 pass, 0 fail
- test-03-rake.R: 124 pass, 0 fail
- Full suite: 1073 pass, 0 fail

## CRAN compliance

- [x] TRUE/FALSE used throughout (no T/F)
- [x] `::` used for external calls (no @importFrom except S3 registration)
- [x] No bare `print()`/`cat()` in non-print-method code
- [x] No randomness in new functions
- [x] No `par()`/`options()` modifications
- [x] No file writes
- [x] `devtools::document()` run; NAMESPACE in sync
- [x] All `cli_abort()`/`cli_warn()` have `class=`; classes in `plans/error-messages.md`

## Notes for tester

- The 5 tests in test-04/05/06 that were patched used the old `calibrate()` signature;
  they have been minimally updated to use `calibrate_greg()`. Full rewrites of
  test-04 and test-05 are out of scope for PR 1.
- The `surveywts_error_targets_variable_not_found` error class is new; the old
  `surveywts_error_population_variable_not_found` and
  `surveywts_error_margins_variable_not_found` classes no longer exist in code.
- `type = "count"` now validates cross-marginal consistency — this is a new
  behavioral check not present in old `calibrate()` or `rake()`.
- HOLDs raised: none.
