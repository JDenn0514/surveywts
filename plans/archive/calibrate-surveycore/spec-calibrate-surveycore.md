# Spec — calibrate-surveycore

**Status**: SPEC_READY
**Spec version**: 1.1
**Target version**: 0.6.0.9000
**PR range**: PR 1–2

---

## Scope

### In

| Item | Description |
|------|-------------|
| `@calibration` population | Populate `@calibration` on `survey_taylor` and `survey_nonprob` outputs from all three calibration functions |
| `survey_replicate` support | Accept `survey_replicate` inputs; apply calibration independently to every replicate weight column using the same population targets |
| `.build_calibration_provenance()` | New internal helper that assembles the `@calibration` list from engine results |
| `.update_survey_weights()` extension | Add a `caldata` argument so callers can set `@calibration` in a single call |
| `.check_input_class()` change | Remove the hard error for `survey_replicate`; it is now a supported input class for the four calibrate functions |
| New warning class | `surveywts_warning_replicate_calibration_failed` — emitted when one replicate column fails calibration; processing continues |
| `calibrate_greg()` | Modified to populate `@calibration` and handle `survey_replicate` |
| `calibrate_rake()` | Modified to populate `@calibration` and handle `survey_replicate` |
| `calibrate_poststrat()` | Modified to populate `@calibration` and handle `survey_replicate` |
| `calibrate()` dispatcher | Passes through unchanged; inherits behavior from dispatched function |

### Out

| Item | Reason |
|------|--------|
| surveycore variance routines | They read `@calibration`; this spec only writes it |
| `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse()` | Separate functions; `survey_replicate` support remains blocked there |
| `as_caldata()` | surveycore function; out of scope |
| Changing point-estimate computations | No change to calibrated weight values |
| `survey_replicate` support outside the four calibrate functions | Scope-bounded to calibration family only |
| Changing `.calibrate_engine()` internals | Engine is not modified; only callers change |

---

## Architecture

### Files touched

| File | Change |
|------|--------|
| `R/calibrate_greg.R` | Modified — add `@calibration` population and `survey_replicate` loop |
| `R/calibrate_rake.R` | Modified — add `@calibration` population and `survey_replicate` loop |
| `R/calibrate_poststrat.R` | Modified — add `@calibration` population and `survey_replicate` loop |
| `R/calibrate.R` | No change — thin dispatcher; inherits behavior |
| `R/calibrate-utils.R` | Modified — add `.build_calibration_provenance()` |
| `R/utils.R` | Modified — extend `.update_survey_weights()` with `caldata` argument; modify `.check_input_class()` to allow `survey_replicate` |
| `plans/error-messages.md` | Modified — add `surveywts_warning_replicate_calibration_failed` |

### Functions added

- `.build_calibration_provenance(engine_result, x_matrix, base_weights, q_weights, population_totals, method, cell_factors)` — `R/calibrate-utils.R`

### Functions modified

- `.check_input_class(data)` — remove `survey_replicate` branch
- `.update_survey_weights(design, new_weights_vec, history_entry, caldata = NULL)` — add `caldata` parameter
- `calibrate_greg()` — add `@calibration` provenance and replicate loop
- `calibrate_rake()` — add `@calibration` provenance and replicate loop
- `calibrate_poststrat()` — add `@calibration` provenance and replicate loop

### Class changes

None. `@calibration` property already exists on `survey_taylor`, `survey_replicate`, and `survey_nonprob` (all typed `default = NULL`). This spec populates it.

---

## `@calibration` list contract

This is the cross-package contract between surveywts and surveycore's variance routines. The exact field names, types, and semantics defined here are the authoritative definition. Surveycore reads this list at variance estimation time; surveywts writes it at calibration time.

```
@calibration = list(
  x_matrix         = <n x J numeric matrix>,
  base_weights     = <numeric length-n>,
  g_weights        = <numeric length-n>,
  crossproduct_inv = <J x J numeric matrix>,
  population_totals = <numeric length-J>,
  discrepancy      = <numeric length-J>,
  lambda           = <numeric length-J or NULL>,
  method           = <character(1)>,
  cell_factors     = <named numeric or NULL>,
  q_weights        = <numeric length-n>,
  converged        = <logical(1)>,
  n_iterations     = <integer(1)>,
  # survey_replicate only:
  replicate_converged = <named logical or NULL>
)
```

