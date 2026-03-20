# Phase 0 Fixes Spec: Post-Implementation Patches

**Version:** 0.4
**Date:** 2026-03-18
**Status:** Approved — Stage 4 complete; v0.4 amended after critical review (2026-03-18)
**Branch identifier:** `phase-0-fixes`
**Related files:** `plans/spec-review-phase-0-fixes.md` (after review),
`plans/decisions-phase-0-fixes.md` (after resolve)

---

## Document Purpose

This document is the single source of truth for patching the Phase 0
implementation of surveywts. It covers both surveywts and surveycore changes
identified during a critical review of the shipped Phase 0 code. Changes are
organized by theme, not by file. Each section is labeled with the affected
package(s) so implementation can proceed package-by-package.

This spec does NOT repeat rules defined in:
- `code-style.md` — formatting, pipe, error structure, S7 patterns, argument order
- `r-package-conventions.md` — `::` usage, NAMESPACE, roxygen2, export policy
- `surveywts-conventions.md` — error/warning prefixes, return visibility
- `testing-standards.md` — `test_that()` scope, coverage targets, assertion patterns

Those rules apply by reference.

---

## I. Scope

### Deliverables

| # | Change | Package | Severity |
|---|--------|---------|----------|
| 1 | Replace vendored algorithms with `survey`/`anesrake` calls | surveywts | High |
| 2 | `adjust_nonresponse()`: zero weights instead of dropping rows | surveywts | High |
| 3 | `.check_input_class()` → use `survey_base` inheritance check | surveywts | Medium |
| 4 | Move `.check_input_class()` and `.get_history()` to `utils.R` | surveywts | Medium |
| 5 | Remove `%||%` redefinition; use `rlang::%||%` | surveywts | Low |
| 6 | Fix `interaction()` in `summarize_weights()` | surveywts | Medium |
| 7 | `response_status` → `tidyselect::eval_select()` | surveywts | Low |
| 8 | `poststratify()` default `type` → `"prop"` | surveywts | Medium |
| 9 | `survey_nonprob` print: fix variance method label | surveywts | Low |
| 10 | Document `@importFrom` exception for S3 method registration | surveywts | Low |
| 11 | Remove `survey_srs` class and `as_survey_srs()` | surveycore | High |

### Non-Deliverables (Deferred)

| Item | Reason |
|------|--------|
| Default weights = 1 (not 1/n) | User deferred: "readdress later" |
| `@calibration` validator structure | Define when Phase 1 implementation begins |
| `visible_vars` property | Does not affect surveywts — no action needed |
| `match.call()` replacement | Current approach is standard and sufficient |

### Affected Package Matrix

| Change # | surveywts | surveycore |
|----------|-----------|------------|
| 1–10 | Yes | No |
| 11 | No | Yes |

---

## II. Change 1 — Replace Vendored Algorithms with Package Calls

**Package:** surveywts
**Severity:** High — removes ~586 lines of vendored code

### Current State

Three vendored files contain algorithm implementations extracted from `survey`
and `anesrake`:

| File | Lines | Origin |
|------|-------|--------|
| `R/vendor-calibrate-greg.R` | 185 | `survey::grake()` |
| `R/vendor-calibrate-ipf.R` | 127 | `survey::rake()` |
| `R/vendor-rake-anesrake.R` | 274 | `anesrake::anesrake()` |

### Target State

- Delete all three `R/vendor-*.R` files
- Move `survey` from `Suggests` to `Imports`; add `anesrake` to `Imports`
  (currently vendored with no package dependency)
- Rewrite `.calibrate_engine()` to delegate to package functions

### `.calibrate_engine()` — Revised Behavior

The engine signature is unchanged. Internal dispatch changes:

| `type` | Before | After |
|--------|--------|-------|
| `"linear"` | `.greg_linear()` (vendored) | `survey::calibrate()` with `calfun = survey::cal.linear` |
| `"logit"` | `.greg_logit()` (vendored) | `survey::calibrate()` with `calfun = survey::cal.logit` |
| `"ipf"` | `.ipf_calibrate()` (vendored) | `survey::rake()` |
| `"anesrake"` | `.anesrake_calibrate()` (vendored) | `anesrake::anesrake()` |
| `"poststratify"` | Inline loop (kept) | `survey::postStratify()` |

#### `survey::calibrate()` Interface (linear/logit)

```r
# Input translation:
#   - Convert each calibration variable to a factor
#   - Build a formula using full indicator encoding (no intercept):
#       ~factor(var1) + factor(var2) - 1
#     with contrasts.arg = list(var1 = contr.treatment(levels1, contrasts = FALSE), ...)
#   - Build a population total vector with k entries per variable (one per level),
#     named to match the model.matrix() column names exactly
#   - Construct a minimal svydesign from data_df + weights_vec

svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)
cal_result <- survey::calibrate(
  svy_tmp,
  formula = full_indicator_formula,   # ~factor(var1) + factor(var2) - 1
  population = pop_totals_vector,     # named: one entry per factor level
  calfun = if (method == "linear") survey::cal.linear else survey::cal.logit,
  maxit = control$maxit,
  epsilon = control$epsilon
)
new_weights <- weights(cal_result)
```

