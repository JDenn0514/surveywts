# surveywts Propensity Phase Spec

**Version:** 0.5 — 2026-05-21 amendment: `missing_method` + `mice_args` args replacing hard NA error; Lenau (2021) reference (see `decisions-propensity.md`)
**Date:** 2026-05-20
**Status:** Approved
**ID:** `propensity`

---

## Document Purpose

This spec is the source of truth for the Propensity phase of surveywts. It governs the
design and implementation of `ipw()` — the primary function for
constructing inverse probability weights for non-probability samples using a companion
probability reference sample — and the removal of the `adjust_nonresponse(method =
"propensity")` stub.

Every implementation decision, API contract, and error condition for this phase must be
resolved here before any R code is written. The Implementation Plan derives from this
document and must not deviate from it without a documented decision.

---

## I. Scope

### Deliverables

| Deliverable | Function / Object | Source file |
|-------------|-------------------|-------------|
| Non-probability sample IPW | `ipw()` | `R/nonprob-ipw.R` (new) |
| Propensity fitting helper (file-local) | `.fit_participation_propensity()` | `R/nonprob-ipw.R` (file-local) |
| Nonresponse propensity method | `adjust_nonresponse(method = "propensity")` | `R/nonresponse.R` (extend) |
| Harmonized NPS dataset — ns_wave1 | `ns_wave1_ipw` | `data/ns_wave1_ipw.rda` (new) |
| Harmonized reference — gss_2024 | `gss_ipw_ref` | `data/gss_ipw_ref.rda` (new) |
| Harmonized NPS dataset — pew_npors_2025 | `npors_2025_ipw` | `data/npors_2025_ipw.rda` (new) |
| Harmonized reference — acs_pums_wy | `acs_ipw_ref` | `data/acs_ipw_ref.rda` (new) |
| Dataset documentation | — | `R/data.R` (new) |
| Data preparation scripts | — | `data-raw/ns-gss-ipw.R` (new), `data-raw/npors-acs-ipw.R` (new) |

### What This Phase Does NOT Deliver

- Mass imputation (MI) estimators — MI produces population estimates, not survey design
  weights; belongs in estimation, not weighting
- Doubly robust (DR) estimators — same reasoning
- Bootstrap variance with propensity model re-estimation — standard `create_bootstrap_weights()`
  suffices; model-resampling bootstrap deferred to a future phase
- Tree/ensemble propensity models (`ranger`, `gbm`) — deferred to a future minor bump;
  logistic regression covers the core case; these would move into `Suggests` when added
- Population-totals-only IPW (calibrated IPW / Chen-Li-Wu GEE approach) — when only
  population totals are available (no reference sample), `calibrate()` / `rake()` produce
  weights with the same population-calibration property; no new function needed
- Balance diagnostics (`check_balance()`, `diagnose_propensity()`) — Diagnostics phase

### Roadmap Clarifications

**`calibrate_nonresponse()` is removed.** The Nonresponse spec's "What This Phase Does
Not Deliver" section names `calibrate_nonresponse()` as a Propensity phase deliverable.
That function was removed from the roadmap. Calibrating respondent weights to population
totals after nonresponse adjustment is handled by the existing `calibrate()` / `rake()` /
`poststratify()` functions. No new function is needed.

**`propensity-cell` is already implemented.** The Nonresponse phase implemented
`adjust_nonresponse(method = "propensity-cell")` with a self-contained inline logistic
regression. This phase does NOT refactor that implementation to share code with
`ipw()`. The decision rationale is in §IX.

### Statistical Scope: Quasi-Randomization Framework Only

`ipw()` implements the **quasi-randomization framework** (Elliott &
Valliant 2017): it requires a companion probability sample with overlapping auxiliary
variables. The NPS participation propensity π̂_i = P(Z=1 | X_i) — where Z=1 indicates
membership in the non-probability sample — is estimated by pooling the NPS and reference
sample and fitting a survey-weighted logistic regression.

The calibrated-IPW approach (population totals only, no reference sample; Chen-Li-Wu
2020) is out of scope: it is mathematically equivalent to calibration/raking to population
totals, which `calibrate()` and `rake()` already implement.

### Input Class Support

| Function | Accepted input |
|---|---|
| `ipw()` | `data.frame` only — NPS raw data; no prior design |
| `adjust_nonresponse(method = "propensity")` | `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob` (same as existing methods; not `survey_replicate`) |

---

## II. Architecture

### Source File Map

```
R/
  nonprob-ipw.R   ← NEW: ipw(),
                         .fit_participation_propensity() (file-local)
  nonresponse.R   ← EXTEND: unlock method = "propensity" (inline glm, no shared helper)
```

`R/nonprob-ipw.R` is a new file. The roadmap's `08-nonprob-ipw.R` filename was a planning
artifact; this package does not use numeric prefixes (per Nonresponse and Utilities spec
precedent and the global CLAUDE.md convention).

No changes to `R/utils.R` are required: `.trim_weights_internal()` was introduced in the
Utilities phase and is called from `R/nonprob-ipw.R` without modification.

**Why no shared `.estimate_propensity_scores()` in `R/utils.R`?**

Response propensity in `adjust_nonresponse(method = "propensity")` — P(respond | sampled)
— and participation propensity in `ipw()` — P(in NPS | X) — require
different data structures:

- NPS case: pool two separate samples (NPS rows with Z=1, reference rows with Z=0, different
  weight schemes for each group)
- Nonresponse case: single sample, response indicator already present, existing design weights
  used throughout

A shared helper would require conditional branching on the problem type, negating the
simplification. Per engineering-preferences.md: DRY over structural similarity, not
surface similarity. Both use `stats::glm()` with `family = binomial`, but the data
preparation and weight assignment differ enough to keep them separate.

### `@family` Tag

`ipw()` introduces a new `propensity` family. Add it to
`surveywts-conventions.md` before the Implementation Plan is written:

| Family tag | Functions |
|------------|-----------|
| `propensity` | `ipw()` |

---

## III. `ipw()`

### Purpose

Construct inverse probability weights for a non-probability sample (NPS) using a companion
probability sample as reference. Estimates the participation propensity π̂_i = P(unit i is
in the NPS | auxiliary variables X_i) by fitting a survey-weighted logistic regression on
the pooled NPS and reference data. Returns a `survey_nonprob` object with IPW weights
w_i = 1/π̂_i.

The quasi-randomization framework (Elliott & Valliant 2017) treats the non-probability
selection mechanism as pseudo-random with unknown probabilities estimated from observed
covariates. IPW weights of the form 1/π̂ produce approximately design-unbiased estimates
of population means and totals when the selection-on-observables assumption holds — all
relevant factors driving NPS participation must be captured by the covariates in
`selection`. Bias from unmeasured participation drivers persists regardless of weight
magnitude or model complexity.

### Signature

```r
ipw(
  data,
  reference,
  selection      = NULL,
  predictors     = NULL,
  missing_method = c("omit", "separate", "impute"),
  mice_args      = list(),
  method         = c("logit", "probit", "cloglog"),
  maxit          = 25L,
  epsilon        = 1e-8,
  trim           = FALSE,
  wt_name        = "ipw_weight"
)
```

