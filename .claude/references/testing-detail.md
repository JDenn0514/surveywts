# Testing Standards — Worked Examples and Templates

Detail moved out of `.claude/rules/testing-standards.md` and
`.claude/rules/testing-surveywts.md`. The rules live there; this file shows
how to apply them. Read this when writing new test files and the correct
pattern is not obvious from the rule tables.

---

## Test structure examples

### `test_that()` descriptions

```r
# Correct — specific, present-tense assertion
test_that("my_fn() rejects data frames with 0 rows", { ... })
test_that("my_fn() assigns a default weight when none is given", { ... })

# Wrong — vague category
test_that("my_fn() validates input", { ... })
test_that("weights work", { ... })
```

### No `describe()` blocks

```r
# Correct
test_that("my_class stores the x property", { ... })
test_that("my_class stores the y property", { ... })

# Wrong
describe("my_class properties", {
  test_that("stores x", { ... })
})
```

### `# nocov` marking

```r
# nocov start
# Defensive: this branch is unreachable via any public function.
# Tested implicitly by all constructor tests.
if (is.null(x@data)) {
  cli::cli_abort("Internal error: @data is NULL", class = "mypkg_error_internal")
}
# nocov end
```

---

## The three mandatory test categories

**1. Happy path** — normal inputs, expected behavior:

```r
test_that("my_fn() creates the right class for standard input", {
  result <- my_fn(data, weights = w)
  expect_true(inherits(result, "my_class"))
})
```

**2. Error paths** — every typed error class from the package's error table:

```r
test_that("my_fn() rejects non-data-frame input", {
  expect_snapshot(error = TRUE, my_fn(list(x = 1)))
  expect_error(my_fn(list(x = 1)), class = "mypkg_error_not_data_frame")
})
```

**3. Edge cases** — boundary conditions, NAs, empty inputs, single-row inputs:

```r
test_that("my_fn() warns for single-row data", {
  single_row <- data.frame(x = 1, w = 1)
  expect_warning(
    my_fn(single_row, weights = w),
    class = "mypkg_warning_single_row"
  )
})
```

---

## Private function testing

```r
# Indirect (preferred) — .validate_weights() tested via the public API
test_that("my_fn() rejects non-positive weights", {
  df <- data.frame(x = 1:5, w = c(1, 0, 1, 1, 1))
  expect_error(my_fn(df, weights = w), class = "mypkg_error_weights_nonpositive")
})

# Direct (only when necessary)
test_that(".validate_fpc() rejects NA in fpc column [direct]", {
  df <- data.frame(y = 1, fpc = NA_real_)
  expect_error(.validate_fpc(df, "fpc"), class = "mypkg_error_fpc_na")
})
```

---

## Dual pattern for constructor errors

```r
test_that("calibrate() rejects weight column with zero values", {
  df <- data.frame(x = 1:5, w = c(1, 0, 1, 1, 1))

  # 1. Typed class check — verifies the right error class is thrown
  expect_error(
    calibrate(df, weights = w),
    class = "surveywts_error_weights_nonpositive"
  )

  # 2. Snapshot — verifies the CLI message text has not changed
  expect_snapshot(error = TRUE, calibrate(df, weights = w))
})
```

Layer 1 (S7 class validators) uses `class=` only — no snapshot — because
those messages are not CLI-formatted.

---

## Warning capture pattern

```r
test_that("my_fn() warns and still returns an object for single-row data", {
  d1 <- data.frame(x = 1, w = 1)

  expect_warning(
    result <- my_fn(d1, weights = w),
    class = "mypkg_warning_single_row"
  )

  expect_true(inherits(result, "my_class"))
})
```

Do **not** use `withCallingHandlers()` or `tryCatch()` in tests.

---

## Test data examples

### Generator usage

```r
df <- make_surveywts_data(n = 200, seed = 123)
obj <- calibrate_rake(df, targets = age_targets, weights = base_weight)
test_invariants(obj)
```

### Edge case data: inline, never via generator parameters

```r
# Correct — inline, self-documenting
test_that("my_fn() rejects data with 0 rows", {
  empty_df <- data.frame(x = numeric(0), w = numeric(0))
  expect_error(my_fn(empty_df, weights = w), class = "mypkg_error_empty_data")
})

# Wrong
df <- make_surveywts_data(edge = "empty", seed = 1)  # don't do this
```

### `skip_if_not_installed()` — block-level

```r
# Correct — block-level
test_that("estimates match reference package [numerical]", {
  skip_if_not_installed("ref_pkg")
  # ...
})

test_that("constructor creates correct class", {
  # runs even without ref_pkg installed
  d <- my_fn(data, weights = w)
  expect_true(inherits(d, "my_class"))
})

# Wrong — skips the entire file
skip_if_not_installed("ref_pkg")  # at top of file
```

### Snapshot updating

To update snapshots after an intentional message change:

```r
testthat::snapshot_review()  # review and approve each diff individually
```

Never run `testthat::snapshot_accept()` blindly. Each snapshot change must
be reviewed. Snapshots live in `tests/testthat/_snaps/` and are committed.

---

## surveywts test templates

### `test_invariants()` — full body

Defined in `tests/testthat/helper-test-data.R`:

```r
test_invariants <- function(obj) {
  if (inherits(obj, "weighted_df")) {
    wt_col <- attr(obj, "weight_col")
    testthat::expect_true(is.character(wt_col) && length(wt_col) == 1)
    testthat::expect_true(wt_col %in% names(obj))
    testthat::expect_true(is.numeric(obj[[wt_col]]))
    testthat::expect_true(is.list(attr(obj, "weighting_history")))
  }
  if (exists("survey_nonprob") &&
        S7::S7_inherits(obj, survey_nonprob)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(obj@variables$weights %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[obj@variables$weights]]))
    testthat::expect_true(all(obj@data[[obj@variables$weights]] > 0))
  }
}
```

The `exists("survey_nonprob")` guard lets `test_invariants()` load before
`survey_nonprob` is defined.

### S7 error testing layers — full examples

**Layer 1 — S7 class validators:**

```r
test_that("survey_nonprob validator rejects non-positive weights", {
  expect_error(
    survey_nonprob(...),
    class = "surveywts_error_weights_nonpositive"
  )
})
```

**Layer 3 — Constructor/function input validation:**

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

### Test file section templates

**Class test file (`test-00-classes.R`)**
```
# 1. weighted_df — class vector, attributes, print snapshot
# 2. weighted_df — dplyr_reconstruct preserves weight col → weighted_df
# 3. weighted_df — dplyr_reconstruct drops weight col → plain tibble + warning
# 4. survey_nonprob — print snapshot
# 5. survey_nonprob — S7 validator errors (class= only, no snapshot)
```

**Calibration / nonresponse function test files (`test-02-*.R` through `test-05-*.R`)**
```
# 1. Happy paths (one block per input class: data.frame, weighted_df,
#    survey_taylor, survey_nonprob)
# 2. Numerical correctness (skip_if_not_installed inside block)
# 3. Standard error paths SE-1 through SE-7
# 4. Function-specific error paths (one block per error class)
# 5. Edge cases
# 6. History / metadata correctness
```

**Diagnostics test file (`test-06-diagnostics.R`)**
```
# 1. Correctness vs hand calculation
# 2. Weight auto-detection (weighted_df, survey_nonprob, survey_taylor)
# 3. summarize_weights() — by = NULL and by = grouping
# 4. Error paths
```
