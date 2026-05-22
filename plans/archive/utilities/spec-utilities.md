# surveywts Utilities Phase Spec

**Version:** 1.0 — Approved for implementation
**Date:** 2026-05-18
**Status:** Approved
**ID:** `utilities`

---

## Document Purpose

This spec is the source of truth for the Utilities phase of surveywts. It governs
the design and implementation of `trim_weights()` and `stabilize_weights()`, and
introduces `.trim_weights_internal()` as a shared internal helper that the Propensity
phase will reuse.

Every implementation decision, API contract, and error condition for this phase must
be resolved here before any R code is written. The Implementation Plan derives from
this document and must not deviate from it without a documented decision.

---

## I. Scope

### Deliverables

| Deliverable | Function | Source file |
|-------------|----------|-------------|
| Trim extreme weights | `trim_weights()` | `R/weight-utils.R` (new) |
| Rescale weights to sum to n | `stabilize_weights()` | `R/weight-utils.R` (new) |
| Internal trimming primitive | `.trim_weights_internal()` | `R/utils.R` (extend) |

### What This Phase Does NOT Deliver

- `estimate_propensity()`, `create_propensity_weights()` — Propensity phase
- `adjust_nonresponse(method = "propensity")` — Propensity phase (remains a stub)
- Any diagnostics (`check_balance()`, etc.) — Diagnostics phase
- `survey_replicate` support for both `trim_weights()` and `stabilize_weights()` is delivered in this phase; both apply the same operation uniformly to main weights and all replicate weight columns

### Roadmap Cross-Reference: `.trim_weights_internal()` Timeline

The roadmap Cross-Cutting Notes state: "Use an unexported `.trim_weights_internal()`
helper from Propensity onward." That note describes the intended relationship between
phases, not which phase introduces the helper. `.trim_weights_internal()` is introduced
**in this phase** (Utilities) — it is the implementation of `trim_weights()`. The
Propensity phase will call this same internal helper for internal weight trimming inside
the non-probability IPW functions. No refactoring between phases is required.

### Input Class Support

| Function | `data.frame` | `weighted_df` | `survey_taylor` | `survey_nonprob` | `survey_replicate` |
|---|---|---|---|---|---|
| `trim_weights()` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stabilize_weights()` | ✅ | ✅ | ✅ | ✅ | ✅ |

### Output Class Contract

Each function preserves the input class. Trimming and stabilizing modify
weights on a probability sample design — they do not change the nature of the
design from probability to non-probability, unlike calibration functions.

| Input type | `trim_weights()` output | `stabilize_weights()` output |
|---|---|---|
| `data.frame` | `weighted_df` | `weighted_df` |
| `weighted_df` | `weighted_df` | `weighted_df` |
| `survey_taylor` | `survey_taylor` | `survey_taylor` |
| `survey_nonprob` | `survey_nonprob` | `survey_nonprob` |
| `survey_replicate` | `survey_replicate` | `survey_replicate` |

All S7 survey class objects have `@metadata@weighting_history` (inherited from
`survey_base`), so history can be appended to any of them without class conversion.

---

## II. Architecture

### Source File Map

```
R/
  weight-utils.R    ← NEW: trim_weights(), stabilize_weights()
  utils.R           ← EXTEND: + .trim_weights_internal()
