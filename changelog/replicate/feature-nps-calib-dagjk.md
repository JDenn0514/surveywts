# Changelog — feature/nps-calib-dagjk (PR 2)

**Target**: `create_group_jackknife_weights()` in `R/create_group_jackknife_weights.R`

## Summary

- Added calibration-only DAGJK path: when `survey_nonprob` weighting history
  contains a supported calibration entry but no IPW entry, replicate weights
  are produced by group deletion + scale-factor adjustment + calibration replay.
- Replaced retired `surveywts_error_dagjk_no_ipw_history` with
  `surveywts_error_dagjk_no_history` (fires when neither IPW nor calibration
  history is present).
- Fixed "i" and "v" bullets in `surveywts_error_dagjk_requires_nonprob` to
  remove "IPW" specificity; new text describes the general weighting-history
  requirement.
- Made reference-sample requirement conditional: required for IPW path and
  calibration-only Level B; not required for calibration-only Level A.
- Groups ceiling check uses `n_A` only (not `n_A + n_ref`) for Level A
  calibration-only; IPW and Level B paths use `n_A + n_ref` as before.
- Added `.dagjk_single_replicate_calib()` internal helper for the
  calibration-only per-replicate engine; delegates dispatch to
  `.dispatch_calibration_replay()` from `replicate-utils.R` (PR 1).

## Files changed

- `R/create_group_jackknife_weights.R` — routing logic, error class
  replacement, bullet fixes, conditional reference/ceiling, new
  `.dagjk_single_replicate_calib()` helper
- `tests/testthat/test-nps-group-jackknife.R` — updated existing test for
  retired error class; updated snapshot call; added calibration-only DAGJK
  test suite (error paths, Level A happy paths, dispatch coverage, Level B,
  warning/edge, regression)
- `tests/testthat/_snaps/nps-group-jackknife.md` — updated "requires_nonprob"
  "v" bullet; updated "no ipw history" → "no history" snapshot; added four
  new snapshots for calib-only error paths

## Backward compatibility

- IPW-only path (`datasets$A`) unchanged and regression-tested GREEN.
- Doubly-robust path (`datasets$B`) unchanged and regression-tested GREEN.
- Legacy `"calibration"` and `"calibrate_greg"` operation keys retained in
  routing gate filter for backward compatibility with pre-v0.4 history entries.
