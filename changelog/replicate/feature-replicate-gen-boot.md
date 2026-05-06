# feat(replicate): add create_gen_boot_weights()

**Date**: 2026-05-06
**Branch**: feature/replicate-gen-boot
**Phase**: Replicate

## Changes

- Add `create_gen_boot_weights()` exported function to `R/replicate-weights.R`:
  - Generates generalized bootstrap replicate weights via `svrep::as_gen_boot_design()`
  - Requires a `survey_taylor` design; rejects `survey_nonprob` with `surveywts_error_nonprob_requires_probability_design`
  - Supports 12 variance estimators (SD1, SD2, Horvitz-Thompson, Yates-Grundy, etc.)
  - Requires `aux_var_names` when `variance_estimator = "Deville-Tille"`, else errors with `surveywts_error_variance_estimator_requires_aux`
  - Exposes `tau` parameter (numeric or `"auto"`) to prevent negative replicate weights
  - Always returns `@variables$type = "bootstrap"` (overriding svrep's internal `"other"` type)
  - Rejects `survey_replicate` input with `surveywts_error_already_replicate`
  - Rejects `data.frame` / `weighted_df` input with `surveywts_error_not_survey_design`
- Add `type_override` parameter to `.convert_and_call()` to allow methods (gen-boot, gen-rep) to set a semantic type that differs from svrep's internal representation
- Extend `tests/testthat/test-replicate-weights.R` with gen-boot test suite:
  - Happy paths (type = bootstrap, SD1 vs SD2 produce different weights)
  - Shared input-class error paths (data.frame, survey_replicate, weighted_df, unsupported class)
  - Gen-boot-specific error paths (replicates < 2, fractional replicates, Deville-Tille without aux, survey_nonprob)
  - Deville-Tille success path: `variance_estimator = "Deville-Tille"` with valid `aux_var_names` (covers tidy-select resolution branch)
  - Numerical equivalence against `svrep::as_gen_boot_design()` directly
  - Edge cases (tau = "auto" produces non-negative weights, all-equal weights succeeds)
- Fix: move `rlang::enquo(aux_var_names)` before the `is.null()` guard in `create_gen_boot_weights()` so that bare tidy-select column names (e.g., `aux_var_names = y`) are captured before R attempts eager evaluation; use `rlang::quo_is_null()` in the guard instead of `is.null()`
- Add `create_gen_boot_weights` to `_pkgdown.yml` Replicate Weights section

## Files Modified

- `R/replicate-weights.R` — add `create_gen_boot_weights()` function; add `type_override` parameter to `.convert_and_call()`; fix `enquo` placement so bare tidy-select names work for `aux_var_names`
- `tests/testthat/test-replicate-weights.R` — gen-boot test suite
- `tests/testthat/_snaps/replicate-weights.md` — new snapshots for gen-boot error messages
- `NAMESPACE` — export `create_gen_boot_weights`
- `man/create_gen_boot_weights.Rd` — generated roxygen2 documentation
- `man/create_bootstrap_weights.Rd`, `man/create_brr_weights.Rd`, `man/create_jackknife_weights.Rd` — updated `@family` cross-references
- `_pkgdown.yml` — add `create_gen_boot_weights` to Replicate Weights section