```

`R/weight-utils.R` is a new file. The roadmap's `10-weight-utils.R` filename was a
planning artifact; the package does not use numeric prefixes (see Nonresponse spec
precedent and global CLAUDE.md).

### New Helpers

**In `R/utils.R`:**

| Helper | Signature | Used by |
|--------|-----------|---------|
| `.trim_weights_internal()` | `(weights, lower, upper, has_trimmed)` | `trim_weights()`; Propensity phase |

Returns a named list `list(weights, has_trimmed)`, not a plain numeric vector. The
Propensity phase must extract `$weights` from the return value.

**In `R/weight-utils.R`** (file-local helper, not exported, not in `utils.R`):

| Helper | Signature | Used by |
|--------|-----------|---------|
| `.check_weight_utils_class()` | `(data)` | `trim_weights()`, `stabilize_weights()` |

A single class-validation helper defined at the top of `R/weight-utils.R`. Accepts all
five input types (`data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`,
`survey_replicate`); throws `surveywts_error_unsupported_class` for anything else.
Replaces `.check_input_class()` for both functions in this file — do not call
`.check_input_class()` from `R/weight-utils.R`.

### `@family` Tag

Both functions belong to a new `utilities` family:

```r
#' @family utilities
trim_weights <- function(...)
stabilize_weights <- function(...)
```

Add `utilities` to the `@family` table in `surveywts-conventions.md` before the
Implementation Plan is written.

---

## III. `trim_weights()`

### Purpose

Trim (clip-and-redistribute) survey weights to a specified interval `[lower, upper]`.
Any weight below `lower` is clipped to `lower`; any weight above `upper` is clipped
to `upper`; the total trimmed excess is then redistributed equally across untrimmed
units, preserving the total weight sum. Bounds can be specified as absolute weight
values or as percentiles (quantiles on the [0, 1] scale) of the main weight
distribution. Preserves the input class and appends a history entry.

Trimming reduces variance at the cost of introducing bias; it is most beneficial when
weights exhibit high variability unrelated to (or negatively correlated with) the
outcome variables. For `survey_taylor` objects, Taylor SEs post-trimming typically
decrease as weight variance falls, but may carry bias when the cutpoint is correlated
with the outcome. For `survey_replicate` objects, replicate weights are trimmed in
parallel so replicate-based variance estimates capture the effect of trimming automatically.

For `survey_replicate` input, the same absolute cutoffs (derived from the main weight
vector when `type = "percentile"`) are applied to both the main weights and all
replicate weight columns.

The core clipping logic is vendored from the `survey` package
(`survey::trimWeights`; Thomas Lumley) and attributed in the source file.

### Details

**Terminology:** This function implements weight *trimming* as defined by Chen et al.
(2017) §2.2.1 — an outcome-independent (y-agnostic) bound that produces multipurpose
weights valid for multiple analyses. This is distinct from *winsorization* (Chen
§2.2.2), which sets outcome-specific bounds and produces weights valid only for the
target outcome. The roxygen2 `@description` for `trim_weights()` must use the word
"trim", not "Winsorize".

**Cutpoint selection:** The default (`upper = NULL, type = "absolute"`) encodes the
Potter & Zheng (2015) IQR-based recommendation: `median(w) + k * IQR(w)` with k = 5.
This means `trim_weights(df, weights = base_weight)` performs meaningful upper-tail
trimming out of the box. To disable automatic cutpoint computation, pass an explicit
numeric value (e.g., `upper = Inf`). For further reading on principled cutpoint choice,
including MSE-minimizing methods, see Potter & Zheng (2015).

### Signature

```r
trim_weights(
  data,
  weights = NULL,
  lower = NULL,
  upper = NULL,
  k = 5,
  type = c("absolute", "percentile"),
  strict = FALSE,
  wt_name = "wts"
)
```

### Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `data` | `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`, or `survey_replicate` | required | Input data. All survey classes supported. |
| `weights` | bare name (NSE) or `NULL` | `NULL` | Weight column. Auto-detected for `weighted_df` and survey objects. For plain `data.frame` with `NULL`, uniform weights (all 1) are used and the output weight column is named `wt_name`. |
| `lower` | `numeric(1)` or `NULL` | `NULL` | Lower bound. `NULL` means no lower trimming (`-Inf` equivalent). When not `NULL`, interpretation depends on `type`: absolute weight value (`type = "absolute"`) or [0, 1] quantile of the main weight distribution (`type = "percentile"`). Must not be `NA`. Bounds order is checked after resolution. |
| `upper` | `numeric(1)` or `NULL` | `NULL` | Upper bound. `NULL` and `type = "absolute"` (the default) computes the cutoff as `median(w) + k * IQR(w)` — the Potter & Zheng (2015) recommended default. `NULL` is incompatible with `type = "percentile"` (error). When not `NULL`, interpretation depends on `type`. Must not be `NA`. When `type = "absolute"`, must be strictly positive. |
| `k` | `numeric(1)` | `5` | IQR multiplier used only when `upper = NULL` and `type = "absolute"`. Computes the upper cutoff as `median(w) + k * IQR(w)`. Must be positive and not `NA`. Ignored when `upper` is a numeric value. Potter & Zheng (2015) suggest k in the range 5–6. |
| `type` | `character(1)` | `"absolute"` | `"absolute"`: non-`NULL` `lower`/`upper` are raw weight values. `"percentile"`: `lower`/`upper` are quantiles on [0, 1] — e.g., `upper = 0.99` clips at the 99th percentile. `upper = NULL` is not permitted with `type = "percentile"`. |
| `strict` | `logical(1)` | `FALSE` | When `FALSE` (default), a single clip-and-redistribute pass is applied. When `TRUE`, the clip-and-redistribute loop is repeated until all main weights fall within `[lower_abs, upper_abs]`, because a single redistribution pass can push previously in-bounds weights past a cutpoint. Mirrors `survey::trimWeights(strict=)`. Not applied to replicate weight columns. |
| `wt_name` | `character(1)` | `"wts"` | Output weight column name. Used only when `data` is a plain `data.frame` with `weights = NULL`. Ignored for all other input types. |

### Output Contract

Returns an object of the **same class as `data`** with:

- Main weight column values trimmed via clip-and-redistribute (see Behavior Rules step 6).
  The total weight sum is preserved: `sum(result_weights) == sum(original_weights)` (up to
  floating-point rounding), unless `surveywts_warning_trimming_failed` fires (all units are
  already trimmed and excess cannot be redistributed), in which case the sum may differ by
  the amount of unredistributed excess — matching `survey::trimWeights` behavior.
  When `strict = TRUE`, all main weights are additionally guaranteed to lie within
  `[lower_abs, upper_abs]` when trimming succeeds.
- For `survey_replicate`: main weights trimmed as above; replicate weight columns trimmed
  via a single-pass column-wise clip-and-redistribute (see Behavior Rules step 7).
  Total weight sum preserved per column.
- Weight column name unchanged from input (except for `data.frame` + `weights = NULL`,
  where the output column is named `wt_name`)
- One new entry appended to `@metadata@weighting_history` (survey objects) or
  `attr(x, "weighting_history")` (`weighted_df`):
  ```
  operation       = "trim_weights"
  type            = <"absolute" or "percentile">
  strict          = <TRUE or FALSE>
  lower_input     = <user-supplied lower value>
  upper_input     = <user-supplied upper value>
  lower_abs       = <resolved absolute lower cutoff>
  upper_abs       = <resolved absolute upper cutoff>
  n_trimmed_lower = <number of main weights originally below lower_abs, before redistribution>
  n_trimmed_upper = <number of main weights originally above upper_abs, before redistribution>
  ```
- All other columns and attributes preserved

### Behavior Rules

0. If `data` is a plain `data.frame` and `weights` is `NULL`, call
   `.validate_wt_name(wt_name)` before any other validation. Skip this step for all
   other input types (the `wt_name` argument is ignored when weights are auto-detected).
1. Validate `type` via `match.arg()`.
2. Validate bounds before extracting weights (fail fast):
   a. If `upper = NULL`:
      - If `type = "percentile"`: error (`surveywts_error_null_bound_percentile`).
      - Validate `k`: must be `numeric(1)`, not `NA`, and `k > 0`.
   b. If `upper` is not `NULL`:
      - Must be `numeric(1)` and not `NA`.
      - When `type = "absolute"`: `upper > 0` (non-positive `upper` would clip all
        weights to ≤ 0, violating the positive-weights invariant).
      - When `type = "percentile"`: must be in [0, 1].
   c. If `lower` is not `NULL`:
      - Must be `numeric(1)` and not `NA`.
      - When `type = "percentile"`: must be in [0, 1].
   d. Bounds order is verified after resolution in step 5.
3. Extract main weight vector via `.get_weight_vec()`. This function must be extended
   (if not already) to handle `survey_replicate` input using `x@variables$weights` —
   the same pattern used for `survey_taylor` and `survey_nonprob`. For plain `data.frame`
   with `weights = NULL`, use `rep(1, nrow(data))` as uniform starting weights (do not
   call `.get_weight_vec()` for this case; inline the `rep(1, nrow(data))` logic directly).
4. Validate the main weight vector via `.validate_weights()`.
5. Resolve absolute cutoffs, then verify order:
   - `type = "absolute"`:
     - `lower_abs = if (!is.null(lower)) lower else -Inf`
     - `upper_abs = if (!is.null(upper)) upper else median(weights) + k * IQR(weights, type = 7)`
   - `type = "percentile"`:
     - `lower_abs = if (!is.null(lower)) quantile(weights, lower, type = 7) else -Inf`
     - `upper_abs = quantile(weights, upper, type = 7)` (`upper` is never `NULL` here)
   After computing `lower_abs` and `upper_abs`: verify `lower_abs < upper_abs`. Equal or
   reversed resolved bounds → `surveywts_error_bounds_invalid`.
6. Apply `.trim_weights_internal()` to the main weight vector using a loop that mirrors
   `survey::do_trimWeights` / `survey::trimWeights.survey.design2`:
   a. Record `outside_initial <- weights < lower_abs | weights > upper_abs` to count
      trimmed units for the history entry (before any redistribution).
   b. If `!any(outside_initial)`, emit `surveywts_warning_no_weights_trimmed` and proceed to step 9 (skip the trimming loop).
   c. Initialise `has_trimmed <- rep(FALSE, length(weights))`.
   d. While any weight is outside `[lower_abs, upper_abs]` (the loop is guaranteed to terminate in ≤ n iterations since `has_trimmed` marks are monotonically set and `pmax/pmin` clips weights to the bound on each pass):
      - Call `.trim_weights_internal(weights, lower_abs, upper_abs, has_trimmed)`.
      - Update `weights` and `has_trimmed` from the returned list.
      - If `strict = FALSE`, break after the first iteration.
   Each iteration clips weights outside the bounds and redistributes the total trimmed
   excess equally across units that have never been trimmed. Subsequent iterations
   (when `strict = TRUE`) handle cases where redistribution pushes previously in-bounds
   weights past a cutpoint.
7. For `survey_replicate` input: the main weight vector is trimmed via step 6.
   Replicate weight columns are trimmed with a single-pass column-wise redistribution
   that mirrors `survey::trimWeights.svyrep.design` (no strict loop). Regardless of
   `strict`, replicate weight columns always receive a single-pass clip-and-redistribute;
   the strict loop is applied only to main weights.
   a. Extract the replicate weight matrix:
      `rep_weights <- as.matrix(design@data[design@variables$repweights])`.
      Then clip the full matrix: `rwnew <- pmax(lower_abs, pmin(rep_weights, upper_abs))`.
   b. Compute per-cell excess: `trimmings <- rep_weights - rwnew`.
   c. For each column `j`, identify which rows are outside:
      `outside_j <- rep_weights[, j] < lower_abs | rep_weights[, j] > upper_abs`.
   d. Redistribute within each column independently:
      `rwnew[!outside_j, j] <- rwnew[!outside_j, j] + sum(trimmings[, j]) / sum(!outside_j)`.
   This preserves the total weight sum within each replicate column, unless all units in
   that column are outside `[lower_abs, upper_abs]` (i.e., `sum(!outside_j) == 0`), in
   which case no redistribution is possible and the column sum changes by the amount of
   unredistributed excess — mirroring the `surveywts_warning_trimming_failed` behavior
   for main weights, but without a warning.
8. Count `n_trimmed_lower` and `n_trimmed_upper` from `outside_initial` (step 6a) —
   the number of **main** weights that were outside each bound before any redistribution.
   Replicate column clip counts are not recorded.
9. Construct and return the output object (same class as input):
   - For `data.frame` and `weighted_df`: use `.make_weighted_df()`.
   - For `survey_taylor`, `survey_nonprob`: use `.update_survey_weights()`, then append the
     history entry via `.make_history_entry()`.
   - For `survey_replicate`: call `.update_survey_weights()` for the main weights + history
     entry (same as the other survey classes), then additionally write back the trimmed
     replicate weight matrix: `design@data[design@variables$repweights] <- as.data.frame(rwnew)`.
10. When resolved `lower_abs = -Inf` and `upper_abs = Inf` (reachable only by
    explicitly passing `upper = Inf`), the function is a no-op on weight values but
    still appends a history entry. This is intentional — it preserves the audit trail.
    `surveywts_warning_no_weights_trimmed` also fires in this case (since no weight
    exceeds `Inf` or falls below `-Inf`). This is expected and correct behavior;
    users calling this form for audit-trail purposes should expect the warning.

### Error Table

| Error class | Condition |
|---|---|
| `surveywts_error_unsupported_class` | `data` is an unsupported class (e.g., plain `list`) (reuse existing) |
| `surveywts_error_empty_data` | `nrow(data) == 0` (reuse existing) |
| `surveywts_error_weights_not_found` | Named weight column missing from data (reuse existing) |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric (reuse existing) |
| `surveywts_error_weights_nonpositive` | Weight column has non-positive values (reuse existing) |
| `surveywts_error_weights_na` | Weight column has `NA` values (reuse existing) |
| `surveywts_error_null_bound_percentile` | `upper = NULL` and `type = "percentile"` — incompatible combination |
| `surveywts_error_k_not_scalar` | `k` is not `numeric(1)` or is `NA` (checked when `upper = NULL`) |
| `surveywts_error_k_nonpositive` | `k <= 0` (checked when `upper = NULL`) |
| `surveywts_error_lower_not_scalar` | `lower` is not `numeric(1)` or is `NA` (when `lower` is not `NULL`) |
| `surveywts_error_upper_not_scalar` | `upper` is not `numeric(1)` or is `NA` (when `upper` is not `NULL`) |
| `surveywts_error_bounds_invalid` | `lower_abs >= upper_abs` after resolution |
| `surveywts_error_upper_nonpositive` | `upper <= 0` when `type = "absolute"` and `upper` is not `NULL` |
| `surveywts_error_percentile_out_of_range` | non-`NULL` `lower` or `upper` not in [0, 1] when `type = "percentile"` |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` (reuse existing) |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` (reuse existing) |

`type` validation uses `match.arg()` — no custom class needed.

### Warning Table

| Warning class | Condition |
|---|---|
| `surveywts_warning_no_weights_trimmed` | Neither bound clipped any main weights. Signals the bounds may be wider than the weight distribution. |
| `surveywts_warning_trimming_failed` | Inside `.trim_weights_internal()`: all remaining units have already been trimmed and no untrimmed units are available to absorb the redistributed excess. Most commonly triggered during `strict = TRUE` multi-pass trimming, but can also fire on the first pass if all weights are initially outside `[lower_abs, upper_abs]`. Mirrors `warning("trimming failed")` in `survey::do_trimWeights`. |

### Example

```r
df <- make_surveywts_data(seed = 1)

