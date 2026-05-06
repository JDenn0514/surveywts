# feat(replicate): add create_brr_weights()

**Date**: 2026-05-05
**Branch**: feature/replicate-brr
**Phase**: Replicate

## Changes

- Add `create_brr_weights()` exported function to `R/replicate-weights.R`:
  - `rho = 0` (default): standard BRR via `survey::as.svrepdesign(type = "BRR")`, returns `@variables$type = "BRR"`
  - `rho > 0`: Fay's BRR variant via `survey::as.svrepdesign(type = "Fay", fay.rho = rho)`, returns `@variables$type = "Fay"`
  - Rejects `survey_nonprob` (no PSU structure) with `surveywts_error_brr_requires_paired_design`
  - Rejects designs missing strata or PSU IDs with `surveywts_error_brr_requires_paired_design`
  - Rejects designs with != 2 PSUs per stratum with `surveywts_error_brr_requires_paired_design`
  - Rejects `rho` outside `[0, 1)` with `surveywts_error_brr_rho_invalid`
- Extend `tests/testthat/test-replicate-weights.R` with BRR test suite:
  - Happy paths (BRR type, Fay type)
  - Shared input-class error paths (data.frame, survey_replicate, weighted_df, unsupported class)
  - BRR-specific error paths (survey_nonprob, non-paired design, rho < 0, rho = 1)
  - Numerical equivalence against `survey::as.svrepdesign(type = "BRR")` directly
  - Edge cases (single-stratum paired design, all-equal base weights)
- Fix pre-existing non-ASCII em dashes in `R/replicate-weights.R` comments (lines 108, 110)
- Update `_pkgdown.yml` to add `create_brr_weights` to the Replicate Weights reference section

## Files Modified

- `R/replicate-weights.R` — `create_brr_weights()` appended; non-ASCII comment chars fixed
- `tests/testthat/test-replicate-weights.R` — BRR tests added (167 total)
- `tests/testthat/_snaps/replicate-weights.md` — new snapshots for BRR error messages
- `man/create_brr_weights.Rd` — generated documentation
- `NAMESPACE` — export for `create_brr_weights` added
- `_pkgdown.yml` — `create_brr_weights` added to Replicate Weights section
- `plans/impl-replicate.md` — PR 4 marked complete
