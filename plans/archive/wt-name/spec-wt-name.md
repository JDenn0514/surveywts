# Spec: `wt_name` Argument for Output Weight Column Naming

**Version:** 0.1
**Date:** 2026-03-19
**Status:** Draft — Stage 1
**Branch identifier:** `wt-name`
**Related files:** `plans/spec-review-wt-name.md` (after review),
`plans/decisions-wt-name.md` (after resolve)

---

## Document Purpose

This document is the single source of truth for adding a `wt_name` argument
to all four weighting functions (`calibrate()`, `rake()`, `poststratify()`,
`adjust_nonresponse()`) that controls the name of the output weight column
when the input is a `data.frame` or `weighted_df`.

This spec does NOT repeat rules defined in:
- `code-style.md` — formatting, error structure, argument order
- `r-package-conventions.md` — `::` usage, NAMESPACE, roxygen2
- `surveywts-conventions.md` — error/warning prefixes, return visibility
- `testing-standards.md` — `test_that()` scope, coverage targets

Those rules apply by reference.

---

## I. Scope

### Deliverables

| # | Change | Severity |
|---|--------|----------|
| 1 | Add `wt_name = "wts"` argument to `calibrate()`, `rake()`, `poststratify()`, `adjust_nonresponse()` | Medium |
| 2 | Output weight column uses `wt_name` for `data.frame` / `weighted_df` inputs | Medium |
| 3 | Validate `wt_name` argument | Low |
| 4 | Update `.get_weight_col_name()` default from `".weight"` to `"wts"` | Low |
| 5 | Add new error classes to `plans/error-messages.md` | Low |

### Non-Deliverables

| Item | Reason |
|------|--------|
| `wt_name` for survey object inputs (`survey_taylor`, `survey_nonprob`) | Out of scope — survey objects manage their own `@variables$weights` |
| Renaming existing weight columns on `weighted_df` input | The input column is preserved; `wt_name` controls the output column only |

### Breaking Changes

| Change | Impact |
|--------|--------|
| Default output column name changes from `".weight"` to `"wts"` for plain `data.frame` with `weights = NULL` | Code relying on `".weight"` as the default column name will break |
| `weighted_df` output now defaults to `"wts"` instead of preserving the input `weight_col` name | Code relying on the input column name being preserved by default will break |

**Mitigation:** Package is pre-CRAN (`0.1.1.9000`), no external users yet.

---

## II. Argument Specification

### New argument: `wt_name`

| Property | Value |
|----------|-------|
| Name | `wt_name` |
| Type | `character(1)` |
| Default | `"wts"` |
| Position in signature | After `weights`, before method/control arguments |
| Scope | `data.frame` and `weighted_df` inputs only; ignored for survey objects |

### Updated signatures

```r
calibrate(data, variables, population, weights = NULL, wt_name = "wts",
          method = "linear", type = "prop", control = list())

rake(data, margins, weights = NULL, wt_name = "wts", type = "prop",
     method = "anesrake", cap = NULL, control = list())

poststratify(data, strata, population, weights = NULL, wt_name = "wts",
             type = "prop")

adjust_nonresponse(data, response_status, weights = NULL, wt_name = "wts",
                   by = NULL, method = "weighting-class",
                   control = list(min_cell = 20, max_adjust = 2.0))
```

### `@param` documentation

```
@param wt_name Character scalar. Name of the output weight column in the
  returned `weighted_df`. Default `"wts"`. Ignored when `data` is a survey
  object (`survey_taylor` or `survey_nonprob`).
```

---

## III. Behavior Rules

### Rule 1: `wt_name` controls the output column name

The computed weights are stored in `out_df[[wt_name]]`. The `weighted_df`
attribute `weight_col` is set to `wt_name`.

### Rule 2: Input weight column is preserved when names differ

When `wt_name` differs from the input weight column name (i.e., the column
identified by the `weights` argument or auto-detected from `weighted_df`
attribute), the input column is **preserved as-is** in the output. This lets
users retain their original weights for comparison.