### Field-by-field contract

| Field | Type | Shape | Semantics |
|-------|------|-------|-----------|
| `x_matrix` | `numeric` matrix | n × J | Calibration model matrix. For GREG and raking: `stats::model.matrix()` output using treatment contrasts (intercept + k−1 dummies per factor/variable). For post-stratification: full cross-cell indicator dummies. Required by surveycore to compute GREG residuals at analysis time. |
| `base_weights` | `numeric` | length n | Pre-calibration design weights (d_k). Required by surveycore to compute T_s and B_hat_s. |
| `g_weights` | `numeric` | length n | G-weights a_k = calibrated_weight_k / base_weight_k. Required by surveycore to form the linearized variable a_k * e_k. |
| `crossproduct_inv` | `numeric` matrix | J × J | Inverse of the weighted cross-product matrix: solve(t(x_matrix) %*% diag(base_weights * q_weights) %*% x_matrix). Required by surveycore to compute B_hat_s without re-inverting. |
| `population_totals` | `numeric` | length J | Known population totals in count scale (not proportions). Required for audit and computing discrepancy. |
| `discrepancy` | `numeric` | length J | Pre-calibration HT deficit: `population_totals` minus HT estimate at starting weights. Stored for diagnostics and lambda computation. **Not** the post-calibration residual (which approaches zero after convergence). |
| `lambda` | `numeric` or `NULL` | length J | Lagrange multiplier vector. For linear GREG: exact closed-form value. For raking: final Newton iterate. For post-stratification: `NULL` (cell factors used instead). |
| `method` | `character(1)` | scalar | One of `"linear"`, `"logit"`, `"raking"`, `"poststrat"`. The actual calibration method used. For `calibrate_greg()`, store the `model` argument directly (`"linear"` or `"logit"`). Both values select the GREG variance formula in surveycore; surveycore does not distinguish them for variance estimation. Allows surveycore to interpret `x_matrix` correctly. |
| `cell_factors` | named `numeric` or `NULL` | length C | Post-stratification cell ratios N_c / N_hat_c, one per cell. Names are cell label strings (paste of cell variable values, separated by `"//"`, matching the key construction in `calibrate_poststrat()`). `NULL` for non-poststrat methods. Required by surveycore for the Valliant (1993) adjusted linearization deviate. |
| `q_weights` | `numeric` | length n | Per-unit tuning constants q_k. Default: all ones. Stored so surveycore can reconstruct T_s when q_k differs from 1. |
| `converged` | `logical(1)` | scalar | `TRUE` if the calibration algorithm converged within `control$maxit`. For linear GREG: always `TRUE`. |
| `n_iterations` | `integer(1)` | scalar | Number of Newton iterations taken. For linear GREG: `1L`. |
| `replicate_converged` | named `logical` or `NULL` | length R | Present only when the input was `survey_replicate`. Named logical vector, one entry per replicate weight column. `FALSE` entries indicate calibration failed for that replicate; a `surveywts_warning_replicate_calibration_failed` is emitted for each failure. `NULL` for non-replicate inputs. |

### Why GREG residuals apply to all three methods

All calibration estimators are asymptotically equivalent to GREG (Deville and Sarndal 1992, Result 5; Deville, Sarndal and Sautory 1993, §4). The GREG variance estimator applies to raking and post-stratification outputs as well as linear GREG. Therefore `x_matrix`, `base_weights`, and `crossproduct_inv` must be stored regardless of which calibration method was used. The `method` field tells surveycore how to interpret the model matrix structure.

---

## Function contracts

### `.check_input_class(data)`

**Change from current behavior**: The `survey_replicate` branch that threw `surveywts_error_replicate_not_supported` is removed. `survey_replicate` is now a supported input class for the four calibrate functions.

**Post-change behavior**:
- `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`, `survey_replicate` — all pass
- Any other class → `surveywts_error_unsupported_class`