### Argument Table

| Argument | Type | Default | Description |
|---|---|---|---|
| `data` | `data.frame` | required | The non-probability sample. Must be a plain `data.frame`. All `selection` variables must be present and non-missing. |
| `reference` | `survey_taylor` | required | The reference probability sample design object from surveycore. Provides both auxiliary variable data and design weights for the pseudo-likelihood estimation. |
| `selection` | one-sided R formula | `NULL` | Specifies propensity model covariates, e.g. `~ age_group + sex`. All variables must exist in both `data` and `reference@data`. Exactly one of `selection` or `predictors` must be non-`NULL`. |
| `predictors` | `character` vector | `NULL` | Programmatic alternative to `selection`. Character vector of covariate names, e.g. `c("age_group", "sex")`. Converted internally to `stats::reformulate(predictors)`. Useful for `lapply()` workflows iterating over covariate sets. Exactly one of `selection` or `predictors` must be non-`NULL`. |
| `missing_method` | `character(1)` | `"omit"` | How to handle `NA` values in `selection` variables in `data`. `"omit"`: rows with any NA in a selection variable are dropped before fitting and excluded from `@data`; a warning reports the count and which variables. `"separate"`: NA values in **factor and character** selection variables are recoded to an explicit `"(Missing)"` level so those units still enter the propensity model and receive weights. **Numeric selection variables with NA values are not supported under `"separate"` — `ipw()` errors with `surveywts_error_separate_numeric_na`.** Convert the numeric variable to a factor (e.g. with `cut()`) or use `missing_method = "impute"` instead. `"impute"`: missing values in selection variables are imputed via a single iteration of predictive mean matching using `mice::mice()` (requires the `mice` package); the imputed complete data are used for propensity model fitting and all NPS units receive weights. Regardless of `missing_method`, NA values in selection variables in `reference@data` are always handled by listwise deletion with a warning. |
| `mice_args` | `list` | `list()` | Named list of additional arguments forwarded to `mice::mice()` when `missing_method = "impute"`. Only the selection variables with NA values are passed to `mice`. The argument `m` is fixed at `1` (single imputation) and cannot be overridden. The default imputation method is `"pmm"` (predictive mean matching, per Lenau et al. 2021) and may be overridden via `mice_args = list(method = "norm")`. Ignored when `missing_method` is `"omit"` or `"separate"`. |
| `method` | `character(1)` | `"logit"` | Link function for the propensity model. `"logit"`: logit link. `"probit"`: probit link. `"cloglog"`: complementary log-log link. All solved via Newton-Raphson on the pseudo-likelihood. |
| `maxit` | `integer(1)` | `25L` | Maximum Newton-Raphson iterations. |
| `epsilon` | `numeric(1)` | `1e-8` | Convergence criterion: iteration stops when `max(abs(delta)) < epsilon` where `delta` is the NR parameter update. |
| `trim` | `logical(1)` | `FALSE` | If `TRUE`, apply `.trim_weights_internal()` using the IQR-based upper bound: `median(w) + 5 * IQR(w)`, no lower bound. Users who need custom trimming bounds should leave `trim = FALSE` and call `trim_weights()` on the output. |
| `wt_name` | `character(1)` | `"ipw_weight"` | Name of the IPW weight column in the returned `survey_nonprob@data`. |

### Output Contract

Returns a `survey_nonprob` object with:

- `@data`: `data` with one new column named `wt_name` containing IPW weights. All original
  columns in `data` are preserved; no rows are dropped.
- `@variables$weights`: `wt_name`
- `@reference_sample`: `reference` (the `survey_taylor` object supplied as the `reference`
  argument). Stored so `surveywts::create_bootstrap_weights(design)` is self-contained for
  propensity-based bootstrap without requiring an extra argument.
- `@metadata@weighting_history`: one entry appended:
  ```
  operation                 = "ipw"
  formula                   = selection          # formula object; deparse() at print time
  method                    = <"logit", "probit", or "cloglog">
  missing_method            = <"omit", "separate", or "impute">
  estimator                 = "ht"              # hard-coded; Hájek support deferred to future phase
  trim                      = <logical: the trim argument value>
  n_nps                     = nrow(data)        # after NA removal when missing_method = "omit"
  n_reference               = nrow(reference@data)  # after reference NA removal
  estimated_population_size = sum(ipw_weights_before_trim)
  n_trimmed                 = <integer: 0 if trim = FALSE; count of trimmed weights otherwise>
  reference_design          = reference         # survey_taylor object; enables Level B bootstrap
  targets_from_reference    = FALSE             # default FALSE; a subsequent rake()/calibrate()
                                                # sets TRUE if its targets are derived from
                                                # reference_design (per spec-methodology-nps-bootstrap.md Q3)
  ```

### Weight Formula

`ipw()` implements the **pseudo-likelihood** approach of Chen et al. (2021), which is
also the method used by `nonprobsvy`. This differs from the plain survey-weighted GLM
(Valliant & Dever 2011): the two solve different estimating equations and produce
different propensity scores. The pseudo-likelihood is the theoretically correct approach
under the quasi-randomization framework (Wu 2022).

Within `.fit_participation_propensity()`:

1. **Extract model matrices and reference weights**:
   ```r
   X_nps <- stats::model.matrix(selection, data = nps_data)   # n_NPS × p
   X_ref <- stats::model.matrix(selection, data = ref_data)   # n_ref × p
   d_ref <- ref_weights                                        # reference design weights
   ```

2. **Newton-Raphson on the pseudo-log-likelihood** (logit case shown; probit and
   cloglog use analogous derivatives):

   The pseudo-log-likelihood is:
   ```
   l*(γ) = Σ_{NPS} x_i'γ  −  Σ_{ref} d_j log(1 + exp(x_j'γ))
   ```
   Score S(γ) and Hessian H(γ):
   ```
   S(γ) = Σ_{NPS} x_i  −  Σ_{ref} d_j π̂_j x_j
   H(γ) = −Σ_{ref} d_j π̂_j(1 − π̂_j) x_j x_j'
   ```
   where π̂_j = expit(x_j'γ) = 1/(1 + exp(−x_j'γ)).

   In R:
   ```r
   gamma <- rep(0, ncol(X_nps))
   for (iter in seq_len(maxit)) {
     pi_ref <- stats::binomial(link = method)$linkinv(X_ref %*% gamma)
     score  <- colSums(X_nps) - drop(t(X_ref) %*% (d_ref * pi_ref))
     hess   <- -crossprod(X_ref, X_ref * (d_ref * pi_ref * (1 - pi_ref)))
     delta  <- tryCatch(
       solve(hess, score),
       error = function(e) stop(structure(
         list(message = e$message),
         class = c("surveywts_error_propensity_hessian_singular", "error", "condition")
       ))
     )
     gamma  <- gamma - delta
     if (max(abs(delta)) < epsilon) break
     if (iter == maxit) warn surveywts_warning_propensity_nr_no_convergence
   }
   ```

3. **Predict propensity scores for NPS units**:
   ```r
   scores <- stats::binomial(link = method)$linkinv(X_nps %*% gamma)
   ```
   These are π̂_i = P(Z = 1 | X_i) for each NPS unit.

