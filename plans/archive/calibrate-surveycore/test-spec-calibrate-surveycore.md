# Test-spec — calibrate-surveycore

---

## Reference oracle

- `survey::calibrate()` (survey package 4.2+) — ground truth for GREG and logit calibration weights
- `survey::rake()` (survey package 4.2+) — ground truth for IPF raking weights
- `survey::postStratify()` (survey package 4.2+) — ground truth for post-stratified weights
- `surveycore::survey_taylor`, `surveycore::survey_replicate`, `surveycore::survey_nonprob` — input class construction
- Hand calculation (R inline) — for `@calibration` field structure checks (shapes, relationships, constraint verification)

---

## Datasets

| Dataset | Construction | Purpose |
|---------|-------------|---------|
| `make_surveywts_data(n = 500, seed = 42)` | Standard synthetic generator | Happy path for `survey_taylor` and `survey_nonprob` inputs |
| `make_surveywts_data(n = 500, seed = 7)` | Alternate seed | Second confirmatory scenario |
| `taylor_design` | Wrap `make_surveywts_data()` output in `surveycore::as_survey()` with `weights = base_weight, ids = id, strata = region` | `survey_taylor` input for all three calibrate functions |
| `nonprob_design` | Wrap data in `surveycore::as_survey_nonprob()` with `weights = base_weight` | `survey_nonprob` input |
| `replicate_design` | Call `calibrate_rake()` or `create_bootstrap_weights()` on a `survey_taylor` to produce a `survey_replicate`; or construct directly via `surveycore::as_survey_replicate()` with explicit replicate columns | `survey_replicate` input |
| `brr_design` | Construct `survey_replicate` with BRR type and manually set replicate weight columns containing negative values (e.g., `wt * -0.1`) | Tests that negative BRR replicate weights pass positivity check suppression |
| `empty_cell_replicate_design` | `survey_replicate` where one replicate weight column assigns zero weight to all members of one calibration category | Tests replicate calibration failure warning path |
| Plain `data.frame` inputs (inline) | `make_surveywts_data()` output without wrapping | Confirm no `@calibration` is set on non-survey outputs |

---

## Per-function test plan

### `calibrate_greg()` — `@calibration` population and `survey_replicate` support

#### Happy path — `survey_taylor` input

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| HT-1 | `calibrate_greg(taylor_design, targets)` returns a `survey_taylor` | Output class is `survey_taylor`; `@calibration` is non-`NULL` |
| HT-2 | `@calibration` has all required fields | All 12 fields present; see field list below |
| HT-3 | `@calibration$x_matrix` has correct shape | n rows × J columns where J = 1 + sum(n_levels - 1) for all variables |
| HT-4 | `@calibration$base_weights` equals input weights | `all.equal(caldata$base_weights, pre_cal_weights)` within 1e-10 |
| HT-5 | `@calibration$g_weights` relation | `all.equal(caldata$g_weights * caldata$base_weights, output@data[[weight_col]])` within 1e-10 |
| HT-6 | `@calibration$crossproduct_inv` shape | J × J matrix |
| HT-7 | `@calibration$population_totals` values | In count scale; `all.equal(sum(caldata$population_totals[intercept_idx]) == sum(weights_vec)` (total matches input total for proportions) |
| HT-8 | Calibration constraint satisfied | `all.equal(drop(t(caldata$x_matrix) %*% output_weights), caldata$population_totals, tolerance = 1e-6)` |
| HT-9 | `@calibration$method` is `"linear"` | `identical(caldata$method, "linear")` |
| HT-10 | `@calibration$cell_factors` is `NULL` | `is.null(caldata$cell_factors)` |
| HT-11 | `@calibration$q_weights` is all-ones | `all(caldata$q_weights == 1)` |
| HT-12 | `@calibration$converged` is `TRUE` | `identical(caldata$converged, TRUE)` |
| HT-13 | `@calibration$n_iterations` is `1L` (linear) | `identical(caldata$n_iterations, 1L)` |
| HT-13b | `@calibration$n_iterations` is `NA_integer_` for `model = "logit"` | `calibrate_greg(taylor_design, targets, model = "logit")`; `identical(caldata$n_iterations, NA_integer_)` |
| HT-14 | `replicate_converged` is `NULL` | `is.null(caldata$replicate_converged)` for taylor input |
| HT-15 | History entry still appended | `length(output@metadata@weighting_history) == length(input_history) + 1L` |
| HT-16 | `test_invariants()` passes | Required first assertion in every test constructing `weighted_df` or `survey_nonprob` |

