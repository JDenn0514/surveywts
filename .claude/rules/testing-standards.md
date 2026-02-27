# Surveyverse Testing Standards

**Version:** 1.1
**Created:** February 2025
**Status:** Decided — applies to all surveyverse packages

For package-specific testing conventions (file mappings, invariant checkers,
data generators, numerical tolerances), see the `testing-{package}.md` rule
in each package's `.claude/rules/` directory.

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Test file granularity | At least 1 file per source file; large source files may split |
| `test_that()` scope | One observable behavior per block |
| Nesting | Flat — no `describe()` blocks |
| Coverage target | 98%+ line coverage; PRs blocked below 95% |
| Test categories | Happy path + error paths + edge cases |
| Private function testing | Default indirect; direct only when gap can't be closed via public API |
| Constructor error testing | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Structural validator errors | `class=` only — no snapshot (messages not CLI-formatted) |
| Snapshot failures | Block PRs; update via `snapshot_review()` before opening |
| Warning capture | `expect_warning()` wrapping call; result from return value |
| Structural assertions | `expect_identical()` |
| Numeric assertions | `expect_equal()` |
| Synthetic test data | Package-specific generator with `seed =`; defined in `helper-*.R` |
| Edge case data | Inline in tests; never add edge case parameters to a data generator |
| `skip_if_not_installed` | Block-level, inside affected `test_that()` blocks |

---

## 1. Test Structure

### Test file granularity
Every source file in `R/` has a corresponding test file in `tests/testthat/`.
One-to-one is the floor — large source files may split into multiple test files
if it improves clarity.

Naming convention: `R/my-thing.R` → `tests/testthat/test-my-thing.R`

### One behavior per `test_that()` block
Each `test_that()` description names one observable behavior. The description
is a present-tense assertion, not a vague category.

```r
# Correct — specific, present-tense assertion
test_that("my_fn() rejects data frames with 0 rows", { ... })
test_that("my_fn() assigns a default weight when none is given", { ... })

# Wrong — vague category
test_that("my_fn() validates input", { ... })
test_that("weights work", { ... })
```

### No `describe()` blocks
Use flat `test_that()` throughout. Do not nest `test_that()` inside
`describe()`. The test file name already provides the grouping context.

```r
# Correct
test_that("my_class stores the x property", { ... })
test_that("my_class stores the y property", { ... })

# Wrong
describe("my_class properties", {
  test_that("stores x", { ... })
})
```

---

## 2. What to Test

### Coverage target
**98%+ line coverage** is the project target. PRs that drop coverage below
**95%** are blocked by CI.

Lines excluded from coverage are marked with `# nocov` and require an
explanatory comment on the preceding line:

```r
# nocov start
# Defensive: this branch is unreachable via any public function.
# Tested implicitly by all constructor tests.
if (is.null(x@data)) {
  cli::cli_abort("Internal error: @data is NULL", class = "mypkg_error_internal")
}
# nocov end
```

Acceptable `# nocov` categories:
- Defensive branches for conditions impossible via public API
- Platform-specific paths (e.g., Windows-only file encoding)
- Explicit non-goals documented in the package specification

Unacceptable `# nocov` use:
- Covering for missing tests — add the test instead
- Error messages that "feel hard to trigger" — find the trigger and test it

### Three mandatory test categories
Every exported function must have tests in all three categories:

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

### Testing private functions
Default to **indirect testing** — exercise private helpers via the public
functions that call them. Only write direct tests for a private function when
coverage cannot be achieved indirectly AND the behavior is material.

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

## 3. Assertions

### Constructor error testing: dual pattern
User-facing input validation errors require two assertions:

```r
test_that("my_fn() rejects weight column with zero values", {
  df <- data.frame(x = 1:5, w = c(1, 0, 1, 1, 1))

  # 1. Typed class check — verifies the right error class is thrown
  expect_error(
    my_fn(df, weights = w),
    class = "mypkg_error_weights_nonpositive"
  )

  # 2. Snapshot — verifies the CLI message text has not changed
  expect_snapshot(error = TRUE, my_fn(df, weights = w))
})
```

Structural/invariant errors (e.g., S7 class validators) use `class=` only —
no snapshot — because those messages are not CLI-formatted. See each package's
testing rule for which validation layers use which pattern.

### Snapshots: blocking and updating
Snapshot failures block PRs. They are not auto-updated — they represent
deliberate decisions about error message text.

To update snapshots after an intentional message change:
```r
testthat::snapshot_review()  # review and approve each diff individually
```

Never run `testthat::snapshot_accept()` blindly. Each snapshot change must
be reviewed.

Snapshots live in `tests/testthat/_snaps/`. They are committed to version
control.

### Warning capture pattern
Use `expect_warning()` wrapping the call. Capture the return value separately
if you need to assert on it:

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

### `expect_identical()` vs `expect_equal()`

| Use `expect_identical()` for... | Use `expect_equal()` for... |
|---------------------------------|-----------------------------|
| Character vectors, names | Floating-point output |
| `NULL` and `NA` values | Numeric computations with tolerance |
| Exact string/integer property values | Any calculated numeric result |
| List structure (keys present/absent) | Weights, proportions, estimates |

---

## 4. Test Data

### Package-specific data generators
Each package defines a synthetic data generator in `tests/testthat/helper-*.R`
for creating realistic test inputs. Use it for all unit tests that need a
domain object. Do not use real datasets in tests that don't need their specific
properties.

The generator must:
- Accept a `seed =` argument for reproducibility
- Return a plain data structure (not yet wrapped in a domain object)
- Produce realistic variation (unequal sizes, varying values, imbalanced groups)

```r
# Usage pattern — create data, then construct the domain object
df <- make_pkg_data(n = 200, seed = 123)
obj <- my_constructor(df, ...)
```

### Real datasets
Use real datasets only for numerical validation tests — comparing package
outputs against a reference implementation. These belong in a dedicated test
file. Never use a real dataset just for convenience when synthetic data works.

### Edge case data: inline
Edge cases requiring specific, atypical values are constructed inline in the
test. Do not add special-case parameters to the data generator.

```r
# Correct — inline, self-documenting
test_that("my_fn() rejects data with 0 rows", {
  empty_df <- data.frame(x = numeric(0), w = numeric(0))
  expect_error(my_fn(empty_df, weights = w), class = "mypkg_error_empty_data")
})

# Wrong
df <- make_pkg_data(edge = "empty", seed = 1)  # don't do this
```

The rule: if the edge case needs exact specific values to trigger, write those
values directly. Data generators produce typical inputs; edge cases are
by definition atypical.

### `skip_if_not_installed()` — block-level, not file-level
Place `skip_if_not_installed()` inside the `test_that()` block that actually
requires the external package. Do not put a file-level skip at the top of a
test file — other blocks in the same file may not need it.

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
