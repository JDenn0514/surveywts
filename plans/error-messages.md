# Error and Warning Classes

All `cli_abort()` and `cli_warn()` calls must use a class from this table.
See `plans/archive/calibration/spec-calibration.md §XII` for full message
templates (organized by function in subsections XII.A through XII.G).

## Errors

### Common (all calibration and nonresponse functions)

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_not_survey_base` | All calibration, NR, utility, and diagnostic functions | Input is not a `survey_base` object (e.g., a plain `data.frame`); replaces `surveywts_error_unsupported_class` for non-replicate functions |
| ~~`surveywts_error_unsupported_class`~~ | ~~All calibration / NR functions~~ | **RETIRED** — replaced by `surveywts_error_not_survey_base` for calibration, nonresponse, utility, and diagnostic functions; still used by `create_*_weights()` and `as_taylor_design()` |
| ~~`surveywts_error_replicate_not_supported`~~ | ~~All calibration / NR functions~~ | **RETIRED** — Replicate release complete; `survey_replicate` now accepted by diagnostic functions (`effective_sample_size()`, `weight_variability()`, `summarize_weights()`) |
| `surveywts_error_empty_data` | All calibration / NR functions | `nrow(data) == 0` |
| `surveywts_error_weights_not_found` | All functions accepting `weights` | Named weight column missing from `data` |
| `surveywts_error_weights_not_numeric` | `.validate_weights()` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | `.validate_weights()` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | `.validate_weights()` | Weight column has `NA` |
| `surveywts_error_wt_name_not_scalar` | `.validate_wt_name()` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `.validate_wt_name()` | `wt_name` is `NA` or `""` |

### `calibrate_to_survey()` and `calibrate_to_estimate()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_primary_not_replicate` | `calibrate_to_survey()` | `primary_design` is not `survey_replicate` or `survey_nonprob` with replicate weights |
| `surveywts_error_control_not_replicate` | `calibrate_to_survey()` | `control_design` is not `survey_replicate` or `survey_nonprob` with replicate weights |
| `surveywts_error_design_not_replicate` | `calibrate_to_estimate()` | `design` is not `survey_replicate` or `survey_nonprob` with replicate weights |
| `surveywts_error_primary_no_repweights` | `calibrate_to_survey()` | `primary_design` is `survey_nonprob` but `@variables$repweights` is `NULL` or length-0 |
| `surveywts_error_control_no_repweights` | `calibrate_to_survey()` | `control_design` is `survey_nonprob` but `@variables$repweights` is `NULL` or length-0 |
| `surveywts_error_design_no_repweights` | `calibrate_to_estimate()` | `design` is `survey_nonprob` but `@variables$repweights` is `NULL` or length-0 |
| `surveywts_error_reference_design_not_taylor` | `calibrate_to_survey()`, `calibrate_to_estimate()` | `reference_design` is non-NULL but not `survey_taylor` |
| `surveywts_error_unit_scale_invalid` | `calibrate_to_survey()`, `calibrate_to_estimate()` | `unit_scale` non-NULL and not numeric, wrong length, has NA, or non-positive values |
| `surveywts_error_variables_not_found` | `calibrate_to_survey()`, `calibrate_to_estimate()` | Variable absent from data, or empty tidy-select result |
| `surveywts_error_targets_not_named_list` | `calibrate_to_estimate()`, `calibrate_to_survey()` | `targets` is not a named list (any element name empty/missing), or `targets` is a non-NULL empty list `list()`; for `calibrate_to_survey()` applies only when `targets` is non-NULL |
| `surveywts_error_targets_element_not_named` | `calibrate_to_estimate()` | Any element of `targets` is not a named numeric vector |
| `surveywts_error_targets_element_not_positive` | `calibrate_to_estimate()` | Any value in `targets` is ≤ 0 or `NA` |
| `surveywts_error_targets_levels_mismatch` | `calibrate_to_estimate()` | Inner names of a `targets` element don't exactly match data levels |
| `surveywts_error_vcov_has_na` | `calibrate_to_estimate()` | `vcov_estimate` contains `NA` |
| `surveywts_error_vcov_dimension_mismatch` | `calibrate_to_estimate()` | `vcov_estimate` is not `k × k` where `k = length(unlist(targets))` |
| `surveywts_error_vcov_not_symmetric` | `calibrate_to_estimate()` | `max(\|V - V^T\|) > 1e-8` |
| `surveywts_error_vcov_cholesky_failed` | `calibrate_to_estimate()` | `chol(vcov_estimate)` fails (not positive definite) |
| `surveywts_error_calibration_not_converged` | `calibrate_to_survey()`, `calibrate_to_estimate()` | svrep or `survey::calibrate()` emits a convergence warning; on the Opsomer path, may occur during per-replicate calibration |
| `surveywts_error_calibration_failed` | `calibrate_to_survey()`, `calibrate_to_estimate()` | svrep or `survey::calibrate()` throws a hard error; on the Opsomer path, may occur during per-replicate calibration |
| ~~`surveywts_error_replicate_count_mismatch`~~ | ~~`calibrate_to_survey()`~~ | **RETIRED** — replicate count mismatches no longer raise an error |
| `surveywts_error_scale_not_found` | `calibrate_to_survey()` | `primary_design@variables$scale` or `control_design@variables$scale` is `NULL`; cannot compute `a_r` constants without the scalar replication constant. Fires on all calls (not only when `targets` is non-NULL). |
| `surveywts_error_targets_variable_not_found` | `calibrate_to_survey()` | A name from the `targets` list is not a column in `primary_design@data`; applies only when `targets` is non-NULL |
| `surveywts_error_targets_element_invalid` | `calibrate_to_survey()` | An element of `targets` is not a named numeric vector and not a tibble with the required columns (variable column + `n` or `prop` column); applies only when `targets` is non-NULL |
| `surveywts_error_targets_totals_invalid` | `calibrate_to_survey()` | `type = "prop"` and a variable's proportions don't sum to 1 (within 1e-6), or `type = "count"` and any total is ≤ 0 or `NA`; applies only when `targets` is non-NULL |
| `surveywts_error_control_level_missing` | `calibrate_to_survey()` | A level of a `variables` variable that exists in `primary_design@data` is not present in `control_design@data`; the control-survey total for that level cannot be estimated. Fires on all calls whenever a level-alignment mismatch is detected. |

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
| `surveywts_error_negative_calibrated_weights` | `calibrate_linear()`, `calibrate_logit()`, `calibrate()` | GREG calibration produced negative calibrated weights; cannot store in S7 survey object |

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

### `ipw()`

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_reference_not_survey_design` | `ipw()` | `reference` is neither `survey_taylor` nor `survey_replicate` |
| ~~`surveywts_error_svydesign_not_taylor`~~ | ~~`ipw()`~~ | **RETIRED** — replaced by `surveywts_error_reference_not_survey_design`; the old class required a `survey_taylor` specifically; the new class covers any non-survey-design input, allowing `survey_replicate` as a valid reference |
| `surveywts_error_reference_weights_nonpositive` | `ipw()` | Main weight column of `reference` contains values ≤ 0 |

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