#### Happy path — `survey_nonprob` input

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| HN-1 | `calibrate_greg(nonprob_design, targets)` | Output class is `survey_nonprob`; `@calibration` populated |
| HN-2 | Same `@calibration` fields as `survey_taylor` case | All fields present; `replicate_converged = NULL` |
| HN-3 | No replicate loop runs | Nonprob has no `@variables$repweights`; `replicate_converged` absent |
| HN-4 | `test_invariants()` passes | First assertion |

#### Happy path — `survey_replicate` input

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| HR-1 | `calibrate_greg(replicate_design, targets)` | Output class is `survey_replicate` |
| HR-2 | `@calibration` populated from full-sample calibration | All 12 base fields present |
| HR-3 | `@calibration$replicate_converged` present | Named logical vector, length = number of replicate columns |
| HR-4 | All successful replicates have `replicate_converged = TRUE` | When all replicates converge, all entries `TRUE` |
| HR-5 | Full-sample weight column calibrated | `output@data[[weight_col]]` differs from input (calibrated); oracle check against `survey::calibrate()` result within 1e-8 |
| HR-6 | Each replicate column calibrated | For each `r` in `@variables$repweights`, output weight column differs from input; calibration constraint verified within 1e-6 |
| HR-7 | Full-sample calibration constraint for full weights | `all.equal(drop(t(caldata$x_matrix) %*% full_weights), caldata$population_totals, tolerance = 1e-6)` |
| HR-8 | Replicate calibration constraint per replicate | For each successfully calibrated replicate r: `all.equal(drop(t(x_matrix) %*% rep_weights_r), population_totals, tolerance = 1e-6)` |
| HR-9 | g_weights correct for full sample | `all.equal(caldata$g_weights * caldata$base_weights, full_sample_calibrated_weights, tolerance = 1e-10)` |

#### Happy path — `calibrate_greg(model = "logit")`

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| HL-1 | `calibrate_greg(taylor_design, targets, model = "logit")` | Output class is `survey_taylor`; `@calibration` populated |
| HL-2 | `caldata$method == "logit"` | `identical(caldata$method, "logit")` |
| HL-3 | `caldata$n_iterations` is `NA_integer_` | `identical(caldata$n_iterations, NA_integer_)` — logit engine does not expose iteration count |
| HL-4 | Calibration constraint satisfied | `all.equal(drop(t(caldata$x_matrix) %*% output_weights), caldata$population_totals, tolerance = 1e-6)` |
| HL-5 | `caldata$converged` is `TRUE` | Logit calibration converged for well-conditioned targets |

#### Happy path — negative BRR replicate weights (gotcha from comprehension.md)

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| HB-1 | `calibrate_greg(brr_design, targets)` where brr_design has negative replicate weights | No `surveywts_error_weights_nonpositive` error thrown for replicate columns |
| HB-2 | Full-sample weights still calibrated | Full-sample calibration proceeds normally |
| HB-3 | Negative replicate weights passed to engine | Calibration engine receives negative starting values for those replicates without error |

#### Happy path — `data.frame` and `weighted_df` inputs (unchanged behavior)

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| HDF-1 | `calibrate_greg(plain_df, targets)` → `weighted_df` | No `@calibration` set (not applicable to S3 class) |
| HDF-2 | `calibrate_greg(weighted_df_obj, targets)` → `weighted_df` | No `@calibration` set |

#### Numerical correctness

| # | Scenario | Oracle | Tolerance |
|---|----------|--------|-----------|
| NC-1 | `survey_taylor` full-sample weights match `survey::calibrate()` | `skip_if_not_installed("survey")` inside block; compare weight vectors | 1e-8 |
| NC-2 | `survey_replicate` full-sample weights match oracle | Same oracle | 1e-8 |
| NC-3 | Each replicate weight column matches oracle applied to that replicate's starting weights | Same oracle per replicate | 1e-8 |