**Formula encoding:** Full indicator encoding without intercept. This replicates
the current vendored GREG behavior exactly: k columns per k-level factor, no
reference-level dropping. The formula uses `- 1` to suppress the intercept, and
`contrasts.arg` is set to `contr.treatment(..., contrasts = FALSE)` for each
factor to produce one column per level. The population totals vector has one
entry per factor level, named to match the `model.matrix()` output.

The temporary `svydesign` uses `ids = ~1` (SRS) because we only need the
calibration computation — the actual design structure is maintained by
surveywts.

**Convergence detection:**
- **Linear calibration:** No convergence check. GREG is a closed-form algebraic
  solution — there is no iteration. The result is exact (up to machine precision).
- **Logit calibration:** `survey::calibrate()` with `cal.logit` uses
  Newton-Raphson and issues a `warning()` on non-convergence. Intercept this
  warning via `withCallingHandlers()`, suppress it, and re-throw as
  `surveywts_error_calibration_not_converged` with the original message as
  context. This keeps a single, typed error class for all non-convergence cases.

**Negative weights warning:** After delegation, the existing negative-weight
check in `calibrate()` (step 10) remains — `survey::calibrate()` with
`cal.linear` can produce negative weights.

#### `survey::rake()` Interface (IPF)

```r
# Input translation:
#   - Build a list of margin formulas: list(~var1, ~var2, ...)
#   - Build a list of population data frames for each margin

svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)
raked <- survey::rake(
  svy_tmp,
  sample.margins = list(~var1, ~var2, ...),
  population.margins = list(pop_df_1, pop_df_2, ...),
  control = list(
    maxit = control$maxit,
    epsilon = control$epsilon
  )
)
new_weights <- weights(raked)
```

Each `pop_df` is a data frame with one column per variable plus a `Freq`
column containing population counts.

**Convergence detection:** `survey::rake()` may issue a `warning()` on
non-convergence. Intercept this warning via `withCallingHandlers()`, suppress
it, and re-throw as `surveywts_error_calibration_not_converged` with the
original message as context. This is the same pattern used for the logit path.

**Cap support:** `survey::rake()` does not support per-step weight capping.

> **GAP RESOLVED: `cap` behavior when `method = "survey"`.**
> **Decision:** Option (b) — error when `cap` is specified with
> `method = "survey"`. `survey::rake()` does not support per-step capping,
> and post-hoc trimming would silently violate marginal constraints.
>
> **Check location:** `rake()`, immediately after `method` is resolved
> (fail fast — before margin parsing, weight extraction, or engine dispatch).
> Do NOT defer this check to `.calibrate_engine()`.
>
> ```r
> # In rake(), after rlang::arg_match(method):
> if (!is.null(cap) && method == "survey") {
>   cli::cli_abort(
>     c(
>       "x" = "{.arg cap} is not supported when {.code method = \"survey\"}.",
>       "i" = "{.fn survey::rake} does not support per-step weight capping.",
>       "v" = "Use {.code method = \"anesrake\"} for raking with a weight cap."
>     ),
>     class = "surveywts_error_cap_not_supported_survey"
>   )
> }
> ```
> Add `surveywts_error_cap_not_supported_survey` to `plans/error-messages.md`
> before implementation.

#### `anesrake::anesrake()` Interface

```r
# Input translation:
#   - Build a named list of target vectors (one per margin variable)
#   - Create a synthetic caseid column for anesrake:
#       data_df_with_id <- data_df
#       data_df_with_id$.anesrake_id <- seq_len(nrow(data_df))
#       id_col <- ".anesrake_id"
#     The .anesrake_id column is not propagated to output.

result <- anesrake::anesrake(
  inputter    = targets_list,      # named list of named target vectors
  dataframe   = data_df_with_id,   # must include caseid column
  caseid      = id_col,            # character: name of id column
  weightvec   = weights_vec,
  choosemethod = control$variable_select,
  cap         = cap,               # NULL means no cap
  pctlim      = control$improvement,  # both are proportions; verified by delegation test
  nlim        = control$min_cell_n,
  iterate     = TRUE,
  maxiter     = control$maxit,
  type        = "pctlim",           # always improvement-based variable selection
  force1      = FALSE               # weight totals not explicitly conserved (see note)
)
new_weights <- result$weightvec
```

