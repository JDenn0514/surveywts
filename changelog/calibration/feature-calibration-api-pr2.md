# PR 2: calibrate_poststrat() + calibrate() dispatcher

**Branch:** `feature/calibration-api-pr2`
**Date:** 2026-06-03
**Type:** feat(calibration)

## Summary

Adds `calibrate_poststrat()` (replaces `poststratify()`) and the new thin
`calibrate()` dispatcher that routes to `calibrate_greg()`, `calibrate_rake()`,
or `calibrate_poststrat()`. After this PR all four calibration functions are
exported and all three old functions (`calibrate()`, `rake()`, `poststratify()`)
are fully replaced.

## Changes

### New files
- `R/calibrate_poststrat.R` — `calibrate_poststrat()` with `targets` data
  frame API, `reference_design` support, and `.validate_population_cells()`
  private helper
- `R/calibrate.R` — thin `calibrate()` dispatcher via `rlang::arg_match()`
  and `switch()`

### Deleted files
- `R/poststratify.R` — replaced by `calibrate_poststrat.R`
- `man/poststratify.Rd` — auto-deleted by `devtools::document()`

### Modified files
- `tests/testthat/test-04-poststratify.R` — full rewrite for `calibrate_poststrat()`
- `tests/testthat/test-02-calibrate.R` — dispatcher section appended
- `R/adjust_nonresponse.R` — fixed broken `[poststratify()]` link
- `plans/error-messages.md` — updated `poststratify()` section to
  `calibrate_poststrat()`, added `surveywts_error_margins_format_invalid`,
  `surveywts_error_no_strata_variables`, `surveywts_error_targets_variable_not_found`,
  `surveywts_error_reference_design_not_taylor` for `calibrate_poststrat()`
- `.claude/rules/surveywts-conventions.md` — updated file mapping table and
  `@family calibration` list
- `NAMESPACE` — regenerated
- `man/calibrate.Rd`, `man/calibrate_poststrat.Rd` — generated

## Key API changes vs old `poststratify()`

| Old | New |
|-----|-----|
| `poststratify(data, strata, population, ...)` | `calibrate_poststrat(data, targets, ...)` |
| `strata` tidy-select + separate `population` data frame | Single `targets` data frame; strata vars = `setdiff(names(targets), "target")` |
| `operation = "poststratify"` in history | `operation = "calibrate_poststrat"` |
| No `reference_design` | `reference_design` argument added |

## New error classes

| Class | Condition |
|-------|-----------|
| `surveywts_error_margins_format_invalid` | `targets` is not a `data.frame` |
| `surveywts_error_no_strata_variables` | `targets` has zero non-`"target"` columns |
| `surveywts_error_targets_variable_not_found` | A non-`"target"` column absent from `data` |
| `surveywts_error_reference_design_not_taylor` | `reference_design` is non-NULL and not `survey_taylor` |

## Implementation note

Post-stratification weights are computed directly (cell-ratio method:
`w_new_i = w_old_i * target_h / sum(w_old in cell h)`) rather than via
`survey::postStratify`, making it robust to single-PSU edge cases while
remaining numerically equivalent for standard inputs.
