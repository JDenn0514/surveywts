# feature/weight-utils-infra — Infrastructure for trim_weights() / stabilize_weights()

**Branch:** `feature/weight-utils-infra`
**PR:** TBD
**Status:** In progress

## Changes

### `plans/error-messages.md`
- Added 9 new error classes under `### trim_weights() / stabilize_weights()`:
  `surveywts_error_null_bound_percentile`, `surveywts_error_k_not_scalar`,
  `surveywts_error_k_nonpositive`, `surveywts_error_lower_not_scalar`,
  `surveywts_error_upper_not_scalar`, `surveywts_error_bounds_invalid`,
  `surveywts_error_upper_nonpositive`, `surveywts_error_percentile_out_of_range`,
  `surveywts_error_by_variable_not_found`
- Added 2 new warning classes to `## Warnings`:
  `surveywts_warning_no_weights_trimmed`, `surveywts_warning_trimming_failed`

### `.claude/rules/surveywts-conventions.md`
- Added `utilities` family row to the `@family groups` table (Section 2)

### `R/utils.R`
- Extended `.get_weight_vec()` with a `survey_replicate` branch before the
  plain-`data.frame` fallback; updated the embedded comment listing accepted types
- Added `.trim_weights_internal()` with attribution to `survey::do_trimWeights`
  (Thomas Lumley, GPL-2/3); inserted after `.validate_formula_variables()` and
  before `.to_svyrep_design()`
- Updated file-level contents table to include `.trim_weights_internal()`