#### Error paths

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_unsupported_class` | Pass a `list` as `data` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_empty_data` | Pass 0-row `survey_taylor` (data = data frame with 0 rows, wrapped in as_survey) | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_weights_not_found` | Pass a `survey_taylor` whose `@variables$weights` names a column absent from `@data` (manually set the slot after construction) | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_weights_not_numeric` | Pass a `survey_taylor` where the weight column is character (coerce after construction) | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_weights_nonpositive` | Main weight column has a value of -1 in `survey_taylor` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_weights_na` | Main weight column has `NA` in `survey_taylor` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_wt_name_not_scalar` | Pass `wt_name = c("a", "b")` (length-2 character) | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_wt_name_empty` | Pass `wt_name = ""` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_targets_variable_not_found` | A `targets` key names a column not in data | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_variable_not_categorical` | A target variable is numeric | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_variable_has_na` | A calibration variable has at least one `NA` value | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_population_level_missing` | A data level absent from `targets` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_population_level_extra` | A `targets` level not in data | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_population_totals_invalid` | `type = "prop"` proportions don't sum to 1 | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_calibration_not_converged` | `control = list(maxit = 0)` with logit model | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_reference_design_not_taylor` | `reference_design` is a plain `data.frame` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_margins_format_invalid` | Pass `targets` as a raw unnamed list (not a named list with `"target"` entries and not a long data frame) | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |

Note: `surveywts_error_replicate_not_supported` must NOT be thrown when `data` is `survey_replicate`. Include a test that explicitly verifies passing a `survey_replicate` to `calibrate_greg()` does not error with this class.

#### Warning paths

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_negative_calibrated_weights` | `model = "linear"` produces negative weights (construct targets that force this) | `expect_warning(class=...)` |
| `surveywts_warning_control_param_ignored` | Pass `control = list(unknown_param = TRUE)` | `expect_warning(class=...)` |
| `surveywts_warning_replicate_calibration_failed` | `empty_cell_replicate_design` where one replicate has a zero-weighted calibration cell | `expect_warning(class=...)` |
| `surveywts_warning_replicate_calibration_failed` — partial failure | One replicate fails, others succeed | Warning emitted once; `replicate_converged` has exactly one `FALSE` entry; other entries are `TRUE` |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| Survey_replicate, all replicates fail | All R replicate columns have a zero-weight cell for a calibration level | R warnings emitted (not errors); `replicate_converged` all `FALSE`; full-sample weights calibrated normally; output returned |
| Survey_replicate, 0 replicate columns | `survey_replicate` with empty `@variables$repweights` | No warnings; `replicate_converged` is named logical of length 0; function returns normally |
| Single-row `survey_taylor` | n=1 data wrapped in `as_survey()` | Full-sample calibration proceeds; `@calibration` populated |
| `survey_nonprob` input | Nonprob design | `@calibration` populated; no replicate loop; `replicate_converged = NULL` |

---

### `calibrate_rake()` — `@calibration` population and `survey_replicate` support

#### Happy path — `survey_taylor` input

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| RT-1 | `calibrate_rake(taylor_design, targets)` → `survey_taylor` | `@calibration` populated; all 12 fields present |
| RT-2 | `@calibration$method == "raking"` | `identical(caldata$method, "raking")` |
| RT-3 | `@calibration$lambda` is `NULL` | Raking does not produce a closed-form Lagrange multiplier |
| RT-4 | `@calibration$cell_factors` is `NULL` | `is.null(caldata$cell_factors)` |
| RT-5 | `x_matrix` uses treatment contrasts | For a two-variable raking with levels c(2,3), J = 1 + (2−1) + (3−1) = 4; `ncol(caldata$x_matrix) == 4`; `colnames(caldata$x_matrix)` includes `"(Intercept)"` |
| RT-6 | Calibration constraint satisfied | `all.equal(drop(t(caldata$x_matrix) %*% output_weights), caldata$population_totals, tolerance = 1e-6)` |
| RT-7 | g_weights relation | `all.equal(caldata$g_weights * caldata$base_weights, output_weights, tolerance = 1e-10)` |
| RT-8 | `crossproduct_inv` is J × J | Shape check |
| RT-9 | `base_weights` equals input weights | `all.equal(caldata$base_weights, pre_cal_weights, tolerance = 1e-10)` |

#### Numerical correctness — raking

| # | Scenario | Oracle | Tolerance |
|---|----------|--------|-----------|
| RNC-1 | `survey_taylor` full-sample weights match `survey::rake()` | `skip_if_not_installed("survey")` inside block; compare weight vectors | 1e-8 |
| RNC-2 | `survey_replicate` full-sample weights match oracle | Same oracle | 1e-8 |
| RNC-3 | Each replicate weight column matches oracle applied to that replicate's starting weights | Same oracle per replicate | 1e-8 |

#### Happy path — `survey_replicate` input

Same structure as `calibrate_greg()` replicate happy path (HR-1 through HR-9), with `calibrate_rake()` substituted. Include:

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| RR-1 | Each replicate column raked with same targets | Calibration constraint verified per replicate within 1e-6 |
| RR-2 | `algorithm = "anesrake"` and `algorithm = "survey"` both tested | Each algorithm tested for `survey_replicate` input |

#### Error paths — raking specific

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_cap_not_supported_survey` | `cap = 5, algorithm = "survey"` with `survey_taylor` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |

