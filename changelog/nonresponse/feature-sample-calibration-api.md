# feat(calibration): rewrite calibrate_to_survey() and calibrate_to_estimate() to v1.2 API

**Date**: 2026-06-12
**Branch**: feature/sample-calibration-api
**Phase**: Nonresponse (sample calibration)

## Changes

- Rewrote `calibrate_to_survey()` with new API:
  - `formula` argument replaced by `variables` (tidy-select bare names)
  - Method `"raking"` renamed to `"rake"` to match the rest of the surveywts API
  - `bounds` format changed from `list(lower, upper)` to `c(L, U)`
  - Added `unit_scale` argument (per-unit variance scaling passed to svrep)
  - Added `reference_design` argument (stored in history for provenance)
  - `control_col_matches` exposed via `control` list (replaces positional argument)
  - Unknown `control` keys fire `surveywts_warning_control_param_ignored`
  - Replicate count mismatch no longer raises an error (removed `surveywts_error_replicate_count_mismatch`)
  - Replicate scheme type mismatch fires `surveywts_warning_replicate_scheme_mismatch`
- Rewrote `calibrate_to_estimate()` with new API:
  - `formula` + `estimate` arguments replaced by `targets` (named list of count totals)
  - Same `method`, `bounds`, `unit_scale`, `reference_design`, `control` arguments as `calibrate_to_survey()`
  - 14-step validation order: design class, reference_design, unit_scale, control, targets structure (named list, named elements, positivity, data levels match), vcov (NA, dimensions, symmetry, positive-definiteness)
  - `col_selection` exposed via `control` list; not stored in history
- Added 16 new error/warning classes to `plans/error-messages.md`; retired `surveywts_error_replicate_count_mismatch`
- Internal wrapper functions `.svrep_calibrate_to_sample()` and `.svrep_calibrate_to_estimate()` created to allow test mocking via `with_mocked_bindings(.package = "surveywts")` despite name collision with svrep exports
- Extended `test_invariants()` with full `survey_replicate` branch
- Added `make_replicate_design()` helper to `helper-test-data.R`
- Full test suite: 132 tests in `test-sample-calibration.R` covering 9 sections (happy paths, numerical correctness, error paths, edge cases, history/metadata)

## Files Modified

- `R/calibrate_to_survey.R` — complete rewrite (signature + body)
- `R/calibrate_to_estimate.R` — complete rewrite (signature + body)
- `tests/testthat/test-sample-calibration.R` — full rewrite (132 tests)
- `tests/testthat/helper-test-data.R` — added `make_replicate_design()`; extended `test_invariants()` survey_replicate branch
- `tests/testthat/_snaps/sample-calibration.md` — new snapshots for all error messages
- `tests/testthat/_snaps/replicate-print.md` — updated date stamps (pre-existing date-dependent snapshots)
- `man/calibrate_to_survey.Rd` — regenerated documentation
- `man/calibrate_to_estimate.Rd` — regenerated documentation
- `NAMESPACE` — exports unchanged (both functions already exported)
- `plans/error-messages.md` — 16 new error/warning classes added; 1 class retired