The error class `surveywts_error_replicate_not_supported` remains in `plans/error-messages.md` (it is used by other functions where replicate remains unsupported) but is no longer thrown by `.check_input_class()`.

---

### `.update_survey_weights(design, new_weights_vec, history_entry, caldata = NULL)`

**Signature**: `.update_survey_weights(design, new_weights_vec, history_entry, caldata = NULL)`

**New argument**:

| Argument | Type | Semantics |
|----------|------|-----------|
| `caldata` | named list or `NULL` | When non-`NULL`, a fully constructed `@calibration` list. Written to `design@calibration` before returning. `NULL` (default) leaves `@calibration` unchanged. |

**Behavior**:
1. Update `design@data[[weight_col]]` with `new_weights_vec` (existing behavior, unchanged)
2. Append `history_entry` to `design@metadata@weighting_history` (existing behavior, unchanged)
3. If `caldata` is non-`NULL`, set `design@calibration <- caldata`
4. Return the modified design object

**Returns**: survey object of the same class as `design` (class is preserved).

**Edge cases**:
- `survey_replicate` input: the weight column written is `design@variables$weights` (full-sample weight). Replicate weight columns are written separately by the caller before invoking `.update_survey_weights()`.
- `caldata = NULL`: `@calibration` is not touched; pre-existing `@calibration` value (if any) is preserved.

---

### `.build_calibration_provenance(engine_result, x_matrix, base_weights, q_weights, population_totals, method, cell_factors = NULL)`

**Location**: `R/calibrate-utils.R`

**Purpose**: Assembles the `@calibration` list from ingredients available after `.calibrate_engine()` returns. Called once per full-sample calibration by each of the three calibrate functions.

**Signature**:
```
.build_calibration_provenance(
  engine_result,
  x_matrix,
  base_weights,
  q_weights,
  population_totals,
  method,
  cell_factors = NULL
)
```

**Arguments**:

| Argument | Type | Semantics |
|----------|------|-----------|
| `engine_result` | named list | Return value from `.calibrate_engine()`: must contain `$weights` (calibrated weight vector) and `$convergence` (list with `$converged` and `$iterations` fields) |
| `x_matrix` | numeric matrix | n × J calibration model matrix built by the calling function from the data and calibration variables |
| `base_weights` | numeric | Length-n vector of pre-calibration weights (d_k) |
| `q_weights` | numeric | Length-n vector of per-unit tuning constants (default: `rep(1, n)`) |
| `population_totals` | numeric | Length-J vector of population totals in count scale |
| `method` | character(1) | One of `"linear"`, `"raking"`, `"poststrat"` |
| `cell_factors` | named numeric or `NULL` | Cell ratios N_c / N_hat_c for post-stratification. `NULL` for non-poststrat methods. |

**Returns**: A named list conforming exactly to the `@calibration` contract defined above (all fields populated; `replicate_converged` is not included — callers add it when needed for `survey_replicate` inputs). Returned visibly (not `invisible()`) so the caller can assign the result directly: `caldata <- .build_calibration_provenance(...)`.

**Computed fields**:
- `g_weights`: `engine_result$weights / base_weights`. When `base_weights[k] == 0`, `g_weights[k]` is `NaN` (cannot divide by zero; this cannot occur under `.validate_weights()` since starting weights are strictly positive, but `.build_calibration_provenance()` must not error on this defensively).
- `discrepancy`: `population_totals - drop(t(x_matrix) %*% base_weights)` — the HT estimate of each population total from the base weights, subtracted from the known total.
- `crossproduct_inv`: `solve(t(x_matrix) %*% (base_weights * q_weights * x_matrix))`. If singular, the engine would have already failed; `.build_calibration_provenance()` does not need a separate singularity check. For post-stratification, this is computed from the cell-indicator columns of `x_matrix`.
- `lambda`: For linear GREG, the Lagrange multiplier is `crossproduct_inv %*% discrepancy`. For raking: `NULL` (convergence is iterative; the lambda concept does not apply to the multiplicative form). For post-stratification: `NULL` (cell factors are stored instead).
- `converged`: `engine_result$convergence$converged`
- `n_iterations`: `as.integer(engine_result$convergence$iterations)`. For linear GREG, `.calibrate_engine()` returns `iterations = 1L` (closed-form, one step). For logit GREG, `.calibrate_engine()` returns `iterations = NA_integer_` — `survey::calibrate()` performs the Newton-Raphson internally without exposing an iteration count. Store whatever the engine returns: `1L` for linear, `NA_integer_` for logit.

