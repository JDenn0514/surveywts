# Error and Warning Classes

All `cli_abort()` and `cli_warn()` calls must use a class from this table.
See `plans/archive/calibration/spec-calibration.md §XII` for full message
templates (organized by function in subsections XII.A through XII.G).

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
| `surveywts_error_wt_name_not_scalar` | `.validate_wt_name()` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `.validate_wt_name()` | `wt_name` is `NA` or `""` |

### `calibrate_greg()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_variable_not_categorical` | `calibrate_greg()` | Calibration variable is numeric or integer |
| `surveywts_error_variable_has_na` | `calibrate_greg()` | A calibration variable has `NA` values |
| `surveywts_error_targets_variable_not_found` | `calibrate_greg()` | A `targets` name not found in `data` |
| `surveywts_error_population_level_missing` | `calibrate_greg()` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | `calibrate_greg()` | A `targets` level absent from `data` |
| `surveywts_error_population_totals_invalid` | `calibrate_greg()` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_calibration_not_converged` | `.calibrate_engine()` | Max iterations reached without convergence |
| `surveywts_error_reference_design_not_taylor` | `calibrate_greg()` | `reference_design` is non-`NULL` and not `survey_taylor` |

### `calibrate_rake()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_margins_format_invalid` | `calibrate_greg()`, `calibrate_rake()` | `targets` is not a named list or valid long data frame |
| `surveywts_error_targets_variable_not_found` | `calibrate_rake()` | A `targets` variable not found in `data` |
| `surveywts_error_variable_not_categorical` | `calibrate_rake()` | Raking variable is numeric or integer |
| `surveywts_error_variable_has_na` | `calibrate_rake()` | A raking variable has `NA` values |
| `surveywts_error_population_level_missing` | `calibrate_rake()` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | `calibrate_rake()` | A `targets` level absent from `data` |
| `surveywts_error_population_totals_invalid` | `calibrate_rake()` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_calibration_not_converged` | `.calibrate_engine()` | Max full sweeps reached without convergence |
| `surveywts_error_cap_not_supported_survey` | `calibrate_rake()` | `cap` specified with `algorithm = "survey"` |
| `surveywts_error_reference_design_not_taylor` | `calibrate_rake()` | `reference_design` is non-`NULL` and not `survey_taylor` |

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
| `surveywts_error_propensity_not_available` | `adjust_nonresponse()` | `method` is `"propensity"` or `"propensity-cell"` (not yet available) |

### Diagnostics

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_weights_required` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` | Plain `data.frame` with `weights = NULL` |

### Replicate Weight Functions

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_already_replicate` | All `create_*_weights()` | Input is already `survey_replicate` |
| `surveywts_error_not_survey_design` | All `create_*_weights()` | Input is `data.frame` or `weighted_df` |
| `surveywts_error_replicates_invalid` | All methods accepting `replicates` | `replicates` is not a single numeric value (wrong type, length ≠ 1, or `NA`) |
| `surveywts_error_replicates_not_positive` | Bootstrap, jackknife (random-groups), gen-boot, SDR | `replicates` < 2 |
| `surveywts_error_replicates_not_whole_number` | All methods accepting `replicates` | `replicates` has non-zero fractional part |
| `surveywts_error_brr_requires_paired_design` | `create_brr_weights()` | Stratum has ≠ 2 PSUs, or input is `survey_nonprob` |
| `surveywts_error_brr_rho_invalid` | `create_brr_weights()` | `rho < 0` or `rho >= 1` |
| `surveywts_error_replicates_required_for_jkn` | `create_jackknife_weights()` | `type = "random-groups"` but `replicates` is `NULL` |
| `surveywts_error_jackknife_type_unsupported_for_nonprob` | `create_jackknife_weights()` | `data` is `survey_nonprob` and `type = "random-groups"` |
| `surveywts_error_nonprob_requires_probability_design` | `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()` | `data` is `survey_nonprob` |
| `surveywts_error_sort_var_has_na` | `create_sdr_weights()` | `sort_var` column contains `NA` |
| `surveywts_error_variance_estimator_requires_aux` | `create_gen_boot_weights()`, `create_gen_rep_weights()` | `variance_estimator = "Deville-Tille"` but `aux_var_names = NULL` |
| `surveywts_error_no_taylor_structure` | `as_taylor_design()` | No `"replicate_creation"` entry in history |
| `surveywts_error_taylor_from_calibrated_replicate` | `as_taylor_design()` | Post-creation weight adjustment in history |
| `surveywts_error_taylor_from_nonprob_replicate` | `as_taylor_design()` | Source was `survey_nonprob` |
| `surveywts_error_unsupported_class` | All `create_*_weights()`, `as_taylor_design()` | Input class is not a supported survey design type |

### Internal / Utility

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_internal` | `.make_weighted_df()`, `.calibrate_engine()` | Defensive unreachable branch indicating a bug in surveywts internals; both call sites are in `# nocov` blocks |

## Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_warning_already_taylor` | `as_taylor_design()` | Input is already `survey_taylor` |
| `surveywts_warning_taylor_loses_variance` | `as_taylor_design()` | Converting drops replicate weights |
| `surveywts_warning_weight_col_dropped` | `dplyr_reconstruct.weighted_df()` | dplyr verb removed the weight column from a `weighted_df` |
| `surveywts_warning_negative_calibrated_weights` | `calibrate_greg()` | Linear calibration produced negative calibrated weights |
| `surveywts_warning_class_near_empty` | `adjust_nonresponse()` | A weighting class cell has fewer than `control$min_cell` respondents (default 20) OR adjustment factor exceeds `control$max_adjust` (default 2.0) |
| `surveywts_warning_control_param_ignored` | `calibrate_greg()`, `calibrate_rake()` | A `control` parameter is not applicable to the specified `model`/`algorithm` (e.g., `control$pval` with `algorithm = "survey"`, or `control$epsilon` with `algorithm = "anesrake"`; or an unrecognized key in `calibrate_greg()`) |

## Messages

`cli_inform()` messages with required classes (testable with `expect_message(class = ...)`):

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_message_already_calibrated` | `calibrate_rake()` | `algorithm = "anesrake"` and all raking variables pass the chi-square threshold in sweep 1 — no adjustment needed |
