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

### `calibrate()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_reference_design_not_taylor` | `calibrate()` | `reference_design` is non-`NULL` and is not a `survey_taylor` object |
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
| `surveywts_error_reference_design_not_taylor` | `rake()` | `reference_design` is non-`NULL` and is not a `survey_taylor` object |
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
| ~~`surveywts_error_propensity_not_available`~~ | `adjust_nonresponse()` | Retired in Propensity phase — `method = "propensity"` is now fully implemented. |

### `adjust_nonresponse(method = "propensity")`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_formula_required_for_propensity` | `adjust_nonresponse()` | `method = "propensity"` and `formula = NULL` |
| `surveywts_error_formula_variable_has_na` | `adjust_nonresponse()` | A formula variable contains `NA` values (reuse) |
| _See also:_ `surveywts_error_formula_invalid` | — | Shared with calibration section above |
| _See also:_ `surveywts_error_formula_variable_not_found` | — | Shared with calibration section above |
| _See also:_ `surveywts_error_propensity_scores_degenerate` | — | Shared with `ipw()` section above |

### `calibrate_to_survey()` / `calibrate_to_estimate()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_primary_not_replicate` | `calibrate_to_survey()`, `calibrate_to_estimate()` | `primary_design` / `design` is not `survey_replicate` |
| `surveywts_error_control_not_replicate` | `calibrate_to_survey()` | `control_design` is not `survey_replicate` |
| `surveywts_error_replicate_count_mismatch` | `calibrate_to_survey()` | Number of replicates differs between `primary_design` and `control_design` |
| `surveywts_error_formula_variable_not_found` | `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse(method = "propensity-cell")` | A formula variable not found in the design data |
| `surveywts_error_formula_invalid` | `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse(method = "propensity-cell")` | `formula` is not a one-sided formula object |
| `surveywts_error_estimate_not_named` | `calibrate_to_estimate()` | `estimate` vector is not named |
| `surveywts_error_estimate_has_na` | `calibrate_to_estimate()` | `estimate` vector has `NA` values |
| `surveywts_error_estimate_length_mismatch` | `calibrate_to_estimate()` | Length of `estimate` does not match model matrix columns |
| `surveywts_error_estimate_names_mismatch` | `calibrate_to_estimate()` | Names of `estimate` do not match model matrix column names |
| `surveywts_error_vcov_dimension_mismatch` | `calibrate_to_estimate()` | `vcov_estimate` dimensions do not match `estimate` length |
| `surveywts_error_vcov_has_na` | `calibrate_to_estimate()` | `vcov_estimate` has `NA` values |
| `surveywts_error_vcov_not_symmetric` | `calibrate_to_estimate()` | `vcov_estimate` is not symmetric (within 1e-8 tolerance) |
| `surveywts_error_vcov_cholesky_failed` | `calibrate_to_estimate()` | `vcov_estimate` is not positive definite (Cholesky fails) |
| `surveywts_error_calibration_not_converged` | `.calibrate_engine()`, `calibrate_to_survey()`, `calibrate_to_estimate()` | Max iterations reached without convergence — **reuse existing class** |

### `redistribute_weights()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_reduce_if_not_found` | `redistribute_weights()` | `reduce_if` column not found in data |
| `surveywts_error_increase_if_not_found` | `redistribute_weights()` | `increase_if` column not found in data |
| `surveywts_error_reduce_if_not_binary` | `redistribute_weights()` | `reduce_if` column is not 0/1 or logical |
| `surveywts_error_increase_if_not_binary` | `redistribute_weights()` | `increase_if` column is not 0/1 or logical |
| `surveywts_error_reduce_if_has_na` | `redistribute_weights()` | `reduce_if` column has `NA` values |
| `surveywts_error_increase_if_has_na` | `redistribute_weights()` | `increase_if` column has `NA` values |
| `surveywts_error_indicators_overlap` | `redistribute_weights()` | A row has both `reduce_if = 1` and `increase_if = 1` |
| `surveywts_error_no_recipients_in_group` | `redistribute_weights()` | A group has `reduce_if` rows but no `increase_if` rows |
| `surveywts_error_wt_name_conflict` | `redistribute_weights()` | `wt_name` matches an existing non-weight column |

### `ipw()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_population_size_invalid` | `ipw()` | `population_size` is non-NULL and is not a positive finite numeric scalar |
| `surveywts_error_adjust_reference_invalid` | `ipw()` | `adjust_reference` is not `logical(1)` or is `NA` |
| `surveywts_error_not_data_frame` | `ipw()` | `data` is not a `data.frame` |
| `surveywts_error_svydesign_not_taylor` | `ipw()` | `reference` is not `survey_taylor` |
| `surveywts_error_reference_weights_nonpositive` | `ipw()` | Any reference design weight ≤ 0 |
| `surveywts_error_selection_missing` | `ipw()` | Both `selection` and `predictors` are `NULL` |
| `surveywts_error_selection_conflict` | `ipw()` | Both `selection` and `predictors` are non-`NULL` |
| `surveywts_error_formula_variable_not_in_reference` | `ipw()` | A `selection` variable missing from `reference@data` |
| `surveywts_error_propensity_level_not_in_reference` | `ipw()` | A factor/char level in `data` absent from `reference@data` |
| `surveywts_error_propensity_invalid_maxit` | `ipw()` | `maxit < 1L` |
| `surveywts_error_propensity_invalid_epsilon` | `ipw()` | `epsilon <= 0` |
| `surveywts_error_propensity_scores_degenerate` | `ipw()` | Any estimated score ≤ 0 or ≥ 1 |
| `surveywts_error_propensity_hessian_singular` | `.fit_participation_propensity()` | Hessian singular during Newton-Raphson |
| `surveywts_error_separate_numeric_na` | `ipw()` | `missing_method = "separate"` and a numeric selection variable in `data` has NA values |
| `surveywts_error_mice_not_installed` | `ipw()` | `missing_method = "impute"` but the `mice` package is not installed |