All other error paths: same as `calibrate_greg()`.

#### Warning paths

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_control_param_ignored` | Pass `control = list(unknown_param = TRUE)` | `expect_warning(class=...)` |
| `surveywts_warning_replicate_calibration_failed` | Raking non-convergence within a replicate | `expect_warning(class=...)` |

---

### `calibrate_poststrat()` — `@calibration` population and `survey_replicate` support

#### Happy path — `survey_taylor` input

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| PT-1 | `calibrate_poststrat(taylor_design, targets)` → `survey_taylor` | `@calibration` populated |
| PT-2 | `@calibration$method == "poststrat"` | `identical(caldata$method, "poststrat")` |
| PT-3 | `@calibration$lambda` is `NULL` | `is.null(caldata$lambda)` |
| PT-4 | `@calibration$cell_factors` is a named numeric | Non-`NULL`; names match cell label strings; length = number of unique cells |
| PT-5 | `cell_factors` values correct | For cell c: `caldata$cell_factors[[c]] == target_c / N_hat_c` within 1e-10, where `N_hat_c = sum(base_weights[cell_c_units])` |
| PT-6 | `x_matrix` is cell indicator matrix | n × C matrix; each row sums to 1; each column is 0/1 |
| PT-7 | Calibration constraint satisfied | `all.equal(drop(t(caldata$x_matrix) %*% output_weights), caldata$population_totals, tolerance = 1e-6)` |
| PT-8 | g_weights relation | `all.equal(caldata$g_weights * caldata$base_weights, output_weights, tolerance = 1e-10)` |

#### Numerical correctness — post-stratification

| # | Scenario | Oracle | Tolerance |
|---|----------|--------|-----------|
| PNC-1 | `survey_taylor` full-sample weights match `survey::postStratify()` | `skip_if_not_installed("survey")` inside block; compare weight vectors | 1e-8 |
| PNC-2 | `survey_replicate` full-sample weights match oracle | Same oracle | 1e-8 |
| PNC-3 | Each replicate weight column matches oracle applied to that replicate's starting weights | Same oracle per replicate | 1e-8 |

#### Happy path — `survey_replicate` input

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| PR-1 | `calibrate_poststrat(replicate_design, targets)` → `survey_replicate` | `@calibration` populated; `replicate_converged` present |
| PR-2 | Each replicate column post-stratified | Calibration constraint verified per replicate within 1e-6 |
| PR-3 | `cell_factors` from full-sample calibration stored | Not from any individual replicate |

#### Error paths — post-stratification specific

All shared error paths from `calibrate_greg()` (unsupported class, empty data, weight not found, weight not numeric, nonpositive, NA, wt_name not scalar, wt_name empty, targets variable not found, variable not categorical, variable has NA, population level missing/extra, totals invalid, reference design not taylor) apply to `calibrate_poststrat()` as well. Additional post-stratification-specific errors:

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_no_strata_variables` | Pass a `targets` data frame with only a `"target"` column and no strata columns | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_population_cell_duplicate` | Pass a `targets` data frame where the same cell combination appears more than once | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_population_cell_missing` | A data cell combination has no row in `targets` | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_population_cell_not_in_data` | A `targets` cell combination has no observations in data | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |
| `surveywts_error_empty_stratum` | A post-stratification cell has zero weighted count in the full-sample (e.g., all units in that cell have base weight 0 — construct inline) | `expect_error(class=...)` + `expect_snapshot(error=TRUE)` |

#### Warning paths — post-stratification specific

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_replicate_calibration_failed` | `empty_cell_replicate_design` where a replicate has zero replicate weight in a post-stratification cell | `expect_warning(class=...)` |

---

### `calibrate()` dispatcher — `survey_replicate` pass-through

