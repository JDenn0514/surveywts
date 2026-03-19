# Error and Warning Classes

All `cli_abort()` and `cli_warn()` calls must use a class from this table.
See `plans/spec-phase-0.md §XII` for full message templates (organized by
function in subsections XII.A through XII.G).

## Errors

### Common (all calibration and nonresponse functions)

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_unsupported_class` | All calibration / NR functions | `data` is not a supported class |
| `surveywts_error_replicate_not_supported` | All calibration / NR functions | `data` is `survey_replicate` |
| `surveywts_error_empty_data` | All calibration / NR functions | `nrow(data) == 0` |
| `surveywts_error_weights_not_found` | All functions accepting `weights` | Named weight column missing from `data` |
| `surveywts_error_weights_not_numeric` | `.validate_weights()` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | `.validate_weights()` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | `.validate_weights()` | Weight column has `NA` |

### `calibrate()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_variable_not_categorical` | `calibrate()` | Calibration variable is numeric or integer |
| `surveywts_error_variable_has_na` | `calibrate()` | A calibration variable has `NA` values |
| `surveywts_error_population_variable_not_found` | `calibrate()` | A `population` name not found in `data` |
| `surveywts_error_population_level_missing` | `calibrate()` | A data level absent from `population` |
| `surveywts_error_population_level_extra` | `calibrate()` | A `population` level absent from `data` |
| `surveywts_error_population_totals_invalid` | `calibrate()` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_calibration_not_converged` | `.calibrate_engine()` | Max iterations reached without convergence |

### `rake()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_margins_format_invalid` | `rake()` | `margins` is not a named list or valid long data frame |
| `surveywts_error_margins_variable_not_found` | `rake()` | A margins variable not found in `data` |
| `surveywts_error_variable_not_categorical` | `rake()` | Raking variable is numeric or integer |
| `surveywts_error_variable_has_na` | `rake()` | A raking variable has `NA` values |
| `surveywts_error_population_level_missing` | `rake()` | A data level absent from `margins` |
| `surveywts_error_population_level_extra` | `rake()` | A margins level absent from `data` |
| `surveywts_error_population_totals_invalid` | `rake()` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_calibration_not_converged` | `.calibrate_engine()` | Max full sweeps reached without convergence |
| `surveywts_error_cap_not_supported_survey` | `rake()` | `cap` specified with `method = "survey"` |

### `poststratify()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_variable_has_na` | `poststratify()` | A strata variable has `NA` values |
| `surveywts_error_population_totals_invalid` | `poststratify()` | `type = "prop"` targets don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_population_cell_duplicate` | `poststratify()` / `.validate_population_cells()` | A cell combination appears more than once in `population` |
| `surveywts_error_population_cell_missing` | `poststratify()` | A data cell has no row in `population` |
| `surveywts_error_population_cell_not_in_data` | `poststratify()` | A `population` cell has no observations in `data` |
| `surveywts_error_empty_stratum` | `poststratify()` | A stratum cell has zero weighted count |

### `adjust_nonresponse()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_variable_has_na` | `adjust_nonresponse()` | A `by` variable has `NA` values |
| `surveywts_error_response_status_not_found` | `adjust_nonresponse()` | `response_status` column missing from `data` |
| `surveywts_error_response_status_not_binary` | `adjust_nonresponse()` | Column is not 0/1 or logical |
| `surveywts_error_response_status_has_na` | `adjust_nonresponse()` | `response_status` column has `NA` values |
| `surveywts_error_response_status_all_zero` | `adjust_nonresponse()` | All rows are nonrespondents |
| `surveywts_error_class_cell_empty` | `adjust_nonresponse()` | Weighting class cell has no respondents |
| `surveywts_error_response_status_multiple_columns` | `adjust_nonresponse()` | `response_status` selects > 1 column |
| `surveywts_error_propensity_requires_phase2` | `adjust_nonresponse()` | `method` is `"propensity"` or `"propensity-cell"` (Phase 2 stubs) |

### Diagnostics

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_weights_required` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` | Plain `data.frame` with `weights = NULL` |

## Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_warning_weight_col_dropped` | `dplyr_reconstruct.weighted_df()` | dplyr verb removed the weight column from a `weighted_df` |
| `surveywts_warning_negative_calibrated_weights` | `calibrate()` | Linear calibration produced negative calibrated weights |
| `surveywts_warning_class_near_empty` | `adjust_nonresponse()` | A weighting class cell has fewer than `control$min_cell` respondents (default 20) OR adjustment factor exceeds `control$max_adjust` (default 2.0) |
| `surveywts_warning_control_param_ignored` | `rake()` | A `control` parameter is not applicable to the specified `method` (e.g., `control$pval` with `method = "survey"`, or `control$epsilon` with `method = "anesrake"`) |

## Messages

`cli_inform()` messages with required classes (testable with `expect_message(class = ...)`):

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_message_already_calibrated` | `rake()` | `method = "anesrake"` and all raking variables pass the chi-square threshold in sweep 1 — no adjustment needed |
