# PR 1: Migrate DAGJK engine helpers; rename dagjk_* error classes

**Branch:** `feature/jackknife-dagjk-engine`
**Type:** refactor (no public API change)

## Summary

Extracted three internal engine helpers from `create_group_jackknife_weights.R`
into a new shared file `R/jackknife-dagjk-utils.R`, and renamed all
`dagjk_*` error/warning class strings to `jackknife_*` (or to existing
`surveywts_error_unsupported_class` / `surveywts_error_replicates_not_whole_number`
where appropriate).

## Files changed

- `R/jackknife-dagjk-utils.R` — NEW: three migrated engine helpers
  (`.validate_replicates_dagjk_arg()`, `.dagjk_single_replicate()`,
  `.dagjk_single_replicate_calib()`)
- `R/create_group_jackknife_weights.R` — MODIFIED: helper defs removed;
  call sites updated; all `dagjk_*` class strings renamed to `jackknife_*`
- `tests/testthat/test-nps-group-jackknife.R` — MODIFIED: all `dagjk_*`
  class assertions renamed to `jackknife_*`
- `tests/testthat/_snaps/nps-group-jackknife.md` — MODIFIED: snapshot
  updated to reflect new warning class name surfacing correctly in output
- `plans/error-messages.md` — MODIFIED: old `dagjk_*` classes retired;
  new `jackknife_*` classes added as active entries

## Error/warning class renames

| Old class | New class |
|-----------|-----------|
| `surveywts_error_dagjk_requires_nonprob` | `surveywts_error_unsupported_class` (existing) |
| `surveywts_error_dagjk_groups_invalid` | `surveywts_error_jackknife_replicates_invalid` |
| `surveywts_error_dagjk_groups_not_whole_number` | `surveywts_error_replicates_not_whole_number` (existing) |
| `surveywts_error_dagjk_groups_too_small` | `surveywts_error_jackknife_replicates_too_small` |
| `surveywts_error_dagjk_groups_exceeds_n` | `surveywts_error_jackknife_replicates_exceeds_n` |
| `surveywts_error_dagjk_degenerate_replicate` | `surveywts_error_jackknife_degenerate_replicate` |
| `surveywts_error_dagjk_no_history` | `surveywts_error_jackknife_no_history` |
| `surveywts_error_dagjk_no_reference` | `surveywts_error_jackknife_no_reference` |
| `surveywts_error_dagjk_all_replicates_failed` | `surveywts_error_jackknife_all_replicates_failed` |
| `surveywts_warning_dagjk_repweights_overwritten` | `surveywts_warning_jackknife_repweights_overwritten` |
| `surveywts_warning_dagjk_small_groups` | `surveywts_warning_jackknife_small_groups` |
| `surveywts_warning_dagjk_replicates_failed` | `surveywts_warning_jackknife_replicates_failed` |
| `surveywts_warning_dagjk_negative_replicate_weights` | `surveywts_warning_jackknife_negative_replicate_weights` |

## Notes

- The user-facing argument name `groups` is unchanged in this PR.
  The internal validator parameter was renamed `replicates` to prepare
  for the PR 2 argument rename.
- `operation = "group_jackknife_weights"` in the history entry is unchanged.
- 293 tests pass; 0 errors, 0 warnings in R CMD check.
