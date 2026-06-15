# Changelog — nonprob-repweights utilities (PR 1)

**Date**: 2026-06-15
**Scope**: `R/weight-utils.R`, `R/trim_weights.R`, `R/stabilize_weights.R`

## Summary

Extends `trim_weights()` and `stabilize_weights()` to apply their replicate-column
operations to `survey_nonprob` objects that carry optional replicate weight columns
(`@variables$repweights`). Previously, the replicate-column path only fired for
`survey_replicate` inputs; now it fires for any input where `.has_repweights()`
returns `TRUE`.

## Changes

### Added

- **`.has_repweights(x)`** internal predicate in `R/weight-utils.R`. Returns `TRUE`
  when `x` is a `survey_replicate` OR when `x` is a `survey_nonprob` with
  `!is.null(@variables$repweights)` and `length(@variables$repweights) >= 1L`.
  Returns `FALSE` for all other inputs including `NULL`. Does not throw.

### Modified

- **`trim_weights()`** Step 7 guard: `S7::S7_inherits(data, surveycore::survey_replicate)`
  replaced with `.has_repweights(data)`. Output-construction branch updated
  identically.

- **`stabilize_weights()`** Global and per-group replicate-scaling guards
  (both `if` blocks): `S7::S7_inherits(data, surveycore::survey_replicate)`
  replaced with `.has_repweights(data)`. Output-construction branch updated
  identically.

- **Roxygen documentation** for both functions: `@description` updated to
  include `survey_nonprob with repweights`; `@param data` updated with forward
  reference to the Replicate Weights section; `@returns` updated to standard
  phrasing; `@section Replicate Weights:` block added to both.

## Test counts

- Before: 380 passing
- After: 438 passing (+58 new)

## Files changed

| File | Action |
|------|--------|
| `R/weight-utils.R` | Added `.has_repweights()` |
| `R/trim_weights.R` | Replaced 2 guards; updated roxygen |
| `R/stabilize_weights.R` | Replaced 3 guards; updated roxygen |
| `man/trim_weights.Rd` | Regenerated |
| `man/stabilize_weights.Rd` | Regenerated |
| `tests/testthat/test-weight-utils.R` | Added 58 new tests |
