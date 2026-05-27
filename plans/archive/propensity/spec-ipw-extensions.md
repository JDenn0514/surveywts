# spec-ipw-extensions.md

**Version:** 0.3
**Date:** 2026-05-26
**Status:** SPEC_READY — Stage 3 PASS; all review issues resolved
**ID:** ipw-extensions

---

## Document Purpose

This spec is the source of truth for all behavioral changes and documentation
additions required by the six-paper methodological audit of `ipw()` in
`R/nonprob-ipw.R`. It governs the builder; the tester uses
`test-spec-ipw-extensions.md` exclusively.

The spec **extends** `ipw()` in place. All existing behavior rules are
unchanged unless explicitly modified below. The existing function signature,
error classes, and output contract are preserved; this spec adds new arguments
after the current ones and adds new behavior blocks before the NR call.

---

## I. Scope

### What this spec delivers

| Gap | Type | Deliverable |
|-----|------|-------------|
| C-1 | Code fix | Change `estimator = "ht"` → `estimator = "ipw2"` in history entry |
| C-2 | Doc | Replace variance `@details` bullet with full refit-required documentation |
| C-3 | Code + doc | Add `adjust_reference` argument; apply Valliant (2020) Eq. (1) adjustment when `nps_fraction > 0.05`; add two warning classes |
| C-4 | Doc | Add misspecification sensitivity section to `@note` |
| H-1 | Doc | Document unconditional estimating equation in `@details` |
| H-2 | Doc | Replace "Selection on observables" `@note` bullet with MAR assumption text |
| H-3 | Doc | Extend `@param reference` with quality requirements |
| H-4 | Doc | Add doubly robust recommendation to `@details`; add `@seealso` |
| H-5 | Doc | Part of C-2 — jackknife preferred over bootstrap |
| H-6 | Code + doc | Add `estimating_eq` argument; implement GEE path in internal NR engine; add `estimating_eq` to history entry |
| M-1 | Code | Add numeric range check and reverse factor level check to common support validation |
| M-2 | Doc | Extend `@param method` with theoretical grounding caveat |
| M-3 | Doc | Extend `@param missing_method` "separate" item with theoretical caveat |
| M-4 | Code | Add `nps_fraction` to history entry |
| M-5 | Doc | Add independence of participation `@note` bullet |
| M-6 | Code | Add `propensity_scores` to history entry |
| L-1 | Doc | Add high-dimensional selection caveat to `@details` |
| L-2 | Doc | Add QBIPW approximation note to `@details` |
| L-3 | Doc | Add measurement equivalence caveat to `@param reference` or `@note` |
| L-4 | Code + doc | Add `population_size` argument; record in history entry |

### What this spec does NOT deliver

- Implementation of doubly robust estimation (H-4 references it as a future function)
- Implementation of QBIPW (L-2 shows the workaround; native QBIPW is a future release)
- Implementation of `diagnose_propensity()` (planned for the Diagnostics phase)
- Changes to any function other than `ipw()` and its internal engine
- Changes to `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse()`, or any replicate weight function

### Class support matrix

`ipw()` accepts only `data.frame` as `data`. This is unchanged.
`reference` must be `survey_taylor`. This is unchanged.
All new arguments apply uniformly regardless of `missing_method` or `method`.

---

## II. Architecture

All changes are confined to `R/nonprob-ipw.R`. No new R files. No new test
helpers (use existing `make_surveywts_data()` and bundled datasets).

```
R/
  nonprob-ipw.R              ← all changes here
    .fit_participation_propensity()   ← new estimating_eq parameter; GEE branch
    ipw()                             ← three new arguments; new validation/behavior blocks
tests/testthat/
  test-08-ipw.R              ← existing test file; new test blocks added
plans/
  error-messages.md          ← add six new classes
  spec-ipw-extensions.md     ← this file
  test-spec-ipw-extensions.md
```

---

## III. `.fit_participation_propensity()` — Internal Engine

### III.A Signature (updated)

```r
.fit_participation_propensity <- function(
  selection, nps_data, ref_data, ref_weights, method, estimating_eq, maxit, epsilon
)
```

`estimating_eq` is a new required parameter. It is always validated by
`match.arg()` in `ipw()` before the call; the internal function trusts the
value.

### III.B Existing behavior (unchanged)

All code before the NR loop (`has_sep` detection, factor level alignment,
`X_nps_fit`, `X_nps_pred`, `X_ref`, `d_ref`, `gamma` initialization, `link`,
`converged`, `delta`) is unchanged.

### III.C NR loop — path-branching (new)

The NR loop retains the outer saturation guard on `X_nps_pred` for all paths
(current behavior). Inside the loop, after the outer guard, branch on
`estimating_eq`:

#### MLE path (current — unchanged)

```
score ← colSums(X_nps_fit) − X_ref^T (d_ref · π_ref)
hess  ← −X_ref^T diag(d_ref · π_ref · (1 − π_ref)) X_ref
```

where `π_ref = link(X_ref %*% gamma)`.

#### GEE path (new — H-6)

```
π_nps ← link(X_nps_fit %*% gamma)
```

Inner guard (GEE-specific, checked before score/Jacobian computation):
```
if any(π_nps ≤ eps):
  return list(scores = link(X_nps_pred %*% gamma), converged = FALSE,
              final_delta = max(|delta|))
```