# Default: IQR-based upper cutpoint (Potter & Zheng 2015)
# upper bound = median(base_weight) + 5 * IQR(base_weight)
result <- trim_weights(df, weights = base_weight)

# Adjust the IQR multiplier
result <- trim_weights(df, k = 6, weights = base_weight)

# Absolute: explicit upper bound
result <- trim_weights(df, upper = 3, weights = base_weight)

# Absolute: explicit both tails
result <- trim_weights(df, lower = 0.3, upper = 5, weights = base_weight)

# Percentile: trim at 1st and 99th percentile of the weight distribution
# (upper must be explicit when type = "percentile")
result <- trim_weights(df, lower = 0.01, upper = 0.99,
                       type = "percentile", weights = base_weight)

# Percentile: upper tail only
result <- trim_weights(df, upper = 0.95, type = "percentile", weights = base_weight)
```

---

## IV. `stabilize_weights()`

### Purpose

Rescale weights so that they sum to the sample size `n` (or, with `by`, to the group
sample size within each group). Relative weights within the sample (or within each group)
are preserved exactly. This is useful for making effective sample size calculations
interpretable when weights do not already sum to n.

Stabilization rescales all weights by the constant factor `n / W`. This preserves all
ratio estimators (means, proportions) exactly, since the factor cancels in numerator and
denominator. However, population total estimators of the form `Σ w_i y_i` change by the
factor `n / W`. Users who intend to estimate population totals should not stabilize before
analysis. For `survey_taylor` objects, variance estimates of means and proportions are
unaffected by stabilization; variance estimates of totals scale by `(n/W)^2`.

### Signature

```r
stabilize_weights(
  data,
  weights = NULL,
  by = NULL,
  wt_name = "wts"
)
```

### Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `data` | `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`, or `survey_replicate` | required | Input data. All survey classes supported. For `survey_replicate`, the same scale factor is applied to both the main weights and all replicate weight columns. |
| `weights` | bare name (NSE) or `NULL` | `NULL` | Weight column. Auto-detected for `weighted_df` and survey objects. For plain `data.frame` with `NULL`, uniform weights (all 1) are used. |
| `by` | `<tidy-select>` | `NULL` | Grouping variable(s). Stabilization is performed within each group (weights in group `h` sum to `n_h`). `NULL` → global stabilization (all weights sum to `n`). |
| `wt_name` | `character(1)` | `"wts"` | Output weight column name. Used only when `data` is a plain `data.frame` with `weights = NULL`. Ignored for all other input types. |

### Output Contract

Returns an object of the **same class as `data`** with:

- Main weight column values rescaled so `sum(w_new) == n` globally (or `sum(w_new_h) == n_h`
  for each group `h` when `by` is specified).
- For `survey_replicate`: all replicate weight columns multiplied by the same scale factor
  `n / sum(w_main)` used for the main weights (global) or the per-group factor for each
  group's rows. This preserves the internal consistency of the design so that variance
  estimates remain valid. `by` grouping applies identically to replicate columns —
  each group's rows in every replicate column are scaled by that group's factor.
- Weight column name unchanged from input (except for `data.frame` + `weights = NULL`,
  where the output column is named `wt_name`).
- One new entry appended to the weighting history:
  ```
  operation  = "stabilize_weights"
  by         = <character vector of by variable names, or NULL>
  scale_factor = <numeric(1) global scale factor (when by = NULL)>
              or <named numeric vector of per-group scale factors (when by is set);
                  for single-variable `by`, names are the character representation of the
                  group values (e.g., `by = age_group` → `c("18-34" = ..., "35-54" = ..., "55+" = ...)`);
                  for multi-variable `by`, names are the group values pasted with ` | `
                  as separator (e.g., `by = c(age_group, sex)` → `"18-34 | F"`, `"18-34 | M"`, ...)>
  ```
- All other columns and attributes preserved.

### Stabilization Formula

**Global (no `by`):**

Let `n` = `nrow(data)`, `W` = `sum(weights)`.

```
w_new_i = w_i * (n / W)
```

After stabilization: `sum(w_new) = n` exactly (up to floating-point rounding).

**Within-group (with `by`):**

For each group `h` defined by the `by` variable(s), let `n_h` = number of rows in
group `h`, `W_h` = sum of weights in group `h`.

```
w_new_i = w_i * (n_h / W_h)  for all i in group h
```

After stabilization: `sum(w_new_h) = n_h` for each group `h`.

### Behavior Rules

0. If `data` is a plain `data.frame` and `weights` is `NULL`, call
   `.validate_wt_name(wt_name)` before any other validation. Skip this step for all
   other input types (the `wt_name` argument is ignored when weights are auto-detected).
1. Extract weight vector via `.get_weight_vec()` (for `weighted_df` and survey objects).
   For plain `data.frame` with `weights = NULL`, do not call `.get_weight_vec()` — inline
   `rep(1, nrow(data))` directly. This matches the uniform-weight semantics for trimming
   and stabilization (each observation counts once), distinct from the `1/n` calibration
   starting weight in `.get_weight_vec()`.
2. Validate weight vector via `.validate_weights()`.
3. If `by` is specified: extract the underlying data frame (`@data` for survey objects),
   then validate that all `by` variables exist and contain no `NA` values.
   Use `tidyselect::eval_select()` to resolve `by` against the data frame (not the S7
   object), following the same pattern as `summarize_weights()`.
4. Compute scale factors per group (or globally) and apply to the main weight vector.
5. For `survey_replicate`: extract the replicate weight matrix
   (`as.matrix(design@data[design@variables$repweights])`), then apply the same per-group
   (or global) scale factors to every replicate column. Each row in a replicate column
   is multiplied by the scale factor for its group (or by the global factor when `by = NULL`).
   Write the scaled matrix back: `design@data[design@variables$repweights] <- as.data.frame(rep_weights_new)`.
6. Construct output via `.make_weighted_df()` or `.update_survey_weights()` (existing
   helpers), then append history entry via `.make_history_entry()`.
7. A global no-op (weights already sum to n) is valid — function completes
   without warning.

### Error Table

| Error class | Condition |
|---|---|
| `surveywts_error_unsupported_class` | `data` is an unsupported class (e.g., plain `list`) (reuse existing) |
| `surveywts_error_empty_data` | `nrow(data) == 0` (reuse existing) |
| `surveywts_error_weights_not_found` | Named weight column missing (reuse existing) |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric (reuse existing) |
| `surveywts_error_weights_nonpositive` | Weight column has non-positive values (reuse existing) |
| `surveywts_error_weights_na` | Weight column has `NA` values (reuse existing) |
| `surveywts_error_by_variable_not_found` | A `by` variable is not in `data` |
| `surveywts_error_variable_has_na` | A `by` variable has `NA` values (reuse existing) |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` (reuse existing) |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` (reuse existing) |

### Warning Table

No warnings defined for `stabilize_weights()`.

### Example

```r
library(survey)
df <- make_surveywts_data(seed = 1)