**No errors thrown**: All validation (singularity, positivity, convergence) is the responsibility of the calling function or `.calibrate_engine()`. `.build_calibration_provenance()` is a pure assembly function.

---

### `calibrate_greg(data, targets, weights, wt_name, model, type, control, reference_design)`

**Signature**: Unchanged from current. No new arguments.

**What changes** (behavior differences from current implementation):

#### When `data` is `survey_taylor` or `survey_nonprob`

After computing `new_weights` from `.calibrate_engine()`:

1. Build `x_matrix` — the calibration model matrix used by the engine. This is the `model.matrix()` output that was fed to `survey::calibrate()` (for linear/logit models), or the margin-indicator matrix (for the IPF path if raking engine is invoked — not applicable here since `calibrate_greg` only uses linear/logit).
2. Call `.build_calibration_provenance()` with the engine result, `x_matrix`, `base_weights = weights_vec` (pre-calibration weights), `q_weights = rep(1, n)` (default; no `q_weights` argument is exposed in `calibrate_greg()`), `population_totals` in count scale, `method = model` (pass the `model` argument value directly: `"linear"` or `"logit"`), `cell_factors = NULL`.
3. Call `.update_survey_weights(data, new_weights, history_entry, caldata = caldata)` instead of the current `.update_survey_weights(data, new_weights, history_entry)`.

**Model-to-method mapping for `@calibration$method`**: Store `model` directly — `"linear"` or `"logit"`. Both are GREG estimators; surveycore uses both values to select the GREG variance formula. The four valid method values are `"linear"`, `"logit"`, `"raking"`, `"poststrat"`.

#### When `data` is `survey_replicate`

After computing the full-sample calibration (steps 1–13 in the current implementation):

1. Build `caldata` as above (full-sample `@calibration`).
2. Add `replicate_converged` field to `caldata` (initialized as named logical vector of length R, all `TRUE`, names = `design@variables$repweights`).
3. For each replicate weight column `repweights_col` in `design@variables$repweights`:
   a. Extract replicate weight vector `rep_wt <- design@data[[repweights_col]]`.
   b. Do NOT validate positivity of `rep_wt` — negative BRR replicate weights are valid.
   c. Convert proportions to counts using the same `total_w` from the full-sample calibration (same population targets, same scale).
   d. Run the calibration engine with `weights_vec = rep_wt` and the same `calibration_spec` as the full-sample calibration.
   e. On success: write `rep_calibrated_weights` back to `design@data[[repweights_col]] <- rep_calibrated_weights`.
   f. On failure (any error from `.calibrate_engine()`): catch the error, set `caldata$replicate_converged[[repweights_col]] <- FALSE`, emit `surveywts_warning_replicate_calibration_failed` (see error table below), continue to next replicate.
4. Call `.update_survey_weights(design, new_weights, history_entry, caldata = caldata)`. This single call writes the full-sample weight column, appends the history entry, and sets `@calibration`. Replicate columns were written directly in step 3e before this call.

**Return value for `survey_replicate` input**: `survey_replicate` (class preserved). When some replicates fail calibration (indicated by `FALSE` entries in `output@calibration$replicate_converged`), the returned object contains calibrated weights for successful replicates and uncalibrated (original) weights for failed replicates. Variance estimates computed from this object will silently mix calibrated and uncalibrated replicate draws. Users should inspect `output@calibration$replicate_converged` before proceeding with variance estimation and treat objects with any `FALSE` entries with caution.

#### When `data` is `data.frame` or `weighted_df`

No change from current behavior. `@calibration` is not set (only survey objects carry it).

