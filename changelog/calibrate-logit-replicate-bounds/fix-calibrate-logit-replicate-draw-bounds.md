# fix(calibration): apply absolute logit bounds per draw in replicates

**Date**: 2026-11-18
**Branch**: fix/calibrate-logit-replicate-draw-bounds
**Issue**: JDenn0514/surveywts#144

## Changes

- `calibrate_logit(bounds_scale = "absolute")` on a replicate design now
  applies the bounds to each draw: every replicate uses the full-sample
  g-weight bounds `L / d_k` and `U / d_k`. Before, the bounds applied to
  the replicate weight itself. Units with a replicate weight at or above
  `U` got undefined logit bounds (#144), and replicates often could not
  meet the targets, so they kept their uncalibrated weights.
- In a simulation, replicate SEs were 1.7 to 2.2 times too large for
  bootstrap and BRR when the bounds bind. A replicate weight can now be as
  large as `(rep_wt / d_k) * U`. Replicate weights change when the bounds
  bind; full-sample weights do not change (#149).
- Entry moved from `NEWS.md` by
  `chore/move-logit-news-to-changelog`, because a PR records its change
  here and never edits `NEWS.md`.

## Files Modified

- `R/calibrate_logit.R` — compute the absolute bounds per replicate draw
  from the full-sample weights.
- `man/calibrate_logit.Rd` — document the per-draw bounds for replicate
  designs.
- `tests/testthat/test-calibrate-logit.R` — tests for replicate weights at
  or above `U` and for per-draw bounds.