# Global stabilization
result <- stabilize_weights(df, weights = base_weight)
# sum(result$wts) == nrow(df)

# Within-group stabilization
result <- stabilize_weights(df, by = age_group, weights = base_weight)
# For each level of age_group: sum(result$wts[group]) == n in group
```

---

## V. Shared Internal Helper: `.trim_weights_internal()`

### Purpose

The single-pass clip-and-redistribute implementation of weight trimming. Introduced in
the Utilities phase; shared with the Propensity phase. Lives in `R/utils.R` (used in
2+ files: `R/weight-utils.R` and the future `R/nonprob-ipw.R`).

### Signature and Contract

The implementation mirrors `survey::do_trimWeights` (Thomas Lumley, GPL-2/3). The
attribution comment in `R/utils.R` must name both the function and the commit, consistent
with the vendoring comments in `R/vendor-calibrate-greg.R` and `R/vendor-calibrate-ipf.R`.

```r
# Clip-and-redistribute logic adapted from survey::do_trimWeights (Thomas Lumley, GPL-2/3).
# Source: https://github.com/cran/survey/blob/4834b8bc91f6414ad4514552daaed8990a86d9c1/R/grake.R#L449
.trim_weights_internal <- function(weights, lower, upper, has_trimmed) {
  outside <- weights < lower | weights > upper
  if (!any(outside)) return(list(weights = weights, has_trimmed = has_trimmed))
  weights_new <- pmax(lower, pmin(weights, upper))
  trimmings <- weights - weights_new
  can_adjust <- !outside & !has_trimmed
  if (!any(can_adjust)) {
    cli::cli_warn(
      c("!" = "Weight redistribution failed: no untrimmed units remain to absorb the trimmed excess."),
      class = "surveywts_warning_trimming_failed"
    )
  } else {
    weights_new[can_adjust] <- weights_new[can_adjust] + sum(trimmings) / sum(can_adjust)
  }
  list(weights = weights_new, has_trimmed = outside | has_trimmed)
}
```

**Arguments:**
- `weights`: `numeric` vector; assumed validated (positive, no NA) by the calling function
- `lower`: `numeric(1)`; the resolved absolute lower cutoff; assumed `lower < upper` and not `NA`
- `upper`: `numeric(1)`; the resolved absolute upper cutoff; assumed `upper > 0` and not `NA`
- `has_trimmed`: `logical` vector the same length as `weights`; `TRUE` for units that have
  already been trimmed in a prior iteration and must not receive redistributed excess

**Returns:** a named list:
- `$weights`: `numeric` vector of the same length as `weights`. Values outside
  `[lower, upper]` are clipped to the bound; the total trimmed excess is then
  redistributed equally across units where `!has_trimmed & !outside`.
- `$has_trimmed`: `logical` vector updated to `TRUE` for all units that were outside the
  bounds in this call (union with the input `has_trimmed`).

**Contract:** Does no validation. All validation is the caller's responsibility. The
Propensity phase will call this helper directly; callers must extract `$weights` from
the returned list.

---

## VI. Testing

### Test File Map

| Source file | Test file |
|---|---|
| `R/weight-utils.R` | `tests/testthat/test-weight-utils.R` (new) |
| `R/utils.R` (`.trim_weights_internal()`) | tested indirectly via `test-weight-utils.R` |

All Layer 3 error paths use the dual pattern per `testing-surveywts.md`:
`expect_error(class=)` + `expect_snapshot(error=TRUE)`.

### `trim_weights()` Test Categories

**1. Happy path — one block per input class**
- `data.frame` + `weights` → `weighted_df`; `test_invariants()` on result
- `weighted_df` input → `weighted_df`; weight column name preserved
- `survey_taylor` input → `survey_taylor` (same class); `test_invariants()` on result
- `survey_nonprob` input → `survey_nonprob`; `test_invariants()` on result
- `survey_replicate` input → `survey_replicate`; main + replicate weights clipped
- `data.frame` + `weights = NULL` → `weighted_df`; weight column named `wt_name`
- Default call (`upper = NULL`, `lower = NULL`, `type = "absolute"`): `upper_abs` in history equals `median(w) + 5 * IQR(w)`; `lower_abs` equals `-Inf`
- `k = 6`: `upper_abs` in history equals `median(w) + 6 * IQR(w)`
- `type = "absolute"` with explicit bounds: both tails, upper only, lower only
- `type = "percentile"`: `upper = 0.99` clips at 99th percentile; verify absolute cutoff in history matches `quantile(weights, 0.99)`
- Explicit no-op (`lower = -Inf`, `upper = Inf`, `type = "absolute"`): no trimming; history entry still appended (expect `surveywts_warning_no_weights_trimmed`)
- `strict = FALSE` (default): weight sum preserved; some non-trimmed weights may exceed cutpoint after redistribution
- `strict = TRUE`: all main weights within `[lower_abs, upper_abs]`; weight sum preserved

**2. Numerical correctness**
- Default `upper = NULL`: `history$upper_abs == median(original_weights) + 5 * IQR(original_weights)`
- Weight sum preserved when trimming succeeds (default `strict = FALSE`): `abs(sum(result_weights) - sum(original_weights)) < 1e-10`; when `surveywts_warning_trimming_failed` fires, the sum may differ by the amount of unredistributed excess
- With `strict = TRUE` (when trimming succeeds): `all(result_weights <= upper_abs + .Machine$double.eps)` AND
  `all(result_weights >= lower_abs - .Machine$double.eps)`
- With `strict = FALSE`: only the originally-outside weights are guaranteed within bounds
  after one pass; redistribution may push some non-trimmed weights past a cutpoint —
  verify `sum(result_weights) ≈ sum(original_weights)`, not that all weights are in bounds
- `n_trimmed_upper` in history entry equals `sum(original_weights > upper_abs)` (counted
  before redistribution)
- `n_trimmed_lower` in history entry equals `sum(original_weights < lower_abs)` (counted
  before redistribution)
- For `survey_replicate`: `abs(colSums(result_rep_weights) - colSums(original_rep_weights)) < 1e-10`
  for each replicate column where redistribution succeeds (i.e., `sum(!outside_j) > 0`
  for that column); columns where all units are outside bounds are exempt
- `type = "percentile"`, `upper = 0.99`: `history$upper_abs == quantile(original_weights, 0.99)`

**3. Error paths**
- `list` input → `surveywts_error_unsupported_class`
- 0-row data frame → `surveywts_error_empty_data`
- Named weight column missing → `surveywts_error_weights_not_found`
- Weight column not numeric → `surveywts_error_weights_not_numeric`
- Negative weight value → `surveywts_error_weights_nonpositive`
- `NA` weight value → `surveywts_error_weights_na`
- `upper = NULL, type = "percentile"` → `surveywts_error_null_bound_percentile`
- `k = "5"` (character) → `surveywts_error_k_not_scalar`
- `k = NA_real_` → `surveywts_error_k_not_scalar`
- `k = c(1, 2)` (length-2 numeric) → `surveywts_error_k_not_scalar`
- `k = -1` → `surveywts_error_k_nonpositive`
- `k = 0` → `surveywts_error_k_nonpositive`
- `lower = "0.5"` (character) → `surveywts_error_lower_not_scalar`
- `lower = NA_real_` → `surveywts_error_lower_not_scalar`
- `upper = c(1, 2)` (length-2) → `surveywts_error_upper_not_scalar`
- `upper = NA_real_` → `surveywts_error_upper_not_scalar`
- `lower = 3, upper = 3` (equal resolved bounds, absolute) → `surveywts_error_bounds_invalid`
- `lower = 5, upper = 3` (reversed, absolute) → `surveywts_error_bounds_invalid`
- `lower = 0.99, upper = 0.01` (reversed percentile) → `surveywts_error_bounds_invalid`
- `upper = 0` (absolute) → `surveywts_error_upper_nonpositive`
- `upper = -1` (absolute) → `surveywts_error_upper_nonpositive`
- `lower = -0.1, type = "percentile"` → `surveywts_error_percentile_out_of_range`
- `upper = 1.1, type = "percentile"` → `surveywts_error_percentile_out_of_range`
- `wt_name = 1L` → `surveywts_error_wt_name_not_scalar`
- `wt_name = ""` → `surveywts_error_wt_name_empty`

**4. Warning paths**
- All main weights already within `[lower_abs, upper_abs]` → `surveywts_warning_no_weights_trimmed`
- All units outside `[lower_abs, upper_abs]` on the first pass → `surveywts_warning_trimming_failed`.
  Trigger: two units with weights `c(1, 10)`, bounds `lower = 3, upper = 7`. Both units are
  outside `[3, 7]`, so `!any(can_adjust)` is `TRUE` on the first pass, no redistribution
  is possible, and the warning fires. Verify: `sum(result_weights) != sum(original_weights)`
  (the unredistributed excess is not recovered).

**5. History correctness**
- History entry has `operation = "trim_weights"`, `type`, `lower_input`, `upper_input`,
  `lower_abs`, `upper_abs`, `n_trimmed_lower`, `n_trimmed_upper`
- For `type = "percentile"`: `lower_input != lower_abs` (percentile ≠ resolved value)
- History step number is correct when chained after `calibrate()`

**6. Edge cases**
- Single-row data: trimming applied, result valid
- All weights equal: trimming is a no-op; warning fires
- Exactly one weight at each bound (`lower_abs = min(w)`, `upper_abs = max(w)`) — both counts are 1
- `survey_replicate` with `type = "percentile"`: cutoffs from main weights, applied to replicates

### `stabilize_weights()` Test Categories

**1. Happy path — one block per input class**
- `data.frame` + `weights` → `weighted_df`; `test_invariants()` on result
- `weighted_df` input → `weighted_df`; weight column name preserved
- `survey_taylor` input → `survey_taylor` (same class); `test_invariants()` on result
- `survey_nonprob` input → `survey_nonprob`; `test_invariants()` on result
- `survey_replicate` input → `survey_replicate`; main + replicate columns scaled by same factor
- `data.frame` + `weights = NULL` → `weighted_df`; weight column named `wt_name`
- `by = NULL` (global): `sum(result_weights) == nrow(data)` exactly
- `by = col`: within each group, `sum(result_weights[group]) == n_group` exactly
- `by = c(col1, col2)`: multi-variable grouping works correctly

**2. Numerical correctness**
- Global: `sum(new_weights) == n` to machine precision (`1e-10` tolerance)
- Within-group: for each level of `by`, sum of new weights equals group size
  (tolerance `1e-10`)
- Scale factor = `n / sum(w)` matches history entry value
- `survey_replicate` global: each replicate column is multiplied by the same factor
  `n / sum(w_main)`; verify `colSums(result_rep_weights) ≈ colSums(original_rep_weights) * (n / sum(w_main))`
  (i.e., relative column sums are preserved)
- `survey_replicate` with `by`: rows in each replicate column are scaled by the per-group
  factor for their group; for each group `h` and replicate column `j`:
  `abs(sum(result_rep[h, j]) - sum(original_rep[h, j]) * (n_h / W_h)) < 1e-10`
  where `W_h = sum(w_main[h])`

**3. Error paths**
- `list` input → `surveywts_error_unsupported_class`
- 0-row data frame → `surveywts_error_empty_data`
- Named weight column missing → `surveywts_error_weights_not_found`
- Weight column not numeric → `surveywts_error_weights_not_numeric`
- Negative weight value → `surveywts_error_weights_nonpositive`
- `NA` weight value → `surveywts_error_weights_na`
- `by` variable not in data → `surveywts_error_by_variable_not_found`
- `by` variable has `NA` values → `surveywts_error_variable_has_na`
- `wt_name = 1L` → `surveywts_error_wt_name_not_scalar`
- `wt_name = ""` → `surveywts_error_wt_name_empty`

**4. History correctness**
- History entry has `operation = "stabilize_weights"`, `by` variable names (or `NULL`),
  correct scale factor(s)
- Step number correct when chained after `trim_weights()`

**5. Edge cases**
- Weights already sum to n: scale factor = 1; function completes, history appended
- Single-row data: weight set to 1 (n=1, sum(w)=w, new_w=1)
- `by` with one group: equivalent to global stabilization
- `by` with a group of size 1: weight for that observation set to 1

### `.trim_weights_internal()` Test Coverage

Tested indirectly via `trim_weights()` tests. No direct test file for the internal
helper — all relevant edge cases (empty lower/upper, clipping on both tails, no
clipping) are covered through the public API tests.

---

## VII. Quality Gates

All of the following must be true before the Utilities phase PR is considered done:

- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤ 2 notes
- [ ] `devtools::test()` passes: all tests green
- [ ] Test coverage ≥ 98% overall
- [ ] Every new `cli_abort()` and `cli_warn()` call has a `class=` argument
- [ ] Every new error/warning class is listed in `plans/error-messages.md`
- [ ] Snapshot tests added for all new user-facing `cli_abort()` calls
- [ ] `devtools::document()` run; NAMESPACE and man/ files are in sync
- [ ] All exported function examples are runnable (`R CMD check`)
- [ ] History entries use correct `operation` strings: `"trim_weights"`, `"stabilize_weights"`
- [ ] `trim_weights()` preserves total weight sum (redistribution test passes)
- [ ] `trim_weights(strict = TRUE)` guarantees all weights within `[lower_abs, upper_abs]`
- [ ] `test_invariants()` called in every new constructor test block
- [ ] `surveywts-conventions.md` updated with `utilities` family
- [ ] `plans/error-messages.md` updated with all new classes (see §VIII)

---

## VIII. Integration

### `plans/error-messages.md`

The following new classes must be added before the Implementation Plan is written:

**New for `trim_weights()`:**
- `surveywts_error_null_bound_percentile`
- `surveywts_error_k_not_scalar`
- `surveywts_error_k_nonpositive`
- `surveywts_error_lower_not_scalar`
- `surveywts_error_upper_not_scalar`
- `surveywts_error_bounds_invalid`
- `surveywts_error_upper_nonpositive`
- `surveywts_error_percentile_out_of_range`
- `surveywts_warning_no_weights_trimmed`
- `surveywts_warning_trimming_failed`

**New for `stabilize_weights()`:**
- `surveywts_error_by_variable_not_found`

All other error classes used by both functions (`surveywts_error_unsupported_class`,
`surveywts_error_empty_data`, `surveywts_error_weights_not_found`, etc.) already exist
in `plans/error-messages.md`.

### `surveywts-conventions.md`

Add the `utilities` family to the `@family groups` table:

```r
#' @family utilities
trim_weights <- function(...)
stabilize_weights <- function(...)
```

### Interaction with Propensity Phase

The Propensity phase calls `.trim_weights_internal()` directly from `R/nonprob-ipw.R`.
No changes to `trim_weights()` or `stabilize_weights()` are required when Propensity
ships. The only contract is that `.trim_weights_internal()` remains in `R/utils.R`
with the same signature.

### Dependencies

No new `Imports` or `Suggests` entries required. `survey` is already in `Imports`.
`tidyselect` is already in `Imports`. Both functions use only base R and existing
internal helpers (`pmax`, `pmin`, `stats::quantile()`, `tidyselect::eval_select()`).

### Vendoring Attribution

`.trim_weights_internal()` is vendored from `survey::do_trimWeights()` (Thomas Lumley,
GPL-2/3), the internal helper that powers `survey::trimWeights()`. The clip-and-redistribute
loop in `trim_weights()` mirrors `survey::trimWeights.survey.design2()`. The replicate
column-wise redistribution in step 7 mirrors `survey::trimWeights.svyrep.design()`.

The source file `R/utils.R` must include a comment attributing the origin and commit:

```r
# Clip-and-redistribute logic adapted from survey::do_trimWeights (Thomas Lumley, GPL-2/3).
# Source: https://github.com/cran/survey/blob/4834b8bc91f6414ad4514552daaed8990a86d9c1/R/grake.R#L449
```

Consistent with the attribution comments in `R/vendor-calibrate-greg.R` and
`R/vendor-calibrate-ipf.R`.
