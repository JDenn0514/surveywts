# Changelog: feature/redistribute-weights

**Branch:** `feature/redistribute-weights`
**Phase:** Nonresponse — PR 3
**Status:** Complete

## What Changed

### New functions

- `redistribute_weights(data, reduce_if, increase_if, weights = NULL, by = NULL, wt_name = "wts", control = list())`:
  General weight redistribution primitive. Takes rows identified by `reduce_if` (e.g.,
  nonrespondents) out of the weighted population and proportionally transfers their weight
  to rows identified by `increase_if` (e.g., respondents). Supports optional `by` grouping
  for within-group redistribution. Equivalent to `adjust_nonresponse(method = "weighting-class")`
  when `reduce_if` and `increase_if` are complementary respondent/nonrespondent indicators.

### Design decisions

- **`.validate_response_status_binary()` reuse:** Rather than duplicating validation logic,
  the existing helper was extended with optional `col_label`, `fn_name`, and `error_class`
  parameters (all defaulting to their pre-existing values) so `redistribute_weights()` can
  call it with `reduce_if`- and `increase_if`-specific error classes. This is fully
  backward-compatible with existing `adjust_nonresponse()` usage.

- **`survey_taylor` / `survey_nonprob` output filters rows:** For S7 input types, rows
  matching `reduce_if` are filtered out of the returned object (not retained with zero
  weight). For `data.frame` / `weighted_df` inputs, `reduce_if` rows are retained with
  their weights zeroed. This matches the behavior of `adjust_nonresponse()` for S7 types.

- **`W_total` formula:** Only sums weights of `reduce_if` + `increase_if` rows; neutral
  rows (matching neither indicator) are excluded from the redistribution calculation and
  their weights are unchanged.

- **Non-ASCII character:** The adjustment-factor warning uses `×` (×) instead of a
  literal multiplication sign to satisfy `R CMD check` portability requirements.

- **`survey_replicate` error class:** The unsupported-class error for `survey_replicate`
  input uses `surveywts_error_replicate_not_supported` (what `.check_input_class()` throws),
  which predates the spec's listed class name `surveywts_error_unsupported_class`. This is
  a pre-existing inconsistency — not fixed here.

## Files Added / Changed

- `R/nonresponse.R` — added `redistribute_weights()`; extended `.validate_response_status_binary()` with optional params
- `tests/testthat/test-05-nonresponse.R` — 32 new test blocks for `redistribute_weights()`
- `tests/testthat/_snaps/05-nonresponse.md` — new snapshot entries for all error/warning paths
- `NAMESPACE` — re-generated to export `redistribute_weights`
- `man/redistribute_weights.Rd` — new roxygen-generated man page
- `man/adjust_nonresponse.Rd` — re-generated (signature change in `.validate_response_status_binary()`)
- `.claude/rules/surveywts-conventions.md` — added `redistribute_weights()` to `@family nonresponse`
