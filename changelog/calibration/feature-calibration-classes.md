# feat(classes): add weighted_df S3 class and survey_nonprob print method

**Date**: 2026-03-04
**Branch**: feature/phase-0-classes
**Phase**: Phase 0

## Changes

- Add `weighted_df` S3 class: tibble subclass with `weight_col` and
  `weighting_history` attributes; class vector
  `c("weighted_df", "tbl_df", "tbl", "data.frame")`
- Implement `print.weighted_df()` with header showing dimensions, weight
  stats (mean, CV, ESS), and formatted weighting history steps
- Implement dplyr compatibility: `dplyr_reconstruct.weighted_df()`,
  `select.weighted_df()`, `rename.weighted_df()`, `mutate.weighted_df()`
  — all emit `surveywts_warning_weight_col_dropped` and downgrade to a
  plain tibble when the weight column is removed
- Add `.new_survey_nonprob()` internal constructor that wraps
  `surveycore::survey_nonprob()`, preserving design variables and
  appending history entries to `@metadata@weighting_history`
- Add S7 `print` method for `surveycore::survey_nonprob` showing
  dimensions, variance method, design variables (IDs/strata/weights), and
  weighting history
- Add `.format_history_step()` internal helper (shared between
  `print.weighted_df()` and the S7 print method)
- Update `plans/` documents (spec, review, impl plan, decisions log, error
  messages, roadmap) to reflect Phase 0 API decisions made during
  implementation
- Update `.claude/rules/surveywts-conventions.md` with final Phase 0
  conventions

## Files Modified

- `R/00-classes.R` — `weighted_df` class definition, print method, and all
  dplyr integration methods
- `R/01-constructors.R` — `.new_survey_nonprob()` internal constructor
- `R/methods-print.R` — S7 print method for `surveycore::survey_nonprob`
- `tests/testthat/test-00-classes.R` — full test suite for all class
  behavior (dplyr compat, print snapshots, validator errors)
- `tests/testthat/_snaps/00-classes.md` — approved snapshots for print
  output and warning messages
- `NAMESPACE` — updated by `devtools::document()` for new S3 exports and
  dplyr imports
- `man/print.weighted_df.Rd` — generated roxygen2 documentation
- `plans/error-messages.md` — updated with `surveywts_warning_weight_col_dropped`
- `plans/impl-phase-0.md` — updated with implementation decisions (v1.3)
- `plans/spec-phase-0.md` — minor clarifications
- `plans/decisions-phase-0.md` — updated design decisions log
- `plans/roadmap.md` — updated phase roadmap
- `.claude/rules/surveywts-conventions.md` — updated conventions