| # | Scenario | Expected behavior |
|---|----------|-------------------|
| D-1 | `calibrate(replicate_design, targets, method = "greg")` | No error; output is `survey_replicate`; same as calling `calibrate_greg()` directly |
| D-2 | `calibrate(replicate_design, targets, method = "rake")` | No error; output is `survey_replicate` |
| D-3 | `calibrate(replicate_design, targets_df, method = "poststrat")` where `targets_df` is a data.frame | No error; output is `survey_replicate` |

---

### `@calibration` list structure — cross-cutting tests

These tests verify the `@calibration` contract fields directly, applicable to any function that outputs a survey object.

| # | Scenario | Expected |
|---|----------|----------|
| CS-1 | `@calibration` is a list | `is.list(output@calibration)` |
| CS-2 | All required fields present | `all(required_fields %in% names(output@calibration))` where `required_fields = c("x_matrix", "base_weights", "g_weights", "crossproduct_inv", "population_totals", "discrepancy", "lambda", "method", "cell_factors", "q_weights", "converged", "n_iterations")` |
| CS-3 | `x_matrix` is a numeric matrix | `is.matrix(caldata$x_matrix) && is.numeric(caldata$x_matrix)` |
| CS-4 | `base_weights` is numeric length n | `is.numeric(caldata$base_weights) && length(caldata$base_weights) == n` |
| CS-5 | `g_weights` is numeric length n | `is.numeric(caldata$g_weights) && length(caldata$g_weights) == n` |
| CS-6 | `crossproduct_inv` is J × J | `isMatrix(caldata$crossproduct_inv) && all(dim(caldata$crossproduct_inv) == c(J, J))` |
| CS-7 | `population_totals` is numeric length J | `is.numeric(caldata$population_totals) && length(caldata$population_totals) == J` |
| CS-8 | `discrepancy` is numeric length J | `is.numeric(caldata$discrepancy) && length(caldata$discrepancy) == J` |
| CS-9 | `q_weights` is numeric length n, all 1 (no q_weights arg exposed) | `is.numeric(caldata$q_weights) && all(caldata$q_weights == 1)` |
| CS-10 | `converged` is logical(1) | `is.logical(caldata$converged) && length(caldata$converged) == 1L` |
| CS-11 | `n_iterations` is integer(1) | `is.integer(caldata$n_iterations) && length(caldata$n_iterations) == 1L` |
| CS-12 | `method` is character(1), valid value | `is.character(caldata$method) && caldata$method %in% c("linear", "logit", "raking", "poststrat")` |

---

### g_weights numerical check (comprehension.md gotcha: variance formula requires g_weights)

| # | Scenario | Expected |
|---|----------|----------|
| GW-1 | g_weights = calibrated / base for all k | `all.equal(caldata$g_weights, output_weights / caldata$base_weights, tolerance = 1e-10)` |
| GW-2 | g_weights are positive when linear model and no negatives | All entries > 0 |
| GW-3 | g_weights can be negative for linear GREG that produces negative calibrated weights | `any(caldata$g_weights < 0)` when `surveywts_warning_negative_calibrated_weights` was emitted |

---

### crossproduct_inv numerical check (comprehension.md: required for GREG residuals)

| # | Scenario | Expected |
|---|----------|----------|
| CI-1 | `crossproduct_inv` is the inverse of `t(X) %*% diag(d) %*% X` | `all.equal(caldata$crossproduct_inv %*% (t(caldata$x_matrix) %*% (caldata$base_weights * caldata$x_matrix)), diag(J), tolerance = 1e-8)` |

---

### Cell factors check for post-stratification (comprehension.md gotcha: Valliant 1991)

| # | Scenario | Expected |
|---|----------|----------|
| CF-1 | `cell_factors` names match cell labels | `all(names(caldata$cell_factors) %in% unique_cell_labels)` |
| CF-2 | `cell_factors` values correct | For each cell c: `caldata$cell_factors[[c]] == target_count_c / sum(base_weights[cell_c_indices])` within 1e-10 |
| CF-3 | `cell_factors` is `NULL` for GREG and raking | `is.null(caldata$cell_factors)` |

---

### Singular x_matrix (comprehension.md gotcha: singular T_s)

This gotcha is already handled by the existing engine for full-sample calibration (produces `surveywts_error_empty_stratum` or `surveywts_error_calibration_not_converged`). For replicates, failure is handled as a warning.