**`force1 = FALSE` note:** Weight totals are not explicitly conserved after
anesrake raking. This replicates the current vendored behavior. Raking adjusts
ratios to match marginal targets, so the total weight is approximately but not
exactly conserved. No post-raking normalization step is applied.

**`already_calibrated` detection:** `anesrake::anesrake()` returns
`$iterations = 0` when all variables already pass the chi-square threshold.
Detect this and emit `surveywts_message_already_calibrated`.

**Convergence detection:** `anesrake::anesrake()` returns `$converge`. If
`FALSE`, throw `surveywts_error_calibration_not_converged`.

#### `survey::postStratify()` Interface

**Target format note:** The engine always receives population counts.
When `type = "prop"`, the calling function (`poststratify()`) converts
proportions to counts (using total weight as the population total) before
calling `.calibrate_engine()`. The engine never handles proportion targets.

```r
# Input translation:
#   - Build a formula from strata_names: ~var1 + var2
#   - Build a population data frame with strata columns + Freq column
#   - Rename "target" column to "Freq"

svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)
ps_result <- survey::postStratify(
  svy_tmp,
  strata = ~var1 + var2,
  population = pop_df_with_freq
)
new_weights <- weights(ps_result)
```

**Pre-validation:** The existing empty-stratum check
(`surveywts_error_empty_stratum`) in `poststratify()` must be retained and
must run **before** calling `.calibrate_engine()` / `survey::postStratify()`.
This ensures that zero-observation strata produce a surveywts-typed error
rather than an untyped error from the `survey` package. The current vendored
code's `n_hat_h <= 0` defensive check in the engine is replaced by this
pre-validation in the calling function.

### Files to Delete

- `R/vendor-calibrate-greg.R`
- `R/vendor-calibrate-ipf.R`
- `R/vendor-rake-anesrake.R`

### Files to Modify

- `R/utils.R` — rewrite `.calibrate_engine()` internal dispatch
- `DESCRIPTION` — move `survey (>= 4.2-1)` from `Suggests` to `Imports`;
  add `anesrake (>= 0.80)` to `Imports` (currently vendored, not listed as
  a dependency). Verify that `anesrake` 0.80 exports the `pctlim`, `type`,
  `force1`, and `choosemethod` parameters used by this spec before pinning.

### Error Table Changes

No new error classes. Existing classes are preserved:
- `surveywts_error_calibration_not_converged` — still thrown, now based on
  post-delegation convergence checks

### New Error Class

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_cap_not_supported_survey` | `rake()` (before engine dispatch) | `cap` specified with `method = "survey"` |

> Add `surveywts_error_cap_not_supported_survey` to `plans/error-messages.md`
> before implementation.

### Testing Implications

- All existing numerical tests remain (tolerance: `1e-8` vs reference)
- Remove unit tests for vendored internals (`.greg_linear()`,
  `.greg_logit()`, `.ipf_calibrate()`, `.anesrake_calibrate()`)
- Add integration tests verifying delegation round-trip:
  `surveywts::calibrate()` output matches `survey::calibrate()` output
  directly
- `skip_if_not_installed()` guards become unnecessary for `survey` and
  `anesrake` (they're now `Imports`), but keep for `svrep` if used as
  additional oracle
- Add convergence detection tests for each delegated path:
  - Logit non-convergence: verify `withCallingHandlers()` intercepts the
    `survey::calibrate()` warning and throws
    `surveywts_error_calibration_not_converged`
  - IPF non-convergence: verify `withCallingHandlers()` intercepts the
    `survey::rake()` warning and throws
    `surveywts_error_calibration_not_converged`
  - Anesrake non-convergence: verify `$converge == FALSE` throws
    `surveywts_error_calibration_not_converged`
  - Anesrake already-calibrated: verify `$iterations == 0` emits
    `surveywts_message_already_calibrated`
- Add anesrake delegation verification test: run the vendored
  `.anesrake_calibrate()` and `anesrake::anesrake()` with identical inputs
  (`make_surveywts_data(seed = 42)`, matching `pctlim`/`improvement`,
  `force1 = FALSE`) and compare output weights within `1e-8`. This verifies:
  - `control$improvement` → `pctlim` mapping is correct (both are proportions)
  - `force1 = FALSE` replicates vendored weight-total behavior
  - No silent numerical divergence from the delegation

---

## III. Change 2 — `adjust_nonresponse()`: Zero Weights Instead of Dropping Rows

**Package:** surveywts
**Severity:** High — changes output contract

### Current Behavior

`adjust_nonresponse()` drops nonrespondent rows (step 14) and returns
respondent-only data. For survey objects, this mutates `@data` to contain
only respondent rows.

### New Behavior

Nonrespondent rows are **retained** with their weights set to 0. Respondent
weights are adjusted identically (same formula). This preserves design
structure (FPC, strata, PSUs) for variance estimation.

#### Before → After

| Aspect | Before | After |
|--------|--------|-------|
| Output rows | Respondents only | All rows (respondents + nonrespondents) |
| Nonrespondent weights | N/A (dropped) | 0 |
| Respondent weights | `w_i × (Σw_h / Σw_h,resp)` | Same formula |
| Design structure | Broken (rows removed) | Preserved |
| `nrow(output)` | `< nrow(input)` | `== nrow(input)` |

#### Implementation Changes

**Step 14 (currently "Subset to respondent rows only"):** Replace with weight
zeroing:

```r
# ---- 14. Set nonrespondent weights to 0 ----------------------------------
new_weights[!is_respondent] <- 0
out_df <- plain_df
out_df[[weight_col]] <- new_weights
```

**Step 15 (`after_stats`):** Compute on **respondent weights only**
(`new_weights[is_respondent]`, i.e., `w[w > 0]`). The history entry should
reflect the effective sample — the population that will contribute to
estimates. This keeps history ESS/CV consistent with what
`effective_sample_size()` and `weight_variability()` report on the same object.

```r
after_stats <- .compute_weight_stats(new_weights[is_respondent])
```

**Step 16 (build output):** For survey objects, no longer filter `@data`:

```r
# Before:
filtered_design <- data
filtered_design@data <- out_df  # respondent rows only
.update_survey_weights(filtered_design, out_weights, history_entry)