4. **Compute IPW weights**:
   ```r
   weights <- 1 / scores
   ```

The weight w_i = 1/π̂_i estimates how many population units each NPS unit represents.
Units with low participation propensity receive higher weights. The sum Σ w_i = Σ (1/π̂_i)
estimates the population size N̂.

### Statistical Notes (document in `@note`)

- **Selection on observables:** IPW reduces bias only when all factors driving NPS
  participation that also correlate with survey outcomes are included in `selection`.
  Unmeasured participation drivers produce residual bias regardless of weight magnitude.
- **Common support:** Requires overlap between the NPS covariate distribution and the
  reference sample. When NPS units have no reference analogues (no common support), the
  quasi-randomization framework fails and IPW weights become unstable. There is no automatic
  support check; users should call `diagnose_propensity()` (Diagnostics phase) or manually
  compare covariate distributions.
- **Variance under-estimation:** `create_bootstrap_weights()` applied to the output
  resamples rows without re-estimating propensity scores. This produces bootstrap variance
  estimates that undercount propensity model estimation uncertainty. This is standard
  practice for applied survey weighting but is a known limitation. Propensity model-
  resampling bootstrap variance is deferred to a future phase.
- **Weight interpretation:** `ipw()` produces unnormalized weights. The package design
  commitment is Hájek-type (ratio) estimation: weighted means are computed as
  `Σ y_i w_i / Σ w_i`, so the estimated population size N̂ = Σ w_i cancels in the
  denominator. For HT-type total estimation (requires known N), users must supply an
  external population size estimate and should NOT rely on N̂ = Σ w_i as the divisor.
  Users may call `stabilize_weights()` on the output to rescale weights to sum to n
  (sample size) for ratio-estimator workflows.
- **Pre-trim population size:** `estimated_population_size` in the weighting history is always
  the pre-trim sum `Σ w_i` (before any trimming). When `trim = TRUE`, the actual weights in
  `@data` sum to a different (lower) value. Use `sum(result@data[[wt_name]])` to get the
  post-trim total for HT-type estimation.

### Behavior Rules

0. Coerce `method` via `match.arg(method)` (standard R partial-match; invalid values produce a base R error).
0a. If both `selection` and `predictors` are non-`NULL` → `surveywts_error_selection_conflict`.
0b. If both `selection` and `predictors` are `NULL` → `surveywts_error_selection_missing`.
0c. If `predictors` is non-`NULL`: build `selection <- stats::reformulate(predictors)` and proceed through the remaining rules using `selection`; set `environment(selection) <- baseenv()` to avoid capturing the local frame.
1. `data` must be a plain `data.frame`. Any other class → `surveywts_error_not_data_frame`.
2. `reference` must satisfy `S7::S7_inherits(reference, surveycore::survey_taylor)`. Any other
   class → `surveywts_error_svydesign_not_taylor`.
3. Extract reference design weights from `reference`. If `any(ref_weights <= 0)` →
   `surveywts_error_reference_weights_nonpositive`.
4. `nrow(data) == 0` → `surveywts_error_empty_data`.
5. Validate `selection` via `.validate_formula(selection)` → `surveywts_error_formula_invalid`.
6. Validate `selection` variables in `data` via `.validate_formula_variables(selection, data, "data")`
   → `surveywts_error_formula_variable_not_found`.
7. Validate `selection` variables in `reference@data` via a new call:
   `.validate_formula_variables(selection, reference@data, "reference", error_class = "surveywts_error_formula_variable_not_in_reference")` →
   `surveywts_error_formula_variable_not_in_reference`. Use a distinct error class from (6)
   so the user knows which dataset is the problem. (`error_class = NULL` is the backward-compatible
   default; existing callers are unaffected.)
8. For each `selection` variable that is a factor or character type, check that every level
   present in `data` is also present in `reference@data`. Any level found in `data` but not
   in `reference@data` → `surveywts_error_propensity_level_not_in_reference`, naming the
   variable and the orphaned levels. Levels present in `reference@data` but absent from
   `data` do not require action — the model handles this gracefully.
9. Coerce `missing_method` via `match.arg(missing_method)` (invalid values produce a base R error).
9a. **Reference NA handling (always listwise):** For each `selection` variable, count NAs in
    `reference@data[[var]]`. If any are found, drop those rows from the reference data used
    for model fitting and emit `surveywts_warning_ipw_reference_na_omitted` reporting the
    count and which variables. This happens regardless of `missing_method`.
9b. **NPS NA handling — `missing_method = "omit"`:** For each `selection` variable, count NAs
    in `data[[var]]`. Drop all rows with any NA in any selection variable. If any rows are
    dropped, emit `surveywts_warning_ipw_data_na_omitted` reporting the count and which
    variables. Dropped rows are excluded from `@data` in the returned object
    (`nrow(result@data) ≤ nrow(data)`).
9c. **NPS NA handling — `missing_method = "separate"`:** For each `selection` variable with
    any NA:
    - If the variable is **factor or character**: recode `NA` to an explicit `"(Missing)"`
      level. `model.matrix()` then produces a dummy variable for that level, and all NPS
      units receive propensity scores and weights.
    - If the variable is **numeric**: error immediately with
      `surveywts_error_separate_numeric_na`, naming the variable and advising the user to
      convert to a factor via `cut()` or switch to `missing_method = "impute"`.
    No rows are dropped. `nrow(result@data) == nrow(data)`.
9d. **NPS NA handling — `missing_method = "impute"`:** Require the `mice` package; if not
    installed, error with `surveywts_error_mice_not_installed`. Identify selection variables
    that have at least one NA in `data`. Extract those columns (plus any complete selection
    variables needed for the imputation model) into a sub-frame. Call:
    ```r
    imp <- do.call(
      mice::mice,
      c(list(data = impute_df, m = 1L, method = "pmm", printFlag = FALSE), mice_args)
    )
    completed <- mice::complete(imp, 1L)
    ```
    Replace the imputed columns in `data` with `completed`. The argument `m` is always
    forced to `1L` even if the user passes `m` via `mice_args`; emit
    `surveywts_warning_ipw_mice_m_ignored` if the user attempted to override `m`. No rows
    are dropped. `nrow(result@data) == nrow(data)`.
10. Validate `wt_name` via `.validate_wt_name(wt_name)` → `surveywts_error_wt_name_not_scalar`,
    `surveywts_error_wt_name_empty`.
11. If `wt_name` already exists as a column in `data`, throw `surveywts_error_wt_name_conflict`.
12. If `maxit < 1L` → `surveywts_error_propensity_invalid_maxit`. (With `maxit = 0L`, the
    NR loop body never executes and gamma stays at all-zeros, producing silently uniform
    weights with no diagnostic. Reject before any computation.)
13. If `epsilon <= 0` → `surveywts_error_propensity_invalid_epsilon`. (A non-positive epsilon
    means `max(abs(delta)) < epsilon` is never satisfied; NR always runs to `maxit` and
    emits a non-convergence warning with no pointer to the real cause.)