#### Errors

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_unsupported_class` | `data` is not a `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`, or `survey_replicate` |
| `surveywts_error_empty_data` | `nrow(data) == 0` (or `nrow(data@data) == 0`) |
| `surveywts_error_weights_not_found` | Named weight column missing from data |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | Main weight column has values ≤ 0 (replicate columns exempt) |
| `surveywts_error_weights_na` | Main weight column has `NA` values |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_targets_variable_not_found` | A `targets` name not in `data` |
| `surveywts_error_variable_not_categorical` | A calibration variable is numeric or integer |
| `surveywts_error_variable_has_na` | A calibration variable has `NA` values |
| `surveywts_error_population_level_missing` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | A `targets` level absent from data |
| `surveywts_error_population_totals_invalid` | Proportions don't sum to 1, or count target ≤ 0 |
| `surveywts_error_calibration_not_converged` | Full-sample calibration fails to converge (not replicate-level — replicate failures become warnings) |
| `surveywts_error_reference_design_not_taylor` | `reference_design` non-`NULL` and not `survey_taylor` |
| `surveywts_error_margins_format_invalid` | `targets` is not a valid named list or long data frame |

#### Warnings

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_negative_calibrated_weights` | Linear calibration produced negative calibrated weights (main weight column only) |
| `surveywts_warning_control_param_ignored` | An unrecognized key in `control` |
| `surveywts_warning_replicate_calibration_failed` | Calibration failed for a specific replicate weight column; message identifies the column name and error condition. One warning per failed replicate. |

#### Edge cases

| Input | Behavior |
|-------|----------|
| `survey_replicate` with R replicate columns, all fail | Calibration of the full-sample weights succeeds; all `replicate_converged` entries are `FALSE`; R warnings emitted; output is returned (not errored) |
| `survey_replicate` with negative BRR replicate weights | Positivity check is suppressed for replicate columns; negative values pass through to the engine |
| `survey_replicate` with 0 replicate columns | Replicate loop runs zero iterations; `replicate_converged` is a named logical of length 0 |
| `survey_nonprob` input | `@calibration` populated identically to `survey_taylor`; no replicate loop (nonprob has no `@variables$repweights`) |
| `data.frame` / `weighted_df` input | `@calibration` not set; existing behavior unchanged |
| Single-row input | Full-sample calibration runs; if it converges, output is returned normally |
| All calibration variables have a single level | Engine returns unchanged weights (trivially calibrated); `converged = TRUE`, `n_iterations = 1L` |

---

### `calibrate_rake(data, targets, weights, wt_name, type, algorithm, cap, control, reference_design)`

**Signature**: Unchanged. No new arguments.

**What changes**: Identical in structure to `calibrate_greg()` above. The following differences apply to the method-specific provenance:

- `method` in `@calibration`: `"raking"` for all `algorithm` values
- `lambda` in `@calibration`: `NULL` (raking uses the multiplicative form; Lagrange multipliers are iteratively updated but are not stored). This deviates from the `@calibration` list structure in `comprehension.md`, which suggested storing the final Newton iterate. Lambda is not required for variance estimation — the GREG-equivalent linearization uses `g_weights`, `x_matrix`, `crossproduct_inv`, and `base_weights` only (DS1992 Result 5); storing `NULL` reduces implementation complexity without affecting downstream correctness.
- `x_matrix`: model matrix using treatment contrasts, built via `stats::model.matrix(formula, data = data_df)` where `formula` is constructed from raking variable names (e.g., `~ v1 + v2 + ...`). J = 1 + Σ(m_j − 1) across all raking variables. The intercept column's population total equals the sum of design weights (≈ N); each treatment-contrast dummy's population total equals the marginal count for that level in count scale. This is the same parameterization used by `calibrate_greg()`.
- `cell_factors`: `NULL`
- `q_weights`: `rep(1, nrow(data))` (no q_weights argument in `calibrate_rake()`)

The replicate loop for `survey_replicate` inputs runs the raking engine with the same `algorithm`, `cap`, and `control` as the full-sample calibration.

#### Errors

Same as `calibrate_greg()` plus:

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_cap_not_supported_survey` | `cap` specified with `algorithm = "survey"` |

#### Warnings