# After:
.update_survey_weights(data, new_weights, history_entry)
```

#### S7 Validator Relaxation (surveycore change)

The `survey_nonprob` S7 validator currently enforces "all weights > 0." Since
S7 re-triggers the validator on property assignment, setting weights to 0 via
`@data[[weight_col]] <- new_weights` would fail validation.

**Resolution:** Relax the `survey_nonprob` validator condition 4 from
"all values are strictly positive (> 0)" to "all values are non-negative
(>= 0) and at least one is positive." This is a surveycore change — see
Change 11 notes for the full scope.

`.validate_weights()` (the internal surveywts validator used at calibration
entry points) remains strict: it rejects zero weights. This ensures that you
cannot start a calibration with zero-weight rows, while allowing
post-nonresponse survey objects to exist.

`test_invariants()` in `helper-test-data.R` must also be updated: change the
`survey_nonprob` branch from `all(w > 0)` to `all(w >= 0) && any(w > 0)`.
Post-nonresponse test blocks will then pass the invariant check.

#### Roxygen Updates

Update `@return` to clarify:

```
All rows (respondents and nonrespondents) are returned. Nonrespondent
weights are set to 0; respondent weights are adjusted upward to conserve
the total weight within each cell.
```

Update `@description` similarly.

Update `@details` to document zero-weight behavior for downstream consumers:

```
Zero-weight observations are retained for design-based variance estimation.
Survey estimation functions (e.g., \code{survey::svymean()}) handle zero
weights correctly --- zero-weight units are excluded from point estimates
but included in the design structure for variance estimation. For manual
calculations, use \code{w[w > 0]} to exclude nonrespondents.
```

#### Downstream Behavior of Zero Weights

1. **Taylor linearization:** Zero-weight units contribute nothing to point
   estimates but still appear in the design structure. They count as sampled
   units for degrees of freedom calculations. `survey::svydesign()` and
   `survey::svymean()` handle this correctly — zero-weight PSUs are effectively
   excluded from variance calculations.

2. **All-zero PSUs:** If a PSU contains only nonrespondent units, all its
   weights are zero. The PSU contributes nothing to estimates but still counts
   as a selected PSU for variance estimation. This is the correct behavior
   (it reflects the selection, not the response) but can produce slightly
   different standard errors than dropping those PSUs entirely.

3. **Re-calibration after nonresponse adjustment:** Zero weights fail
   `.validate_weights()`, preventing re-calibration on the full dataset. Users
   must filter to respondents (`w > 0`) before re-calibrating. A more
   integrated workflow (nonresponse + calibration in one step) is deferred to
   Phase 2.

#### Downstream Impact on Diagnostics

`effective_sample_size()`, `weight_variability()`, and `summarize_weights()`
use `.validate_weights()` which rejects weights ≤ 0. After this change,
post-nonresponse objects will have zero weights.

**Resolution:** `.validate_weights()` must be updated to allow zero weights
when they result from nonresponse adjustment. Two options:

> **GAP RESOLVED: How should `.validate_weights()` handle zeros?**
> **Decision:** Option (b) — diagnostics filter to `w > 0` internally.
> `.validate_weights()` stays strict for calibration entry points (you should
> not calibrate data with zero weights). Diagnostic functions filter to
> positive weights **before** calling `.validate_weights()`:
> ```r
> # In each diagnostic function, after extracting weight_col:
> w_all <- data_df[[weight_col]]
> data_df <- data_df[w_all > 0, , drop = FALSE]
> # Now .validate_weights() sees only positive weights — no error
> .validate_weights(data_df, weight_col)
> w <- data_df[[weight_col]]  # positive weights only
> ```
> This preserves `.validate_weights()` as the strict gatekeeper for
> calibration while allowing diagnostics to operate on post-nonresponse
> objects. The filtering happens before validation, not after.

#### Breaking Change Documentation

This is a breaking change to the `adjust_nonresponse()` output contract.
Pre-CRAN semver allows this without deprecation, but it must be documented:

- Add a NEWS.md entry under `## Breaking changes`:
  ```
  * `adjust_nonresponse()` now returns all rows with nonrespondent weights
    set to 0, instead of dropping nonrespondent rows. This preserves design
    structure for variance estimation. Code that uses `nrow(result)` to count
    respondents should use `sum(result$weight_col > 0)` instead.
  ```

