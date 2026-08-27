# surveywts R Package Conventions

This document extends the **generic R package conventions** (`r-package-conventions.md`)
with surveywts-specific examples and detailed guidance.

**Read `r-package-conventions.md` first, then this document.**

---

## Quick Reference (surveywts-specific)

| Decision | Choice | Example |
|----------|--------|---------|
| Error prefix | `surveywts_error_*` | `surveywts_error_weights_nonpositive` |
| Warning prefix | `surveywts_warning_*` | `surveywts_warning_no_weights_trimmed` |
| Internal constructor return | Visible (the new object) | `.make_history_entry()` |
| Internal validator return | `invisible(TRUE)` on success | `.validate_weights()` |
| Print method return | `invisible(x)` | `S7::method(print, surveycore::survey_nonprob)`, `S7::method(print, surveycore::survey_replicate)` |
| Diagnostic function return | Visible named scalar or tibble | `effective_sample_size()` |

---

## 1. Naming Conventions

| Category | Pattern | Example |
|----------|---------|---------|
| User-facing calibration functions | verb | `calibrate()`, `calibrate_rake()`, `poststratify()` |
| User-facing nonresponse function | verb + noun | `adjust_nonresponse()` |
| User-facing diagnostic functions | noun phrase | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| Internal validators | `.validate_` prefix | `.validate_weights()`, `.validate_calibration_variables()` |
| Internal shared helpers | `.` prefix + descriptive name | `.get_weight_vec()`, `.compute_weight_stats()`, `.make_history_entry()` |
| Internal single-file helpers | `.` prefix + descriptive name | `.parse_margins()`, `.validate_population_cells()` |
| Internal dispatch/engine functions | `.` prefix + `_engine` suffix | `.calibrate_nr_engine()`, `.anesrake_engine()` |
| Internal output constructors | `.make_` prefix | `.make_history_entry()`, `.make_calfun_linear()` |

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
| `methods-print.R` | All print methods — two `S7::method(print, ...)` registrations for surveycore classes |
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
| `calibrate-utils.R` | `calibrate()`, `calibrate_linear()`, `calibrate_logit()`, `calibrate_rake()` |

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

---

## 4. Return Value Visibility

| Function type | Return |
|---------------|--------|
| Calibration / nonresponse functions | Visible (new object) |
| Diagnostic functions | Visible (named scalar or tibble) |
| Internal constructors (`.make_*()`) | Visible (the new object) |
| Print / summary methods | `invisible(x)` |
| Internal validators (`.validate_*()`) | `invisible(TRUE)` on success |

---

## 5. Export Policy

### What to export
- User-facing functions only. `NAMESPACE` holds 23 `export()` entries and
  nothing else: `calibrate()`, `calibrate_linear()`, `calibrate_logit()`,
  `calibrate_rake()`, `poststratify()`, `calibrate_to_survey()`,
  `calibrate_to_estimate()`, `adjust_nonresponse()`, `redistribute_weights()`,
  `trim_weights()`, `rescale_weights()`, `effective_sample_size()`,
  `weight_variability()`, `summarize_weights()`, `ipw()`, `as_taylor_design()`,
  `create_replicate_weights()`, `create_bootstrap_weights()`,
  `create_brr_weights()`, `create_jackknife_weights()`,
  `create_gen_boot_weights()`, `create_gen_rep_weights()`,
  `create_sdr_weights()`

### What NOT to export
- All `.`-prefixed internal helpers (`.validate_weights()`,
  `.make_history_entry()`, `.check_input_class()`, etc.)
- No classes. surveywts defines none — see §6
- No S3 methods. `NAMESPACE` holds zero `S3method()` directives
- No re-exports — not the pipe, not tidyselect helpers

---

## 6. S7 Classes

**surveywts defines no classes.** There is no `S7::new_class()` call anywhere
in `R/`, and `NAMESPACE` exports no class object. Every survey class surveywts
works with — `survey_base`, `survey_taylor`, `survey_nonprob`,
`survey_replicate` — is defined and exported by **surveycore**, in
`surveycore/R/core-classes.R`. surveywts consumes them; it does not own them.

What surveywts does own, on the S7 side, is two print methods:

```r
# R/methods-print.R — registered by S7::methods_register() in .onLoad()
S7::method(print, surveycore::survey_nonprob)   <- function(x, n = 10, ...) { }
S7::method(print, surveycore::survey_replicate) <- function(x, ...) { }
```

### `survey_nonprob` (defined in surveycore)

- Parent is `survey_base`. It does NOT extend `survey_taylor`, which avoids
  inheriting Taylor-specific dispatch that would be incorrect post-calibration
- Inherits five properties from `survey_base`: `@data`, `@metadata`,
  `@variables`, `@groups`, `@call`
