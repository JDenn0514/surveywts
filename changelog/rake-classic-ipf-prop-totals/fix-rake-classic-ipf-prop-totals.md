# fix(calibration): keep the weight total for classic_ipf prop rakes

**Date**: 2026-11-18
**Branch**: fix/rake-classic-ipf-prop-totals

## Changes

- `calibrate_rake(algorithm = "classic_ipf", type = "prop")` now returns
  weights that sum to `sum(base_wt)`, the same total as `algorithm = "nr"`.
  Before, they summed to the row count n, because the anesrake engine
  returns weights with mean 1. Each replicate column now sums to
  `sum(rep_wt)`, by the replicate-total rule in
  `plans/archive/calibration-framework/`. Printed weights scale by
  `sum(base_wt) / n`.
- The calibration-only quasi-randomization bootstrap now starts each draw
  at the mean weight that the full-sample calibration started from
  (`weight_stats$before$mean` in the history entry), not at 1. For
  `type = "prop"`, each draw now sums to the main weight total. Bounds see
  the same weight scale as in the full-sample run, so a
  `calibrate_logit(bounds_scale = "absolute")` replay with bounds that
  exclude 1 no longer fails on every draw. Rake, unbounded linear, and
  poststratify replays change only by a uniform scale factor.
- The calibration-only grouped jackknife (DAGJK) already starts from the
  current weights times `a_g`. Its classic_ipf prop replicate totals now
  equal the nr totals, `a_g * sum(main_wt[kept])`.

## Files Modified

- `R/calibrate_rake.R` — applies the classic_ipf target-total rescale to
  `type = "prop"` as well as `type = "count"`, on the full sample and on
  replicates.
- `R/replicate-utils.R` — adds `.replay_start_weight()` and uses it as the
  starting weight of each calibration-only QR bootstrap draw.
- `tests/testthat/test-03-rake.R` — adds a test that classic_ipf prop
  totals match the nr path on the full sample and on replicates.
- `tests/testthat/_snaps/03-rake.md` — printed weights scale by
  `sum(base_wt) / n`.
- `tests/testthat/test-replicate-weights.R` — adds a QR bootstrap test with
  weights that average about 27 and absolute logit bounds that exclude 1.
- `tests/testthat/test-nps-jackknife.R` — adds a DAGJK test that classic_ipf
  prop replicate totals match the nr path.
