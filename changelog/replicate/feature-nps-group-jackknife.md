# feat(replicate-weights): add DAGJK replicate weights for NPS

**Date**: 2026-06-01
**Branch**: feature/nps-group-jackknife
**Phase**: Replicate (NPS extension)

## Changes

- Add `create_group_jackknife_weights()` implementing the delete-a-group
  jackknife (DAGJK) variance estimator for non-probability samples
  (Elliott & Valliant 2017; Valliant 2020), including:
  - Random group assignment across the combined NPS + reference dataset
  - Full binary logistic model refit per replicate (no computational shortcut)
  - Reference weight adjustment (`w_ref_adj = w_ref * (N_hat - n_nps) / N_hat`)
    applied within each replicate
  - Optional calibration (raking / post-stratification) repeated per replicate
    when detected in weighting history
  - `scale = (G-1)/G`, `rscales = rep(1, G)`, `mse = TRUE`
  - Replicate failure tolerance: failed replicates are counted and skipped;
    >10% failure rate emits `surveywts_warning_dagjk_replicates_failed`
  - History entry with `operation = "group_jackknife_weights"`
- Add `"group-jackknife"` method to `create_replicate_weights()` dispatcher
- Extend `.validate_reference_sample()` with a `data.frame` branch that
  includes an `'i'` bullet directing users to `survey::svydesign()`
- Add `make_dagjk_datasets()` to `tests/testthat/helper-test-data.R`
- Add full test suite `tests/testthat/test-nps-group-jackknife.R` (34 blocks):
  structural invariants, seed reproducibility, calibration refit, dispatcher,
  error paths (E1–E14), warning paths (W1–W4), edge cases, scaling factor,
  model refit, and zero-weight assignment tests

## Files Modified

- `R/nps-group-jackknife.R` — new file: `create_group_jackknife_weights()` +
  `.validate_groups_arg()` + `.dagjk_single_replicate()` internal helpers
- `R/replicate-dispatch.R` — added `"group-jackknife"` method; updated
  `@return` roxygen
- `R/replicate-weights.R` — extended `.validate_reference_sample()` with
  `data.frame` branch
- `tests/testthat/helper-test-data.R` — added `make_dagjk_datasets()`
- `tests/testthat/test-nps-group-jackknife.R` — new test file (34 blocks)
- `tests/testthat/test-replicate-dispatch.R` — added group-jackknife dispatch test
- `tests/testthat/_snaps/` — new snapshots for DAGJK error/warning messages
- `NAMESPACE` — regenerated (`create_group_jackknife_weights` exported)
- `man/create_group_jackknife_weights.Rd` — generated documentation
- `man/create_replicate_weights.Rd` — updated documentation (return value note)