> **`create_group_jackknife_weights()` no longer exists.** The jackknife-merge
> refactor folded delete-a-group jackknife into `create_jackknife_weights()`
> as `type = "grouped"`. Every live row below names the real thrower. The
> struck-through **RETIRED** rows keep the old function name on purpose —
> they record what was true when those classes were retired.
>
> The `type` argument accepts `"jkn"`, `"jk1"`, and `"grouped"`. There is no
> `"random-groups"` type and no `groups` argument; the count comes from
> `replicates`.

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_already_replicate` | All `create_*_weights()` | Input is already `survey_replicate` |
| `surveywts_error_not_survey_design` | All `create_*_weights()` | Input is `data.frame` or `weighted_df` |
| `surveywts_error_replicates_invalid` | All methods accepting `replicates` | `replicates` is not a single numeric value (wrong type, length ≠ 1, or `NA`) |
| `surveywts_error_replicates_not_positive` | Bootstrap, jackknife (grouped), gen-boot, SDR | `replicates` < 2 |
| `surveywts_error_replicates_not_whole_number` | All methods accepting `replicates` | `replicates` has non-zero fractional part |
| `surveywts_error_brr_requires_paired_design` | `create_brr_weights()` | Stratum has ≠ 2 PSUs, or input is `survey_nonprob` |
| `surveywts_error_brr_rho_invalid` | `create_brr_weights()` | `rho < 0` or `rho >= 1` |
| `surveywts_error_jackknife_type_nonprob_only` | `create_jackknife_weights()` | `data` is `survey_nonprob` and `type = "jkn"` or `type = "jk1"` |
| `surveywts_error_jackknife_replicates_required` | `create_jackknife_weights()` | `type = "grouped"` and `replicates = NULL` (both `survey_taylor` and `survey_nonprob` inputs) |
| `surveywts_error_nonprob_requires_probability_design` | `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()` | `data` is `survey_nonprob` |
| `surveywts_error_sort_var_has_na` | `create_sdr_weights()` | `sort_var` column contains `NA` |
| `surveywts_error_use_normal_hadamard_invalid` | `create_sdr_weights()` | `use_normal_hadamard` is not a single non-NA `TRUE` or `FALSE` (wrong type, length ≠ 1, or `NA`) |
| `surveywts_error_variance_estimator_requires_aux` | `create_gen_boot_weights()`, `create_gen_rep_weights()` | `variance_estimator = "Deville-Tille"` but `aux_var_names = NULL` |
| `surveywts_error_no_taylor_structure` | `as_taylor_design()` | No `"replicate_creation"` entry in history |
| `surveywts_error_taylor_from_calibrated_replicate` | `as_taylor_design()` | Post-creation weight adjustment in history |
| `surveywts_error_taylor_from_nonprob_replicate` | `as_taylor_design()` | Source was `survey_nonprob` |
| `surveywts_error_unsupported_class` | All `create_*_weights()`, `as_taylor_design()` | Input class is not a supported survey design type |
| `surveywts_error_reference_sample_class` | `create_bootstrap_weights()`, `create_jackknife_weights()` | `reference_sample` is not a `survey_taylor` |
| `surveywts_error_qr_bootstrap_requires_nonprob` | `create_bootstrap_weights()` | `type = "quasi-randomization"` but `data` is not `survey_nonprob` |
| `surveywts_error_hybrid_bootstrap_requires_nonprob` | `create_bootstrap_weights()` | `type = "hybrid"` but `data` is not `survey_nonprob` |
| `surveywts_error_hybrid_bootstrap_not_implemented` | `create_bootstrap_weights()` | `type = "hybrid"` is requested (not yet implemented) |
| `surveywts_error_mse_not_character` | `create_bootstrap_weights()` | `mse` argument is `logical` instead of `character` |
| `surveywts_error_chrostowski_prob_sample` | `create_bootstrap_weights()` | `mse = "chrostowski"` used with a probability-sample type |
| ~~`surveywts_error_qr_bootstrap_no_ipw_history`~~ | ~~`create_bootstrap_weights()`~~ | **RETIRED** — replaced by `surveywts_error_qr_bootstrap_no_history`; the old error required IPW specifically; the new error covers any missing weighting history |
| `surveywts_error_qr_bootstrap_no_history` | `create_bootstrap_weights()` | `type = "quasi-randomization"` and `survey_nonprob` has no IPW or calibration entry in weighting history |
| `surveywts_error_qr_bootstrap_no_reference` | `create_bootstrap_weights()` | Calibration-only Level B path: no reference design found in calibration history entry and `reference_sample` not supplied; also fired on the IPW path when no reference is available |
| `surveywts_error_bootstrap_all_draws_failed` | `.quasi_randomization_bootstrap()` | All B bootstrap draws failed |
| `surveywts_error_unsupported_calibration_op` | `.dispatch_calibration_replay()` | Unsupported calibration operation in history entry |
| ~~`surveywts_error_dagjk_requires_nonprob`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_unsupported_class`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_no_ipw_history`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_dagjk_no_history`; the old error required IPW specifically; the new error covers any missing weighting history |
| ~~`surveywts_error_dagjk_no_history`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_jackknife_no_history`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_no_reference`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_jackknife_no_reference`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_groups_invalid`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_jackknife_replicates_invalid`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_groups_not_whole_number`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_replicates_not_whole_number` (existing); class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_groups_too_small`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_jackknife_replicates_too_small`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_groups_exceeds_n`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_jackknife_replicates_exceeds_n`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_degenerate_replicate`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_jackknife_degenerate_replicate`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_error_dagjk_all_replicates_failed`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_error_jackknife_all_replicates_failed`; class renaming in PR 1 of jackknife-merge |
| `surveywts_error_jackknife_replicates_invalid` | `create_jackknife_weights()` | `replicates` is not a single non-NA numeric value |
| `surveywts_error_jackknife_replicates_too_small` | `create_jackknife_weights()` | `replicates` < 2 |
| `surveywts_error_jackknife_replicates_exceeds_n` | `create_jackknife_weights()` | `replicates` exceeds the combined NPS + reference row count |
| `surveywts_error_jackknife_degenerate_replicate` | `create_jackknife_weights()` | A group replicate produced non-positive, non-finite, or NA weights, or the reduced dataset contains no NPS or reference units |
| `surveywts_error_jackknife_no_history` | `create_jackknife_weights()` | `survey_nonprob` has no IPW or calibration entry in weighting history |
| `surveywts_error_jackknife_no_reference` | `create_jackknife_weights()` | IPW path or calibration-only Level B path: no reference design found and `reference_sample` not supplied |
| `surveywts_error_jackknife_all_replicates_failed` | `create_jackknife_weights()` | All G group replicates failed; no replicate weights could be produced |

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
| `surveywts_warning_negative_calibrated_weights` | `calibrate()`, `calibrate_to_survey()`, `calibrate_to_estimate()` | Linear calibration produced negative calibrated weights |
| `surveywts_warning_class_near_empty` | `adjust_nonresponse()`, `redistribute_weights()` | A weighting class cell, propensity cell, or redistribution group has fewer than `control$min_cell` members (default 20) OR adjustment factor exceeds `control$max_adjust` (default 2.0). All three messages come from `.warn_near_empty_cell()` |
| `surveywts_warning_control_param_ignored` | `rake()`, `calibrate_to_survey()`, `calibrate_to_estimate()` | A `control` parameter is not applicable to the function (unknown key) |
| `surveywts_warning_replicate_scheme_mismatch` | `calibrate_to_survey()` | `primary_design` and `control_design` have different replicate scheme types |
| `surveywts_warning_repweights_overwritten` | `create_bootstrap_weights()` | A previous call already created replicate weight columns; they are overwritten |
| `surveywts_warning_bootstrap_draws_failed` | `create_bootstrap_weights()` | More than 10% of bootstrap draws failed and were skipped |
| `surveywts_warning_reference_sample_ignored` | `create_bootstrap_weights()` | `reference_sample` supplied but ignored for probability-sample bootstrap types |
| ~~`surveywts_warning_dagjk_repweights_overwritten`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_warning_jackknife_repweights_overwritten`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_warning_dagjk_small_groups`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_warning_jackknife_small_groups`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_warning_dagjk_replicates_failed`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_warning_jackknife_replicates_failed`; class renaming in PR 1 of jackknife-merge |
| ~~`surveywts_warning_dagjk_negative_replicate_weights`~~ | ~~`create_group_jackknife_weights()`~~ | **RETIRED** — replaced by `surveywts_warning_jackknife_negative_replicate_weights`; class renaming in PR 1 of jackknife-merge |
| `surveywts_warning_jackknife_repweights_overwritten` | `create_jackknife_weights()` | A previous call already created replicate weight columns; they are overwritten |
| `surveywts_warning_jackknife_small_groups` | `create_jackknife_weights()` | Average group size is fewer than 5 units |
| `surveywts_warning_jackknife_replicates_failed` | `create_jackknife_weights()` | More than 10% of group replicates failed and were skipped |
| `surveywts_warning_jackknife_negative_replicate_weights` | `create_jackknife_weights()` | One or more replicate weight values are negative after calibration |
| `surveywts_warning_jackknife_mse_overridden` | `create_jackknife_weights()` | `mse = FALSE` with `type = "grouped"` and `survey_nonprob`; overridden to `TRUE` |
| `surveywts_warning_jackknife_svrep_args_ignored` | `create_jackknife_weights()` | Any non-default svrep arg (`var_strat`, `var_strat_frac`, `sort_var`, `adj_method`, `scale_method`) passed with `survey_nonprob` input; emitted once for all non-default args collectively |