14. Call `.fit_participation_propensity()`. If Newton-Raphson exhausts `maxit` iterations
    without `max(abs(delta)) < epsilon`, emit `surveywts_warning_propensity_nr_no_convergence`
    including the number of iterations and the final `max(abs(delta))`. Scores from the
    final incomplete iteration are still returned; the user is responsible for deciding
    whether to trust them. Document in `@details` that NR non-convergence indicates
    potential perfect separation or very sparse covariate cells — inspect covariate
    distributions and consider simplifying `selection`.
15. Validate estimated scores: if `any(scores <= 0 | scores >= 1)` →
    `surveywts_error_propensity_scores_degenerate`. This guards against perfect separation
    where `glm()` returns boundary predictions (0 or 1) rather than erroring.
16. Warn if `any(scores < 0.01)`: emit `surveywts_warning_extreme_propensity_scores`,
    including the count and the minimum observed score. Scores near 0 produce extreme weights
    (high variance and sensitivity to model misspecification).
17. Compute weights: `w <- 1 / scores`.
18. If `trim = TRUE`: call `.trim_weights_internal(w, lower = -Inf, upper = median(w) +
    5 * IQR(w), has_trimmed = rep(FALSE, length(w)))`. Use `$weights` from the result.
    `.trim_weights_internal()` returns a list with `$weights` (trimmed weight vector) and
    `$has_trimmed` (logical vector; `TRUE` for each trimmed weight) per the Utilities spec;
    set `n_trimmed = sum(result$has_trimmed)`.
19. Record `estimated_population_size = sum(w_before_trim)` for the history entry (before any
    trimming, so users can compare to a known population size). Note: when `trim = TRUE`,
    `estimated_population_size` reflects the pre-trim sum; users must call
    `sum(result@data[[wt_name]])` to get the post-trim total.
20. Construct and return `survey_nonprob` via the surveycore internal constructor, with the
    new weight column and history entry.

### Error Table

| Error class | Condition |
|---|---|
| `surveywts_error_selection_missing` | Both `selection` and `predictors` are `NULL` (new) |
| `surveywts_error_selection_conflict` | Both `selection` and `predictors` are non-`NULL` (new) |
| `surveywts_error_not_data_frame` | `data` is not a `data.frame` (new) |
| `surveywts_error_svydesign_not_taylor` | `reference` is not `survey_taylor` (new) |
| `surveywts_error_reference_weights_nonpositive` | Any reference design weight ≤ 0 (new) |
| `surveywts_error_empty_data` | `nrow(data) == 0` (reuse) |
| `surveywts_error_formula_invalid` | `selection` is not a valid one-sided formula (reuse) |
| `surveywts_error_formula_variable_not_found` | A `selection` variable is missing from `data` (reuse) |
| `surveywts_error_formula_variable_not_in_reference` | A `selection` variable is missing from `reference@data` (new) |
| `surveywts_error_propensity_level_not_in_reference` | A factor/character `selection` variable has levels in `data` absent from `reference@data` (new) |
| `surveywts_error_separate_numeric_na` | `missing_method = "separate"` and a numeric selection variable in `data` has NA values (new) |
| `surveywts_error_mice_not_installed` | `missing_method = "impute"` but the `mice` package is not installed (new) |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` (reuse) |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` (reuse) |
| `surveywts_error_wt_name_conflict` | `wt_name` already exists as a column in `data` (reuse) |
| `surveywts_error_propensity_invalid_maxit` | `maxit < 1L` (new) |
| `surveywts_error_propensity_invalid_epsilon` | `epsilon <= 0` (new) |
| `surveywts_error_propensity_scores_degenerate` | Any estimated propensity score ≤ 0 or ≥ 1 (new) |
| `surveywts_error_propensity_hessian_singular` | Hessian is singular during Newton-Raphson (collinear/degenerate covariates) (new) |

### Warning Table

| Warning class | Condition |
|---|---|
| `surveywts_warning_extreme_propensity_scores` | Any estimated propensity score < 0.01 (new) |
| `surveywts_warning_propensity_nr_no_convergence` | Newton-Raphson exhausted `maxit` iterations without meeting `epsilon` (new) |
| `surveywts_warning_ipw_data_na_omitted` | `missing_method = "omit"` dropped one or more NPS rows with NA in selection variables; reports count and variable names (new) |
| `surveywts_warning_ipw_reference_na_omitted` | One or more reference rows with NA in selection variables were excluded from model fitting; reports count and variable names (new) |
| `surveywts_warning_ipw_mice_m_ignored` | User passed `m` via `mice_args` but `m = 1` is fixed for single imputation; the user-supplied value is ignored (new) |

### Console Output

`ipw()` returns a `survey_nonprob`. The print method for
`survey_nonprob` is inherited from the Calibration phase. No new print method is
required. **However, `.format_history_step()` in `R/utils.R` must be extended with an `"ipw"`
case** that reads `entry$formula` (deparsed via `deparse()`), `entry$method`,
`entry$n_reference`, and `entry$estimated_population_size` to build the bracketed display
string. The `"ipw"` operation currently falls through to the default case (returns only the
operation name); without this extension the history line will be wrong.

The output prints as:

```
# A calibrated survey design: 200 observations, 4 variables
# Variance: model-assisted (SRS assumption)
# IDs: ~1 | Strata: NULL | Weights: ipw_weight
# Weighting history: 1 step
#   Step 1 [2026-05-19]: ipw [~ age_grp + sex, logit, n_ref=1000, N_hat=148392]
```

The history line renders via the existing `.format_history_step()` helper (extended as noted
above). The `formula` field is deparsed at print time via `deparse(entry$formula)`. The format is:

```
#   Step N [YYYY-MM-DD]: ipw [~ age_grp + sex, logit, n_ref=1000, N_hat=148392]
```

Fields shown in brackets: `deparse(formula)`, `method`, `n_ref=<n_reference>`, `N_hat=<estimated_population_size>`.
`trim`, `n_trimmed`, `estimator`, `reference_design`, and `targets_from_reference` are not shown
in the one-line summary (they are accessible via `@metadata@weighting_history` directly).

### References

Document in `@references`:

- Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability samples.
  *Statistical Science* **32**(2), 249–264.
- Chen, Y., Li, P. and Wu, C. (2020). Doubly robust inference with nonprobability
  survey samples. *Journal of the American Statistical Association* **115**(532),
  2011–2021.
- Lenau, S., Marchetti, S., Munnich, R., Pratesi, M., Salvati, N., Shlomo, N.,
  Schirripa Spagnolo, F. and Zhang, L.-C. (2021). Methods for sampling and
  inference with non-probability samples. Deliverable D11.8, InGRID-2 project
  730998 – H2020.

### Bundled Datasets

Four harmonized datasets ship with `surveywts` as package data (`.rda` in `data/`).
They are created by `data-raw/ns-gss-ipw.R` and `data-raw/npors-acs-ipw.R` from raw
`surveycore` datasets. Source datasets require `surveycore (>= 0.9.0)` (already in
`Imports`).

#### `ns_wave1_ipw` — NPS for Pair 1

Source: `surveycore::ns_wave1` (n = 6422, Lucid online panel)

Harmonized columns:

| Column | Type | Source | Notes |
|--------|------|--------|-------|
| `gender` | factor | `ns_wave1$gender` | Levels: `"Male"` (1), `"Female"` (2); 0 NAs |
| `age` | integer | `ns_wave1$age` | Raw ages 18–96; 0 NAs |