- Adds two of its own: `@calibration` (calibration provenance written by
  surveywts, `NULL` otherwise) and `@reference_sample` (an optional
  `survey_taylor` used for propensity estimation)
- `@variables$weights` — character scalar: the name of the weight column in `@data`
- Weighting history is stored in `@metadata@weighting_history` (list of history entries)

**The surveycore validator enforces four conditions**, and its error classes are
`surveycore_error_*`, not `surveywts_error_*`:

1. The column named by `@variables$weights` exists in `@data` —
   `surveycore_error_design_var_missing`
2. That column is numeric — `surveycore_error_weights_not_numeric`
3. It has at least one non-NA value, and at least one value greater than 0 —
   `surveycore_error_weights_all_zero`
4. No non-NA value is negative — `surveycore_error_weights_negative`

Note what the validator does **not** enforce: NAs are permitted, and zeroes are
permitted, as long as one positive weight remains. Strictly-positive,
fully-observed weights are a surveywts precondition, not a class invariant.
`.validate_weights()` in `utils.R` is what enforces it, throwing
`surveywts_error_weights_nonpositive` and `surveywts_error_weights_na`.

Test surveycore validator errors with `class =` only — no snapshot (messages
are not CLI-formatted, and surveywts does not own the text).

---

## 7. Argument Order

| Function | Argument order |
|----------|----------------|
| `calibrate()` | `data, targets, weights = NULL, wt_name = NULL, type = c("prop", "count"), reference_design = NULL, ..., method = c("rake", "linear", "logit")` |
| `calibrate_linear()` | `data, targets, weights = NULL, wt_name = NULL, bounds = NULL, bounds_scale = c("multiplicative", "absolute"), unit_scale = NULL, type = c("prop", "count"), control = list(), reference_design = NULL` |
| `calibrate_logit()` | `data, targets, weights = NULL, wt_name = NULL, bounds = c(1e-6, 1e6), bounds_scale = c("multiplicative", "absolute"), unit_scale = NULL, type = c("prop", "count"), control = list(), reference_design = NULL` |
| `calibrate_rake()` | `data, targets, weights = NULL, wt_name = NULL, type = c("prop", "count"), algorithm = c("classic_ipf", "nr"), cap = NULL, control = list(), reference_design = NULL` |
| `poststratify()` | `data, targets, weights = NULL, wt_name = NULL, type = c("prop", "count"), reference_design = NULL` |
| `adjust_nonresponse()` | `data, response_status, weights = NULL, by = NULL, wt_name = NULL, method = c("weighting-class", "propensity-cell", "propensity"), formula = NULL, control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)` |
| `redistribute_weights()` | `data, reduce_if, increase_if, weights = NULL, by = NULL, wt_name = NULL, control = list()` |
| `trim_weights()` | `data, weights = NULL, lower = NULL, upper = NULL, k = 5, type = c("absolute", "percentile"), strict = FALSE, wt_name = NULL` |
| `rescale_weights()` | `data, weights = NULL, by = NULL, wt_name = NULL` |
| `calibrate_to_survey()` | `primary_design, control_design, variables, targets = NULL, type = c("prop", "count"), method = c("rake", "linear", "logit"), algorithm = c("classic_ipf", "nr"), bounds = c(-Inf, Inf), unit_scale = NULL, reference_design = NULL, control = list()` |
| `calibrate_to_estimate()` | `design, targets, vcov_estimate, method = c("rake", "linear", "logit"), bounds = c(-Inf, Inf), unit_scale = NULL, reference_design = NULL, control = list()` |
| `effective_sample_size()` | `x, weights = NULL` |
| `weight_variability()` | `x, weights = NULL` |
| `summarize_weights()` | `x, weights = NULL, by = NULL` |
| `as_taylor_design()` | `data` |
| `ipw()` | `data, reference, selection = NULL, predictors = NULL, missing_method = c("omit", "separate", "impute"), mice_args = list(), method = "logit", estimating_eq = c("gee", "mle"), maxit = 25L, epsilon = 1e-8, adjust_reference = TRUE, trim = FALSE, population_size = NULL, wt_name = "ipw_weight"` |

---

## 8. Documentation Checklist

Before committing any roxygen2 changes:

- [ ] `devtools::document()` has been run
- [ ] `NAMESPACE` file has been updated
- [ ] All exported functions have `@returns` (the plural tag — `@return` is not used anywhere in `R/`)
- [ ] All `@examples` are runnable
- [ ] Internal helpers have `@keywords internal` + `@noRd` if needed
- [ ] `@family` tags are correct (see Section 2)
- [ ] No `@importFrom` tags anywhere
- [ ] All external calls use `::`
- [ ] `R CMD check` passes with 0 errors, 0 warnings, ≤2 notes