## Messages

`cli_inform()` messages with required classes (testable with `expect_message(class = ...)`):

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_message_already_calibrated` | `rake()` | `method = "anesrake"` and all raking variables pass the chi-square threshold in sweep 1 — no adjustment needed |
| `surveywts_message_replay_already_calibrated` | `create_jackknife_weights()`, `create_bootstrap_weights()`, `create_replicate_weights()` | One or more replicates of a calibration replay already met their margins; replaces the per-replicate `surveywts_message_already_calibrated` |
| `surveywts_message_row_order_assumed` | `create_gen_boot_weights()`, `create_gen_rep_weights()` | `variance_estimator` is `"SD1"` or `"SD2"`, which read the row order of the data; replaces an unclassed svrep message |
| `surveywts_message_replicates_rounded_up` | `create_sdr_weights()` | The Hadamard matrix order is above `replicates`, so the result carries more replicate columns than the caller asked for |
| `surveywts_message_replicates_subsampled` | `create_gen_rep_weights()` | `max_replicates` is below the fully efficient replicate count, so the back end keeps a random sample of the replicates |
| `surveywts_message_backend_note` | Any `create_*_weights()` that calls `.convert_and_call()` | The svrep or survey back end emitted a message this package does not recognise; re-emitted verbatim under a class |
