# surveywts R Package Conventions

**Version:** 1.0 — Calibration API complete
**Status:** Stable for Calibration

This document extends the **generic R package conventions** (`r-package-conventions.md`)
with surveywts-specific examples and detailed guidance.

**Read `r-package-conventions.md` first, then this document.**

---

## Quick Reference (surveywts-specific)

| Decision | Choice | Example |
|----------|--------|---------|
| Error prefix | `surveywts_error_*` | `surveywts_error_weights_nonpositive` |
| Warning prefix | `surveywts_warning_*` | `surveywts_warning_weight_col_dropped` |
| Internal constructor return | Visible (the new object) | `.new_survey_nonprob()` |
| Internal validator return | `invisible(TRUE)` on success | `.validate_weights()` |
| Print method return | `invisible(x)` | `print.weighted_df()`, S7 print |
| Diagnostic function return | Visible named scalar or tibble | `effective_sample_size()` |

---

## 1. Naming Conventions

| Category | Pattern | Example |
|----------|---------|---------|
| User-facing calibration functions | verb | `calibrate()`, `calibrate_rake()`, `poststratify()` |
| User-facing nonresponse function | verb + noun | `adjust_nonresponse()` |
| User-facing diagnostic functions | noun phrase | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| Internal constructor | `.new_` prefix | `.new_survey_nonprob()` |
| Internal validators | `.validate_` prefix | `.validate_weights()`, `.validate_calibration_variables()` |
| Internal shared helpers | `.` prefix + descriptive name | `.get_weight_vec()`, `.compute_weight_stats()`, `.make_history_entry()` |
| Internal single-file helpers | `.` prefix + descriptive name | `.parse_margins()`, `.validate_population_cells()` |
| Internal dispatch/engine functions | `.` prefix + `_engine` suffix | `.calibrate_engine()` |
| Internal output constructors | `.make_` prefix | `.make_weighted_df()` |

---

## 2. Function Families (`@family` groups)

| Family tag | Functions |
|------------|-----------|
| `calibration` | `calibrate()`, `calibrate_linear()`, `calibrate_logit()`, `calibrate_rake()`, `poststratify()` |
| `sample-calibration` | `calibrate_to_survey()`, `calibrate_to_estimate()` |
| `nonresponse` | `adjust_nonresponse()`, `redistribute_weights()` |
| `diagnostics` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| `replicate-weights` | `create_bootstrap_weights()`, `create_jackknife_weights()`, `create_brr_weights()`, `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()`, `create_replicate_weights()`, `as_taylor_design()` |
| `utilities` | `trim_weights()`, `rescale_weights()` |
| `propensity` | `ipw()` |

Use `@family calibration`, `@family sample-calibration`, `@family nonresponse`, `@family diagnostics`, `@family replicate-weights`, `@family utilities`, `@family propensity` in roxygen2.

---

## 3. File Organization

### Rules
1. Every exported function lives in a `.R` file named identically to it (matching its `.Rd` filename without the extension).
2. The exported function appears at the **top** of its file; helpers used only by that function appear **below** it.
3. Helpers shared by 2+ functions in the same family go to `{family}-utils.R`.
4. Helpers used across different families stay in `utils.R`.
5. Structural/role-based files are exempt from rule 1.

### Exempt structural files

| File | Purpose |
|------|---------|
| `utils.R` | Cross-family internal helpers |
| `methods-print.R` | All S7 and S3 print methods |
| `zzz.R` | `.onLoad()` / `.onAttach()` hooks |
| `data.R` | `@docType data` documentation stubs |
| `surveywts-package.R` | Package-level documentation |

### Family utils files

| File | Shared helpers for |
|------|--------------------|
| `diagnostics-utils.R` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| `nonresponse-utils.R` | `adjust_nonresponse()`, `redistribute_weights()` |
| `replicate-utils.R` | All `create_*_weights()` functions + `as_taylor_design()` |
| `jackknife-dagjk-utils.R` | DAGJK engine internals for `create_jackknife_weights()` |
| `weight-utils.R` | `trim_weights()`, `rescale_weights()` |