GEE score and Jacobian:
```
score ← colSums(X_nps_fit / π_nps) − X_ref^T d_ref
hess  ← −X_nps_fit^T diag((1 − π_nps) / π_nps) X_nps_fit
```

where `X_ref^T d_ref = colSums(X_ref * d_ref)` (reference population
covariate totals — fixed within the iteration, does not depend on gamma).

The existing `solve(hess, score)` with `tryCatch` for Hessian singularity is
reused for both paths.

**Critical difference from MLE:** The GEE Jacobian sums over NPS rows; the MLE
Hessian sums over reference rows. Both paths use the same `solve(hess, score)`
and convergence check.

**Convergence criterion:** Both paths use the same criterion: `max(abs(delta)) < epsilon`
checked after each NR step, where `delta = solve(hess, score)` is the NR update vector.
The `epsilon` argument is shared by both paths.

**Return value:** Unchanged for both paths — `list(scores, converged, final_delta)`
where `scores = link(X_nps_pred %*% gamma)` at the final gamma.

**GEE + missing_method = "separate" interaction:** When `has_sep = TRUE`,
`X_nps_fit` covers only complete-case NPS rows. The GEE calibration guarantee
(`Σ w_k x_k = Σ d_k^B x_k`) therefore applies only to complete-case rows.
This is documented in `ipw()`'s `@param estimating_eq` and `@param
missing_method` (see Section IV.H). **No runtime warning is emitted** for this
combination; the limitation is communicated through documentation only,
consistent with the treatment of `missing_method = "separate"` in other
contexts (M-3). No code change is needed inside the engine; the engine already
uses `X_nps_fit` correctly.

**Convergence failure and error propagation:** When `.fit_participation_propensity()`
returns `converged = FALSE` — whether triggered by the MLE outer saturation guard
or the GEE inner saturation guard — `ipw()` follows the same existing
convergence-failure path that throws `surveywts_error_propensity_scores_degenerate`.
This path is unchanged by this spec; the GEE inner guard is simply an additional
trigger for the same error.

### III.D Return value

Unchanged: `list(scores, converged, final_delta)`. `scores` are the propensity
score predictions on ALL NPS rows (from `X_nps_pred`), suitable for the
`propensity_scores` history field.

---

## IV. `ipw()` — User-Facing Function

### IV.A Signature (updated)

```r
ipw <- function(
  data,
  reference,
  selection      = NULL,
  predictors     = NULL,
  missing_method = c("omit", "separate", "impute"),
  mice_args      = list(),
  method         = "logit",
  estimating_eq  = c("mle", "gee"),
  maxit          = 25L,
  epsilon        = 1e-8,
  adjust_reference = TRUE,
  trim           = FALSE,
  population_size = NULL,
  wt_name        = "ipw_weight"
)
```

Argument order follows `code-style.md §4` (data → optional NSE → optional
scalar). All three new arguments are optional scalars with defaults; existing
argument order is preserved.

### IV.B Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `data.frame` | — | Non-probability sample. |
| `reference` | `survey_taylor` | — | Probability-based reference sample. Must have strictly positive design weights and must represent the target population without material coverage or nonresponse bias (see `@param reference` documentation in §IV.H). |
| `selection` | formula | `NULL` | One-sided formula specifying propensity covariates. Exactly one of `selection`/`predictors` must be supplied. |
| `predictors` | `character` | `NULL` | Character vector of covariate names. Programmatic alternative to `selection`. |
| `missing_method` | `character(1)` | `"omit"` | How to handle NPS NA values. One of `"omit"`, `"separate"`, `"impute"`. |
| `mice_args` | `list` | `list()` | Additional arguments for `mice::mice()`. Used only when `missing_method = "impute"`. |
| `method` | `character(1)` | `"logit"` | Link function. One of `"logit"`, `"probit"`, `"cloglog"`. Partial matching. |
| `estimating_eq` | `character(1)` | `"mle"` | Estimating equation for the propensity model. One of `"mle"` (pseudo-likelihood score, current default) or `"gee"` (calibration score that guarantees weighted NPS covariate totals equal reference totals). Partial matching. |
| `maxit` | `integer(1)` | `25L` | Maximum Newton-Raphson iterations. Must be ≥ 1. |
| `epsilon` | `numeric(1)` | `1e-8` | Convergence threshold. Must be > 0. |
| `adjust_reference` | `logical(1)` | `TRUE` | Whether to apply Valliant (2020) Eq. (1) reference weight adjustment when `nps_fraction > 0.05`. Must be `logical(1)`, non-NA. |
| `trim` | `logical` | `FALSE` | Whether to trim IPW weights at median + 5 × IQR. |
| `population_size` | `numeric(1)` | `NULL` | Known population size N. When supplied, overrides the self-normalizing N̂ estimate in the history entry. Must be a positive finite scalar. Affects only the history entry, not the estimated weights. |
| `wt_name` | `character(1)` | `"ipw_weight"` | Name for the output weight column. |

### IV.C Validation rules (new — added to existing block)

The following new validation rules slot into the existing validation sequence.
All existing rules 0–13 apply unchanged.

**Rule 0d — `estimating_eq` partial match:**
Immediately after Rule 0 (`match.arg(method, ...)`), apply:
```r
estimating_eq <- match.arg(estimating_eq, c("mle", "gee"))
```

**Rule 0e — `adjust_reference` type check:**
After Rule 0d. Trigger: `adjust_reference` is not `logical(1)` or is `NA`.
```
Error class: surveywts_error_adjust_reference_invalid
"x" = "{.arg adjust_reference} must be TRUE or FALSE."
"i" = "Got {.cls {class(adjust_reference)}} of length {length(adjust_reference)}."
"v" = "Set {.code adjust_reference = TRUE} (default) or {.code adjust_reference = FALSE}."
```

**Rule 0f — `population_size` validation:**
After Rule 0e. Only triggered when `population_size` is non-NULL.
Trigger: `population_size` is not `numeric(1)`, is `NA`, is not finite, or is ≤ 0.
```
Error class: surveywts_error_population_size_invalid
"x" = "{.arg population_size} must be a positive finite number."
"i" = "Got {.val {population_size}}."
"v" = "Supply a known census population count or leave {.arg population_size = NULL} to use the self-normalizing estimate."
```

### IV.D Behavior rules (new)

#### Rule 9a-ii — Reference weight adjustment (C-3)

**Position:** Immediately after reference NA handling (Rule 9a, after reference
rows are excluded and `ref_weights_for_fit` is finalized), **before** NPS NA
handling (Rule 9b/9c/9d).

1. Compute `n_hat <- sum(ref_weights_for_fit)` (estimated population size from
   the post-NA-deletion reference).
2. Compute `nps_fraction <- nrow(data) / n_hat` (using `data` before any NPS
   NA deletion, i.e., full NPS row count).
3. Determine the adjustment factor:
   - If `adjust_reference == TRUE` and `nps_fraction > 0.05`:
     - `adjust_factor <- 1 - nps_fraction`  (i.e., `(n_hat - n_NPS) / n_hat`)
     - Multiply: `ref_weights_for_fit <- ref_weights_for_fit * adjust_factor`
     - Emit `surveywts_warning_ipw_reference_weight_adjusted` (see §VI)
   - If `adjust_reference == FALSE` and `nps_fraction > 0.05`:
     - `adjust_factor <- 1` (no adjustment)
     - Emit `surveywts_warning_ipw_reference_unadjusted_large_nps` (see §VI)
   - Otherwise (`nps_fraction <= 0.05`, regardless of `adjust_reference`):
     - `adjust_factor <- 1` (adjustment is unnecessary and not applied)
     - No warning emitted

The `adjust_factor` value (1.0 when no adjustment; `1 - nps_fraction` when
adjusted) is recorded in the history entry.

**Order-of-operations constraint:** `n_hat` must be computed from
`ref_weights_for_fit` **after** reference NA listwise deletion, so that
excluded reference rows do not inflate `n_hat`.

**Threshold note:** The 5% threshold operationalizes Valliant (2020) §2.1.1
("if n is a small fraction of N̂, this adjustment is unnecessary"). The paper
does not quantify "small"; 5% is an engineering choice.

#### Rule 8b — Numeric covariate range check (M-1)

**Position:** After Rule 9a (reference NA handling), before Rule 9b/9c/9d
(NPS NA handling). Use `ref_data_for_fit` (the post-NA-deletion reference
data frame), not `reference@data`.

For each variable `var` in `sel_vars`:
- If `data[[var]]` and `ref_data_for_fit[[var]]` are both numeric:
  - `nps_range <- range(data[[var]], na.rm = TRUE)`
  - `ref_range <- range(ref_data_for_fit[[var]], na.rm = TRUE)`
  - If `nps_range[1] < ref_range[1]` or `nps_range[2] > ref_range[2]`:
    - Emit `surveywts_warning_ipw_covariate_range_extrapolation` (see §VI)

Only numeric covariates are checked; character and factor covariates are
covered by Rule 8 (error on NPS levels absent from reference) and Rule 8c below.

#### Rule 8c — Reference factor levels absent from NPS (M-1)

**Position:** After Rule 8b (same block — both after Rule 9a, before Rule 9b/9c/9d).

For each variable `var` in `sel_vars`:
- If `data[[var]]` is character or factor:
  - `nps_levels <- unique(as.character(data[[var]][!is.na(data[[var]])]))`
  - `ref_levels <- unique(as.character(ref_data_for_fit[[var]][!is.na(ref_data_for_fit[[var]])]))`
  - `absent_in_nps <- setdiff(ref_levels, nps_levels)`
  - If `length(absent_in_nps) > 0`:
    - Emit `surveywts_warning_ipw_reference_levels_absent_from_nps` (see §VI)

This is a **warning**, not an error (unlike Rule 8 which errors on NPS levels
absent from reference). Reference units in absent cells have propensity scores
near 0 — they do not prevent model fitting. The warning gives diagnostic signal
without blocking the user.

#### Rule 14 (extended) — Pass `estimating_eq` to internal engine (H-6)

The existing Rule 14 call to `.fit_participation_propensity()` is extended with
the `estimating_eq` argument:
```r
fit <- .fit_participation_propensity(
  selection     = selection,
  nps_data      = data,
  ref_data      = ref_data_for_fit,
  ref_weights   = ref_weights_for_fit,
  method        = method,
  estimating_eq = estimating_eq,   # NEW
  maxit         = as.integer(maxit),
  epsilon       = epsilon
)
```

#### Rule 20 (extended) — Updated history entry

The history entry is extended with five new fields and one fixed field.
**Note:** The field names and types below must stay in sync with the schema
table in §V — any future amendment requires updating both locations.



```r
history_entry <- list(
  step                      = length(.get_history(result)) + 1L,
  timestamp                 = Sys.time(),
  operation                 = "ipw",
  formula                   = selection,
  method                    = method,
  estimating_eq             = estimating_eq,         # NEW (H-6)
  missing_method            = missing_method,
  estimator                 = "ipw2",                # FIXED from "ht" (C-1)
  adjust_reference          = adjust_reference,      # NEW (C-3)
  nps_fraction              = nps_fraction,          # NEW (M-4)
  adjust_factor             = adjust_factor,         # NEW (C-3)
  trim                      = trim,
  n_nps                     = nrow(data),
  n_reference               = nrow(ref_data_for_fit),
  estimated_population_size = if (!is.null(population_size)) population_size
                              else estimated_population_size, # L-4
  population_size_known     = !is.null(population_size),     # NEW (L-4)
  n_trimmed                 = as.integer(n_trimmed),
  reference_design          = reference,
  targets_from_reference    = FALSE,
  propensity_scores         = scores                 # NEW (M-6)
)
```

`estimated_population_size` behavior:
- If `population_size` is NULL: `sum(w_before_trim)` as before (IPW2/Hájek)
- If `population_size` is supplied: use the supplied value (IPW1 semantics in
  downstream analysis); the weights themselves are unaffected

`propensity_scores`: the full numeric vector of length `nrow(data)` (after NA
omit when `missing_method = "omit"`). Stores propensity scores in (0, 1).
Enables downstream `diagnose_propensity()` to compute AUC, calibration plots,
and standardized mean differences without refitting the model.

### IV.E Error table (new classes only)

Existing error classes in `plans/error-messages.md §ipw()` are unchanged.

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_adjust_reference_invalid` | `adjust_reference` is not `logical(1)` or is `NA` |
| `surveywts_error_population_size_invalid` | `population_size` is non-NULL and is not a positive finite numeric scalar |