#### Error Table Changes

No new error classes. The existing `surveywts_error_weights_nonpositive`
remains for calibration entry-point validation (you cannot start a
calibration with zero weights).

#### Testing Implications

- All existing `adjust_nonresponse()` tests that check `nrow(result) < nrow(input)` → update to `nrow(result) == nrow(input)`
- Add tests verifying nonrespondent weights are exactly 0
- Add tests verifying respondent weights are unchanged from previous behavior
- Add tests that diagnostics work correctly on post-nonresponse data
- Add tests that re-calibrating a post-nonresponse `weighted_df` errors
  (zero weights fail `.validate_weights()`)
- Add happy path test for `survey_nonprob` input: verify `nrow(@data)`
  unchanged, nonrespondent weights == 0, respondent weights adjusted,
  `@variables` and `@metadata` preserved

---

## IV. Change 3 — `.check_input_class()` → Universal `survey_base` Check

**Package:** surveywts
**Severity:** Medium

### Current Behavior

`.check_input_class()` (in `calibrate.R`) checks for specific classes:

```r
is_supported <- inherits(data, "data.frame") ||
  S7::S7_inherits(data, surveycore::survey_taylor) ||
  S7::S7_inherits(data, surveycore::survey_nonprob)
```

This requires updating every time a new survey class is added to surveycore.

### New Behavior

```r
.check_input_class <- function(data) {
  # Replicate designs require Phase 1 — check first (specific before general)
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.cls survey_replicate} objects are not supported in Phase 0.",
        "i" = "Replicate-weight support requires Phase 1.",
        "v" = "Use a {.cls survey_taylor} design, or wait for Phase 1."
      ),
      class = "surveywts_error_replicate_not_supported"
    )
  }

  is_supported <- inherits(data, "data.frame") ||
    S7::S7_inherits(data, surveycore::survey_base)

  if (!is_supported) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} must be a data frame or a supported survey design object.",
        "i" = "Got {.cls {cls}}.",
        "v" = "See package documentation for supported input types."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }
}
```

The `survey_replicate` check remains first — it's a specific rejection that
gives a more helpful message than the generic check.

### Diagnostics Function Update

`.diag_validate_input()` uses a similar pattern. Update it identically, including
the `survey_replicate` rejection guard:

```r
.diag_validate_input <- function(x, weights_quo) {
  # Replicate designs require Phase 1 — check first (specific before general)
  if (S7::S7_inherits(x, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.cls survey_replicate} objects are not supported in Phase 0.",
        "i" = "Replicate-weight support requires Phase 1.",
        "v" = "Use a {.cls survey_taylor} design, or wait for Phase 1."
      ),
      class = "surveywts_error_replicate_not_supported"
    )
  }

  is_supported <- is.data.frame(x) ||
    S7::S7_inherits(x, surveycore::survey_base)

  # ... rest of validation unchanged
}
```

This mirrors `.check_input_class()`: reject `survey_replicate` first (specific
before general), then use the `survey_base` check for future-proofing. When
Phase 1 adds replicate support, remove the guard from both functions.

#### Testing Implications

- Update snapshot tests for the unsupported-class error message (new wording)
- Existing typed `class =` tests are unaffected

---

## V. Change 4 — Move `.check_input_class()` and `.get_history()` to `utils.R`

**Package:** surveywts
**Severity:** Medium — pure refactor, no behavioral change

### Current State

Both functions are defined in `calibrate.R` but called by `calibrate.R`,
`rake.R`, `poststratify.R`, and `nonresponse.R`.

### Target State

Move to `R/utils.R` per `code-style.md §4`: "Helper used in 2+ source files →
lives in `R/utils.R`."

Add to the file header comment:

```r
#   .check_input_class()              — input class validation for all functions
#   .get_history()                    — extract weighting history from any class
```

Remove the corresponding definitions from `calibrate.R`. No functional
change.

---

## VI. Change 5 — Remove `%||%` Redefinition