### File mapping (R/ → export)

| File | Export |
|------|--------|
| `adjust_nonresponse.R` | `adjust_nonresponse()` |
| `as_taylor_design.R` | `as_taylor_design()` |
| `calibrate.R` | `calibrate()` — thin dispatcher |
| `calibrate-utils.R` | (internal helpers — not exported) |
| `calibrate_linear.R` | `calibrate_linear()` |
| `calibrate_logit.R` | `calibrate_logit()` |
| `calibrate_rake.R` | `calibrate_rake()` |
| `poststratify.R` | `poststratify()` |
| `calibrate_to_estimate.R` | `calibrate_to_estimate()` |
| `calibrate_to_survey.R` | `calibrate_to_survey()` |
| `create_bootstrap_weights.R` | `create_bootstrap_weights()` |
| `create_brr_weights.R` | `create_brr_weights()` |
| `create_gen_boot_weights.R` | `create_gen_boot_weights()` |
| `create_gen_rep_weights.R` | `create_gen_rep_weights()` |
| `create_jackknife_weights.R` | `create_jackknife_weights()` |
| `jackknife-dagjk-utils.R` | DAGJK engine internals (internal helpers only) |
| `create_replicate_weights.R` | `create_replicate_weights()` |
| `create_sdr_weights.R` | `create_sdr_weights()` |
| `effective_sample_size.R` | `effective_sample_size()` |
| `ipw.R` | `ipw()` |
| `redistribute_weights.R` | `redistribute_weights()` |
| `rescale_weights.R` | `rescale_weights()` |
| `summarize_weights.R` | `summarize_weights()` |
| `trim_weights.R` | `trim_weights()` |
| `weight_variability.R` | `weight_variability()` |
| `weighted-df-dplyr.R` | dplyr methods for `weighted_df` |

---

## 4. Return Value Visibility

| Function type | Return |
|---------------|--------|
| Calibration / nonresponse functions | Visible (new object) |
| Diagnostic functions | Visible (named scalar or tibble) |
| Internal constructors (`.new_*()`) | Visible (the new object) |
| Print / summary methods | `invisible(x)` |
| Internal validators (`.validate_*()`) | `invisible(TRUE)` on success |

---

## 5. Export Policy

### What to export
- All user-facing functions: `calibrate()`, `calibrate_rake()`, `poststratify()`,
  `adjust_nonresponse()`, `effective_sample_size()`, `weight_variability()`,
  `summarize_weights()`
- `survey_nonprob` S7 class object (part of the public API)
- `print.weighted_df()` and `dplyr_reconstruct.weighted_df()` via `@export`
  (S3 method registration)

### What NOT to export
- All `.`-prefixed internal helpers (`.validate_weights()`, `.make_weighted_df()`, etc.)
- `.new_survey_nonprob()` internal constructor
- `weighted_df` is NOT exported as an object — it is produced as output from
  calibration and nonresponse functions; users never construct it directly

---

## 6. S7 Classes

### `survey_nonprob`

```r
survey_nonprob <- S7::new_class(
  "survey_nonprob",
  parent = surveycore::survey_base,
  ...
)
```

- Inherits all properties from `survey_base`: `@data`, `@variables`, `@metadata`
- `@variables$weights` — character scalar: the name of the weight column in `@data`
- Weighting history is stored in `@metadata@weighting_history` (list of history entries)
- Does NOT extend `survey_taylor` — extends `survey_base` directly to avoid
  inheriting Taylor-specific dispatch that would be incorrect post-calibration

**Validator enforces (5 conditions, S7 native mechanism — not `cli_abort()`):**
1. `@variables$weights` is a character scalar
2. The column named by `@variables$weights` exists in `@data`
3. That column is numeric
4. All values are strictly positive (> 0)
5. No NAs in the weight column

Test validator errors with `class =` only — no snapshot (messages are not CLI-formatted).

### `weighted_df` (S3)

```r
class(x)  #=> c("weighted_df", "tbl_df", "tbl", "data.frame")
```