### `adjust_nonresponse()` — propensity-cell

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_formula_required_for_propensity_cell` | `adjust_nonresponse()` | `method = "propensity-cell"` but `formula = NULL` |
| `surveywts_error_formula_variable_has_na` | `adjust_nonresponse()` | A formula variable contains `NA` values |
| `surveywts_error_n_cells_invalid` | `adjust_nonresponse()` | `control$n_cells` is not a whole number ≥ 2 |
| `surveywts_error_no_respondents_in_propensity_cell` | `adjust_nonresponse()` | A propensity score cell contains no respondents |
| _See also:_ `surveywts_error_formula_invalid` | — | Shared with calibration section above |
| _See also:_ `surveywts_error_formula_variable_not_found` | — | Shared with calibration section above |

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

### `trim_weights()` / `stabilize_weights()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_null_bound_percentile` | `trim_weights()` | `upper = NULL` with `type = "percentile"` |
| `surveywts_error_k_not_scalar` | `trim_weights()` | `k` is not `numeric(1)` or is `NA` |
| `surveywts_error_k_nonpositive` | `trim_weights()` | `k <= 0` |
| `surveywts_error_lower_not_scalar` | `trim_weights()` | `lower` is not `numeric(1)` or is `NA` |
| `surveywts_error_upper_not_scalar` | `trim_weights()` | `upper` is not `numeric(1)` or is `NA` |
| `surveywts_error_bounds_invalid` | `trim_weights()` | Resolved `lower_abs >= upper_abs` |
| `surveywts_error_upper_nonpositive` | `trim_weights()` | `upper <= 0` when `type = "absolute"` |
| `surveywts_error_percentile_out_of_range` | `trim_weights()` | Bound not in [0, 1] with `type = "percentile"` |
| `surveywts_error_by_variable_not_found` | `stabilize_weights()` | A `by` variable not in `data` |

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
| `surveywts_warning_negative_calibrated_weights` | `calibrate()` | Linear calibration produced negative calibrated weights |
| `surveywts_warning_class_near_empty` | `adjust_nonresponse()` | A weighting class cell has fewer than `control$min_cell` respondents (default 20) OR adjustment factor exceeds `control$max_adjust` (default 2.0) |
| `surveywts_warning_control_param_ignored` | `rake()` | A `control` parameter is not applicable to the specified `method` (e.g., `control$pval` with `method = "survey"`, or `control$epsilon` with `method = "anesrake"`) |
| `surveywts_warning_replicate_scheme_mismatch` | `calibrate_to_survey()` | `primary_design` and `control_design` have different replicate weight types (e.g., `"bootstrap"` vs `"JK1"`) |
| `surveywts_warning_by_ignored_for_propensity_cell` | `adjust_nonresponse()` | `by` is non-`NULL` with `method = "propensity-cell"` — `by` is ignored for this method |
| `surveywts_warning_by_ignored_for_propensity` | `adjust_nonresponse()` | `by` is non-`NULL` with `method = "propensity"` — `by` is ignored for this method |
| `surveywts_warning_extreme_propensity_adjustment` | `adjust_nonresponse()` | Maximum weight adjustment ratio (`max(w/score) / mean(w)`) exceeds `control$max_adjust` (default 5.0) |
| `surveywts_warning_propensity_glm_convergence` | `adjust_nonresponse()` | `stats::glm()` emits an "algorithm did not converge" warning during response propensity fitting |
| `surveywts_warning_extreme_propensity_scores` | `ipw()`, `adjust_nonresponse()` | Any estimated propensity score < 0.01 |
| `surveywts_warning_propensity_nr_no_convergence` | `ipw()` | Newton-Raphson exhausted `maxit` without convergence |
| `surveywts_warning_ipw_data_na_omitted` | `ipw()` | `missing_method = "omit"` dropped NPS rows with NA in selection variables; reports count and variable names |
| `surveywts_warning_ipw_reference_na_omitted` | `ipw()` | Reference rows with NA in selection variables excluded from model fitting; reports count and variable names |
| `surveywts_warning_ipw_mice_m_ignored` | `ipw()` | User passed `m` in `mice_args` but `m = 1` is fixed; user value is ignored |
| `surveywts_warning_ipw_reference_weight_adjusted` | `ipw()` | `adjust_reference = TRUE` and `nps_fraction > 0.05` — reference weights multiplied by `1 - nps_fraction` |
| `surveywts_warning_ipw_reference_unadjusted_large_nps` | `ipw()` | `adjust_reference = FALSE` and `nps_fraction > 0.05` — no adjustment applied despite large NPS fraction |
| `surveywts_warning_no_weights_trimmed` | `trim_weights()` | No main weights fell outside the resolved bounds |
| `surveywts_warning_trimming_failed` | `trim_weights()` | All remaining units already trimmed; no untrimmed units to absorb excess |
| _See also:_ `surveywts_warning_negative_calibrated_weights` | — | Shared with `calibrate()` section; also thrown by `calibrate_to_survey()` and `calibrate_to_estimate()` |
| _See also:_ `surveywts_warning_class_near_empty` | — | Shared with `adjust_nonresponse()` section; also thrown by `redistribute_weights()` |

## Messages

`cli_inform()` messages with required classes (testable with `expect_message(class = ...)`):

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_message_already_calibrated` | `rake()` | `method = "anesrake"` and all raking variables pass the chi-square threshold in sweep 1 — no adjustment needed |