**Package:** surveywts
**Severity:** Low

### Current State

`utils.R` line 899 defines:

```r
`%||%` <- function(x, y) if (!is.null(x)) x else y
```

### Target State

Delete the definition. Replace all usage with `rlang::%||%`. Since `rlang` is
already in `Imports`, this adds no new dependency.

Search for `%||%` usage in the codebase and replace with `rlang::%||%` — but
note that the `%||%` infix can be used without prefix after `rlang` is loaded,
so the simplest approach is just to delete the redefinition and let
rlang's version take precedence via the NAMESPACE.

**Actually:** The `%||%` operator is not automatically available without either
`@importFrom` or `::`. Since our style forbids `@importFrom`, we need to
either:
1. Use `rlang::`%||%`` explicitly at each call site (awkward syntax)
2. Add a single `@importFrom rlang %||%` to `surveywts-package.R`
3. Inline the null checks: `if (is.null(x)) y else x`

**Usage sites (4 calls + 1 definition):**

| File | Line | Expression |
|------|------|------------|
| `R/utils.R` | 899 | Definition — delete |
| `R/calibrate.R` | 279 | `attr(x, "weighting_history") %||% list()` |
| `R/calibrate.R` | 282 | `x@metadata@weighting_history %||% list()` |
| `R/utils.R` | 663 | `attr(g, "iterations") %||% NA_integer_` |
| `R/utils.R` | 664 | `attr(g, "max_error") %||% 0` |

**Decision:** Option 3 — inline the null checks. There are only 4
`%||%` uses. Replace each with `if (is.null(x)) y else x`. This follows the
"no `@importFrom`" rule without exception.

**Pre-implementation audit:** Grep the entire repo (`R/`, `tests/`, `man/`)
for `%||%` before removing the definition to confirm no additional usage
sites. Audit result (2026-03-18): no `%||%` usage in `tests/` or `man/`;
only the 4 sites listed above plus the definition in `R/`.

---

## VII. Change 6 — Rewrite Grouped Path in `summarize_weights()`

**Package:** surveywts
**Severity:** Medium — `interaction()` uses `.` as separator, which collides
with factor levels containing `.`; replacement rewrites the full grouped
summarization path (grouping mechanism + per-group computation)

### Current Behavior (diagnostics.R line 127)

```r
group_factor <- if (length(by_names) == 1L) {
  data_df[[by_names]]
} else {
  interaction(lapply(by_names, function(v) data_df[[v]]), drop = TRUE)
}
```

`interaction()` joins factor levels with `.`, which is ambiguous if any level
contains `.` (e.g., `"Dr."`, `"U.S."`).

### New Behavior

Replace with `paste(..., sep = "//")`, matching the pattern already used in
`adjust_nonresponse()` and `poststratify()`:

```r
if (length(by_names) == 0L) {
  # ... existing single-summary path
} else {
  cell_keys <- do.call(
    paste,
    c(lapply(by_names, function(v) as.character(data_df[[v]])), sep = "//")
  )
  groups <- split(seq_len(nrow(data_df)), cell_keys)

  result_dfs <- lapply(names(groups), function(gkey) {
    idx <- groups[[gkey]]
    w <- data_df[[weight_col]][idx]
    stats_tbl <- tibble::as_tibble(.compute_weight_stats(w))
    group_row <- data_df[idx[[1L]], by_names, drop = FALSE]
    dplyr::bind_cols(
      tibble::as_tibble(group_row),
      stats_tbl
    )
  })

  dplyr::bind_rows(result_dfs)
}
```

### Testing Implications

- Add a test case with a grouping variable containing `.` in its levels
  (e.g., `"Dr."`)
- Existing tests pass unchanged (separator is internal)

---

## VIII. Change 7 — `response_status` → `tidyselect::eval_select()`

**Package:** surveywts
**Severity:** Low — consistency fix

### Current Behavior

`adjust_nonresponse()` uses `rlang::as_name()` to resolve `response_status`:

```r
rs_quo <- rlang::enquo(response_status)
status_var <- rlang::as_name(rs_quo)
```

### New Behavior

Use `tidyselect::eval_select()` for consistency with how `variables`,
`strata`, and `by` are resolved:

```r
rs_quo <- rlang::enquo(response_status)
status_pos <- tidyselect::eval_select(rs_quo, plain_df)
if (length(status_pos) == 0L) {
  cli::cli_abort(
    c(
      "x" = "{.arg response_status} column not found in {.arg data}.",
      "i" = "Available columns: {.and {.field {names(plain_df)}}}.",
      "v" = "Pass a single bare column name, e.g., {.code response_status = responded}."
    ),
    class = "surveywts_error_response_status_not_found"
  )
}
if (length(status_pos) > 1L) {
  cli::cli_abort(
    c(
      "x" = "{.arg response_status} must select exactly one column.",
      "i" = "Got {length(status_pos)} column(s).",
      "v" = "Pass a single bare column name, e.g., {.code response_status = responded}."
    ),
    class = "surveywts_error_response_status_multiple_columns"
  )
}
status_var <- names(status_pos)
```

