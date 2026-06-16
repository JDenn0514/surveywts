# impl-ipw-extensions.md

**Version:** 1.0
**Date:** 2026-05-26
**Status:** DRAFT
**ID:** ipw-extensions
**Spec:** `plans/spec-ipw-extensions.md` (v0.3, SPEC_READY)
**Test spec:** `plans/test-spec-ipw-extensions.md`

---

## Overview

This plan delivers the six-paper methodological audit of `ipw()` as specified
in `spec-ipw-extensions.md`. All changes are confined to `R/nonprob-ipw.R`,
`tests/testthat/test-nonprob-ipw.R`, and `plans/error-messages.md`. No new R
files; no new test helpers.

Five PRs in strict sequence (all write to the same source files): code
additions first (PRs 1–4), documentation-only last (PR 5). The ordering within
code PRs matters: PR 2 inserts Rule 9a-ii right after Rule 9a; PR 3 inserts
Rules 8b/8c after Rule 9a-ii; PR 4 extends the NR engine without disturbing the
rule block already in place.

---

## PR Map

- [x] PR 1: `feature/ipw-history-fields` — Fix `estimator` label (C-1); add `propensity_scores`, `population_size` to history (M-6, L-4)
- [x] PR 2: `feature/ipw-adjust-reference` — Add `adjust_reference` argument and reference weight adjustment logic (C-3, M-4)
- [x] PR 3: `feature/ipw-common-support` — Add numeric range and reverse-factor-level common support checks (M-1)
- [x] PR 4: `feature/ipw-gee` — Add `estimating_eq = "gee"` path to NR engine (H-6)
- [x] PR 5: `feature/ipw-docs` — All documentation-only gaps (C-2, C-4, H-1 through H-5, M-2, M-3, M-5, L-1 through L-3)

---

## PR 1: History entry fixes and `population_size`

**Branch:** `feature/ipw-history-fields`
**Depends on:** none

### Spec coverage
- C-1: Fix `estimator = "ht"` → `"ipw2"` in history entry
- M-6: Add `propensity_scores` to history entry
- L-4: Add `population_size` argument; validation Rule 0f; `population_size_known` and updated `estimated_population_size` in history

### Files (TDD order)

1. `plans/error-messages.md` — add `surveywts_error_population_size_invalid` to `ipw()` errors table
2. `tests/testthat/test-nonprob-ipw.R` — add test blocks for C-1, M-6, L-4 (write failing tests first)
3. `R/nonprob-ipw.R` — apply all code changes for this PR (see Notes)

### Code changes in `R/nonprob-ipw.R`

**Signature update** — add `population_size = NULL` after `trim`:
```r
ipw <- function(
  data, reference, selection = NULL, predictors = NULL,
  missing_method = c("omit", "separate", "impute"), mice_args = list(),
  method = "logit", maxit = 25L, epsilon = 1e-8,
  trim = FALSE, population_size = NULL, wt_name = "ipw_weight"
)
```

**Rule 0f** — add after Rule 0 (match.arg for method), before Rule 0a:
```r
if (!is.null(population_size)) {
  if (!is.numeric(population_size) || length(population_size) != 1L ||
      is.na(population_size) || !is.finite(population_size) ||
      population_size <= 0) {
    cli::cli_abort(
      c("x" = ..., "i" = ..., "v" = ...),
      class = "surveywts_error_population_size_invalid"
    )
  }
}
```
See spec §IV.C for exact message text.

**Rule 20 history entry** — three changes:
1. `estimator = "ipw2"` (was `"ht"`)
2. New field `propensity_scores = scores` (the full vector from `fit$scores`)
3. `estimated_population_size = if (!is.null(population_size)) population_size else estimated_population_size`
4. New field `population_size_known = !is.null(population_size)`

**`@param population_size`** — add after `@param trim`; exact text in spec §IV.H.

### Test blocks to add

From `test-spec-ipw-extensions.md`:

| Gap | Block description |
|-----|-------------------|
| C-1 | "ipw() history entry records estimator = 'ipw2'" |
| M-6 block 1 | "propensity_scores are in history entry as numeric vector" |
| M-6 block 2 | "all propensity_scores are in (0, 1)" |
| M-6 block 3 | "propensity_scores length equals n_nps after omit" |
| M-6 block 4 | "propensity_scores matches 1/weights before trimming" |
| L-4 block 1 | "population_size = NULL → population_size_known = FALSE" |
| L-4 block 2 | "population_size supplied → population_size_known = TRUE" |
| L-4 block 3 | "population_size does not change the weights" |
| L-4 block 4 | "population_size = 0 or negative → error" (dual pattern) |
| L-4 block 5 | "population_size = non-numeric → error" (dual pattern) |
| L-4 block 6 | "population_size = Inf → error" |

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `history[[1]]$estimator == "ipw2"` for any valid `ipw()` call
- [ ] `history[[1]]$estimator != "ht"` (explicit regression check)
- [ ] `history[[1]]$propensity_scores` is numeric vector of length `n_nps`
- [ ] All propensity scores in `(0, 1)` exclusive (tolerance `.Machine$double.eps`)
- [ ] `weights_in_data == 1 / propensity_scores` when `trim = FALSE` (tolerance 1e-10)
- [ ] `population_size_known = FALSE` when `population_size = NULL`
- [ ] `estimated_population_size == supplied value` when `population_size` supplied
- [ ] Weights unchanged regardless of `population_size`
- [ ] Both error classes have dual-pattern tests (`expect_error(class=)` + snapshot)
- [ ] `plans/error-messages.md` updated with `surveywts_error_population_size_invalid`
- [ ] Test coverage ≥ 98% for `R/nonprob-ipw.R` (verify with `covr::package_coverage()`)
- [ ] `test_invariants(result)` is the first assertion in every result-constructing block

### Notes

