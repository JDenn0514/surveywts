# surveywts Nonresponse Phase Spec

**Version:** 0.5 — Approved
**Date:** 2026-05-13
**Status:** Methodology Locked — Ready for Implementation
**ID:** `nonresponse`

---

## Document Purpose

This spec is the source of truth for the Nonresponse phase of surveywts. It governs the
design and implementation of sample-based calibration functions, a general weight
redistribution primitive, and the `propensity-cell` extension to `adjust_nonresponse()`.

Every implementation decision, API contract, and error condition for this phase must be
resolved here before any R code is written. The Implementation Plan derives from this
document and must not deviate from it without a documented decision.

---

## I. Scope

### Deliverables

| Deliverable | Function | Source file |
|-------------|----------|-------------|
| Sample-based calibration (replicate ↔ replicate) | `calibrate_to_survey()` | `R/sample-calibration.R` (new) |
| Sample-based calibration (estimate + covariance) | `calibrate_to_estimate()` | `R/sample-calibration.R` (new) |
| General weight redistribution primitive | `redistribute_weights()` | `R/nonresponse.R` (extend) |
| Nonresponse: propensity-cell method | `adjust_nonresponse(method = "propensity-cell")` | `R/nonresponse.R` (extend) |

### What This Phase Does NOT Deliver

- `method = "propensity"` in `adjust_nonresponse()` — remains a stub; requires Propensity
  phase infrastructure (`estimate_propensity()`, `create_propensity_weights()`)
- `trim_weights()` and `stabilize_weights()` — Utilities phase
- Balance diagnostics — Diagnostics phase
- `calibrate_nonresponse()` (calibrate respondent weights to match full-sample totals) —
  Propensity phase
- `calibrate_to_survey()` with a Taylor linearization control design — out of scope for
  this phase; users should compute estimated totals + covariance and use
  `calibrate_to_estimate()` instead

### Roadmap Ambiguity: Propensity Methods in Nonresponse vs. Propensity Phase

The roadmap (§ Nonresponse) says both `propensity-cell` and `propensity` are unlocked in
this phase. The Propensity section also says "remove stub errors; both delegate to
`estimate_propensity()` + `create_propensity_weights()`."

**Decision:** `propensity-cell` is implemented here with a self-contained inline logistic
regression (no dependency on Propensity phase functions). `propensity` remains stubbed
until the Propensity phase (it genuinely requires `estimate_propensity()` +
`create_propensity_weights()`). The Propensity phase may refactor `propensity-cell` to
delegate to the new infrastructure — that is a Propensity phase decision.

### Input Class Support

| Function | `data.frame` | `weighted_df` | `survey_taylor` | `survey_nonprob` | `survey_replicate` |
|---|---|---|---|---|---|
| `calibrate_to_survey()` | — | — | — | — | ✅ (primary_design only) |
| `calibrate_to_estimate()` | — | — | — | — | ✅ |
| `redistribute_weights()` | ✅ | ✅ | ✅ | ✅ | ✗ (error) |
| `adjust_nonresponse()` (propensity-cell) | ✅ | ✅ | ✅ | ✅ | ✗ (existing error) |

For `calibrate_to_survey()`: `control_design` must also be `survey_replicate`. If
`control_design` is a Taylor or nonprob design, use `calibrate_to_estimate()` instead.

---

## II. Architecture

### Source File Map

```
R/
  sample-calibration.R    ← NEW: calibrate_to_survey(), calibrate_to_estimate()
  nonresponse.R           ← EXTEND: + redistribute_weights(), + propensity-cell branch
  utils.R                 ← EXTEND: + .to_svyrep_design(),
                                     + .validate_formula_variables(),
                                     + .validate_formula()
```

