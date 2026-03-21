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
| User-facing calibration functions | verb | `calibrate()`, `rake()`, `poststratify()` |
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
| `calibration` | `calibrate()`, `rake()`, `poststratify()` |
| `nonresponse` | `adjust_nonresponse()` |
| `diagnostics` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |

Use `@family calibration`, `@family nonresponse`, `@family diagnostics` in roxygen2.

---

## 3. Return Value Visibility

| Function type | Return |
|---------------|--------|
| Calibration / nonresponse functions | Visible (new object) |
| Diagnostic functions | Visible (named scalar or tibble) |
| Internal constructors (`.new_*()`) | Visible (the new object) |
| Print / summary methods | `invisible(x)` |
| Internal validators (`.validate_*()`) | `invisible(TRUE)` on success |

---

## 4. Export Policy

### What to export
- All user-facing functions: `calibrate()`, `rake()`, `poststratify()`,
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

## 5. S7 Classes

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

## 6. Argument Order (Calibration Functions)

| Function | Argument order |
|----------|----------------|
| `calibrate()` | `data, variables, population, weights = NULL, method = "linear", type = "prop", control = list()` |
| `rake()` | `data, margins, weights = NULL, type = "prop", method = "anesrake", cap = NULL, control = list()` |
| `poststratify()` | `data, strata, population, weights = NULL, type = "prop"` |
| `adjust_nonresponse()` | `data, response_status, weights = NULL, by = NULL, method = "weighting_class", control = list()` |
| `effective_sample_size()` | `x, weights = NULL` |
| `weight_variability()` | `x, weights = NULL` |
| `summarize_weights()` | `x, weights = NULL, by = NULL` |

---

## 7. Documentation Checklist

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