| Input type | `weights` | `wt_name` | Input col | Output cols |
|-----------|-----------|-----------|-----------|-------------|
| Plain `data.frame` | `NULL` | `"wts"` (default) | *(none — uniform created internally)* | `"wts"` (calibrated) |
| Plain `data.frame` | `base_wt` | `"wts"` (default) | `base_wt` | `base_wt` (original, preserved) + `"wts"` (calibrated) |
| Plain `data.frame` | `base_wt` | `"base_wt"` | `base_wt` | `base_wt` (overwritten with calibrated) |
| `weighted_df` | `NULL` | `"wts"` (default) | whatever `weight_col` attr is | old col (preserved if name ≠ `"wts"`) + `"wts"` (calibrated) |
| `weighted_df` | `NULL` | same as input `weight_col` | `weight_col` attr | col overwritten with calibrated |
| Survey object | *(any)* | *(ignored)* | `@variables$weights` | `@variables$weights` (unchanged behavior) |

### Rule 3: Chaining works naturally

When chaining `calibrate() |> rake()`, both default to `wt_name = "wts"`.
The second function reads from `"wts"` (via `weighted_df` attribute) and
writes back to `"wts"`, overwriting with the newly calibrated values. This
is the expected behavior for sequential calibration steps.

### Rule 4: `wt_name` is ignored for survey objects

When `data` is a `survey_taylor` or `survey_nonprob`, the `wt_name` argument
is silently ignored. Survey objects manage their own weight column via
`@variables$weights`, and `.update_survey_weights()` handles that path.

No warning is emitted — this is analogous to how many R functions silently
ignore inapplicable arguments.

### Rule 5: Default column name change

The default output column name changes from `".weight"` to `"wts"` for plain
`data.frame` inputs with `weights = NULL`. The `.get_weight_col_name()`
fallback (line 100 of `utils.R`) is updated from `".weight"` to `"wts"` to
stay consistent, though this path is now only used for the internal weight
extraction logic, not for naming the output.

---

## IV. Validation

### `wt_name` validation

Performed early in each function, after `weights_quo` capture and before any
weight extraction.

| Condition | Error class | Message |
|-----------|-------------|---------|
| `wt_name` is not a character scalar (`!is.character(wt_name) \|\| length(wt_name) != 1`) | `surveywts_error_wt_name_not_scalar` | `{.arg wt_name} must be a single character string.` |
| `wt_name` is `NA_character_` or `""` | `surveywts_error_wt_name_empty` | `{.arg wt_name} must be a non-empty, non-NA string.` |

No validation against existing column names — if `wt_name` matches an existing
data column, that column is overwritten. This is intentional (see Rule 2: when
`wt_name` equals the input weight column, it overwrites; otherwise, the input
column is preserved and `wt_name` creates a new column).

### Shared validation helper

Since all four functions perform the same validation, extract a shared helper:

```r
#' @keywords internal
#' @noRd
.validate_wt_name <- function(wt_name) {
  if (!is.character(wt_name) || length(wt_name) != 1) {
    cli::cli_abort(
      c("x" = "{.arg wt_name} must be a single character string.",
        "i" = "Got {.cls {class(wt_name)}} of length {length(wt_name)}."),
      class = "surveywts_error_wt_name_not_scalar"
    )
  }
  if (is.na(wt_name) || wt_name == "") {
    cli::cli_abort(
      c("x" = "{.arg wt_name} must be a non-empty, non-NA string."),
      class = "surveywts_error_wt_name_empty"
    )
  }
  invisible(TRUE)
}
```

Lives in `R/utils.R` (used by 4 functions → shared helper per `code-style.md`).

---

## V. Implementation Changes by File

### `R/utils.R`

1. Add `.validate_wt_name()` helper (Section IV)
2. Update `.get_weight_col_name()` default from `".weight"` to `"wts"` (line 100)

### `R/calibrate.R`

1. Add `wt_name = "wts"` to function signature (after `weights`)
2. Add `.validate_wt_name(wt_name)` call early in function body
3. In the `data.frame` output branch: change `out_df[[weight_col]]` to
   `out_df[[wt_name]]`
4. Pass `wt_name` to `.make_weighted_df()` instead of `weight_col`
5. Update roxygen `@param` documentation