### IV.F Warning table (new classes only)

Existing warning classes are unchanged.

| Class | Trigger condition | Message summary |
|-------|-------------------|-----------------|
| `surveywts_warning_ipw_reference_weight_adjusted` | `adjust_reference = TRUE` and `nps_fraction > 0.05` | Reports NPS size, population estimate, NPS fraction, and adjustment factor applied; cites Valliant (2020) Eq. (1) |
| `surveywts_warning_ipw_reference_unadjusted_large_nps` | `adjust_reference = FALSE` and `nps_fraction > 0.05` | Reports NPS fraction; notes that Valliant (2020) recommends adjustment; suggests setting `adjust_reference = TRUE` |
| `surveywts_warning_ipw_covariate_range_extrapolation` | NPS numeric covariate outside reference range | Reports variable name, NPS range, reference range; cites common support assumption |
| `surveywts_warning_ipw_reference_levels_absent_from_nps` | Reference factor level absent from NPS | Reports variable name and absent levels; explains near-zero propensity consequence |

#### Warning message templates

**`surveywts_warning_ipw_reference_weight_adjusted`:**
```
"!" = "NPS ({nrow(data)} units) is {round(nps_fraction * 100, 1)}% of the estimated population (N_hat = {round(n_hat)})."
"i" = "Reference weights adjusted by factor {round(adjust_factor, 4)} per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat."
"v" = "Set {.code adjust_reference = FALSE} to skip this adjustment if the NPS is known to be disjoint from the reference frame."
```