| # | Scenario | Expected |
|---|----------|----------|
| SX-1 | `empty_cell_replicate_design` passed to `calibrate_poststrat()` | `surveywts_warning_replicate_calibration_failed` emitted; other replicates calibrated; `replicate_converged[[failed_col]] == FALSE` |
| SX-2 | Full-sample singular cell still errors | `surveywts_error_empty_stratum` (existing behavior unchanged) |

---

### replicate_converged field — `survey_replicate` tests

| # | Scenario | Expected |
|---|----------|----------|
| RC-1 | All replicates converge | `all(caldata$replicate_converged)` |
| RC-2 | One replicate fails | Exactly one `FALSE` in `replicate_converged`; name matches the failed column |
| RC-3 | `replicate_converged` names match `@variables$repweights` | `identical(names(caldata$replicate_converged), output@variables$repweights)` |
| RC-4 | Non-replicate output: `NULL` | `is.null(caldata$replicate_converged)` for `survey_taylor` and `survey_nonprob` |

---

### No `@calibration` for data.frame / weighted_df outputs

| # | Scenario | Expected |
|---|----------|----------|
| DF-1 | `calibrate_greg(plain_df, targets)` | Output inherits from `data.frame` (is `weighted_df`); no `@calibration` attribute |
| DF-2 | `calibrate_rake(weighted_df_obj, targets)` | Output is `weighted_df`; no `@calibration` attribute |
| DF-3 | `calibrate_poststrat(plain_df, targets_df)` | Output is `weighted_df`; no `@calibration` attribute |

---

### Regression — existing error classes still thrown (no regressions)

| # | Scenario | Expected |
|---|----------|----------|
| REG-1 | `calibrate_greg(list(), targets)` | `surveywts_error_unsupported_class` (not `surveywts_error_replicate_not_supported`) |
| REG-2 | `calibrate_greg(survey_replicate_obj, targets)` | No `surveywts_error_replicate_not_supported` — this is the key regression test confirming the class is now accepted |
| REG-3 | Existing `survey_taylor` happy path still works | Calibrated weights match oracle within 1e-8 (survey package) |

---

### Gotchas from comprehension.md — explicit test mapping

| Gotcha | Test(s) covering it | Out of scope? |
|--------|---------------------|---------------|
| Per-replicate re-calibration mandatory | HR-6, HR-8, RR-1, PR-2 — verify each replicate column is independently calibrated | No |
| Variance formula requires GREG residuals | CS-5 (g_weights), CS-6 (crossproduct_inv), GW-1 — fields needed to compute a_k * e_k are present | No |
| GREG residuals valid for raking and post-stratification | RT-5 (x_matrix stored for raking), PT-6 (x_matrix stored for poststrat) | No |
| Singular T_s / empty calibration cell | SX-1, SX-2 | No |
| Negative replicate weights in BRR | HB-1, HB-2, HB-3 | No |
| Empty calibration cell in a replicate | SX-1, RC-2 | No |
| Standard linearization without calibration adjustment | CS-4, CS-5, CS-6, PT-4, PT-5 (cell_factors stored) | No |
| GREG weights can be negative | GW-3, existing `surveywts_warning_negative_calibrated_weights` test | No |
| Newton overshoot for bounded distance functions | Covered by existing convergence error test (logit model) | No |
| Redundant raking equation | Not a new concern; existing engine handles it; no new test needed | Yes — existing engine unchanged |
| Single-PSU strata | Not introduced by this feature; no new test needed | Yes — orthogonal to @calibration population |
| q_k defaults to 1 | CS-9 — `q_weights` all-ones | No |
| @calibration carries no per-outcome residuals | CS-2 (e_k not in field list) — verify no `residuals` field in `@calibration` | No |

---

## Tolerances

| Estimand | Tolerance | Justification |
|----------|-----------|---------------|
| Weight computations (g_weights, constraint check) | 1e-10 | Package default per `testing-surveywts.md` |
| Numerical correctness vs `survey` package | 1e-8 | Package default per `testing-surveywts.md` |
| Calibration constraint `t(X) %*% w = Z` | 1e-6 | Looser than weight tolerance; constraint is satisfied to `control$epsilon` (default 1e-7) plus floating-point accumulation; 1e-6 is conservative |
| `crossproduct_inv` identity check (`C^{-1} * C == I`) | 1e-8 | Matrix inversion introduces floating-point error; 1e-8 matches SE tolerance |
| `cell_factors` values | 1e-10 | Direct ratio computation; machine precision applies |

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED — pre-pkgdown release phase
- [ ] `covr::package_coverage()` — ≥ 95% (target 98%)