### `R/rake.R`

Same pattern as `calibrate.R`.

### `R/poststratify.R`

Same pattern as `calibrate.R`.

### `R/nonresponse.R`

Same pattern as `calibrate.R`.

### `plans/error-messages.md`

Add two new error classes to the "Common" section:

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_wt_name_not_scalar` | `.validate_wt_name()` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `.validate_wt_name()` | `wt_name` is `NA` or `""` |

---

## VI. Weighting History

History entries should record the output weight column name. The `weight_col`
field in history entries (already present) should use `wt_name` rather than
the input weight column name when they differ. This ensures the history
accurately reflects which column holds the weights at each step.

---

## VII. Testing

### New test categories per function

Each of the four function test files gets:

**1. `wt_name` happy path — default**

```r
test_that("calibrate() names output weight column 'wts' by default", {
  result <- calibrate(df, variables = ..., population = ...)
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true("wts" %in% names(result))
})
```

**2. `wt_name` happy path — custom name**

```r
test_that("calibrate() uses custom wt_name for output column", {
  result <- calibrate(df, variables = ..., population = ..., wt_name = "cal_wt")
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "cal_wt")
  expect_true("cal_wt" %in% names(result))
})
```

**3. `wt_name` preserves input weight column when names differ**

```r
test_that("calibrate() preserves input weight column when wt_name differs", {
  result <- calibrate(df, variables = ..., population = ...,
                      weights = base_weight, wt_name = "cal_wt")
  test_invariants(result)
  expect_true("base_weight" %in% names(result))  # original preserved
  expect_true("cal_wt" %in% names(result))       # new column added
  expect_identical(attr(result, "weight_col"), "cal_wt")
})
```

**4. `wt_name` overwrites when same as input column**

```r
test_that("calibrate() overwrites input column when wt_name matches", {
  result <- calibrate(df, variables = ..., population = ...,
                      weights = base_weight, wt_name = "base_weight")
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "base_weight")
  # Only one weight column, values are calibrated (not original)
})
```

**5. `wt_name` ignored for survey objects**

```r
test_that("calibrate() ignores wt_name for survey_nonprob input", {
  result <- calibrate(snp, variables = ..., population = ..., wt_name = "ignored")
  # Output weight column name comes from @variables$weights, not wt_name
  expect_identical(result@variables$weights, snp@variables$weights)
})
```

**6. `wt_name` validation errors**

```r
test_that("calibrate() rejects non-character wt_name", {
  expect_error(
    calibrate(df, ..., wt_name = 42),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(error = TRUE, calibrate(df, ..., wt_name = 42))
})

test_that("calibrate() rejects empty wt_name", {
  expect_error(
    calibrate(df, ..., wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(error = TRUE, calibrate(df, ..., wt_name = ""))
})
```

**7. Chaining preserves wt_name**

```r
test_that("chaining calibrate() |> rake() uses 'wts' throughout", {
  result <- calibrate(df, ...) |> rake(margins = ...)
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "wts")
})
```

### Snapshot updates

Existing snapshots referencing `".weight"` as the output column name will need
updating to `"wts"`. Run `testthat::snapshot_review()` after implementation.

### Coverage

All new code paths must be covered. The `.validate_wt_name()` helper is tested
indirectly via the four calling functions (per `testing-standards.md` — default
indirect testing for private functions).

---

## VIII. Quality Gates

- [ ] All four functions accept `wt_name` with correct default
- [ ] `wt_name` validation errors fire for bad input
- [ ] Default output column is `"wts"` for `data.frame` input
- [ ] Custom `wt_name` produces correctly named output column
- [ ] Input weight column preserved when `wt_name` differs
- [ ] `wt_name` silently ignored for survey object inputs
- [ ] Chaining works: `calibrate() |> rake()` both use `"wts"` by default
- [ ] Weighting history records the correct output column name
- [ ] `plans/error-messages.md` updated with new error classes
- [ ] All existing tests updated for `".weight"` → `"wts"` default change
- [ ] `devtools::check()` passes: 0 errors, 0 warnings
- [ ] 98%+ line coverage maintained