**Note:** The `tidyselect::eval_select()` call must happen AFTER the empty
data check (step 3) and AFTER `plain_df` is assembled, but BEFORE the
response status validation (step 7). Move the `rs_quo` capture to the top
(already there) and add the eval_select call in the existing step 7 location.

### Error Table Changes

New class: `surveywts_error_response_status_multiple_columns` — thrown when
`tidyselect::eval_select()` selects more than one column. The existing
`surveywts_error_response_status_not_found` is used for zero selections.

> Add `surveywts_error_response_status_multiple_columns` to
> `plans/error-messages.md` before implementation.

---

## IX. Change 8 — `poststratify()` Default `type` → `"prop"`

**Package:** surveywts
**Severity:** Medium — API change (but pre-CRAN)

### Current Behavior

```r
poststratify <- function(..., type = c("count", "prop"))
```

### New Behavior

```r
poststratify <- function(..., type = c("prop", "count"))
```

This makes `poststratify()` consistent with `calibrate()` and `rake()`, which
both default to `type = "prop"`.

### Roxygen Update

Update `@param type` to note the change:

```
@param type Character scalar. `"prop"` (default): `target` values are
  proportions summing to 1.0. `"count"`: `target` values are population
  counts.
```

Remove the note in the current `@param type` that says "Note: default is
`"count"`, unlike [calibrate()] and [rake()]."

### Testing Implications

- Update `poststratify()` tests that rely on the `type = "count"` default.
  The following `test_that()` blocks in `test-04-poststratify.R` call
  `poststratify()` without an explicit `type =` argument and use count-based
  population data (via `.make_pop_ps()` which defaults to `"count"`):
  - Line 66: `"poststratify() returns weighted_df for data.frame input"`
  - Line 82: `"poststratify() default type is 'count', not 'prop'"` — must
    be rewritten entirely (title, assertions, population data)
  - Line 136: `"poststratify() preserves survey_taylor class..."`
  - Line 161: `"poststratify() accepts and returns survey_nonprob"`
  - Line 551: `"poststratify() history entry has correct structure"`
  - Line 580: `"poststratify() step increments correctly in chained calls"`
  - Error path tests (lines 238–497) that use `.make_pop_ps()` without
    `type =` — add `type = "count"` explicitly to preserve test intent
- Add a test verifying the new default behavior with proportions

---

## X. Change 9 — `survey_nonprob` Print: Fix Variance Method Label

**Package:** surveywts
**Severity:** Low — cosmetic

### Current Behavior (methods-print.R line 38)

```r
cat("# Variance method: Taylor linearization\n")
```

This is incorrect for `survey_nonprob`, which is a non-probability sample
class that does not use Taylor linearization.

### New Behavior

```r
cat("# Variance: model-assisted (SRS assumption)\n")
```

### Testing Implications

- Update print snapshot for `survey_nonprob` to reflect new label

---

## XI. Change 10 — Document `@importFrom` Exception for S3 Method Registration

**Package:** surveywts
**Severity:** Low — documentation only

### Current State

`classes.R` uses `@importFrom` tags for dplyr S3 method registration:

```r
#' @importFrom dplyr dplyr_reconstruct
#' @export
dplyr_reconstruct.weighted_df <- function(data, template) { ... }

#' @importFrom dplyr select
#' @export
select.weighted_df <- function(.data, ...) { ... }
```

This is required by R's S3 method registration mechanism: the generic must be
imported for `roxygen2` to register the method in `NAMESPACE`. But it violates
the "`::` everywhere; no `@importFrom`" rule.

### Target State

Add an exception clause to `code-style.md` §4 (Import style):

> **Exception: S3 method registration.** `@importFrom` is required when
> registering an S3 method for a generic from another package (e.g.,
> `dplyr::dplyr_reconstruct`, `dplyr::select`). Without it, `roxygen2`
> cannot generate the `S3method()` directive in `NAMESPACE`. This is the
> only approved use of `@importFrom`.

No code changes. The existing `@importFrom` tags in `classes.R` are correct.

---

## XII. Change 11 — Remove `survey_srs` from surveycore

**Package:** surveycore
**Severity:** High — class removal

### Background

The user is already in the process of removing `survey_srs` and
`as_survey_srs()` from surveycore. After removal, `as_survey()` always
returns `survey_taylor` (even with no ids/strata — interpreted as SRS).

### surveywts Impact

`survey_srs` is not referenced in any surveywts source file. The Phase 0
implementation already handles `survey_taylor` with `ids = ~1` as the SRS
case. No code changes needed in surveywts.