- S3 subclass of tibble; never constructed directly by users
- Produced as output from calibration and nonresponse functions when input is a
  plain `data.frame` or `weighted_df`

**Attributes:**

| Attribute | Type | Description |
|-----------|------|-------------|
| `weight_col` | `character(1)` | Name of the weight column |
| `weighting_history` | `list` | Ordered list of history entries |

The weight column is always present as a regular column in the data frame.
`weight_col` identifies which column it is.

**dplyr compatibility:** `dplyr_reconstruct.weighted_df()` preserves the
`weighted_df` class when the weight column is retained; emits
`surveywts_warning_weight_col_dropped` and returns a plain tibble when
the weight column is removed.

---

## 7. Argument Order

| Function | Argument order |
|----------|----------------|
| `calibrate()` | `data, targets, weights = NULL, wt_name = "wts", type = c("prop", "count"), reference_design = NULL, ..., method = c("rake", "linear", "logit")` |
| `calibrate_linear()` | `data, targets, weights = NULL, wt_name = "wts", bounds = NULL, bounds_scale = c("multiplicative", "absolute"), unit_scale = NULL, type = c("prop", "count"), control = list(), reference_design = NULL` |
| `calibrate_logit()` | `data, targets, weights = NULL, wt_name = "wts", bounds = c(1e-6, 1e6), bounds_scale = c("multiplicative", "absolute"), unit_scale = NULL, type = c("prop", "count"), control = list(), reference_design = NULL` |
| `calibrate_rake()` | `data, targets, weights = NULL, wt_name = "wts", type = c("prop", "count"), algorithm = c("classic_ipf", "nr"), cap = NULL, control = list(), reference_design = NULL` |
| `poststratify()` | `data, targets, weights = NULL, wt_name = "wts", type = c("prop", "count"), reference_design = NULL` |
| `adjust_nonresponse()` | `data, response_status, weights = NULL, by = NULL, wt_name = "wts", method = c("weighting-class", "propensity-cell", "propensity"), formula = NULL, control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)` |
| `redistribute_weights()` | `data, reduce_if, increase_if, weights = NULL, by = NULL, wt_name = "wts", control = list()` |
| `trim_weights()` | `data, weights = NULL, lower = NULL, upper = NULL, k = 5, type = c("absolute", "percentile"), strict = FALSE, wt_name = "wts"` |
| `rescale_weights()` | `data, weights = NULL, by = NULL, wt_name = "wts"` |
| `calibrate_to_survey()` | `primary_design, control_design, variables, method = c("rake", "linear", "logit"), bounds = c(-Inf, Inf), unit_scale = NULL, reference_design = NULL, control = list()` |
| `calibrate_to_estimate()` | `design, targets, vcov_estimate, method = c("rake", "linear", "logit"), bounds = c(-Inf, Inf), unit_scale = NULL, reference_design = NULL, control = list()` |
| `effective_sample_size()` | `x, weights = NULL` |
| `weight_variability()` | `x, weights = NULL` |
| `summarize_weights()` | `x, weights = NULL, by = NULL` |
| `as_taylor_design()` | `data` |
| `ipw()` | `data, reference, selection = NULL, predictors = NULL, missing_method = c("omit", "separate", "impute"), mice_args = list(), method = "logit", estimating_eq = c("mle", "gee"), maxit = 25L, epsilon = 1e-8, adjust_reference = TRUE, trim = FALSE, population_size = NULL, wt_name = "ipw_weight"` |

---

## 8. Documentation Checklist

Before committing any roxygen2 changes:

- [ ] `devtools::document()` has been run
- [ ] `NAMESPACE` file has been updated
- [ ] All exported functions have `@return`
- [ ] All `@examples` are runnable
- [ ] Internal helpers have `@keywords internal` + `@noRd` if needed
- [ ] `@family` tags are correct (see Section 2)
- [ ] No `@importFrom` tags anywhere
- [ ] All external calls use `::`
- [ ] `R CMD check` passes with 0 errors, 0 warnings, ≤2 notes
