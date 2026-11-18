# fix(calibration): scale classic_ipf count rake weights to N

**Date**: 2026-11-18
**Branch**: fix/rake-classic-ipf-count-totals
**Phase**: Diagnostics

## Changes

- `calibrate_rake(algorithm = "classic_ipf", type = "count")` now returns
  weights that sum to the population total N. Before, the full-sample
  weights and every replicate summed to the number of rows. Each replicate
  now sums to `N * sum(rep_wt) / sum(base_wt)`, the rule that
  `algorithm = "nr"` already used. Weighted proportions and the `cap`
  ratio do not change; weighted totals do.

## Files Modified

- `R/calibrate_rake.R` — rescales the classic_ipf output to the count
  target total on the full sample and on each replicate when
  `type = "count"`.
- `tests/testthat/test-03-rake.R` — adds a test of the full-sample total,
  the margins, and the replicate totals for classic_ipf with
  `type = "count"` and `sum(base_wt) != N`.