`R/sample-calibration.R` is a new file following the naming convention of existing
source files (no numeric prefix, per the pattern established in Calibration; the
roadmap's `06-` / `07-` prefixes were planning artifacts that were not used).

`R/nonresponse.R` is extended in place — no rename.

### New Shared Helpers in `R/utils.R`

| Helper | Signature | Used by |
|--------|-----------|---------|
| `.to_svyrep_design()` | `(design)` | `calibrate_to_survey()`, `calibrate_to_estimate()` |
| `.validate_formula_variables()` | `(formula, data, design_label)` | `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse()` |
| `.validate_formula()` | `(formula)` | `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse()` |

### Replicate Weight Structure (Reference)

`survey_replicate` stores replicate weights as columns in `@data`:

```
@data            — data frame; contains data columns + replicate weight columns
@variables$weights     — character(1): full-sample weight column name
@variables$repweights  — character vector: replicate weight column names ("rep_1", "rep_2", ...)
@variables$type        — character(1): scheme ("bootstrap", "JK1", "BRR", etc.)
@variables$scale       — numeric(1): variance scale factor
@variables$rscales     — numeric vector: per-replicate scale factors (length = n_rep)
```

The number of replicates is `length(@variables$repweights)`.

---

## III. `calibrate_to_survey()`

### Purpose

Calibrates a replicate primary design to estimated control totals from a replicate
control design. Propagates the variance of the estimated control totals into the
variance estimates by calibrating each replicate to the corresponding control replicate's
totals. Requires both designs to have the same number of replicates.

Reference implementation: `svrep::calibrate_to_sample()`.

### Signature

```r
calibrate_to_survey(
  primary_design,
  control_design,
  formula,
  method = c("raking", "linear", "logit"),
  bounds = list(lower = -Inf, upper = Inf),
  control = list(maxit = 50, epsilon = 1e-7)
)
```

### Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `primary_design` | `survey_replicate` | required | The design to calibrate. Must be `survey_replicate`. |
| `control_design` | `survey_replicate` | required | Provides control totals. Must be `survey_replicate` with the same number of replicates as `primary_design`. |
| `formula` | one-sided R formula | required | Specifies calibration variables, e.g. `~ age_group + sex`. Standard R formula; no NSE. Variables must exist in both `primary_design@data` and `control_design@data`. |
| `method` | `character(1)` | `"raking"` | `"raking"`: iterative multiplicative calibration (raking ratio; always positive weights). `"linear"`: one-step GREG (may produce negative weights). `"logit"`: bounded iterative (always positive). |
| `bounds` | named list | `list(lower = -Inf, upper = Inf)` | Weight bounds passed to svrep. `lower` and `upper` define the minimum and maximum calibrated weight values. Default is unbounded (no-op for raking and linear calibration). For `method = "logit"`, set finite bounds to constrain calibrated weights within a specified range. Document in `@details`: when `method = "logit"`, both `bounds$lower` and `bounds$upper` must be finite; the default infinite bounds will cause `survey::cal.logit` to fail with a raw survey package error rather than a surveywts-classed one. |
| `control` | named list | `list(maxit = 50, epsilon = 1e-7)` | Convergence parameters, merged with defaults. Applies to every individual calibration call (full-sample + each replicate). |

### Output Contract

Returns a `survey_replicate` with:
- Full-sample weights (`@data[[primary_design@variables$weights]]`) calibrated to
  full-sample control totals from `control_design`
- Each replicate weight column (`@data[[repweights[r]]]`) calibrated to the
  corresponding replicate's control totals from `control_design`
- `@variables` unchanged (same `repweights` column names, same `type`, `scale`,
  `rscales`, `mse`)
- `@metadata@weighting_history` with one new entry:
  `operation = "sample_calibration_replicate"` appended
- **Note:** The intercept constraint forces the calibrated weight sum to equal the
  control survey's weight sum (`sum(w_new) ≈ sum(control_design@data[[control_design@variables$weights]])`),
  not the primary design's original weight sum. This is expected calibration behavior,
  not a weight total preservation guarantee.

### Behavior Rules

1. Both `primary_design` and `control_design` must have the same number of replicates
   (`length(@variables$repweights)`). Mismatch → error.
2. If `primary_design@variables$type ≠ control_design@variables$type`, warn with
   `surveywts_warning_replicate_scheme_mismatch`. Mismatched schemes (e.g., bootstrap
   vs. BRR) may produce non-standard variance estimates due to scale-factor differences.
   Proceed after warning — the user may have legitimate reasons (e.g., scheme names
   differ by convention: `"boot"` vs. `"bootstrap"`).
3. All variables named in `formula` must exist in BOTH `@data` sets. Missing in either
   design → error (separate error for each design).
4. Both designs are converted to `svyrep.design` objects via `.to_svyrep_design()`.
5. `svrep::calibrate_to_sample()` is called with `primary_rep_design`, `control_rep_design`,
   `cal_formula = formula`, `calfun` derived from `method` (`survey::cal.raking` for
   `"raking"`, `survey::cal.linear` for `"linear"`, `survey::cal.logit` for `"logit"`),
   `bounds` (the `lower`/`upper` list), and `maxit`/`epsilon` from `control`.
6. Updated full-sample and replicate weights are extracted from the `svyrep.design` result
   and written back into `primary_design`.
7. If `svrep::calibrate_to_sample()` throws a calibration error, catch it and re-throw as
   `surveywts_error_calibration_not_converged`.
8. If `method = "linear"` produces negative weights in the full-sample calibration,
   warn with `surveywts_warning_negative_calibrated_weights`. Do NOT warn for individual
   replicate calibrations — this would produce up to `R` warnings; a single summary
   warning for the full-sample calibration is sufficient.
9. The history entry records: `formula` as a character string (`deparse(formula)`),
   `method`, `n_replicates`, `control_design` class and number of replicates.
10. `wt_name` is not applicable — this function only operates on survey objects.

### Error Table

| Error class | Condition |
|---|---|
| `surveywts_error_primary_not_replicate` | `primary_design` is not `survey_replicate` |
| `surveywts_error_control_not_replicate` | `control_design` is not `survey_replicate` |
| `surveywts_error_replicate_count_mismatch` | `primary_design` and `control_design` have different numbers of replicates |
| `surveywts_error_formula_variable_not_found` | A variable in `formula` is not in `primary_design@data` or `control_design@data` (include design label in message) |
| `surveywts_error_formula_invalid` | `formula` is not a valid one-sided R formula object |
| `surveywts_error_calibration_not_converged` | Full-sample or replicate calibration did not converge (reuse existing class) |

### Warning Table

| Warning class | Condition |
|---|---|
| `surveywts_warning_negative_calibrated_weights` | Full-sample linear calibration produced negative weights (reuse existing class) |
| `surveywts_warning_replicate_scheme_mismatch` | `primary_design@variables$type ≠ control_design@variables$type` |

### Example

```r
# primary_design: survey_replicate with 500 bootstrap replicates
# control_design: survey_replicate from a reference survey, also 500 replicates
result <- calibrate_to_survey(
  primary_design = my_bootstrap,
  control_design = acs_bootstrap,
  formula = ~ age_group + sex + region
)
```

---

## IV. `calibrate_to_estimate()`

### Purpose

Calibrates a replicate design to control totals specified as a point estimate vector and
an associated covariance matrix. Used when the control survey is not available as a live
design object (e.g., published table with standard errors, or a Taylor-linearized design
where only the estimated totals are available).

The function propagates uncertainty in the control totals by perturbing the targets for
each replicate using the covariance structure.

Reference implementation: `svrep::calibrate_to_estimate()`.

### Signature

```r
calibrate_to_estimate(
  design,
  formula,
  estimate,
  vcov_estimate,
  method = c("raking", "linear", "logit"),
  bounds = list(lower = -Inf, upper = Inf),
  control = list(maxit = 50, epsilon = 1e-7)
)
```

### Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `design` | `survey_replicate` | required | The design to calibrate. Must be `survey_replicate`. |
| `formula` | one-sided R formula | required | Specifies calibration variables, e.g. `~ age_group + sex`. Defines the model matrix; `estimate` names must match the non-intercept columns of `model.matrix(formula, design@data)`. |
| `estimate` | named `numeric` vector | required | Point estimates of the control totals. Names must match the non-intercept columns of `model.matrix(formula, design@data)`. |
| `vcov_estimate` | numeric matrix | required | Variance-covariance matrix of `estimate`. Must be symmetric positive definite with `nrow == ncol == length(estimate)`. Singular (PSD but not PD) matrices will cause Cholesky factorization to fail with `surveywts_error_vcov_cholesky_failed`. |
| `method` | `character(1)` | `"raking"` | `"raking"`, `"linear"`, or `"logit"`. Same semantics as `calibrate_to_survey()`. |
| `bounds` | named list | `list(lower = -Inf, upper = Inf)` | Weight bounds passed to svrep. Same semantics as `calibrate_to_survey()`. |
| `control` | named list | `list(maxit = 50, epsilon = 1e-7)` | Convergence parameters, merged with defaults. |

### Output Contract

Returns a `survey_replicate` with:
- Full-sample weights calibrated to `estimate` (the point estimates)
- Each replicate weight column calibrated to a perturbed version of `estimate`
  (perturbation derived from `vcov_estimate` and the replicate's scale factor)
- `@metadata@weighting_history` with one new entry:
  `operation = "sample_calibration_estimate"` appended

### Behavior Rules

1. `design` must be `survey_replicate`. Other classes → error.
2. `estimate` must be a named numeric vector. Names must exactly match the
   non-intercept column names of `model.matrix(formula, design@data)`. Mismatch → error.
2a. `estimate` must not contain any `NA` values. Any `NA` → `surveywts_error_estimate_has_na`.
3. `vcov_estimate` must be a numeric matrix with dimensions `p × p` where
   `p = length(estimate)`. Check `anyNA(vcov_estimate)` first — any NA →
   `surveywts_error_vcov_has_na`. Must be symmetric (checked to tolerance `1e-8`).
   No NAs. Non-positive-definite matrices will cause Cholesky factorization to fail —
   catch and re-throw as `surveywts_error_vcov_cholesky_failed`.
4. All variables named in `formula` must exist in `design@data`. Missing → error.
5. `design` is converted to a `svyrep.design` via `.to_svyrep_design()`.
   `svrep::calibrate_to_estimate()` is called with `rep_design`, `estimate`,
   `vcov_estimate`, `cal_formula = formula`, `calfun` derived from `method`
   (`survey::cal.raking` for `"raking"`, `survey::cal.linear` for `"linear"`,
   `survey::cal.logit` for `"logit"`), `bounds` (the `lower`/`upper` list),
   and `maxit`/`epsilon` from `control`.
   The perturbation of control totals across replicates — including Cholesky
   factorization and replicate-type-specific scaling — is handled entirely by `svrep`.

6. Updated weights are extracted from the `svyrep.design` result and written back into
   `design`. Same convergence-error and negative-weight-warning rules as
   `calibrate_to_survey()` (rules 6 and 7 from §III).
7. History entry records: `formula` as character, `method`, `n_replicates`,
   `estimate` names, `vcov` dimension.

### Error Table

| Error class | Condition |
|---|---|
| `surveywts_error_primary_not_replicate` | `design` is not `survey_replicate` |
| `surveywts_error_formula_variable_not_found` | A formula variable not in `design@data` |
| `surveywts_error_formula_invalid` | `formula` is not a valid one-sided formula |
| `surveywts_error_estimate_not_named` | `estimate` is not a named numeric vector |
| `surveywts_error_estimate_has_na` | `estimate` contains one or more `NA` values |
| `surveywts_error_estimate_length_mismatch` | `length(estimate)` ≠ number of non-intercept model matrix columns |
| `surveywts_error_estimate_names_mismatch` | `names(estimate)` do not match model matrix column names |
| `surveywts_error_vcov_dimension_mismatch` | `vcov_estimate` is not `p × p` |
| `surveywts_error_vcov_has_na` | `vcov_estimate` contains one or more `NA` values |
| `surveywts_error_vcov_not_symmetric` | `vcov_estimate` is not symmetric (tolerance `1e-8`) |
| `surveywts_error_vcov_cholesky_failed` | `vcov_estimate` is not positive definite (Cholesky factorization fails) |
| `surveywts_error_calibration_not_converged` | Any calibration failed to converge (reuse existing) |

### Warning Table

| Warning class | Condition |
|---|---|
| `surveywts_warning_negative_calibrated_weights` | Full-sample linear calibration produced negative weights (reuse existing) |

### Statistical Assumptions

The perturbation approach assumes the control totals are approximately multivariate
normally distributed — i.e., the sampling distribution of `estimate` can be
approximated by a multivariate normal with mean `estimate` and covariance
`vcov_estimate`. For large control surveys this is satisfied by the CLT. For small
control samples or non-normal sampling distributions, the perturbation may produce
misleading variance estimates. Document this assumption in the function's `@note`.

---

## V. `redistribute_weights()`

### Purpose

A general-purpose weight redistribution primitive. Sets the weights of rows satisfying
`reduce_if` to zero and redistributes their weight to rows satisfying `increase_if`,
proportionally by current weight, within groups defined by `by`.

This is the generalization of `adjust_nonresponse(method = "weighting-class")` — that
function's core logic is equivalent to calling `redistribute_weights()` with
`reduce_if = nonrespondent indicator` and `increase_if = respondent indicator`.

The equivalence is documented but `adjust_nonresponse()` does NOT refactor to call
`redistribute_weights()` internally (DRY rule applies when there are 2+ call sites;
`adjust_nonresponse()` is the only current call site). If a second call site emerges,
refactor then.

### Signature

```r
redistribute_weights(
  data,
  reduce_if,
  increase_if,
  weights = NULL,
  by = NULL,
  wt_name = "wts",
  control = list()
)
```

### Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `data` | `data.frame`, `weighted_df`, `survey_taylor`, or `survey_nonprob` | required | Input data. `survey_replicate` → error. |
| `reduce_if` | bare name (NSE) | required | Binary indicator column (`logical` or `integer` 0/1). Rows where this is `TRUE`/`1` have their weight set to 0. |
| `increase_if` | bare name (NSE) | required | Binary indicator column (`logical` or `integer` 0/1). Rows where this is `TRUE`/`1` receive the redistributed weight. |
| `weights` | bare name (NSE) | `NULL` | Weight column. Auto-detected from `weighted_df` attribute or `@variables$weights`. For plain `data.frame` with `NULL`, uniform starting weights are used. |
| `by` | `<tidy-select>` | `NULL` | Grouping variable(s). Redistribution is performed within each group. `NULL` → global redistribution. |
| `wt_name` | `character(1)` | `"wts"` | Output weight column name for `data.frame` / `weighted_df` inputs. Ignored for survey objects. |
| `control` | named list | `list()` | Merged with defaults `list(min_cell = 20, max_adjust = 2.0)`. `min_cell` and `max_adjust` are thresholds for the sparse-cell warning, following the same semantics as `adjust_nonresponse()`. |

**Constraint:** `reduce_if` and `increase_if` must be mutually exclusive — no row may
have both indicators set to `TRUE`. Overlap → error.

### Output Contract

- `data.frame` or `weighted_df` → `weighted_df` (all rows retained; `reduce_if` rows have weight 0)
- `survey_taylor` or `survey_nonprob` → same class as input, with `reduce_if` rows
  **filtered out** (zero-weight rows would violate the S7 strictly-positive-weights
  validator; filtering mirrors the behavior of `adjust_nonresponse()` weighting-class)
- History entry: `operation = "redistribute_weights"`, parameters include
  `reduce_col`, `increase_col`, `by_variables`, `method = "general_redistribution"`

### Redistribution Formula

Within each group `h` defined by `by`:

Let:
- `W_reduce` = sum of weights for `reduce_if` rows in group `h`
- `W_increase` = sum of weights for `increase_if` rows in group `h`
- `W_total` = `W_reduce + W_increase` (weight of all participating rows)

For each `increase_if` row `i` in group `h`:
```
new_weight_i = weight_i × (W_total / W_increase)
```

For each `reduce_if` row in group `h`:
```
new_weight = 0
```

Rows matching neither indicator: weights unchanged within the group.

### Behavior Rules

1. `reduce_if` and `increase_if` are validated via `.validate_response_status_binary()`
   (same binary validation as in `adjust_nonresponse()`). Both helpers reused.
2. NA in `reduce_if` or `increase_if` columns → error.
3. NA in `by` variables → error (same check as `adjust_nonresponse()`).
4. A group with no `increase_if` rows (but at least one `reduce_if` row) → error.
   A group with no `reduce_if` rows → weights unchanged for that group (no redistribution,
   no error).
5. `reduce_if` and `increase_if` share any row (both = TRUE) → error.
6. Sparse/extreme-adjustment warning fires under the same conditions as
   `adjust_nonresponse()`: `n_increase < control$min_cell` OR
   `W_total / W_increase > control$max_adjust` in any group.
7. If `wt_name` matches an existing column in `data` that is not the current weight
   column, throw `surveywts_error_wt_name_conflict`. Applies to `data.frame` and
   `weighted_df` inputs only (survey objects ignore `wt_name`).

### Error Table

| Error class | Condition |
|---|---|
| `surveywts_error_unsupported_class` | `data` is an unsupported class (including `survey_replicate`) |
| `surveywts_error_empty_data` | `nrow(data) == 0` (reuse existing) |
| `surveywts_error_weights_not_found` | Named weight column missing (reuse existing) |
| `surveywts_error_weights_not_numeric` | Weight column not numeric (reuse existing) |
| `surveywts_error_weights_nonpositive` | Weight column has non-positive values (reuse existing) |
| `surveywts_error_weights_na` | Weight column has NA (reuse existing) |
| `surveywts_error_wt_name_not_scalar` | `wt_name` not `character(1)` (reuse existing) |
| `surveywts_error_wt_name_empty` | `wt_name` is NA or `""` (reuse existing) |
| `surveywts_error_wt_name_conflict` | `wt_name` matches an existing non-weight column in `data` |
| `surveywts_error_reduce_if_not_found` | `reduce_if` column not in `data` |
| `surveywts_error_increase_if_not_found` | `increase_if` column not in `data` |
| `surveywts_error_reduce_if_not_binary` | `reduce_if` column is not binary (0/1 or logical) |
| `surveywts_error_increase_if_not_binary` | `increase_if` column is not binary |
| `surveywts_error_reduce_if_has_na` | `reduce_if` column has NA values |
| `surveywts_error_increase_if_has_na` | `increase_if` column has NA values |
| `surveywts_error_indicators_overlap` | A row has both `reduce_if = TRUE` and `increase_if = TRUE` |
| `surveywts_error_no_recipients_in_group` | A group has `reduce_if` rows but no `increase_if` rows |
| `surveywts_error_variable_has_na` | A `by` variable has NA values (reuse existing) |

### Warning Table

| Warning class | Condition |
|---|---|
| `surveywts_warning_class_near_empty` | A group has fewer than `control$min_cell` `increase_if` respondents OR `W_total / W_increase > control$max_adjust` (reuse existing) |

---

## VI. `adjust_nonresponse()` — Propensity-Cell Method

### What Changes

`adjust_nonresponse()` exists. This phase implements the `method = "propensity-cell"`
branch that currently stubs with `surveywts_error_propensity_not_available`.

The `"propensity"` method remains a stub until the Propensity phase.

### New Argument: `formula`

A new `formula` argument is added to `adjust_nonresponse()`:

```r
adjust_nonresponse(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  wt_name = "wts",
  method = c("weighting-class", "propensity-cell", "propensity"),
  formula = NULL,    # NEW — required when method = "propensity-cell"
  control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)
)
```

| Argument | Type | Default | Description |
|---|---|---|---|
| `formula` | one-sided R formula or `NULL` | `NULL` | Specifies propensity model covariates, e.g. `~ age_group + sex`. Required when `method = "propensity-cell"`. Ignored when `method = "weighting-class"`. Error if `method = "propensity-cell"` and `formula = NULL`. |

**`control` additions:**

| Key | Type | Default | Description |
|---|---|---|---|
| `n_cells` | `integer(1)` | `5` | Number of propensity score cells (quintiles by default). Must be ≥ 2. |
| `min_cell` | `integer(1)` | `20` | Existing: warn if fewer than this many respondents in a cell |
| `max_adjust` | `numeric(1)` | `2.0` | Existing: warn if adjustment factor exceeds this |

### Propensity-Cell Algorithm

1. **Fit propensity model:** `glm(response_status ~ RHS(formula), family = binomial,
   data = plain_df, weights = weights_vec)` where `RHS(formula)` is the right-hand side
   of the user-supplied formula. Uses `stats::glm()` — no new Imports.
2. **Predict propensity scores:** `predict(model, type = "response")` for ALL rows
   (respondents + nonrespondents).
3. **Define cell cutpoints:** `quantile(predicted_scores, probs = seq(0, 1, 1/n_cells))`.
   Cutpoints are computed from ALL rows' predicted scores (not just respondents).
4. **Assign cells:** `findInterval(predicted_scores, cutpoints, rightmost.closed = TRUE)`.
   Each unit assigned to cell `1` through `n_cells`.
5. **Redistribute within cells:** Same formula as `weighting-class`:
   `new_weight_i = weight_i × (W_cell / W_cell_resp)` for respondents,
   `new_weight_i = 0` for nonrespondents.
   Before redistribution, check that each cell contains at least one respondent. If any
   cell contains zero respondents, throw `surveywts_error_no_respondents_in_propensity_cell`
   with the cell index and the propensity score range of that cell in the message.
   Sparse/extreme-adjustment warning fires under same conditions as weighting-class.
6. **Return value:** Same output contract as `method = "weighting-class"`.
   History entry: `operation = "nonresponse_propensity_cell"`, parameters include
   `formula` (as character), `n_cells`. (`by` is not used and not recorded.)

### Behavior Notes

- `formula` must be a valid one-sided R formula. Call `.validate_formula(formula)` (shared helper from §VII) before fitting the model → `surveywts_error_formula_invalid`.
- Formula variables must exist in `plain_df`. Validate via `.validate_formula_variables(formula, plain_df, "data")` (shared helper from §VII) → `surveywts_error_formula_variable_not_found`.
- Formula variable NAs: `glm()` drops NA rows silently. To be consistent with the
  package's NA-intolerant stance, check for NAs in formula variables and error before
  fitting the model.
- `by` is ignored when `method = "propensity-cell"`. If the user specifies both
  `by` and `method = "propensity-cell"`, warn with `surveywts_warning_by_ignored_for_propensity_cell`.
  Do not silently discard — the user may have intended the weighting-class method.
- `survey_taylor` input: same respondent-only filtering applies as in the weighting-class
  method (zero weights violate the Taylor validator).
- `glm()` convergence warnings (e.g., from perfect separation or very sparse data)
  pass through unchanged — surveywts does not catch or re-wrap them. Document in
  `@details` that users should inspect their propensity model if this warning appears.

### Statistical Assumptions

- **MAR:** The propensity-cell method assumes nonresponse is Missing at Random (MAR)
  conditional on the propensity score. Within each cell, respondents and nonrespondents
  are assumed exchangeable for survey outcome variables. Bias reduction depends on how
  well the propensity model covariates predict both response propensity and survey
  outcomes. Document in `@note`.
- **Propensity as known:** Variance estimates after propensity-cell adjustment treat
  the estimated propensity scores as known and do not account for uncertainty from
  model estimation. This is standard practice for propensity-cell nonresponse
  adjustment but is a known limitation. Document in `@note`.
- **Unweighted quantiles:** Cell boundaries are defined by unweighted quantiles of
  the predicted scores (via `quantile()` + `findInterval()`), so each cell contains
  approximately the same number of sampled units. This matches the svrep reference
  implementation (`ntile()`) and the conventional approach (Rosenbaum & Rubin 1984;
  Little 1986). Do not switch to weighted quantiles. Document in `@details`.

### Error Table (New Errors Only)

| Error class | Condition |
|---|---|
| `surveywts_error_formula_required_for_propensity_cell` | `method = "propensity-cell"` but `formula = NULL` |
| `surveywts_error_formula_invalid` | `formula` is not a valid one-sided formula (reuse class from §III) |
| `surveywts_error_formula_variable_not_found` | A formula covariate not in `data` (reuse new class from §III) |
| `surveywts_error_formula_variable_has_na` | A formula covariate has NA values |
| `surveywts_error_n_cells_invalid` | `control$n_cells` is not a whole number ≥ 2 |
| `surveywts_error_no_respondents_in_propensity_cell` | A propensity cell contains zero respondents (cell index + propensity range in message) |

### Warning Table (New Warnings Only)

| Warning class | Condition |
|---|---|
| `surveywts_warning_by_ignored_for_propensity_cell` | `by` is non-NULL and `method = "propensity-cell"` |

---

## VII. Shared Helpers

### `.to_svyrep_design(design)`

Converts a `survey_replicate` to a `survey` package `svyrep.design` object — the input
format required by `svrep::calibrate_to_sample()` and `svrep::calibrate_to_estimate()`.

```
Arguments:
  design : survey_replicate

Returns: a `svyrep.design` (survey package class)
```

Lives in `R/utils.R`. Used by `calibrate_to_survey()` (twice: primary and control) and
`calibrate_to_estimate()`.

### `.validate_formula_variables(formula, data, design_label)`

Checks that all variables referenced in `formula` (via `all.vars()`) exist in `data`.
Throws `surveywts_error_formula_variable_not_found` on first missing variable. The
`design_label` argument (`"primary_design"` or `"control_design"`) is included in the
error message.

```
Arguments:
  formula      : one-sided R formula
  data         : data.frame
  design_label : character(1) — label for the error message

Returns: invisible(TRUE) on success. Throws on first missing variable.
```

### `.validate_formula(formula)`

Checks that `formula` is a valid one-sided R formula object. Throws
`surveywts_error_formula_invalid` if not.

---

## VIII. Testing

### Test File Map

| Source file | Test file |
|---|---|
| `R/sample-calibration.R` | `tests/testthat/test-sample-calibration.R` (new) |
| `R/nonresponse.R` (extensions) | `tests/testthat/test-05-nonresponse.R` (extend) |

All Layer 3 error paths use the dual pattern per testing-surveywts.md: `expect_error(class=)` + `expect_snapshot(error=TRUE)`.

### `calibrate_to_survey()` Test Categories

**1. Happy path**
- Both `survey_replicate` with matching replicates → returns `survey_replicate`
- Full-sample weights calibrated to control full-sample totals
- Each replicate calibrated to its corresponding control replicate totals
- History entry appended with correct `operation` and parameters
- `test_invariants()` called on result

**2. Numerical correctness**
- Calibrated full-sample weights satisfy the calibration constraints:
  `abs(sum(w_new * X) - sum(w_control * X)) < 1e-8` for all formula variables.
- Weight totals conserve to the control survey: `sum(w_new) ≈ sum(control_design@data[[control_design@variables$weights]])`, not `sum(w_original)` (intercept constraint forces alignment with control weight total).

**3. Error paths**
- `primary_design` is `survey_taylor` → `surveywts_error_primary_not_replicate`
- `control_design` is `survey_taylor` → `surveywts_error_control_not_replicate`
- Replicate count mismatch → `surveywts_error_replicate_count_mismatch`
- Formula variable missing in primary → `surveywts_error_formula_variable_not_found`
- Formula variable missing in control → `surveywts_error_formula_variable_not_found`
- `formula` is not a formula object → `surveywts_error_formula_invalid`
- Calibration fails to converge → `surveywts_error_calibration_not_converged`

**4. Warning paths**
- Scheme mismatch (e.g., `primary_design@variables$type = "bootstrap"`, `control_design@variables$type = "JK1"`) → `surveywts_warning_replicate_scheme_mismatch`; calibration still proceeds and result passes `test_invariants()`
- `method = "linear"` with control totals that produce negative full-sample weights → `surveywts_warning_negative_calibrated_weights`; calibration result is still returned

**5. Edge cases**
- Single formula variable
- Formula with interaction terms `~ age * sex`
- Method `"linear"`
- Method `"logit"`
- Single replicate (n_rep = 1)

### `calibrate_to_estimate()` Test Categories

**1. Happy path**
- Returns `survey_replicate` with updated full-sample + replicate weights
- `test_invariants()` on result
- History entry correct

**2. Numerical correctness**
- Calibrated full-sample weights satisfy the calibration constraints:
  `abs(sum(w_new * X) - estimate) < 1e-8` for all calibration variables.

**3. Error paths**
- `design` not `survey_replicate` → `surveywts_error_primary_not_replicate`
- Formula variable missing from `design@data` → `surveywts_error_formula_variable_not_found`
- `formula` is not a formula object → `surveywts_error_formula_invalid`
- `estimate` not named → `surveywts_error_estimate_not_named`
- `estimate` has NA values → `surveywts_error_estimate_has_na`
- `estimate` wrong length → `surveywts_error_estimate_length_mismatch`
- `estimate` wrong names → `surveywts_error_estimate_names_mismatch`
- `vcov_estimate` wrong dimensions → `surveywts_error_vcov_dimension_mismatch`
- `vcov_estimate` has NA values → `surveywts_error_vcov_has_na`
- `vcov_estimate` not symmetric → `surveywts_error_vcov_not_symmetric`
- Non-PSD `vcov_estimate` → `surveywts_error_vcov_cholesky_failed`
- Calibration not converged → `surveywts_error_calibration_not_converged`

**4. Warning paths**
- `method = "linear"` with estimates that produce negative full-sample weights → `surveywts_warning_negative_calibrated_weights`; calibration result is still returned

**5. Edge cases**
- Identity covariance (zero uncertainty in control totals)
- Single calibration variable
- Method `"linear"`
- Method `"logit"`

### `redistribute_weights()` Test Categories

**1. Happy path**
- `data.frame` input → `weighted_df`; `test_invariants()` on result
- `weighted_df` input → `weighted_df`
- `survey_nonprob` input → `survey_nonprob`
- `survey_taylor` input → `survey_taylor` (respondent-only output)
- With `by`: groups processed independently
- Without `by`: global redistribution
- Rows matching neither indicator: weights unchanged

**2. Numerical correctness**
- Compare to `adjust_nonresponse()` applied to equivalent weighting-class setup
  (no external reference package needed — internal consistency check)

**3. Error paths**
- `survey_replicate` input → `surveywts_error_unsupported_class`
- 0-row data frame input → `surveywts_error_empty_data`
- Named weight column missing → `surveywts_error_weights_not_found`
- Weight column not numeric → `surveywts_error_weights_not_numeric`
- Weight column has non-positive value → `surveywts_error_weights_nonpositive`
- Weight column has NA → `surveywts_error_weights_na`
- `wt_name` not `character(1)` → `surveywts_error_wt_name_not_scalar`
- `wt_name` is NA or `""` → `surveywts_error_wt_name_empty`
- `reduce_if` column not found → `surveywts_error_reduce_if_not_found`
- `increase_if` column not found → `surveywts_error_increase_if_not_found`
- `reduce_if` not binary (factor) → `surveywts_error_reduce_if_not_binary`
- `increase_if` not binary (character) → `surveywts_error_increase_if_not_binary`
- `reduce_if` column has NA → `surveywts_error_reduce_if_has_na`
- `increase_if` column has NA → `surveywts_error_increase_if_has_na`
- Indicator overlap → `surveywts_error_indicators_overlap`
- Group with no recipients → `surveywts_error_no_recipients_in_group`
- `by` variable with NA → `surveywts_error_variable_has_na`
- `wt_name` matches existing non-weight column → `surveywts_error_wt_name_conflict`

**4. Edge cases**
- All rows are `reduce_if` (global: error; with `by`: one group all-reduce + other groups fine)
- No rows are `reduce_if` → weights unchanged, no error, no warning
- Zero-weight rows in `increase_if` → caught by `surveywts_error_weights_nonpositive` before redistribution logic runs (tests the weight validator, not redistribution)
- Sparse cell → `surveywts_warning_class_near_empty`
- History: step number correct when chained after calibration

### `adjust_nonresponse()` Propensity-Cell Test Categories

**1. Happy path (propensity-cell)**
- Returns same class as input
- All rows returned; nonrespondent weights = 0
- History entry `operation = "nonresponse_propensity_cell"`
- `test_invariants()` on result

**2. Numerical correctness**
- No external package comparison needed; verify that within-cell respondent weights
  scale correctly: `sum(new_weights[in_cell & resp]) == sum(old_weights[in_cell])`

**3. Error paths (new)**
- `method = "propensity-cell"` without `formula` → `surveywts_error_formula_required_for_propensity_cell`
- `formula` is not a formula object → `surveywts_error_formula_invalid`
- Formula variable missing → `surveywts_error_formula_variable_not_found`
- Formula variable has NA → `surveywts_error_formula_variable_has_na`
- `control$n_cells = 1` → `surveywts_error_n_cells_invalid`
- `method = "propensity"` still errors → `surveywts_error_propensity_not_available` (existing)
- Propensity cell contains no respondents → `surveywts_error_no_respondents_in_propensity_cell`

**4. Edge cases**
- `by` non-NULL with propensity-cell → warning `surveywts_warning_by_ignored_for_propensity_cell`
- `control$n_cells = 2`
- Very high propensity concentration (all scores near 0 or 1)
- One propensity cell contains fewer than `control$min_cell` respondents → `surveywts_warning_class_near_empty`

---

## IX. Quality Gates

All of the following must be true before the Nonresponse phase PR is considered done:

- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤ 2 notes
- [ ] `devtools::test()` passes: all tests green
- [ ] Test coverage ≥ 98% overall (branch coverage for `adjust_nonresponse()` extension
  should be verified manually)
- [ ] Every new `cli_abort()` and `cli_warn()` call has a `class=` argument
- [ ] Every new error/warning class is listed in `plans/error-messages.md`
- [ ] Snapshot tests added for all new user-facing `cli_abort()` calls
- [ ] `devtools::document()` run; NAMESPACE and man/ files are in sync
- [ ] All exported function examples are runnable (`R CMD check --run-dontrun`)
- [ ] `calibrate_to_survey()` and `calibrate_to_estimate()` calibration constraints
  verified: calibrated full-sample weights satisfy target totals within `1e-8`
- [ ] History entries use correct `operation` strings (see §III–VI)
- [ ] `test_invariants()` called in every new constructor test block

---

## X. Integration

### `plans/error-messages.md`

The following new classes must be added before the Implementation Plan is written:

**New for `calibrate_to_survey()` / `calibrate_to_estimate()`:**
- `surveywts_error_primary_not_replicate`
- `surveywts_error_control_not_replicate`
- `surveywts_error_replicate_count_mismatch`
- `surveywts_warning_replicate_scheme_mismatch`
- `surveywts_error_formula_variable_not_found`
- `surveywts_error_formula_invalid`
- `surveywts_error_estimate_not_named`
- `surveywts_error_estimate_has_na`
- `surveywts_error_estimate_length_mismatch`
- `surveywts_error_estimate_names_mismatch`
- `surveywts_error_vcov_dimension_mismatch`
- `surveywts_error_vcov_has_na`
- `surveywts_error_vcov_not_symmetric`
- `surveywts_error_vcov_cholesky_failed`

**New for `redistribute_weights()`:**
- `surveywts_error_reduce_if_not_found`
- `surveywts_error_increase_if_not_found`
- `surveywts_error_reduce_if_not_binary`
- `surveywts_error_increase_if_not_binary`
- `surveywts_error_reduce_if_has_na`
- `surveywts_error_increase_if_has_na`
- `surveywts_error_indicators_overlap`
- `surveywts_error_no_recipients_in_group`
- `surveywts_error_wt_name_conflict`

**New for `adjust_nonresponse()` propensity-cell:**
- `surveywts_error_formula_required_for_propensity_cell`
- `surveywts_error_formula_invalid` (reuse — also used by calibration functions)
- `surveywts_error_formula_variable_has_na`
- `surveywts_error_n_cells_invalid`
- `surveywts_error_no_respondents_in_propensity_cell`
- `surveywts_warning_by_ignored_for_propensity_cell`

### `surveywts-conventions.md`

Update the `@family` table to confirm `sample-calibration` family:

```r
#' @family sample-calibration
calibrate_to_survey <- function(...)
calibrate_to_estimate <- function(...)
```

And update the `@family nonresponse` table to include `redistribute_weights()`:

```r
#' @family nonresponse
redistribute_weights <- function(...)
```

### Dependency: `svrep`

`svrep` is called directly by `calibrate_to_survey()` (via `svrep::calibrate_to_sample()`)
and `calibrate_to_estimate()`. It must be in `Imports` — add it to `DESCRIPTION` at the
start of this phase. No other new `Imports` are required — `stats::glm()` (propensity-cell)
is base R. `stats::chol()` is no longer needed since `svrep` handles vcov factorization
internally.

### Interaction with Propensity Phase

`calibrate_nonresponse()` (Propensity phase) calibrates respondent weights to match
full-sample totals. That function uses `calibrate()` internally and does not depend on
this phase's deliverables. No changes to this spec are needed when Propensity ships.

The Propensity phase will refactor `adjust_nonresponse(method = "propensity-cell")`
to delegate to `estimate_propensity()` + `create_propensity_weights()`. That refactor
should not change the public API (same arguments, same output contract). When it
happens, the spec for that change lives in the Propensity phase spec.
