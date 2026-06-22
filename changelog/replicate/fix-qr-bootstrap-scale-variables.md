# fix(weights): populate scale/rscales/type/mse for QR bootstrap survey_nonprob

**Date**: 2026-06-22
**Branch**: fix/qr-bootstrap-scale-variables
**Phase**: Replicate (NPS extension)

## Changes

- Fix `.quasi_randomization_bootstrap()` to set `@variables$scale`,
  `@variables$rscales`, `@variables$type`, and `@variables$mse` on the
  returned `survey_nonprob`; previously these were left NULL, causing
  `calibrate_to_survey()` to error with `surveywts_error_scale_not_found`
  when a QR-bootstrapped design was passed as `primary_design` or
  `control_design`
- Add six tests covering the new `@variables` fields: `scale = 1/draws_used`,
  `rscales = rep(1, draws_used)`, `type = "bootstrap"`, `mse = TRUE` for
  `mse = "mse"`, `mse = FALSE` for `mse = "uncentered"`, and an IPW-path
  regression check

## Files Modified

- `R/replicate-utils.R` — add four `@variables` assignments after repwt column
  assembly in `.quasi_randomization_bootstrap()`
- `tests/testthat/test-replicate-weights.R` — six new test blocks for
  `@variables$scale`, `@variables$rscales`, `@variables$type`, and
  `@variables$mse` on calibration-only and IPW QR bootstrap outputs