No rows dropped. All 6422 units retained.

#### `gss_ipw_ref` — Reference for Pair 1

Source: `surveycore::gss_2024` (n = 3309, GSS probability sample)

Harmonization steps:
1. Drop 19 rows where `gss_2024$sex` is NA → 3290 rows
2. Rename `sex` → `gender`; recode to factor (1 → `"Male"`, 2 → `"Female"`)
3. Keep `age`, `vpsu`, `vstrat`, `wtssps`
4. `gss_ipw_ref <- surveycore::as_survey(., weights = wtssps, strata = vstrat, ids = vpsu)`

Stored object is a `survey_taylor`; n = 3290.

#### `npors_2025_ipw` — NPS for Pair 2

Source: `surveycore::pew_npors_2025` (n = 5022, Pew NPORS online panel)

Harmonized columns:

| Column | Type | Source | Coding | NAs (from 99 → NA) |
|--------|------|--------|--------|---------------------|
| `age_group` | factor | `agegrp` | 1–13 = "18-24", "25-29", …, "80+" | 56 |
| `gender` | factor | `gender` | 1 → `"Male"`, 2 → `"Female"`; 3/99 → NA | 70 |
| `race_ethn` | factor | `racethn` | 1–5 = "White", "Black", "Hispanic", "Asian", "Other"; 99 → NA | 79 |
| `educ` | factor | `educcat` | 1 → `"Less than HS"`, 2 → `"HS/Some college"`, 3 → `"College+"`; 99 → NA | 45 |

Refuse/don't-know codes (99 for all, additionally 3 for gender) are recoded to `NA`
rather than dropped. This produces realistic NA patterns (≈1–2% per variable) for
demonstrating `missing_method`. All 5022 rows retained.

Factor levels for `age_group`: `"18-24"`, `"25-29"`, `"30-34"`, `"35-39"`,
`"40-44"`, `"45-49"`, `"50-54"`, `"55-59"`, `"60-64"`, `"65-69"`, `"70-74"`,
`"75-79"`, `"80+"`.

#### `acs_ipw_ref` — Reference for Pair 2

Source: `surveycore::acs_pums_wy` (n = 5962, ACS PUMS — Wyoming)

Harmonization steps:
1. Filter to adults: `agep >= 18` → 4736 rows
2. `age_group`: `cut(agep, breaks = c(18,25,30,35,40,45,50,55,60,65,70,75,80,Inf), labels = c("18-24","25-29","30-34","35-39","40-44","45-49","50-54","55-59","60-64","65-69","70-74","75-79","80+"), right = FALSE)` — factor; 0 NAs
3. `gender`: factor from `sex` (1 → `"Male"`, 2 → `"Female"`); 0 NAs
4. `race_ethn`: factor derived from `rac1p` + `hisp` (Hispanic-priority coding):
   - `hisp > 1` → `"Hispanic"`
   - `rac1p == 1` → `"White"`
   - `rac1p == 2` → `"Black"`
   - `rac1p %in% 4:6` → `"Asian"`
   - otherwise → `"Other"`
   0 NAs
5. `educ`: factor from `schl`:
   - `schl %in% 1:11` → `"Less than HS"`
   - `schl %in% 12:15` → `"HS/Some college"`
   - `schl %in% 16:24` → `"College+"`
   - `NA` when `schl` is NA (168 NAs in full dataset; 0 in adults — verified)
6. Keep `pwgtp` (person weight)
7. `acs_ipw_ref <- surveycore::as_survey(., weights = pwgtp)` — no strata/PSU args;
   treats as probability sample with person weights only (SRS + weights)

Factor levels for harmonized variables must match `npors_2025_ipw` exactly so
that Behavior Rule 8 (factor level alignment) passes.

Stored object is a `survey_taylor`; n = 4736.

**Dataset documentation** goes in `R/data.R` with `@title`, `@description`,
`@format`, `@source` for each of the four objects. All four are exported (i.e.,
the `.rda` files make them available to users via `data()`). Add `LazyData: true`
to `DESCRIPTION` so datasets are available without calling `data()`.

### Example

```r
# --- Pair 1: ns_wave1 (NPS) + gss_2024 (probability reference) ---
# Harmonized datasets ship with surveywts (see data-raw/ for preparation)
data(ns_wave1_ipw)
data(gss_ipw_ref)

# Formula interface
result1 <- ipw(ns_wave1_ipw, gss_ipw_ref, selection = ~gender + age)

# Programmatic interface — suitable for lapply()
result2 <- ipw(ns_wave1_ipw, gss_ipw_ref, predictors = c("gender", "age"))

# Inspect weight quality before analysis
effective_sample_size(result1)
weight_variability(result1)

# --- Pair 2: pew_npors_2025 (NPS) + acs_pums_wy (probability reference) ---
# npors_2025_ipw has real NA values (refuse/DK recoded from 99 → NA)
data(npors_2025_ipw)
data(acs_ipw_ref)

# missing_method = "omit" (default): rows with NA in selection vars are dropped
result_omit <- ipw(npors_2025_ipw, acs_ipw_ref,
                   selection = ~gender + age_group + race_ethn + educ,
                   missing_method = "omit")

# missing_method = "separate": NA recoded to "(Missing)" factor level; all rows kept
result_sep <- ipw(npors_2025_ipw, acs_ipw_ref,
                  selection = ~gender + age_group + race_ethn + educ,
                  missing_method = "separate")

# missing_method = "impute": NA imputed via mice::mice() (requires mice package)
if (requireNamespace("mice", quietly = TRUE)) {
  result_imp <- ipw(npors_2025_ipw, acs_ipw_ref,
                    selection = ~gender + age_group + race_ethn + educ,
                    missing_method = "impute")
}
```

---

## IV. `.fit_participation_propensity()` (File-Local Helper)

### Purpose

File-local internal helper in `R/nonprob-ipw.R`. Pools the NPS and reference data, fits a
survey-weighted logistic regression, and returns predicted propensity scores for NPS units.

Defined at the top of `R/nonprob-ipw.R`, before `ipw()`.

### Signature

```r
.fit_participation_propensity <- function(
  selection,    # one-sided formula; covariates only
  nps_data,     # data.frame of NPS units — covariate columns only
  ref_data,     # data.frame of reference sample units — covariate columns only
  ref_weights,  # numeric vector of reference sample design weights
  method,       # character(1): "logit", "probit", or "cloglog"
  maxit,        # integer(1): max Newton-Raphson iterations
  epsilon       # numeric(1): NR convergence criterion
)
```

**Returns:** Named numeric vector of length `nrow(nps_data)` containing π̂_i ∈ (0, 1).
No validation — all validation is the caller's responsibility.

**Documentation:** `@keywords internal` + `@noRd`. Per code-style.md: complex enough to
explain.

---

## V. `adjust_nonresponse(method = "propensity")`

### What Changes

The `method = "propensity"` branch currently stubs with `surveywts_error_propensity_not_available`.
This phase implements the full propensity method using an inline `stats::glm()` call —
NOT by delegating to `.fit_participation_propensity()`. See §II Architecture for the
rationale.