**`surveywts_warning_ipw_reference_unadjusted_large_nps`:**
```
"!" = "NPS fraction is {round(nps_fraction * 100, 1)}% of the estimated population but {.code adjust_reference = FALSE}."
"i" = "Valliant (2020) recommends adjusting reference weights when n_NPS / N_hat > 5%."
"v" = "Set {.code adjust_reference = TRUE} (the default) to apply the correction."
```

**`surveywts_warning_ipw_covariate_range_extrapolation`:**
```
"!" = "Variable {.field {var}} has a wider range in {.arg data} ([{nps_range[1]}, {nps_range[2]}]) than in {.arg reference} ([{ref_range[1]}, {ref_range[2]}])."
"i" = "NPS units outside the reference covariate range violate the common support assumption and may produce extreme propensity scores."
"v" = "Consider removing NPS units with {.field {var}} values outside [{ref_range[1]}, {ref_range[2]}], or trimming with {.code trim = TRUE}."
```

**`surveywts_warning_ipw_reference_levels_absent_from_nps`:**
```
"!" = "{length(absent_in_nps)} level(s) of variable {.field {var}} are present in {.arg reference} but not in {.arg data}: {.and {.val {absent_in_nps}}}."
"i" = "Reference units in these cells have no NPS analog. Their propensity scores will be near 0, contributing extreme weights to the score equation."
"v" = "Review whether {.field {var}} is measured equivalently in both samples."
```

