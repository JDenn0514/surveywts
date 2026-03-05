# surveywts Testing: Package-Specific Standards

**Version:** 1.0 — Phase 0 complete
**Status:** Stable for Phase 0

Extends `testing-standards.md`. Read that document first; this file covers
only what is specific to surveywts.

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Invariant checker | `test_invariants(obj)` — defined in `helper-test-data.R` |
| Synthetic data generator | `make_surveywts_data(n, seed, include_nonrespondents)` |
| Layer 1 errors (S7 validators) | `class=` only — no snapshot |
| Layer 3 errors (constructors/functions) | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Weight computation tolerance | `1e-10` |
| Numerical correctness vs reference package | `1e-8` |

---

## File Mapping

| Source file | Test file |
|---|---|
| `R/classes.R` + `R/constructors.R` | `tests/testthat/test-00-classes.R` |
| `R/calibrate.R` | `tests/testthat/test-02-calibrate.R` |
| `R/rake.R` | `tests/testthat/test-03-rake.R` |
| `R/poststratify.R` | `tests/testthat/test-04-poststratify.R` |
| `R/nonresponse.R` | `tests/testthat/test-05-nonresponse.R` |
| `R/diagnostics.R` | `tests/testthat/test-06-diagnostics.R` |
| `R/utils.R` | (tested indirectly via PRs 5–9; no direct test file) |

---

## `test_invariants()` — required in every constructor test

Every `test_that()` block that creates a `weighted_df` or `survey_calibrated`
object must call `test_invariants(obj)` as its **first** assertion.

Definition (from `tests/testthat/helper-test-data.R`):

```r
test_invariants <- function(obj) {
  if (inherits(obj, "weighted_df")) {
    wt_col <- attr(obj, "weight_col")
    testthat::expect_true(is.character(wt_col) && length(wt_col) == 1)
    testthat::expect_true(wt_col %in% names(obj))
    testthat::expect_true(is.numeric(obj[[wt_col]]))
    testthat::expect_true(is.list(attr(obj, "weighting_history")))
  }
  if (exists("survey_calibrated") &&
        S7::S7_inherits(obj, survey_calibrated)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(obj@variables$weights %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[obj@variables$weights]]))
    testthat::expect_true(all(obj@data[[obj@variables$weights]] > 0))
  }
}
```

The `exists("survey_calibrated")` guard allows `test_invariants()` to load
from `helper-test-data.R` before PR 3 lands (when `survey_calibrated` is not
yet defined).

---

## S7 Error Testing Layers

**Layer 1 — S7 class validators** (structural invariants enforced by S7):
Messages are not CLI-formatted. Test with `class=` only — no snapshot.

```r
test_that("survey_calibrated validator rejects non-positive weights", {
  expect_error(
    survey_calibrated(...),
    class = "surveywts_error_weights_nonpositive"
  )
})
```

**Layer 3 — Constructor/function input validation** (user-facing errors from
`cli::cli_abort()`). Test with the dual pattern.

```r
test_that("calibrate() rejects negative weights", {
  df <- make_surveywts_data(seed = 1)
  df$base_weight[1] <- -1

  expect_error(
    calibrate(df, variables = c(age_group), population = pop,
              weights = base_weight),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group), population = pop,
              weights = base_weight)
  )
})
```

---

## Synthetic Data Generator

`make_surveywts_data()` is defined in `tests/testthat/helper-test-data.R`.

**Signature:**

```r
make_surveywts_data(n = 500, seed = 42, include_nonrespondents = FALSE)
```

**Returns:** A plain `data.frame` with columns:

| Column | Type | Values |
|--------|------|--------|
| `id` | `integer` | `1L..nL` |
| `age_group` | `character` | `"18-34"`, `"35-54"`, `"55+"` (unequal probabilities) |
| `sex` | `character` | `"M"`, `"F"` |
| `education` | `character` | `"<HS"`, `"HS"`, `"College"`, `"Graduate"` |
| `region` | `character` | `"Northeast"`, `"South"`, `"Midwest"`, `"West"` |
| `base_weight` | `numeric` | Positive, log-normally distributed |
| `responded` | `integer` | `0`/`1`; ≥ 20% nonrespondents; only if `include_nonrespondents = TRUE` |

**Rules:**
- Uses `set.seed(seed)` at the top
- Groups are NOT equal-sized — use `prob =` with unequal probabilities
- `base_weight` is log-normally distributed: `exp(rnorm(n, 0, 0.4))`
- When `include_nonrespondents = TRUE`, realistic split with ≥ 20% nonrespondents
- Edge case inputs (0-row, NA columns, negative weights) are constructed inline
  in each test — never via generator parameters

---

## Numerical Tolerances

| Estimand | Tolerance | Example use |
|----------|-----------|-------------|
| Weight computations (ESS, CV, conservation) | `1e-10` | `expect_equal(result, expected, tolerance = 1e-10)` |
| Numerical correctness vs `survey` package | `1e-8` | `expect_equal(sw_result, survey_result, tolerance = 1e-8)` |

Reference package comparisons use `skip_if_not_installed("survey")` **inside**
the relevant `test_that()` block (never at file level).

---

## Test File Section Templates

### Class test file (`test-00-classes.R`)
```
# 1. weighted_df — class vector, attributes, print snapshot
# 2. weighted_df — dplyr_reconstruct preserves weight col → weighted_df
# 3. weighted_df — dplyr_reconstruct drops weight col → plain tibble + warning
# 4. survey_calibrated — print snapshot
# 5. survey_calibrated — S7 validator errors (class= only, no snapshot)
```

### Calibration / nonresponse function test files (`test-02-*.R` through `test-05-*.R`)
```
# 1. Happy paths (one block per input class: data.frame, weighted_df,
#    survey_taylor, survey_calibrated)
# 2. Numerical correctness (skip_if_not_installed inside block)
# 3. Standard error paths SE-1 through SE-7
# 4. Function-specific error paths (one block per error class)
# 5. Edge cases
# 6. History / metadata correctness
```

### Diagnostics test file (`test-06-diagnostics.R`)
```
# 1. Correctness vs hand calculation
# 2. Weight auto-detection (weighted_df, survey_calibrated, survey_taylor)
# 3. summarize_weights() — by = NULL and by = grouping
# 4. Error paths
```