### No New Arguments Required

`formula` was already added to `adjust_nonresponse()` in the Nonresponse phase (required
when `method = "propensity-cell"`). It is equally required for `method = "propensity"`.
`control$n_cells` is ignored when `method = "propensity"`.

### Algorithm

1. **Require formula**: `formula = NULL` and `method = "propensity"` →
   `surveywts_error_formula_required_for_propensity` (new class; distinct from propensity-cell).
2. **Validate formula**: `.validate_formula(formula)` → `surveywts_error_formula_invalid`.
3. **Validate formula variables**: `.validate_formula_variables(formula, plain_df, "data")` →
   `surveywts_error_formula_variable_not_found`.
4. **Check for NAs** in formula variables → `surveywts_error_formula_variable_has_na`.
5. **Warn if `by` non-NULL**: `surveywts_warning_by_ignored_for_propensity` (new class; analogous
   to `surveywts_warning_by_ignored_for_propensity_cell` from the Nonresponse phase).
6. **Fit response propensity model**:
   ```r
   status_vec <- plain_df[[response_status_col]]
   fit <- stats::glm(
     stats::update(formula, status_vec ~ .),
     data    = plain_df,
     weights = weight_vec,
     family  = stats::binomial(link = "logit"),
     control = stats::glm.control(maxit = 25, epsilon = 1e-8)
   )
   ```
   Method is always `"logit"` for response propensity (no `method` argument in
   `adjust_nonresponse()`). Catch any `"algorithm did not converge"` warning from
   `stats::glm()` and re-emit as `surveywts_warning_propensity_glm_convergence`,
   stating explicitly that response propensity scores from a non-converged model
   are unreliable and that the user should simplify `formula` or inspect covariate
   distributions. All other GLM warnings pass through unchanged.
7. **Predict response scores** for all units (respondents + nonrespondents):
   ```r
   scores <- stats::predict(fit, type = "response")
   ```
8. **Validate scores**: `any(scores <= 0 | scores >= 1)` →
   `surveywts_error_propensity_scores_degenerate` (reuse from §III).
9. **Warn on extreme scores**: `any(scores < 0.01)` →
   `surveywts_warning_extreme_propensity_scores` (reuse from §III).
10. **Compute adjusted weights**:
    ```
    new_weight_i = weight_i / score_i   for respondents (response_status = 1)
    new_weight_i = 0                     for nonrespondents
    ```
11. **Extreme-adjustment check**: check whether `max(weight_i / score_i) / mean(weight_i)`
    exceeds `control$max_adjust`. The default (2.0) and NULL-disables-check behavior are
    inherited from the existing `adjust_nonresponse()` control list (see Nonresponse spec).
    If exceeded, emit
    `surveywts_warning_extreme_propensity_adjustment` (distinct from
    `surveywts_warning_class_near_empty`, which refers to discrete weighting classes).
    Message text should reference extreme adjustment factors, not cells.
12. **Return**: respondent rows only, with adjusted weights. Same output contract as
    `method = "weighting-class"`. History entry:
    ```
    operation = "nonresponse_propensity"
    formula   = deparse(formula)
    method    = "propensity"
    ```

### Degenerate Response Patterns

All-respondents (`sum(response_status == 0) == 0`) and all-nonrespondents
(`sum(response_status == 1) == 0`) follow the same behavior as `method = "weighting-class"`.
Those cases are already specified in the Nonresponse spec and handled by the shared input-validation
logic in `adjust_nonresponse()`; the propensity branch does not need to re-specify them.

### Statistical Note (document in `@note`)

This is the unit-level analogue of `method = "propensity-cell"`: it applies a continuous
individual-level inverse propensity weight rather than discretizing scores into cells.
Both methods assume MAR conditional on the estimated response propensity. Propensity
estimates are treated as known; variance estimates do not capture model estimation
uncertainty. Perfect separation (all estimated scores near 0 or 1) indicates the response
model is unstable — inspect the covariate distribution and consider simplifying `formula`.

### Error Table (New Errors Only)

| Error class | Condition |
|---|---|
| `surveywts_error_formula_required_for_propensity` | `method = "propensity"` and `formula = NULL` (new; distinct from propensity-cell error) |
| `surveywts_error_propensity_scores_degenerate` | Any estimated score ≤ 0 or ≥ 1 (reuse from §III) |

### Warning Table (New Warnings Only)

| Warning class | Condition |
|---|---|
| `surveywts_warning_by_ignored_for_propensity` | `by` is non-NULL when `method = "propensity"` (new) |
| `surveywts_warning_extreme_propensity_scores` | Any estimated score < 0.01 (reuse from §III) |
| `surveywts_warning_extreme_propensity_adjustment` | `max(w/score) / mean(w)` exceeds `control$max_adjust` (new; replaces `surveywts_warning_class_near_empty` for this method) |
| `surveywts_warning_propensity_glm_convergence` | `stats::glm()` emits "algorithm did not converge" — re-wrapped with explicit message about unreliable scores (new) |

---

## VI. Testing

### Test File Map

| Source file | Test file |
|---|---|
| `R/nonprob-ipw.R` | `tests/testthat/test-nonprob-ipw.R` (new) |
| `R/nonresponse.R` (propensity branch) | `tests/testthat/test-05-nonresponse.R` (extend) |

All Layer 3 error paths use the dual pattern per `testing-surveywts.md`:
`expect_error(class=)` + `expect_snapshot(error=TRUE)`.

### `ipw()` Test Categories

**1. Happy path**

- `data.frame` + `survey_taylor` with default control → returns `survey_nonprob`;
  `test_invariants()` on result
- `@data` has new column named `"ipw_weight"` (default `wt_name`)
- All original columns in `data` are preserved; `nrow(result@data) == nrow(data)`
- History entry: `operation = "ipw"`, `n_nps`, `n_reference`, `trim = FALSE`, `n_trimmed = 0`,
  `missing_method = "omit"` (default)
- `method = "logit"` (default): all weights positive; `sum(weights) > 0`
- `method = "probit"`: valid `survey_nonprob` result
- `method = "cloglog"`: valid `survey_nonprob` result
- Custom `wt_name`: weight column uses the specified name
- `trim = TRUE`: history entry has `trim = TRUE`, `n_trimmed >= 0`; `sum(result_weights) ≈ sum(untrimmed_weights)`
  (within `1e-10` when trimming succeeds); `test_invariants()` passes
- `missing_method = "omit"` with NAs in a factor selection variable: dropped rows excluded
  from `@data`; `nrow(result@data) < nrow(data)`; `test_invariants()` passes;
  `surveywts_warning_ipw_data_na_omitted` emitted
- `missing_method = "separate"` with NAs in a factor selection variable: all rows preserved
  in `@data`; `nrow(result@data) == nrow(data)`; all weights positive; `test_invariants()` passes
- `missing_method = "impute"` with NAs in a selection variable: all rows preserved; all
  weights positive; `test_invariants()` passes (`skip_if_not_installed("mice")`)
- `mice_args = list(seed = 42)` with `missing_method = "impute"`: result is reproducible;
  same weights on two calls with the same seed
- NA values in `reference@data` selection variable: reference rows dropped; warning emitted;
  result valid; `test_invariants()` passes