Same as `calibrate_greg()` plus:

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_replicate_calibration_failed` | Raking failed for a specific replicate column (non-convergence or empty margin cell within that replicate) |

#### Edge cases

Same as `calibrate_greg()` with the addition:

| Input | Behavior |
|-------|----------|
| `survey_replicate` with a replicate whose effective sample creates an empty raking margin | The margin calibration fails; `surveywts_warning_replicate_calibration_failed` is emitted; processing continues for remaining replicates |

---

### `calibrate_poststrat(data, targets, weights, wt_name, type, reference_design)`

**Signature**: Unchanged. No new arguments.

**What changes**: Identical in structure to `calibrate_greg()`. Method-specific provenance:

- `method` in `@calibration`: `"poststrat"`
- `lambda` in `@calibration`: `NULL`
- `x_matrix`: full cross-cell indicator matrix (n × C), one column per unique cell combination in `targets`. For unit k in cell c, `x_matrix[k, c] = 1`; all other entries 0.
- `cell_factors`: named numeric vector of length C. Names use the same `"//"` key format as the existing key construction in `calibrate_poststrat()`. Values: `N_c / N_hat_c` for each cell c, where `N_hat_c = sum(base_weights[data_keys == pop_keys[c]])`.
- `q_weights`: `rep(1, nrow(data))`

The replicate loop for `survey_replicate` inputs applies post-stratification to each replicate weight column. For a given replicate, if a cell's HT estimate `N_hat_c^(r) = sum(rep_wt[cell_c_indices])` is zero or negative (all units in that cell have zero or negative replicate weight — a valid BRR scenario), calibration fails for that replicate and `surveywts_warning_replicate_calibration_failed` is emitted.

#### Errors

Same as `calibrate_greg()` plus post-stratification specific:

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_margins_format_invalid` | `targets` is not a `data.frame` |
| `surveywts_error_no_strata_variables` | `targets` has zero non-`"target"` columns |
| `surveywts_error_population_cell_duplicate` | A cell combination appears > once in `targets` |
| `surveywts_error_population_cell_missing` | A data cell has no row in `targets` |
| `surveywts_error_population_cell_not_in_data` | A `targets` cell has no observations in data |
| `surveywts_error_empty_stratum` | A stratum cell has zero weighted count (full-sample only; replicate analog becomes a warning) |