- `propensity_scores = scores` — `scores` is already computed at Rule 15 from `fit$scores`. The history entry assignment in Rule 20 just captures the same vector.
- When `missing_method = "omit"` drops rows, `nrow(data)` after Rule 9b and `length(scores)` will both equal `n_nps`. The test-spec fixture confirms this via `length(hist$propensity_scores) == hist$n_nps`.
- `population_size` validation must happen before any computation. Rule 0f position: right after Rule 0 (match.arg), before Rule 0a (conflict check). Actually looking at the spec §IV.C, it should go after Rule 0e (adjust_reference) but Rule 0e doesn't exist yet (it's added in PR 2). Put Rule 0f right after Rule 0d (which doesn't exist yet either). For this PR, just add Rule 0f immediately after `match.arg(missing_method)` at Rule 9 — or more precisely, after the existing Rule 0 for `method` match.arg and before Rule 0a conflict check. The spec says "after Rule 0e" but since Rule 0e is added in PR 2, add it after Rule 0 for now and PR 2 will insert Rule 0e before it.

---

## PR 2: Reference weight adjustment (`adjust_reference`)

**Branch:** `feature/ipw-adjust-reference`
**Depends on:** PR 1

### Spec coverage
- C-3: Add `adjust_reference` argument; Rule 0e validation; Rule 9a-ii adjustment logic; two new warning classes; `adjust_reference`, `adjust_factor`, `nps_fraction` in history
- M-4: Add `nps_fraction` to history entry (computed as part of Rule 9a-ii)

### Files (TDD order)

1. `plans/error-messages.md` — add `surveywts_error_adjust_reference_invalid` (error), `surveywts_warning_ipw_reference_weight_adjusted` and `surveywts_warning_ipw_reference_unadjusted_large_nps` (warnings)
2. `tests/testthat/test-nonprob-ipw.R` — add test blocks for C-3 and M-4 (write failing tests first)
3. `R/nonprob-ipw.R` — signature, Rule 0e, Rule 9a-ii, history fields

### Code changes in `R/nonprob-ipw.R`

**Signature update** — add `adjust_reference = TRUE` after `epsilon`:
```r
ipw <- function(
  data, reference, selection = NULL, predictors = NULL,
  missing_method = c("omit", "separate", "impute"), mice_args = list(),
  method = "logit", maxit = 25L, epsilon = 1e-8,
  adjust_reference = TRUE, trim = FALSE, population_size = NULL,
  wt_name = "ipw_weight"
)
```

**Rule 0e** — insert after Rule 0 `match.arg(method)`, before Rule 0f:
```r
if (!is.logical(adjust_reference) || length(adjust_reference) != 1L ||
    is.na(adjust_reference)) {
  cli::cli_abort(
    c("x" = ..., "i" = ..., "v" = ...),
    class = "surveywts_error_adjust_reference_invalid"
  )
}
```
See spec §IV.C for exact message text.

**Rule 9a-ii** — insert immediately after the existing Rule 9a block (after `ref_weights_for_fit` is finalized), before the NPS NA handling block. This block must use `nrow(data)` (full pre-NPS-deletion row count) for `nps_fraction`:
```r
n_hat <- sum(ref_weights_for_fit)
nps_fraction <- nrow(data) / n_hat
if (adjust_reference && nps_fraction > 0.05) {
  adjust_factor <- 1 - nps_fraction
  ref_weights_for_fit <- ref_weights_for_fit * adjust_factor
  cli::cli_warn(..., class = "surveywts_warning_ipw_reference_weight_adjusted")
} else if (!adjust_reference && nps_fraction > 0.05) {
  adjust_factor <- 1
  cli::cli_warn(..., class = "surveywts_warning_ipw_reference_unadjusted_large_nps")
} else {
  adjust_factor <- 1
}
```
See spec §IV.D Rule 9a-ii and §IV.F for exact warning message templates.

**Rule 20 history entry** — add three new fields:
```r
adjust_reference = adjust_reference,
nps_fraction     = nps_fraction,
adjust_factor    = adjust_factor,
```

**`@param adjust_reference`** — add after `@param epsilon`; exact text in spec §IV.H.

### Test blocks to add

From `test-spec-ipw-extensions.md`:

| Gap | Block description |
|-----|-------------------|
| C-3 block 1 | "adjust_reference = TRUE warns and adjusts when nps_fraction > 0.05" |
| C-3 block 2 | "adjust_reference = FALSE warns but does not adjust when nps_fraction > 0.05" |
| C-3 block 3 | "no warning or adjustment when nps_fraction <= 0.05" |
| C-3 block 4 | "adjust_reference validation — non-logical rejected" (dual pattern) |
| C-3 block 5 | "adjust_reference = NA rejected" |
| M-4 | "nps_fraction is correctly recorded in history entry" |
| NA-boundary | "nps_fraction uses pre-NA-deletion row count" — NPS with NAs in selection variable + `missing_method = "omit"`; assert `hist$nps_fraction == nrow(nps_original) / n_hat` (not post-drop count) |

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `surveywts_warning_ipw_reference_weight_adjusted` fires when `adjust_reference = TRUE` and `nps_fraction > 0.05`
- [ ] `surveywts_warning_ipw_reference_unadjusted_large_nps` fires when `adjust_reference = FALSE` and `nps_fraction > 0.05`
- [ ] No warning fires when `nps_fraction <= 0.05`
- [ ] `hist$adjust_factor == 1 - nps_fraction` when adjustment applied (tolerance 1e-10)
- [ ] `hist$adjust_factor == 1.0` when no adjustment applied
- [ ] `hist$nps_fraction == nrow(data) / sum(ref_weights_after_na_deletion)` (tolerance 1e-10)
- [ ] `surveywts_error_adjust_reference_invalid` with dual-pattern test
- [ ] All warning classes have both `expect_warning(class=)` and snapshot tests
- [ ] `plans/error-messages.md` updated with all three new classes
- [ ] Test coverage ≥ 98% for `R/nonprob-ipw.R`
- [ ] `test_invariants(result)` first assertion in every result-constructing block
- [ ] New snapshot files in `tests/testthat/_snaps/` are staged and committed

### Notes

- The `nps_fraction` computation in Rule 9a-ii uses `nrow(data)` **before** NPS NA deletion. This is the full NPS row count. Rule 9b/9c/9d (which may reduce `nrow(data)`) execute after Rule 9a-ii.
- `n_hat = sum(ref_weights_for_fit)` is computed from `ref_weights_for_fit` **after** reference NA listwise deletion (after Rule 9a). Do not use `ref_weights` (pre-NA-deletion) for this.
- Warning message templates: see spec §IV.F. Use `round(nps_fraction * 100, 1)` and `round(n_hat)` and `round(adjust_factor, 4)` in the message.
- The `adjust_reference = NA` test (block 5) only needs `expect_error(class=)` — no snapshot needed beyond block 4's dual test (the error message is identical structure).

---

## PR 3: Common support checks (numeric range + reverse factor levels)

**Branch:** `feature/ipw-common-support`
**Depends on:** PR 2

### Spec coverage
- M-1: Rule 8b (numeric covariate range extrapolation warning) and Rule 8c (reference factor levels absent from NPS warning)

### Files (TDD order)

1. `plans/error-messages.md` — add `surveywts_warning_ipw_covariate_range_extrapolation` and `surveywts_warning_ipw_reference_levels_absent_from_nps`
2. `tests/testthat/test-nonprob-ipw.R` — add test blocks for M-1 (write failing tests first)
3. `R/nonprob-ipw.R` — insert Rules 8b and 8c

### Code changes in `R/nonprob-ipw.R`

**Rules 8b and 8c** — insert after Rule 9a-ii (reference weight adjustment block), before Rule 9b/9c/9d (NPS NA handling). Both use `ref_data_for_fit` (post-NA-deletion reference data, NOT `reference@data`):

Rule 8b (numeric range check):
```r
for (var in sel_vars) {
  if (is.numeric(data[[var]]) && is.numeric(ref_data_for_fit[[var]])) {
    nps_range <- range(data[[var]], na.rm = TRUE)
    ref_range <- range(ref_data_for_fit[[var]], na.rm = TRUE)
    if (nps_range[1] < ref_range[1] || nps_range[2] > ref_range[2]) {
      cli::cli_warn(..., class = "surveywts_warning_ipw_covariate_range_extrapolation")
    }
  }
}
```

Rule 8c (reverse factor level check):
```r
for (var in sel_vars) {
  if (is.character(data[[var]]) || is.factor(data[[var]])) {
    nps_levels <- unique(as.character(data[[var]][!is.na(data[[var]])]))
    ref_levels <- unique(as.character(ref_data_for_fit[[var]][!is.na(ref_data_for_fit[[var]])]))
    absent_in_nps <- setdiff(ref_levels, nps_levels)
    if (length(absent_in_nps) > 0) {
      cli::cli_warn(..., class = "surveywts_warning_ipw_reference_levels_absent_from_nps")
    }
  }
}
```

See spec §IV.D Rules 8b and 8c, and §IV.F for exact warning message templates.

### Test blocks to add

From `test-spec-ipw-extensions.md`:

| Gap | Block description |
|-----|-------------------|
| M-1 block 1 | "numeric covariate range extrapolation warns" (+ snapshot) |
| M-1 block 2 | "numeric covariate within reference range — no range warning" |
| M-1 block 3 | "reference factor levels absent from NPS warns" (+ snapshot) |
| M-1 block 4 | "NPS levels absent from reference still errors (existing behavior unchanged)" |
| M-1 block 5 | "both warning types can fire simultaneously" |

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `surveywts_warning_ipw_covariate_range_extrapolation` fires when NPS numeric range exceeds reference range
- [ ] No range warning when NPS numeric values within reference range
- [ ] `surveywts_warning_ipw_reference_levels_absent_from_nps` fires when reference has a factor level absent from NPS
- [ ] `surveywts_error_propensity_level_not_in_reference` still fires for NPS levels absent from reference (regression test)
- [ ] Both warnings can fire simultaneously in one `ipw()` call
- [ ] All warning classes have both `expect_warning(class=)` and snapshot tests
- [ ] `plans/error-messages.md` updated with both new warning classes
- [ ] Test coverage ≥ 98% for `R/nonprob-ipw.R`
- [ ] `test_invariants(result)` is the first assertion in every result-constructing block

### Notes

- Rules 8b/8c use `ref_data_for_fit`, not `reference@data`. This matters when reference rows with NA in selection variables were dropped by Rule 9a. Do not accidentally use `reference@data` here.
- Rule 8c is a **warning** (not an error) because reference units in absent cells can still receive near-zero propensity scores and be fitted. The complementary Rule 8 (existing, NPS levels absent from reference → **error**) is unchanged.
- M-1 block 1: the warning fires once per variable, not once per out-of-range unit. The warning message reports `nps_range` and `ref_range` for the offending variable. See spec §IV.F for the template.
- M-1 block 5: both warnings are independent and both should fire. The test calls `ipw()` twice (once asserting each class), not once with `expect_warning()` wrapping both.

---

## PR 4: GEE estimating equation

**Branch:** `feature/ipw-gee`
**Depends on:** PR 3 (PRs 2, 3, and 4 all write to the same two files — `R/nonprob-ipw.R` and `tests/testthat/test-nonprob-ipw.R` — and must execute in strict sequence. GEE balance tests also use `adjust_reference = FALSE` to isolate GEE; test block 2b tests GEE + adjust_reference interaction requiring PR 2's logic to be present.)

### Spec coverage
- H-6: `estimating_eq` argument; Rule 0d validation; GEE path in `.fit_participation_propensity()`; `estimating_eq` in history

### Files (TDD order)

1. `tests/testthat/test-nonprob-ipw.R` — add test blocks for H-6 (write failing tests first)
2. `R/nonprob-ipw.R` — Rule 0d, signature, engine extension, Rule 14 update, Rule 20 history

### Code changes in `R/nonprob-ipw.R`

**Signature update** — add `estimating_eq = c("mle", "gee")` after `method`:
```r
ipw <- function(
  data, reference, selection = NULL, predictors = NULL,
  missing_method = c("omit", "separate", "impute"), mice_args = list(),
  method = "logit", estimating_eq = c("mle", "gee"),
  maxit = 25L, epsilon = 1e-8, adjust_reference = TRUE,
  trim = FALSE, population_size = NULL, wt_name = "ipw_weight"
)
```

**Rule 0d** — insert immediately after `match.arg(method, ...)`:
```r
estimating_eq <- match.arg(estimating_eq, c("mle", "gee"))
```

**`.fit_participation_propensity()` signature** — add `estimating_eq` parameter:
```r
.fit_participation_propensity <- function(
  selection, nps_data, ref_data, ref_weights, method, estimating_eq, maxit, epsilon
)
```

**GEE path in NR loop** — branch on `estimating_eq` inside the existing NR loop, after the outer saturation guard on `X_nps_pred`. See spec §III.C for the GEE score and Jacobian formulas:

MLE path (existing, unchanged):
```r
pi_ref <- link(drop(X_ref %*% gamma))
score  <- colSums(X_nps_fit) - drop(t(X_ref) %*% (d_ref * pi_ref))
hess   <- -crossprod(X_ref, X_ref * (d_ref * pi_ref * (1 - pi_ref)))
```

GEE path (new):
```r
pi_nps <- link(drop(X_nps_fit %*% gamma))
if (any(pi_nps <= eps)) {
  return(list(scores = link(drop(X_nps_pred %*% gamma)),
              converged = FALSE, final_delta = max(abs(delta))))
}
score <- colSums(X_nps_fit / pi_nps) - colSums(X_ref * d_ref)
hess  <- -crossprod(X_nps_fit, X_nps_fit * ((1 - pi_nps) / pi_nps))
```

Note: `colSums(X_ref * d_ref)` is `X_ref^T d_ref` — reference population covariate totals. This is a fixed vector within the iteration (does not depend on gamma). Compute it before the loop or on first iteration.

**Rule 14** — add `estimating_eq = estimating_eq` to the call:
```r
fit <- .fit_participation_propensity(
  selection     = selection,
  nps_data      = data,
  ref_data      = ref_data_for_fit,
  ref_weights   = ref_weights_for_fit,
  method        = method,
  estimating_eq = estimating_eq,
  maxit         = as.integer(maxit),
  epsilon       = epsilon
)
```

**Rule 20 history entry** — add `estimating_eq = estimating_eq` after `method = method`.

**`@param estimating_eq`** — add after `@param method`; exact text in spec §IV.H.

### Test blocks to add

From `test-spec-ipw-extensions.md`:

| Gap | Block description |
|-----|-------------------|
| H-6 block 1 | "estimating_eq = 'gee' converges on balanced data" |
| H-6 block 2 | "GEE covariate balance guarantee at convergence (adjust_reference = FALSE)" — tolerance 1e-6 |
| H-6 block 2b | "GEE balance holds against Valliant-adjusted reference totals when nps_fraction > 0.05" — tolerance 1e-6 |
| H-6 block 3 | "estimating_eq = 'gee' and = 'mle' recorded in history entry" |
| H-6 block 4 | "estimating_eq = 'gee' and = 'mle' produce different weights" |
| H-6 block 5 | "GEE degeneration triggers surveywts_error_propensity_scores_degenerate" |
| H-6 block 6 | "estimating_eq = 'gee' + missing_method = 'separate' — no runtime warning" |

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] GEE converges on `ns_wave1_ipw` + `gss_ipw_ref` (block 1)
- [ ] GEE balance: `sum(w * x) == sum(d_ref * x)` at tolerance 1e-6 for each model matrix column, with `adjust_reference = FALSE` (block 2)
- [ ] GEE balance holds against adjusted totals: `sum(w_adj * x) == adjust_factor * sum(d_ref * x)` at tolerance 1e-6 (block 2b)
- [ ] `hist$estimating_eq == "gee"` and `"mle"` for respective calls (block 3)
- [ ] GEE and MLE weights differ (`isFALSE(all.equal(w_gee, w_mle))`)
- [ ] GEE inner saturation guard triggers `surveywts_error_propensity_scores_degenerate` (block 5)
- [ ] No `surveywts_warning_ipw_gee_calibration_partial` warning with `missing_method = "separate"` (block 6 regression test)
- [ ] Test coverage ≥ 98% for `R/nonprob-ipw.R`
- [ ] `test_invariants(result)` is the first assertion in every result-constructing block

### Notes

- The `colSums(X_ref * d_ref)` reference total is constant across NR iterations. Compute it once before the loop and capture in a variable to avoid recomputing per iteration.
- GEE Jacobian sums over NPS rows (`X_nps_fit`); MLE Hessian sums over reference rows (`X_ref`). Both paths share the same `solve(hess, score)` with `tryCatch` for singularity — reuse the existing error handling.
- The GEE inner guard (`any(pi_nps <= eps)`) fires when NPS propensity approaches 0 from below — this is the GEE-specific degeneration path. It triggers the same `converged = FALSE` return, which propagates to `surveywts_error_propensity_scores_degenerate` via the existing Rule 15 path. No new error class is needed.
- Block 2b requires PR 2 to be merged (adjust_reference = TRUE behavior). If running this PR before PR 2, skip block 2b with a comment and add it when PR 2 is merged. The PR ordering (PR 2 before PR 4) avoids this.
- GEE with `missing_method = "separate"`: the engine already uses `X_nps_fit` (complete-case NPS only). No code change needed; the calibration guarantee applies only to complete-case rows. Block 6 verifies no warning is emitted (Option A from decisions-ipw-extensions.md Decision 1).

---

## PR 5: Documentation-only gaps

**Branch:** `feature/ipw-docs`
**Depends on:** PR 4 (all arguments must exist before their `@param` text can be finalized)

### Spec coverage
- C-2: Replace variance `@details` bullet with full refit-required documentation (jackknife + bootstrap procedures)
- C-4: Add misspecification sensitivity section to `@note`
- H-1: Document unconditional estimating equation in `@details`
- H-2: Replace "Selection on observables" `@note` bullet with MAR assumption text
- H-3: Extend `@param reference` with quality requirements (Elliott & Valliant 2017; Valliant 2020)
- H-4: Add doubly robust recommendation to `@details`; add `@seealso` section
- H-5: Jackknife preferred note (part of C-2)
- M-2: Extend `@param method` with theoretical grounding caveat
- M-3: Extend `@param missing_method` "separate" item with theoretical caveat
- M-5: Add independence of participation `@note` bullet (cluster NPS, non-overlapping samples)
- L-1: Add high-dimensional selection caveat to `@details`
- L-2: Add QBIPW approximation note to `@details` (with inline code example)
- L-3: Add measurement equivalence caveat (part of `@param reference` or `@note`)
- Net-new `@references`: Valliant & Dever (2011), Valliant (2020), Yang et al. (2020), Beresewicz et al. (2025)
- `@examples`: add GEE example and `population_size` example blocks

### Files (TDD order)

1. `R/nonprob-ipw.R` — all roxygen2 changes only; no code changes
2. *(run `devtools::document()` — man/ipw.Rd must update)*

No test additions for this PR (doc-only). Quality gate is `R CMD check` + manual inspection of `?ipw`.

### Documentation changes (summary)

All exact text is specified in `spec-ipw-extensions.md §IV.H`. Key structural changes:

| Section | Action | Spec ref |
|---------|--------|---------|
| `@param reference` | Replace with extended version (quality requirements + L-3 measurement equivalence) | H-3, L-3 |
| `@param method` | Replace with extended version (theoretical grounding caveat) | M-2 |
| `@param estimating_eq` | Verify text matches spec §IV.H (was added in PR 4; confirm completeness) | H-6 |
| `@param missing_method` "separate" item | Append caveat block | M-3 |
| `@param adjust_reference` | Verify text matches spec §IV.H (was added in PR 2; confirm completeness) | C-3 |
| `@param population_size` | Verify text matches spec §IV.H (was added in PR 1; confirm completeness) | L-4 |
| `@details` variance bullet | Full replacement with jackknife + bootstrap procedures | C-2, H-5 |
| `@details` new bullets | Estimating equation (H-1), doubly robust (H-4), misspecification (C-4), high-dimensional (L-1), QBIPW (L-2) | multiple |
| `@note` "Selection on observables" | Replace with MAR assumption text | H-2 |
| `@note` new bullets | Independence of participation + non-overlapping samples | M-5 |
| `@seealso` | Add new section linking `adjust_nonresponse()`, `calibrate_to_survey()`, `diagnose_propensity()` | H-4 |
| `@references` | Append 4 net-new entries | multiple |
| `@examples` | Add GEE and `population_size` blocks after existing examples | spec §IV.H |

**Chen et al. year note:** The existing file uses 2020 (the published year). Update any "2021" references introduced by new `@param`/`@details` text to 2020 to match the existing `@references` entry.

### Acceptance criteria

- [ ] `devtools::document()` runs without warnings; `man/ipw.Rd` updated
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes (all `@examples` run clean)
- [ ] All six documentation gaps in quality gate are present: C-2, C-4, H-1 through H-5, M-2, M-3, M-5, L-1 through L-3 (verify by reading `man/ipw.Rd`)
- [ ] `@seealso` section present with all three links
- [ ] All four net-new `@references` entries added (check against spec §IV.H)
- [ ] `@examples` GEE block and `population_size` block added and run without error
- [ ] No `"2021"` in-text citation for Chen et al. — all occurrences use 2020
- [ ] `@param` text for `adjust_reference`, `estimating_eq`, `population_size` matches spec §IV.H exactly

### Notes

- The QBIPW `@details` bullet (L-2) includes an inline code block. In roxygen2, use ```` ``` ```` fencing inside the `@details`. The `air` formatter does not reformat code inside roxygen comment blocks, so manual line-wrapping at 80 chars applies.
- Beresewicz et al. (2025) citation: the spec notes "[Verify journal/preprint details before submission]". Use the arXiv citation form if no published venue is confirmed; the builder should check.
- `@examples` must use `data(ns_wave1_ipw)` and `data(gss_ipw_ref)` (already called by earlier examples). The new blocks add after the existing `predictors =` block. Do not repeat `data()` calls.
- After this PR, run `testthat::snapshot_review()` to ensure no existing snapshots regressed from the doc changes (they shouldn't, but verify).

---

## File write surface map

| File | PR 1 | PR 2 | PR 3 | PR 4 | PR 5 |
|------|------|------|------|------|------|
| `plans/error-messages.md` | add 1 error | add 2 warn + 1 error | add 2 warn | — | — |
| `tests/testthat/test-nonprob-ipw.R` | add ~11 blocks | add ~6 blocks | add ~5 blocks | add ~7 blocks | — |
| `R/nonprob-ipw.R` | sig + Rule 0f + hist | sig + Rule 0e + 9a-ii + hist | Rules 8b/8c | sig + Rule 0d + engine + Rule 14 + hist | roxygen only |
| `man/ipw.Rd` | auto (document) | auto | auto | auto | auto |
| `NAMESPACE` | auto | auto | auto | auto | auto |

No concurrent write surface conflicts. All PRs are strictly sequential.

---

## Quality gates (from spec §VII)

Before closing the final PR (PR 5), verify ALL of the following:

- [ ] `R CMD check` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/ipw.Rd` up to date
- [ ] All six new warning/error classes in `plans/error-messages.md`
- [ ] `estimator = "ipw2"` in history entry (not `"ht"`)
- [ ] GEE balance: `sum(w * x) ≈ sum(d_adjusted * x)` for all covariates (tolerance 1e-6), where `d_adjusted = ref_weights_for_fit` after Rule 9a-ii
- [ ] `adjust_factor` recorded in history
- [ ] `nps_fraction` in history
- [ ] `propensity_scores` in history as numeric vector
- [ ] `population_size_known` in history
- [ ] Rules 8b and 8c execute after reference NA handling (use `ref_data_for_fit`) and before NPS NA handling
- [ ] Rule 9a-ii executes after reference NA handling and before NPS NA handling
- [ ] All four new warning classes have snapshot tests and `expect_warning(class=)` tests
- [ ] Both new error classes have dual-pattern tests
- [ ] Test coverage ≥ 98% for `R/nonprob-ipw.R`
- [ ] All `@examples` run under `R CMD check` without error
- [ ] All roxygen documentation changes in place for all spec gaps
