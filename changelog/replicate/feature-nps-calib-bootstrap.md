# feat(weights): add calibration-only quasi-randomization bootstrap path

**Date**: 2026-06-15
**Branch**: feature/nps-calib-bootstrap
**Phase**: Replicate (NPS calibration path)

## Changes

- Add calibration-only path to `.quasi_randomization_bootstrap()`: when a
  `survey_nonprob` has a calibration entry (`calibrate_rake`, `calibrate_linear`,
  `calibrate_logit`, `poststratify`) but no IPW entry, each bootstrap draw
  uses SRSWR resampling with equal initial weights followed by calibration
  replay (Level A: fixed targets; Level B: targets re-estimated from resampled
  reference)
- Replace IPW-only routing gate with three-path routing: doubly-robust (IPW +
  calibration), IPW-only, calibration-only; error on no supported history
- Retire `surveywts_error_qr_bootstrap_no_ipw_history` and replace with
  `surveywts_error_qr_bootstrap_no_history` (fires when no IPW entry and no
  supported calibration entry is found in history)
- Fix misleading `"i"` bullet in `surveywts_error_qr_bootstrap_requires_nonprob`:
  remove "with IPW history"
- Add `.dispatch_calibration_replay()` internal helper in `replicate-utils.R`:
  owns the calibration dispatch table (calibrate_rake/raking → calibrate_rake,
  calibrate_linear, calibrate_logit, poststratify) and is the single shared
  implementation for the QR bootstrap calibration-only path (and will be reused
  by the DAGJK path in PR 2)
- Add `.extract_weight_vec()` internal helper: extracts the weight column from
  a calibration result regardless of whether it returns `survey_nonprob` or
  `weighted_df`
- Fix `"i"` bullet of `surveywts_warning_bootstrap_draws_failed` to be
  path-agnostic: changed from "A draw fails when `ipw()` or calibration does
  not converge" to "A draw fails when calibration or IPW re-estimation does
  not converge"
- Extend test suite in `test-replicate-weights.R` with 21 new blocks covering:
  error paths (no history, bad reference_sample class, no reference for Level B),
  Level A happy paths (invariants, history entry, repwt column names, original
  columns preserved, reproducibility, reference_sample accepted but unused),
  dispatch coverage (calibrate_linear, calibrate_logit, poststratify),
  Level B happy path, warning paths (overwrite, all-draws-fail), and regression
  tests for existing IPW-only and doubly-robust paths

## Files Modified

- `R/replicate-utils.R` — routing logic rewrite, `.dispatch_calibration_replay()`
  helper, `.extract_weight_vec()` helper, calibration-only bootstrap branch,
  warning text fix
- `R/create_bootstrap_weights.R` — `"i"` bullet text fix in
  `surveywts_error_qr_bootstrap_requires_nonprob`
- `tests/testthat/test-replicate-weights.R` — 21 new test blocks
- `tests/testthat/test-08-nps-bootstrap.R` — E4 test class updated to
  `surveywts_error_qr_bootstrap_no_history`; `np_no_ipw` renamed to
  `np_no_history`
- `tests/testthat/_snaps/08-nps-bootstrap.md` — updated snapshots for E4
  (new class/message) and `surveywts_error_qr_bootstrap_requires_nonprob`
  (removed "with IPW history" from `"v"` bullet; added calibrate_rake reference)
- `plans/error-messages.md` — added new classes, marked retired class
- `NAMESPACE` — unchanged (no new exports)
