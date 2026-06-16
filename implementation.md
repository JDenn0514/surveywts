# Implementation — nps-calibration-path PR 1

**Branch**: `feature/nps-calib-bootstrap`
**Spec**: `plans/spec-nps-calibration-path.md`
**Date**: 2026-06-15

## Write Surface

Files modified:
- `R/replicate-utils.R` — routing logic rewrite, `.dispatch_calibration_replay()` helper, `.extract_weight_vec()` helper, calibration-only bootstrap branch, warning text fix
- `R/create_bootstrap_weights.R` — `"i"` bullet text fix in `surveywts_error_qr_bootstrap_requires_nonprob`
- `tests/testthat/test-replicate-weights.R` — 23 new test blocks for calibration-only QR bootstrap (21 from builder + 2 added post-BLOCK)
- `tests/testthat/test-08-nps-bootstrap.R` — E4 test class updated from `surveywts_error_qr_bootstrap_no_ipw_history` to `surveywts_error_qr_bootstrap_no_history`; fixture renamed `np_no_ipw` → `np_no_history` (necessary maintenance caused by spec-mandated class retirement)
- `tests/testthat/_snaps/08-nps-bootstrap.md` — updated snapshots for E4 and `surveywts_error_qr_bootstrap_requires_nonprob`
- `tests/testthat/_snaps/replicate-weights.md` — new snapshots for calibration-only error paths
- `plans/error-messages.md` — new classes added, retired class marked
- `changelog/replicate/feature-nps-calib-bootstrap.md` — changelog entry

Files NOT modified (NAMESPACE unchanged, no new exports):
- `NAMESPACE`
- `man/*.Rd`

## Summary

- Added calibration-only routing to `.quasi_randomization_bootstrap()`: three-path routing (doubly-robust, IPW-only, calibration-only) with `surveywts_error_qr_bootstrap_no_history` replacing the retired `surveywts_error_qr_bootstrap_no_ipw_history`
- Added `.dispatch_calibration_replay()` internal helper in `replicate-utils.R`: owns the full dispatch table for calibrate_rake, calibrate_linear, calibrate_logit, and poststratify; shared by QR bootstrap and reused by DAGJK in PR 2
- Added `.extract_weight_vec()` internal helper: handles weight extraction from survey_nonprob, weighted_df, or plain data.frame results
- Calibration-only bootstrap (Level A): SRSWR resample → set equal initial weights (1 per row, NOT carrying forward calibrated weights) → calibration replay with stored fixed targets
- Calibration-only bootstrap (Level B): as Level A but additionally SRSWR-resamples reference rows and re-estimates targets from resampled reference via `.reestimate_margins_from_reference()`

## Task Checklist

- [x] 1. Snapshot cleanup in `_snaps/08-nps-bootstrap.md` for retired class
- [x] 2. Failing tests — error paths (no history, bad reference_sample class, no reference for Level B, requires_nonprob message)
- [x] 3. Failing tests — Level A happy paths
- [x] 4. Failing tests — dispatch coverage (calibrate_linear, calibrate_logit, poststratify)
- [x] 5. Failing tests — Level B, warning paths, all-draws-fail edge case
- [x] 6. Regression tests — IPW-only, doubly-robust Level A, doubly-robust Level B
- [x] 7. Fix `"i"` bullet in `create_bootstrap_weights.R` (remove "with IPW history")
- [x] 8. Implement routing logic in `.quasi_randomization_bootstrap()`
- [x] 9. Implement `.dispatch_calibration_replay()` + calibration-only bootstrap branch
- [x] 10. Fix `surveywts_warning_bootstrap_draws_failed` `"i"` bullet text
- [x] 11. `devtools::document()` run (NAMESPACE unchanged); `devtools::check()` 0 errors, 0 warnings, 0 notes
- [x] 12. Add weight conservation test (post-BLOCK fix: uses `nps_calib_a@variables$weights` dynamically)
- [x] 13. Add `replicates = 2L` minimum edge case test (post-BLOCK fix)

## HOLDs

None.

## Notes for Tester

- `calibrate_linear` and `calibrate_logit` store `bounds_scale = NULL` in their history entry when `bounds = NULL` (they store `NULL` for `bounds_scale` in that case, since bounds_scale is irrelevant when there are no bounds). The dispatch function detects `NULL` and omits the `bounds_scale` argument so `rlang::arg_match` uses the function default — this is the correct behavior.
- The calibration-only bootstrap uses equal initial weights (1 per row), not the original calibrated weights. This is intentional: SRSWR gives equal selection probability, so equal initial weights avoid double-counting calibration.
- The `.dispatch_calibration_replay()` helper is designed to be reused by the DAGJK calibration-only path (PR 2). Its location in `replicate-utils.R` makes it accessible from `create_group_jackknife_weights.R`.
- The `"raking"` legacy operation is mapped to `calibrate_rake()` in the dispatch table for backward compatibility with objects created before the operation string was standardized.
- `poststratify` history entries store `targets` as a data.frame (not a named list like calibrate_rake). The dispatch table passes `targets` directly — this is correct.
- The weight conservation test uses `nps_calib_a@variables$weights` dynamically (not the hardcoded `"wts"` from the test-spec which was a fixture naming error). The actual weight column is `"base_weight"` since `calibrate_rake()` on `survey_nonprob` updates the existing weight column.
