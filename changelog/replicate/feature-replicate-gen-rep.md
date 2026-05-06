# feat(replicate): add create_gen_rep_weights()

**Date**: 2026-05-06
**Branch**: feature/replicate-gen-rep
**Phase**: Replicate

## Changes

- Add `create_gen_rep_weights()` exported function to `R/replicate-weights.R`:
  - Generates Fay's generalized replication weights via `svrep::as_fays_gen_rep_design()`
  - Requires a `survey_taylor` design; rejects `survey_nonprob` with `surveywts_error_nonprob_requires_probability_design`
  - Supports 12 variance estimators (SD1, SD2, Horvitz-Thompson, Yates-Grundy, etc.)
  - Requires `aux_var_names` when `variance_estimator = "Deville-Tille"`, else errors with `surveywts_error_variance_estimator_requires_aux`
  - Exposes `max_replicates`, `balanced`, `mse`, and `seed` parameters
  - Adds `seed = NULL` parameter (svrep's `make_fays_gen_rep_factors` uses `sample()` internally; seed enables reproducibility)
  - Rejects `survey_replicate` input with `surveywts_error_already_replicate`
  - Rejects `data.frame` / `weighted_df` input with `surveywts_error_not_survey_design`
- Extend `tests/testthat/test-replicate-weights.R` with gen-rep test suite:
  - Happy paths (reproducibility with `seed`, max_replicates limits count, balanced = FALSE)
  - Shared input-class error paths (data.frame, survey_replicate, weighted_df, unsupported class)
  - Gen-rep-specific error paths (Deville-Tille without aux, survey_nonprob)
  - Numerical equivalence against `svrep::as_fays_gen_rep_design()` directly (using matched seed)
  - Edge cases (0-row input propagates error from as_survey, all-equal weights reproducible)
- Spec correction: the spec claimed the function was "deterministic (no randomness)" — this is incorrect; svrep's internal Hadamard matrix shuffling uses `sample()`. Added `seed` parameter and updated tests accordingly.
- Add `create_gen_rep_weights` to `_pkgdown.yml` Replicate Weights section

## Files Modified

- `R/replicate-weights.R` — add `create_gen_rep_weights()` function
- `tests/testthat/test-replicate-weights.R` — gen-rep test suite
- `tests/testthat/_snaps/replicate-weights.md` — new snapshots for gen-rep error messages
- `NAMESPACE` — export `create_gen_rep_weights`
- `man/create_gen_rep_weights.Rd` — generated roxygen2 documentation
- `_pkgdown.yml` — add `create_gen_rep_weights` to Replicate Weights section