The Phase 1 spec references `survey_srs` in its input/output class matrix.
That spec should be updated separately when this change lands.

### Additional surveycore Change: Relax `survey_nonprob` Weight Validator

Change 2 (zero weights for nonrespondents) requires relaxing the
`survey_nonprob` S7 validator. Currently condition 4 enforces "all weights
strictly positive (> 0)." This must change to "all weights non-negative
(>= 0) and at least one positive."

**Why:** S7 re-triggers the validator on property assignment via `@<-`. When
`adjust_nonresponse()` sets nonrespondent weights to 0 on a `survey_nonprob`
object, the validator would reject the update under the current strict rule.

**Scope of change in surveycore:**
- Update the `survey_nonprob` validator condition 4
- Update all validator tests that assert "all positive"
- No change to `survey_taylor` or `survey_replicate` validators (they have
  their own weight semantics)

**surveywts impact:**
- `.validate_weights()` remains strict (rejects zero weights) for calibration
  entry points — you cannot start a calibration with zero-weight rows
- `test_invariants()` updated: `all(w > 0)` → `all(w >= 0) && any(w > 0)`

### Implementation Notes

The `survey_srs` removal is entirely in surveycore. The validator relaxation
is also in surveycore but is driven by surveywts Change 2. Both are included
here for tracking completeness.

---

## XIII. Quality Gates

All of the following must be true before this spec is considered complete:

- [ ] All 3 vendor files deleted
- [ ] `survey` and `anesrake` moved to `Imports`
- [ ] `.calibrate_engine()` delegates to package functions for all 5 methods
- [ ] `adjust_nonresponse()` returns all rows with nonrespondent weights = 0
- [ ] `.check_input_class()` uses `survey_base` inheritance
- [ ] `.check_input_class()` and `.get_history()` live in `utils.R`
- [ ] `%||%` redefinition removed; null checks inlined
- [ ] `interaction()` replaced with `paste(sep = "//")` in `summarize_weights()`
- [ ] `response_status` resolved via `tidyselect::eval_select()`
- [ ] `poststratify()` defaults to `type = "prop"`
- [ ] `survey_nonprob` S7 validator relaxed to allow zero weights (surveycore)
- [ ] `test_invariants()` updated for zero-weight `survey_nonprob`
- [ ] `survey_nonprob` print says "model-assisted (SRS assumption)"
- [ ] `code-style.md` documents `@importFrom` exception
- [ ] `plans/error-messages.md` updated with `surveywts_error_cap_not_supported_survey` and `surveywts_error_response_status_multiple_columns`
- [ ] Diagnostic functions (`effective_sample_size()`, `weight_variability()`, `summarize_weights()`) return correct results on post-nonresponse objects with zero weights
- [ ] NEWS.md entry documents the `adjust_nonresponse()` breaking change
- [ ] surveywts DESCRIPTION pins `surveycore (>= 0.1.1)`
- [ ] `R CMD check`: 0 errors, 0 warnings, ≤2 notes
- [ ] All existing tests updated; no snapshot regressions
- [ ] 98%+ line coverage maintained

---

## XIV. GAP Summary

Both GAPs resolved:

| GAP | Location | Decision |
|-----|----------|----------|
| `cap` with `method = "survey"` in `rake()` | §II | **(b) Error** — throw `surveywts_error_cap_not_supported_survey` in `rake()` (fail fast, before engine dispatch); users must use `method = "anesrake"` for capping |
| `.validate_weights()` and zero weights | §III | **(b) Diagnostics filter internally** — `.validate_weights()` stays strict; diagnostics add `w <- w[w > 0]` |

---

## XV. Integration: surveywts ↔ surveycore

### Dependency Order

Surveycore changes **must land first** before surveywts implementation begins:

1. **surveycore release >= 0.1.1** must include:
   - `survey_srs` removal (Change 11)
   - `survey_nonprob` validator relaxation: condition 4 from `> 0` to
     `>= 0 && any > 0` (required by Change 2)
2. **surveywts DESCRIPTION** must be updated: `surveycore (>= 0.1.1)`
   (currently `>= 0.1.0`)
3. **surveywts CI** must run against the updated surveycore. If surveycore
   0.1.1 is not yet on CRAN, use `Remotes:` in DESCRIPTION to point to the
   dev branch during development, and remove `Remotes:` before merging.

### Cross-Package Verification

Change 11 (remove `survey_srs`) is the only surveycore class change. It has
no direct code impact on surveywts but may require updating the Phase 1
spec's class matrix.

Change 3 (use `survey_base` for class checks) depends on `survey_base` being
the correct inheritance root for all survey objects in surveycore. Verify
that `survey_taylor`, `survey_nonprob`, and `survey_replicate` all inherit
from `survey_base` (they do as of surveycore 0.1.0).
