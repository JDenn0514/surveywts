# Changelog: feature/sample-calibration

**Branch:** `feature/sample-calibration`
**Phase:** Nonresponse — PR 2
**Status:** Complete

## What Changed

### New functions

- `calibrate_to_survey(primary_design, control_design, formula, method, bounds, control)`:
  Calibrates the full-sample and replicate weights of a `survey_replicate` so that
  weighted totals of the calibration variables match those of a control `survey_replicate`.
  Each replicate is calibrated to the corresponding control replicate, propagating
  the variance of the control totals into variance estimates. Delegates to
  `svrep::calibrate_to_sample()`.

- `calibrate_to_estimate(design, formula, estimate, vcov_estimate, method, bounds, control)`:
  Calibrates a `survey_replicate` to control totals specified as a named numeric vector
  and a variance-covariance matrix. Each replicate is calibrated to a perturbed draw
  from N(estimate, vcov_estimate), propagating control-survey uncertainty into variance
  estimates. Delegates to `svrep::calibrate_to_estimate()`.

### Design decisions

- **Negative weights (linear calibration):** When `method = "linear"` produces negative
  full-sample weights, a `surveywts_warning_negative_calibrated_weights` warning is
  emitted and the negative weights are clipped to `.Machine$double.eps` to keep the
  resulting `survey_replicate` object valid (S7 validator requires strictly positive
  weights).

- **Type mapping in `.to_svyrep_design()`:** Added a type map that converts
  surveywts/svrep-style type strings (e.g., `"Random-groups jackknife"`) to
  `survey::svrepdesign()`-compatible strings (e.g., `"JK1"`). Unknown types fall back
  to `"other"`.

- **Convergence errors:** svrep emits warnings on convergence failure; the implementation
  captures these with `withCallingHandlers` and converts them to
  `surveywts_error_calibration_not_converged` errors.

- **Tolerance:** Numerical correctness tests use tolerance `1e-6` rather than `1e-8`
  because svrep's default `epsilon = 1e-7` convergence criterion achieves relative
  precision of approximately `1e-7`, not `1e-8`.

## Files Added / Changed

- `R/sample-calibration.R` (new)
- `tests/testthat/test-sample-calibration.R` (new)
- `R/utils.R` -- added type-map in `.to_svyrep_design()`
- `tests/testthat/helper-test-data.R` -- changed `>= 2L` to `>= 1L` in `test_invariants()`
  for `survey_replicate` to support single-replicate edge case
- `_pkgdown.yml` -- added Sample-Based Calibration reference section
- `.claude/rules/surveywts-conventions.md` -- added `sample-calibration` family
- `tests/testthat/_snaps/sample-calibration.md` -- snapshots for new error messages
