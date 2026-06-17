# Changelog — feature/cts-opsomer-validation

**PR**: 1 of 2 for calibrate-to-survey-opsomer
**Branch**: `feature/cts-opsomer-validation`
**Date**: 2026-06-17

## Changes

### `calibrate_to_survey()` — new arguments

- Added `targets = NULL`: optional named list of fixed census margins (named
  numeric vectors or tibbles). When `NULL`, existing behavior is preserved
  (svrep delegation). When non-NULL, validated against 4 new error classes.
- Added `type = c("prop", "count")`: controls interpretation of `targets`
  values. Matched with `rlang::arg_match()`; ignored when `targets = NULL`.
- Added `algorithm = c("classic_ipf", "nr")`: raking algorithm selection.
  Matched with `rlang::arg_match()`; silently ignored when `method != "rake"`.

### New validation

- `surveywts_error_scale_not_found`: fires on all calls when
  `primary_design@variables$scale` or `control_design@variables$scale` is
  `NULL`. Required for the Opsomer `a_r` constant computation (PR 2).
- `surveywts_error_control_level_missing`: fires on all calls when a level of
  a `variables` variable in `primary_design@data` is absent from
  `control_design@data`. Implemented via `.check_control_levels()` helper.
- `surveywts_error_targets_not_named_list`: fires when `targets` is non-NULL
  but is not a non-empty named list (covers empty list and unnamed elements).
- `surveywts_error_targets_variable_not_found`: fires when a name from
  `targets` is not a column in `primary_design@data`.
- `surveywts_error_targets_element_invalid`: fires when a `targets` element
  is not a named numeric vector or a tibble with required columns.
- `surveywts_error_targets_totals_invalid`: fires when proportions don't sum
  to 1 (within 1e-6) or counts are ≤ 0 or NA.

### Test helpers

- `make_replicate_design()` gains `R = 50L` parameter (backward-compatible).
- `make_nonprob_replicate_design()` gains `R = 30L` parameter and now sets
  `@variables$scale <- 1/R` on the returned design so callers requiring
  `@variables$scale` (e.g., `calibrate_to_survey()`) receive a valid object.

### Error classes added to `plans/error-messages.md`

All 6 classes listed above were added during the spec phase and confirmed
present before implementation.