- Print snapshot: `print(ipw(...))` matches expected `survey_nonprob` format with
  `ipw  [~ ..., logit, n_ref=..., N_hat=...]` history line

**2. Numerical correctness**

- Compare weighted mean estimates against `nonprobsvy::nonprob()` with `selection = formula`,
  `svydesign = reference_design`, `method_selection = "logit"`:
  ```r
  ipw_mean <- sum(nps_data$y * result@data$ipw_weight) / sum(result@data$ipw_weight)
  # expect_equal(ipw_mean, nonprobsvy_result$output$mean, tolerance = 1e-6)
  ```
  (`skip_if_not_installed("nonprobsvy")` inside the block)
- IPW weights equal `1 / predicted_scores` from the underlying `glm()` (tolerance `1e-10`):
  manually fit the same survey-weighted logistic regression and compare
- All weights positive: `all(result@data$ipw_weight > 0)`

**3. Error paths**

- `data = list(x = 1)` → `surveywts_error_not_data_frame`
- `data = data.frame()` (0 rows) → `surveywts_error_empty_data`
- `reference` is a `data.frame` → `surveywts_error_svydesign_not_taylor`
- `reference` is `survey_nonprob` → `surveywts_error_svydesign_not_taylor`
- `reference` has a zero or negative design weight → `surveywts_error_reference_weights_nonpositive`
- `selection = "~ age_grp"` (character, not formula) → `surveywts_error_formula_invalid`
- `selection` variable missing from `data` → `surveywts_error_formula_variable_not_found`
- `selection` variable missing from `reference@data` → `surveywts_error_formula_variable_not_in_reference`
- `selection` factor variable with a level in `data` absent from `reference@data` → `surveywts_error_propensity_level_not_in_reference`
- `missing_method = "separate"` and a numeric selection variable in `data` has NA →
  `surveywts_error_separate_numeric_na`
- `missing_method = "impute"` and `mice` is not installed →
  `surveywts_error_mice_not_installed`
- `wt_name = 1L` → `surveywts_error_wt_name_not_scalar`
- `wt_name = ""` → `surveywts_error_wt_name_empty`
- `wt_name = NA_character_` → `surveywts_error_wt_name_empty`
- `wt_name = "age_grp"` (already exists in `data`) → `surveywts_error_wt_name_conflict`
- Perfect-separation scenario (all NPS units in one covariate cell not present in reference,
  producing score = 1) → `surveywts_error_propensity_scores_degenerate`
- Collinear `selection` covariates producing a singular Hessian → `surveywts_error_propensity_hessian_singular`

**4. Warning paths**

- Data with some scores < 0.01 (e.g., NPS heavily skewed away from reference distribution
  in one covariate stratum) → `surveywts_warning_extreme_propensity_scores`; result is still
  returned with valid `survey_nonprob`
- `maxit = 1L` with data requiring more than one NR iteration →
  `surveywts_warning_propensity_nr_no_convergence`; result still returned; `test_invariants()` passes
- `missing_method = "omit"` with NAs in a selection variable →
  `surveywts_warning_ipw_data_na_omitted`; warning names the variable and row count
- NA values in a selection variable in `reference@data` →
  `surveywts_warning_ipw_reference_na_omitted`; warning names the variable and row count
- `missing_method = "impute"` and user passes `m` in `mice_args` →
  `surveywts_warning_ipw_mice_m_ignored`; `m = 1` is used regardless
  (`skip_if_not_installed("mice")`)

**5. Edge cases**

- Single covariate: `selection = ~ age_grp`
- Formula with interaction: `selection = ~ age_grp * sex`
- NPS and reference have identical covariate distributions: weights should be approximately
  uniform (low CV), all near `nrow(reference) / nrow(nps)` in magnitude
- Small NPS (n = 5): valid output; no special handling needed
- NPS larger than reference: valid; weights may be small (π̂ close to 1 for all units)

**6. History correctness**

- `estimated_population_size` in history equals `sum(ipw_weights_before_trim)`
- `n_nps` equals `nrow(data)`; `n_reference` equals `nrow(reference@data)`
- `formula` in history entry is a formula object (not a character string): `inherits(entry$formula, "formula")`
- `operation` equals `"ipw"` (not `"propensity_ipw"`)
- `reference_design` in history entry is a `survey_taylor` object: `S7::S7_inherits(entry$reference_design, surveycore::survey_taylor)`
- History step number correct when chained after `adjust_nonresponse()`

### `adjust_nonresponse(method = "propensity")` Test Categories

**1. Happy path**

- `data.frame` input → `weighted_df`; `test_invariants()` on result
- `weighted_df` input → `weighted_df`; `test_invariants()` on result
- `survey_taylor` input → `survey_taylor`; respondent rows only; `test_invariants()` on result
- `survey_nonprob` input → `survey_nonprob`; respondent rows only; `test_invariants()` on result
- Respondent count matches `sum(response_status == 1)`
- History entry: `operation = "nonresponse_propensity"`

**2. Numerical correctness**

- New weight for respondent i = `original_weight_i / predicted_score_i` (verify to `1e-10`)
- Note: weight conservation (`sum(new_wts) ≈ sum(orig_wts)`) holds algebraically for
  weighting-class methods but only approximately for continuous propensity scores (logistic
  regression). Do not assert exact equality; the approximation error depends on data and
  model fit and may be several percent of the total weight in finite samples.

**3. Error paths (new)**

- `method = "propensity"` with `formula = NULL` → `surveywts_error_formula_required_for_propensity`
- `formula` not a formula object → `surveywts_error_formula_invalid` (reuse)
- Formula variable missing → `surveywts_error_formula_variable_not_found` (reuse)
- Formula variable has NA → `surveywts_error_formula_variable_has_na` (reuse)
- Degenerate propensity scores → `surveywts_error_propensity_scores_degenerate` (reuse)
- `method = "propensity"` with `survey_replicate` input → existing
  `surveywts_error_unsupported_class` (no change)

**4. Warning paths**

- `by` non-NULL → `surveywts_warning_by_ignored_for_propensity`; result still valid
- Extreme scores (< 0.01) → `surveywts_warning_extreme_propensity_scores`
- High adjustment factors: if `max(weight_i / score_i) / mean(weight_i)` exceeds `control$max_adjust`
  → `surveywts_warning_extreme_propensity_adjustment` (new)
- Construct a dataset with near-perfect separation to trigger `stats::glm()` non-convergence
  → `surveywts_warning_propensity_glm_convergence`; result still returned. Data-construction
  hint: create a binary covariate where all nonrespondents have value = 1 and all respondents
  have value = 0 (perfect separation). Note: `control = list(maxit = N)` has no effect on
  the GLM; the internal `stats::glm.control(maxit = 25)` is hard-coded in §V step 6.

**5. Edge cases**

- Very high response rate (95%): small adjustment factors; no warning
- Very low response rate (20%): large adjustment factors; `surveywts_warning_extreme_propensity_adjustment` expected
- `control$n_cells = 10` specified: ignored without warning (only relevant for propensity-cell)

---

## VII. Quality Gates

All of the following must be true before the Propensity phase PR is considered done:

- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤ 2 notes
- [ ] `devtools::test()` passes: all tests green
- [ ] Test coverage ≥ 98% overall
- [ ] Every new `cli_abort()` and `cli_warn()` call has a `class=` argument
- [ ] Every new error/warning class is listed in `plans/error-messages.md`
- [ ] Snapshot tests added for all new user-facing `cli_abort()` calls
- [ ] `devtools::document()` run; NAMESPACE and man/ files are in sync
- [ ] All exported function examples are runnable
- [ ] History entries use correct `operation` strings: `"ipw"`, `"nonresponse_propensity"`
- [ ] `test_invariants()` called in every new constructor test block
- [ ] `surveywts-conventions.md` updated with `propensity` family and `ipw()` argument order
- [ ] `plans/error-messages.md` updated with all new classes (see §VIII)
- [ ] `method = "propensity"` stub error removed from `R/nonresponse.R`
- [ ] Numerical correctness test against `nonprobsvy` passes (or skipped if not installed)
- [ ] Console output format confirmed: `Step N [date]: ipw [~ ..., method, n_ref=..., N_hat=...]` (GAP resolved in Stage 4)
- [ ] `.validate_formula_variables()` in `R/utils.R` has `error_class = NULL` parameter added (backward-compatible)
- [ ] `.format_history_step()` in `R/utils.R` has `"ipw"` case added to the `switch()`
- [ ] `missing_method = "omit"` drops rows and warns; `nrow(result@data) ≤ nrow(data)`
- [ ] `missing_method = "separate"` errors on numeric NA; preserves all rows for factor/character NA
- [ ] `missing_method = "impute"` calls `mice::mice()` with `m = 1`, default method `"pmm"`; all rows preserved
- [ ] Reference NA listwise deletion always fires regardless of `missing_method`; warning emitted
- [ ] `mice_args` passthrough works; `m` override triggers `surveywts_warning_ipw_mice_m_ignored`
- [ ] `mice` added to `Suggests` in DESCRIPTION

---

## VIII. Integration

### `plans/error-messages.md`

The following new classes must be added before the Implementation Plan is written:

**New for `ipw()`:**
- `surveywts_error_not_data_frame`
- `surveywts_error_svydesign_not_taylor`
- `surveywts_error_reference_weights_nonpositive`
- `surveywts_error_formula_variable_not_in_reference`
- `surveywts_error_propensity_level_not_in_reference`
- `surveywts_error_propensity_invalid_maxit`
- `surveywts_error_propensity_invalid_epsilon`
- `surveywts_error_propensity_scores_degenerate`
- `surveywts_error_propensity_hessian_singular`
- `surveywts_error_separate_numeric_na`
- `surveywts_error_mice_not_installed`
- `surveywts_warning_extreme_propensity_scores`
- `surveywts_warning_propensity_nr_no_convergence`
- `surveywts_warning_ipw_data_na_omitted`
- `surveywts_warning_ipw_reference_na_omitted`
- `surveywts_warning_ipw_mice_m_ignored`

**New for `adjust_nonresponse(method = "propensity")`:**
- `surveywts_error_formula_required_for_propensity`
- `surveywts_warning_by_ignored_for_propensity`
- `surveywts_warning_extreme_propensity_adjustment`
- `surveywts_warning_propensity_glm_convergence`

Existing classes reused without change (already in `plans/error-messages.md`):
`surveywts_error_empty_data`, `surveywts_error_formula_invalid`,
`surveywts_error_formula_variable_not_found`, `surveywts_error_formula_variable_has_na`,
`surveywts_error_wt_name_not_scalar`, `surveywts_error_wt_name_empty`,
`surveywts_error_wt_name_conflict`, `surveywts_warning_class_near_empty`.

### `surveywts-conventions.md`

Add `propensity` to the `@family groups` table:

| Family tag | Functions |
|------------|-----------|
| `propensity` | `ipw()` |

Add to the argument order table:

| Function | Argument order |
|---|---|
| `ipw()` | `data, reference, selection = NULL, predictors = NULL, missing_method = c("omit", "separate", "impute"), mice_args = list(), method = "logit", maxit = 25L, epsilon = 1e-8, trim = FALSE, wt_name = "ipw_weight"` |

### Dependencies

No new `Imports` required:
- `stats::glm()`, `stats::predict()`, `stats::binomial()`, `stats::glm.control()` — base R
- `surveycore` — already in `Imports`
- `dplyr` — already in `Imports` (used in `data-raw/` scripts, not in package source)
- `.trim_weights_internal()` — already in `R/utils.R` (Utilities phase)

Add `nonprobsvy` to `Suggests` for numerical cross-validation in tests.
Add `mice` to `Suggests` for `missing_method = "impute"` support (already present in
DESCRIPTION as of the start of this phase).

Add `LazyData: true` to `DESCRIPTION` so the four bundled datasets (`ns_wave1_ipw`,
`gss_ipw_ref`, `npors_2025_ipw`, `acs_ipw_ref`) are available without explicit
`data()` calls.

`usethis` is used in `data-raw/` scripts via `usethis::use_data()` but is NOT listed
as a formal dependency — data-raw scripts are developer tools, not runtime code.

### Interaction with Utilities Phase

`R/nonprob-ipw.R` calls `.trim_weights_internal()` from `R/utils.R`. The Utilities phase
must be complete before Propensity can be implemented.

One backward-compatible change to `R/utils.R` is required: `.validate_formula_variables()`
must gain an optional `error_class = NULL` parameter. When `NULL` (default), the function
uses `"surveywts_error_formula_variable_not_found"` as before — all existing callers are
unaffected. When a non-NULL string is supplied (as in Behavior Rule 7), the function uses
that class for the `cli::cli_abort()` call. No other changes to the Utilities API are
required.

### Interaction with Nonresponse Phase

The `method = "propensity"` stub error (`surveywts_error_propensity_not_available`) is
removed from `R/nonresponse.R` and replaced with the propensity IPW algorithm (§V). The
`surveywts_error_propensity_not_available` class is retired — it should remain in
`plans/error-messages.md` with a note: "Retired in Propensity phase — `method =
"propensity"` is now fully implemented."

No changes to the public API of `adjust_nonresponse()` are needed; `formula` was already
added in the Nonresponse phase.

### DRY Decision: No Shared Propensity Helper

The Nonresponse spec (§IX, "Interaction with Propensity Phase") anticipated a possible
refactor of `propensity-cell` to delegate to propensity infrastructure. **Decision: no
refactor for either branch.**

Response propensity (P(respond | sampled)) in `adjust_nonresponse()` and participation
propensity (P(in NPS | X)) in `ipw()` share `stats::glm()` as their
implementation tool but differ in:
- Data structure: single sample (nonresponse) vs. pooled two-sample design (IPW)
- Weight construction: redistribute existing weights (nonresponse) vs. create new weights
  from scratch (IPW)
- Reference data: not needed (nonresponse) vs. required `reference` (`survey_taylor` class, IPW)

Abstracting a shared `.estimate_propensity_scores()` into `R/utils.R` would require
conditional logic on the problem type, producing a helper that is harder to test and
harder to reason about than two self-contained inline implementations. This is structural
difference, not surface-level repetition.
