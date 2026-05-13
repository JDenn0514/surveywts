# feat(utils): add formula and svyrep helpers for nonresponse phase

**Date**: 2026-05-13
**Branch**: feature/nonresponse-infrastructure
**Phase**: Nonresponse

## Changes

- Move `svrep` from Suggests to Imports in `DESCRIPTION` with minimum version pin `(>= 0.9.1)`
- Add three shared internal helpers to `R/utils.R`:
  - `.validate_formula()` — validates one-sided formula objects (`~ RHS`)
  - `.validate_formula_variables()` — validates all formula variables exist in a data frame
  - `.to_svyrep_design()` — converts a `survey_replicate` to `survey::svyrep.design` for use with `svrep` calibration functions; always passes `combined.weights = FALSE` to correctly interpret scale factors
- Add `make_replicate_design()` test helper to `tests/testthat/helper-test-data.R` — builds a `survey_replicate` from `make_surveywts_data()` for use in PRs 2–4
- Add all new error/warning classes for the Nonresponse phase to `plans/error-messages.md`:
  - Calibration section: 13 new error classes + `surveywts_warning_replicate_scheme_mismatch`
  - Redistribute section: 9 new error classes
  - Propensity-cell section: 4 new error classes + `surveywts_warning_by_ignored_for_propensity_cell`

## Files Modified

- `DESCRIPTION` — `svrep` moved from Suggests to Imports with `(>= 0.9.1)` pin
- `R/utils.R` — header comment updated; `.validate_formula()`, `.validate_formula_variables()`, `.to_svyrep_design()` added
- `tests/testthat/helper-test-data.R` — `make_replicate_design()` added
- `plans/error-messages.md` — new error/warning classes for Nonresponse phase
- `changelog/nonresponse/feature-infrastructure.md` — this file