### IV.G Output contract

Unchanged. `ipw()` returns a `survey_nonprob` object. `@data` contains all
columns of the (possibly row-reduced) `data` plus `wt_name`. A history entry
is appended to `@metadata@weighting_history`. The history entry schema is
extended as specified in §V.

### IV.H Documentation text changes

This section specifies the exact roxygen2 text changes required. Each
subsection identifies the location (roxygen2 section and approximate line
number in current code) and the new text.

#### `@param reference` (H-3, L-3)

**Replace** the current single-sentence `@param reference` with:

```r
#' @param reference A `survey_taylor` object representing the probability-based
#'   reference sample. Must have strictly positive design weights. The reference
#'   sample must itself represent the target population without material coverage
#'   or nonresponse bias — design weights alone do not correct for an internally
#'   biased reference survey. Elliott & Valliant (2017) recommend using large,
#'   well-controlled probability surveys (e.g., government-conducted household
#'   surveys) as the reference; a biased reference will produce biased propensity
#'   estimates regardless of model specification. Shared covariates must be
#'   measured with the same question wording, response options, and measurement
#'   period in both samples — category differences (e.g., 4-point vs. 5-point
#'   scales) produce spurious covariate imbalance that the propensity model
#'   cannot correct (Valliant, 2020).
```

#### `@param method` (M-2)

**Replace** the current two-sentence `@param method` with:

```r
#' @param method Link function for the propensity model. One of `"logit"`
#'   (default), `"probit"`, or `"cloglog"`. Partial matching is supported.
#'   Asymptotic consistency and normality results in the cited literature
#'   (Chen, Li & Wu, 2021; Beresewicz et al., 2025) are derived specifically
#'   for logistic regression. `"probit"` and `"cloglog"` are computationally
#'   valid alternatives but have weaker formal backing in the pseudo-likelihood
#'   framework for non-probability samples.
```

#### `@param estimating_eq` (H-6 — new parameter)

**Add** after `@param method`:

```r
#' @param estimating_eq Estimating equation for the propensity model. One of
#'   `"mle"` (default) or `"gee"`. Partial matching is supported.
#'
#'   - `"mle"` uses the pseudo-likelihood score equation
#'     (Chen, Li & Wu, 2021; Beresewicz et al., 2025, eq. 3.1). Weights
#'     reproduce the reference-weighted covariate totals in expectation but
#'     not exactly.
#'   - `"gee"` uses the calibration estimating equations
#'     (Beresewicz et al., 2025, eq. 3.3). At convergence, the weighted NPS
#'     covariate totals exactly reproduce the reference-weighted totals:
#'     `sum(w_k * x_k) = sum(d_k * x_k)`. When `adjust_reference = TRUE`
#'     and `nps_fraction > 0.05`, the calibration target is the
#'     Valliant-adjusted reference totals `sum(adjust_factor * d_k * x_k)`
#'     (where `adjust_factor = 1 - nps_fraction`), not the original
#'     design-weight totals. This covariate balance guarantee
#'     makes `"gee"` the building block for doubly robust estimation.
#'     When `missing_method = "separate"`, the guarantee applies only to
#'     complete-case NPS rows.
#'
#'   Beresewicz et al. (2025) show GEE-based methods generally outperform MLE
#'   in simulation. For most applications `"gee"` is preferred.
```

#### `@param missing_method` (M-3 — add caveat to "separate" item)

**Extend** the `"separate"` item description with:

```r
#'     **Caveat:** The pseudo-likelihood is fitted on complete-case NPS rows
#'       only; propensity scores are predicted for all rows by substituting
#'       `"(Missing)"` with the reference baseline level. This adaptation is
#'       not derived from the pseudo-likelihood framework and has no published
#'       theoretical validation. Use `missing_method = "impute"` for a more
#'       principled missing data approach.
```

#### `@param adjust_reference` (C-3 — new parameter)

**Add** after `@param epsilon`:

```r
#' @param adjust_reference Logical (default `TRUE`). Whether to apply Valliant
#'   (2020) Eq. (1) reference weight adjustment when the NPS is a non-negligible
#'   fraction of the estimated population. When `nps_fraction = nrow(data) /
#'   sum(d)` (where `d` are the reference design weights after excluding rows
#'   with `NA` in any selection variable) exceeds 0.05, the reference weights
#'   are multiplied by `(N_hat - n_NPS) / N_hat` to prevent the reference-side
#'   score denominator from being inflated by NPS units already counted on the
#'   NPS side. When `nps_fraction <= 0.05`, no adjustment is applied regardless
#'   of this argument. Set `adjust_reference = FALSE` to skip the adjustment
#'   when the NPS and reference frames are known to be disjoint and the
#'   correction is inappropriate.
```

#### `@param population_size` (L-4 — new parameter)

**Add** after `@param trim`:

```r
#' @param population_size Optional positive numeric scalar. If the population
#'   size N is known from a census or frame, supply it here. When provided,
#'   `estimated_population_size` in the history entry records this known value
#'   and `population_size_known` is set to `TRUE`. This value is stored for
#'   reference only and does not affect the returned weights or any downstream
#'   `svymean()` call (which always uses the Hájek/IPW2 estimator). To compute
#'   an IPW1-style mean manually: `sum(result@data[[wt_name]] * y) /
#'   population_size`. When `NULL` (default), `population_size_known = FALSE`
#'   and the self-normalizing estimate `N_hat = sum(1 / pi_hat)` is recorded
#'   (IPW2/Hájek). If `population_size < nrow(data)`, the recorded value will
#'   be smaller than the sample size — this indicates a user error (N < n is
#'   impossible). Verify that `population_size` is the total population count N,
#'   not a subsample or domain size.
```

#### `@examples` additions

**Add** after the existing examples (after the `predictors =` vector interface block):

```r
#' # --- GEE estimating equation ---
#' # GEE guarantees sum(w * x) = sum(d * x) at convergence;
#' # generally preferred over the default MLE when covariate balance matters.
#' result_gee <- ipw(
#'   ns_wave1_ipw,
#'   gss_ipw_ref,
#'   selection = ~gender + age_group,
#'   estimating_eq = "gee"
#' )
#'
#' # --- Known population size ---
#' # Supply N from a census frame to record it in the history entry.
#' # The returned weights are unchanged; N enables manual IPW1 means:
#' #   sum(result@data[["ipw_weight"]] * y) / population_size
#' result_known_n <- ipw(
#'   ns_wave1_ipw,
#'   gss_ipw_ref,
#'   selection = ~gender + age_group,
#'   population_size = 258000000L
#' )
#' result_known_n@metadata@weighting_history[[1]]$population_size_known
```

#### `@details` additions

**Replace** the current single-sentence variance bullet (current lines 189–191):

```r
#' **Variance estimation — refit required:** Naive variance estimates from the
#' returned `survey_nonprob` object treat the propensity scores as fixed and
#' underestimate variance. Correct variance estimation requires a replication
#' approach in which the propensity model is **refit at every replicate**
#' (bootstrap resample or jackknife group) so that estimation uncertainty in
#' the propensity parameters is captured (Elliott & Valliant, 2017; Valliant,
#' 2020).
#'
#' Jackknife is generally preferred over bootstrap when point estimates are
#' nearly unbiased: Valliant (2020, Table 9) shows jackknife confidence interval
#' coverage consistently nearer the 95% nominal level than bootstrap with
#' replacement. Both require refitting the propensity model at each replicate.
#'
#' A correct jackknife procedure (preferred):
#' 1. Partition `data` into G groups (G = 20 is a standard choice;
#'    Valliant (2020, §2.1.4) uses G = 20 in simulations).
#' 2. For each group g (1..G), omit group g from `data` and call `ipw()` on
#'    the reduced NPS dataset and the full `reference`.
#' 3. Compute the estimand from each of the G replicate weighted samples.
#' 4. Compute jackknife variance:
#'    `V_JK = ((G - 1) / G) * sum((theta_g - mean(theta_g))^2)`.
#'
#' A correct bootstrap procedure (valid alternative):
#' 1. Resample `data` with replacement (simple random, or cluster-aware if the
#'    NPS has a known cluster structure).
#' 2. Resample `reference` using a design-respecting method — for complex
#'    designs, use Rao-Wu rescaled bootstrap
#'    (`survey::as.svrepdesign(type = "subbootstrap")`) rather than plain SRS
#'    resampling.
#' 3. Call `ipw()` on each resample pair to produce new weights.
#' 4. Compute the estimand from each replicate's weighted sample.
#' 5. Use replicate variance as the variance estimate.
#'
#' Both procedures apply equally when `estimating_eq = "gee"`. Variance
#' estimates that do not refit the propensity model at each replicate will be
#' anti-conservative.
```

**Add** after the variance section (new `@details` bullets):

```r
#' **Estimating equation:** `ipw()` uses the *unconditional* pseudo-likelihood
#' approach (Valliant & Dever, 2011, as described in Elliott & Valliant, 2017,
#' p. 256). NPS units enter the score equation with implicit weight 1; reference
#' units enter with their design weights. This estimates P(NPS | in population)
#' directly, rather than P(NPS | in combined sample). The alternative
#' *conditional* approach — pooling both samples and running an unweighted
#' logistic regression with NPS membership as the outcome — is not used because
#' it does not account for reference design weights and estimates a different
#' quantity (Chen, Li & Wu, 2021, §2.1).
#'
#' **Doubly robust estimation (recommended):** The papers in `@references`
#' unanimously recommend combining IPW weights with an outcome regression model
#' to form a doubly robust (DR) estimator. A DR estimator is consistent if
#' *either* the propensity model *or* the outcome regression model is correctly
#' specified — providing protection against misspecification of either.
#' Valliant (2020) found DR "was the best combination in this study in terms
#' of bias, RMSE, and confidence interval coverage"; Yang et al. (2020) show
#' that DR substantially outperforms IPW-only under propensity misspecification.
#' The weights returned by `ipw()` are the propensity component of such a DR
#' pipeline; the outcome regression step is planned for a future release.
#'
#' **Sensitivity to propensity model misspecification:** IPW estimates can be
#' severely biased when selection is nonlinear and the `selection` formula does
#' not capture this nonlinearity. Chen, Li & Wu (2021, Table 1) demonstrate
#' ~25% relative bias under a misspecified propensity model even when the
#' correct variables are included. Beresewicz et al. (2025) show RMSE
#' increases of 30× or more under nonlinear selection. To mitigate this risk:
#' add interaction or polynomial terms to `selection` if nonlinear selection is
#' suspected; follow `ipw()` with a doubly robust step; or use
#' `diagnose_propensity()` (planned) to assess covariate balance.
#'
#' **High-dimensional selection:** For large covariate vectors, Elliott &
#' Valliant (2017) recommend regularized alternatives such as LASSO-penalized
#' logistic regression, BART, or super learner. `ipw()` uses Newton-Raphson on
#' the full unpenalized model and may overfit in high-dimensional settings. In
#' such cases, fit the propensity model externally, extract predicted
#' probabilities, and use them directly.
#'
#' **Quantile balancing approximation:** Beresewicz et al. (2025) show that
#' augmenting the propensity model with quantile-indicator variables for
#' continuous covariates substantially reduces bias under nonlinear selection
#' ("quantile balancing IPW"). Users can approximate this by adding cut-point
#' indicators to `selection`:
#' ```r
#' nps$age_q <- cut(nps$age, quantile(nps$age, c(0, .25, .5, .75, 1)),
#'                  include.lowest = TRUE)
#' ipw(nps, ref, selection = ~age_q + sex)
#' ```
#' Native QBIPW support (Beresewicz et al., 2025, eqs. 4.1–4.2) is planned
#' for a future release.
```

#### `@note` replacements and additions

**Replace** the current "Selection on observables" bullet with (H-2):

```r
#' **Missing at random (MAR) assumption:** `ipw()` is consistent only if NPS
#' participation is independent of the outcome variable given the observed
#' covariates in `selection` — formally, P(I_NPS = 1 | X, Y) = P(I_NPS = 1 |
#' X). This is called "missing at random" (MAR) or "non-informative sampling"
#' in the survey statistics literature (Chen, Li & Wu, 2021, Assumption A1;
#' Valliant, 2020). It is not testable from observed data. If participation
#' depends on Y even after conditioning on X (not missing at random, NMAR),
#' IPW weights will be biased regardless of model quality. Common causes of
#' NMAR in opt-in panels include self-selection on health, income, or political
#' engagement when those outcomes are also the study variables.
```

**Add** after the "Common support" `@note` bullet (M-5):

```r
#' **Independence of participation:** The pseudo-likelihood assumes NPS
#' participation decisions are independent across units given the covariates in
#' `selection` (Chen, Li & Wu, 2021, Assumption A3). This assumption fails when
#' NPS units are clustered — for example, household panels where multiple family
#' members participate together, or snowball-recruited samples. In clustered NPS
#' settings the propensity model should include cluster-level covariates, and
#' variance estimation should use cluster-aware resampling.
#'
#' **Non-overlapping samples:** The pseudo-likelihood codes NPS units as
#' members (1) and reference units as non-members (0). If the same individual
#' appears in both `data` and `reference`, the coding is inconsistent and
#' propensity estimates will be biased. Remove any units present in both samples
#' from `reference` before calling `ipw()` (Valliant, 2020, §2.1.2).
```

#### `@seealso` (H-4 — new section)

**Add** a `@seealso` section:

```r
#' @seealso
#'   [adjust_nonresponse()] for unit nonresponse adjustment via weighting
#'   class methods, which can serve as the IPW step in a doubly robust pipeline
#'   when the nonresponse mechanism is modeled.
#'
#'   [calibrate_to_survey()] for post-stratification and raking calibration
#'   that can be applied after `ipw()` as the regression correction step of a
#'   doubly robust estimator.
#'
#'   `diagnose_propensity()` (planned) for propensity score diagnostics
#'   including AUC, covariate balance plots, and standardized mean differences.
#'   Uses the `propensity_scores` stored in the history entry returned by
#'   `ipw()` without refitting the model.
```

#### `@references` additions (net-new citations only)

The following citations appear in the `@details`, `@note`, and `@param` additions
above but are **not** in the existing `@references` block. The builder must add
each one that is not already present after checking the current file.

**Already present in current `@references` (do not duplicate):**
- Elliott, M.R. and Valliant, R. (2017). *Statistical Science* 32(2), 249--264.
- Chen, Y., Li, P. and Wu, C. (2020). *JASA* 115(532), 2011--2021.
  Note: the spec cites this as "Chen, Li & Wu (2021)" in several places — the
  existing file uses 2020. Use 2020 (the published year) throughout; update
  any "2021" in-text references introduced by this PR to "2020".

**Net-new — add these entries:**

```r
#' Valliant, R. and Dever, J.A. (2011). Estimating propensity adjustments
#' for volunteer web surveys. *Sociological Methods & Research*
#' **40**(1), 105--137.
#'
#' Valliant, R. (2020). Comparing alternatives for estimation from
#' nonprobability samples. *Survey Methods: Insights from the Field*
#' **16**(1). \doi{10.13094/SMIF-2020-00011}
#'
#' Yang, S., Kim, J.K. and Song, R. (2020). Doubly robust inference when
#' combining probability and non-probability samples with high dimensional
#' data. *Journal of the Royal Statistical Society: Series B* **82**(2),
#' 445--465.
#'
#' Beresewicz, M., Szymkowiak, M. and Chlebicki, P. (2025). Quantile
#' balancing inverse probability weighting for non-probability samples.
#' *[Verify journal/preprint details before submission; cite arXiv or
#' published venue as appropriate.]*
```

---

## V. History Entry Schema

The complete updated schema for the `ipw` history entry:

| Field | Type | Description |
|-------|------|-------------|
| `step` | `integer(1)` | Position in the weighting history |
| `timestamp` | `POSIXct` | Time of the `ipw()` call |
| `operation` | `character(1)` | Always `"ipw"` |
| `formula` | `formula` | The `selection` formula used (possibly constructed from `predictors`) |
| `method` | `character(1)` | Link function: `"logit"`, `"probit"`, or `"cloglog"` |
| `estimating_eq` | `character(1)` | **NEW** — `"mle"` or `"gee"` |
| `missing_method` | `character(1)` | `"omit"`, `"separate"`, or `"impute"` |
| `estimator` | `character(1)` | **FIXED** — always `"ipw2"` (was `"ht"`) |
| `adjust_reference` | `logical(1)` | **NEW** — value of the `adjust_reference` argument |
| `nps_fraction` | `numeric(1)` | **NEW** — `nrow(data) / n_hat` computed from post-NA-deletion reference |
| `adjust_factor` | `numeric(1)` | **NEW** — `1 - nps_fraction` if adjustment applied; `1.0` otherwise |
| `trim` | `logical(1)` | Value of the `trim` argument |
| `n_nps` | `integer(1)` | Number of NPS rows used (after NA deletion when `missing_method = "omit"`) |
| `n_reference` | `integer(1)` | Number of reference rows used (after NA deletion) |
| `estimated_population_size` | `numeric(1)` | `population_size` if supplied; else `sum(w_before_trim)` |
| `population_size_known` | `logical(1)` | **NEW** — `TRUE` if `population_size` was supplied |
| `n_trimmed` | `integer(1)` | Number of weights trimmed; 0 if `trim = FALSE` |
| `reference_design` | `survey_taylor` | The `reference` object |
| `targets_from_reference` | `logical(1)` | Always `FALSE` |
| `propensity_scores` | `numeric` | **NEW** — vector of length `n_nps`; propensity score for each NPS row |

`propensity_scores` stores the full vector. For `n_nps = 10,000` this is ~80KB.
This is acceptable given that history entries already store the full
`reference_design` object. Users who want to strip scores to reduce memory can
replace the field: `result@metadata@weighting_history[[1]]$propensity_scores <- NULL`.

---

## VI. Error/Warning Class Additions to `plans/error-messages.md`

Add the following rows to the `ipw()` sections:

**Errors:**

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_adjust_reference_invalid` | `ipw()` | `adjust_reference` is not `logical(1)` or is `NA` |
| `surveywts_error_population_size_invalid` | `ipw()` | `population_size` is non-NULL and is not a positive finite numeric scalar |