#### Warnings

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_replicate_calibration_failed` | Post-stratification failed for a replicate (empty cell within the replicate's effective sample) |

---

### `calibrate(data, targets, weights, wt_name, type, reference_design, ..., method)`

**No change to signature or behavior.** This is a thin dispatcher. All changes flow through the dispatched function. Document for completeness:

- `method = "greg"` → `calibrate_greg()` (which now supports `survey_replicate`)
- `method = "rake"` → `calibrate_rake()` (which now supports `survey_replicate`)
- `method = "poststrat"` → `calibrate_poststrat()` (which now supports `survey_replicate`)

The `survey_replicate` input will be passed through to the dispatched function without modification.

---

## `@calibration` provenance — method-specific x_matrix construction

The following table specifies how `x_matrix` is built for each method. The builder constructs this matrix in the calibrate function before calling `.build_calibration_provenance()`.

| Method | `x_matrix` construction | J |
|--------|------------------------|---|
| `calibrate_greg(model = "linear")` | `stats::model.matrix(formula, data = plain_df)` (with intercept; same formula as passed to `survey::calibrate()`; factors set to levels from `targets`) | ncol(model.matrix output) |
| `calibrate_greg(model = "logit")` | Same as linear | ncol(model.matrix output) |
| `calibrate_rake()` | `stats::model.matrix(formula, data = data_df)` using treatment contrasts (intercept + k−1 dummies per variable), where `formula` is constructed from the names of raking variables (e.g., `~ v1 + v2`). Same construction as GREG. | 1 + Σ(m_j − 1) across all raking variables |
| `calibrate_poststrat()` | One column per unique cell (cross-tabulation of all strata variables). Column c: 1 if data unit is in cell c, 0 otherwise. | n_unique_cells |

**Note on GREG x_matrix**: The `model.matrix()` call uses treatment contrasts (intercept + k-1 dummies per factor). The resulting J equals 1 + sum(n_levels - 1) for all variables. This is the same matrix the engine uses internally when calling `survey::calibrate()`. The `population_totals` vector matches the column names of this matrix exactly.

**Note on raking x_matrix**: Treatment contrasts (same as `calibrate_greg()`) are used. Full dummy encoding is rank-deficient for any raking calibration with 2+ variables — for each variable v_j, the sum of its m_j indicator columns equals the all-ones vector, producing a linear dependency among all indicator columns that causes `solve()` to fail regardless of whether any margin cell is empty. Treatment contrasts avoid this: J = 1 + Σ(m_j − 1) columns, which is non-singular for any non-empty level. The `population_totals` vector is parameterized accordingly: the intercept column's total is the sum of design weights (≈ N), and each contrast column's total is the marginal count for that level in count scale.

---

## `surveywts_warning_replicate_calibration_failed` — message template

```
"!" = "Calibration failed for replicate column {.field {repweights_col}}."
"i" = "Reason: {conditionMessage(e)}"
"i" = "This replicate's calibrated weights are not updated; base weights are retained for this column."
```

Class: `"surveywts_warning_replicate_calibration_failed"`

One warning is emitted per failed replicate column. The warning carries a `call. = FALSE` equivalent (no call context in the message). The returned object has `@calibration$replicate_converged[[repweights_col]] == FALSE` for each failed replicate.

---

## Quality gates

1. For every `survey_taylor` output of any calibrate function: `!is.null(output@calibration)`, `is.list(output@calibration)`, and all required fields in the `@calibration` contract are present.
2. For every `survey_nonprob` output: same as above.
3. For every `survey_replicate` output: `!is.null(output@calibration)`, `!is.null(output@calibration$replicate_converged)`, `length(output@calibration$replicate_converged) == length(output@variables$repweights)`.
4. For `survey_replicate` outputs: every replicate column named in `output@variables$repweights` has been overwritten in `output@data` (successful replicates have calibrated weights; failed replicates retain their pre-calibration values from the input).
5. The full-sample weight column in `output@data[[output@variables$weights]]` contains calibrated weights regardless of whether any replicate failed.
6. `g_weights` satisfies: `all.equal(caldata$g_weights * caldata$base_weights, calibrated_weights_vec)` within machine precision.
7. Calibration constraint: `t(caldata$x_matrix) %*% calibrated_weights_vec` equals `caldata$population_totals` within `control$epsilon` (verified at quality-gate time, not stored).
8. `data.frame` and `weighted_df` outputs: `@calibration` is not set (these classes do not carry it).

## Pipeline split

`recommended` — introduces a new internal helper (`.build_calibration_provenance()`), modifies three exported functions (`calibrate_greg`, `calibrate_rake`, `calibrate_poststrat`), extends two internal helpers, and touches 6+ files. The replicate loop is a non-trivial behavioral addition.

---

## References

- Deville, J.C.; Sarndal, C.E. (1992). Calibration Estimators in Survey Sampling. *Journal of the American Statistical Association*, Vol. 87, No. 418, pp. 376–382. http://links.jstor.org/sici?sici=0162-1459%28199206%2987%3A418%3C376%3ACEISS%3E2.0.CO%3B2-3
- Deville, J.-C.; Sarndal, C.-E.; Sautory, O. (1993). Generalized Raking Procedures in Survey Sampling. *Journal of the American Statistical Association*, Vol. 88, No. 423, pp. 1013–1020. https://www.jstor.org/stable/2290793
- Rao, J.N.K.; Yung, W.; Hidiroglou, M.A. (2002). Estimating Equations for the Analysis of Survey Data Using Poststratification Information. *Sankhya: The Indian Journal of Statistics (San Antonio Conference: Selected Articles)*, Volume 64, Series A, Pt. 2, pp. 364–378. DOI: [unavailable]
- Valliant, R. (1993). Poststratification and Conditional Variance Estimation. *Journal of the American Statistical Association*, 88(421), 89–96. https://doi.org/10.2307/2290701
- Rao, J.N.K.; Wu, C.F.J.; Yue, K. (1992). Some Recent Work on Resampling Methods for Complex Surveys. *Survey Methodology*, Vol. 18, No. 2, pp. 209–217. DOI: [unavailable]
