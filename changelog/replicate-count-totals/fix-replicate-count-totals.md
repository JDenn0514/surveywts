# fix(calibration): scale count replicate totals consistently

**Date**: 2026-11-18
**Branch**: fix/replicate-count-totals
**Issue**: JDenn0514/surveywts#148

## Changes

- `calibrate_linear()` and `calibrate_logit()` with `type = "count"` on a
  `survey_replicate` now give each replicate the population counts scaled
  by `sum(replicate weights) / sum(base weights)`, with the same level mix
  as the targets. Before, when the base weights did not sum to N, the
  replicate intercept was `sum(replicate weights)` and the first level of
  each variable took the difference, so replicate standard errors were
  wrong.
- `poststratify()` with `type = "count"` now uses the same scaling for its
  replicates. Before, it used the unscaled counts, so its replicate
  standard errors change.

## Files Modified

- `R/calibrate_linear.R` — the replicate intercept is the sum of the scaled
  level totals.
- `R/calibrate_logit.R` — the same change as `calibrate_linear()`.
- `R/poststratify.R` — replicate count targets are scaled by
  `sum(rep_wt) / sum(base_wt)`; the `data` parameter doc states the rule.
- `man/poststratify.Rd` — regenerated from the roxygen change.
- `tests/testthat/test-replicate-count-totals.R` — new tests: with
  `sum(base weights) != N`, every replicate's level totals equal the
  scaled targets for linear, logit, rake (`nr`), and poststratify.