**Warnings:**

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_warning_ipw_reference_weight_adjusted` | `ipw()` | `adjust_reference = TRUE` and `nps_fraction > 0.05` |
| `surveywts_warning_ipw_reference_unadjusted_large_nps` | `ipw()` | `adjust_reference = FALSE` and `nps_fraction > 0.05` |
| `surveywts_warning_ipw_covariate_range_extrapolation` | `ipw()` | A selection numeric variable has a wider range in `data` than in `reference` |
| `surveywts_warning_ipw_reference_levels_absent_from_nps` | `ipw()` | A reference factor level is absent from the NPS for a selection variable |

---

## VII. Quality Gates

Done means ALL of the following are true:

- [ ] `R CMD check` passes: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/ipw.Rd` are up to date
- [ ] All six new warning/error classes are in `plans/error-messages.md`
- [ ] `estimator = "ipw2"` in history entry (not `"ht"`)
- [ ] `estimating_eq = "gee"` path: at convergence, `sum(w * x) ≈ sum(d_adjusted * x)` for all covariates (tolerance 1e-6), where `d_adjusted = ref_weights_for_fit` after Rule 9a-ii (equals original `d` when `nps_fraction ≤ 0.05` or `adjust_reference = FALSE`)
- [ ] `adjust_reference` adjustment factor recorded in history entry (`adjust_factor` field)
- [ ] `nps_fraction` in history entry
- [ ] `propensity_scores` in history entry as numeric vector
- [ ] `population_size_known` in history entry
- [ ] Rules 8b and 8c execute after reference NA handling (use `ref_data_for_fit`) and before NPS NA handling
- [ ] Rule 9a-ii executes after reference NA handling and before NPS NA handling
- [ ] All four new warning classes have snapshot tests and `expect_warning(class = ...)` tests
- [ ] Both new error classes have dual-pattern tests (`expect_error(class = ...)` + `expect_snapshot(error = TRUE)`)
- [ ] Test coverage ≥ 98% for `R/nonprob-ipw.R`
- [ ] All `@examples` run under `R CMD check` without error
- [ ] roxygen documentation changes are in place for all gaps C-2, C-4, H-1 through H-5, M-2, M-3, M-5, L-1 through L-3
