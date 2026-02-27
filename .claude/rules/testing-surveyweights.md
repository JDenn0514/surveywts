# surveyweights Testing: Package-Specific Standards

**Version:** 0.1 — stub, to be expanded as the Phase 0 API is designed
**Status:** In progress — fill in as constructors and functions are specified

Extends `testing-standards.md`. Read that document first; this file covers
only what is specific to surveyweights.

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Invariant checks | `test_invariants(obj)` — definition TBD after Phase 0 spec |
| Layer 1 errors (S7 validators) | `class=` only — no snapshot |
| Layer 3 errors (constructors/functions) | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Synthetic data | `make_weights_data(seed = N)` in `helper-test-data.R` — definition TBD |
| Numerical tolerance | TBD after Phase 0 spec |

---

## File Mapping

> **TODO:** Fill in source-to-test file mapping after Phase 0 implementation
> plan is written. One test file per source file.

---

## `test_invariants()` — required in every constructor test

> **TODO:** Define `test_invariants()` in `tests/testthat/helper-test-data.R`
> after Phase 0 spec. It should assert all formal invariants of the package's
> core S7 objects.

Every `test_that()` block that creates a surveyweights object via a constructor
must call `test_invariants(obj)` as its **first** assertion.

---

## S7 Error Testing Layers

surveyweights has two validation layers with different testing requirements:

**Layer 1 — S7 class validators** (structural invariants enforced by S7 system):
Messages are not CLI-formatted. Test with `class=` only — no snapshot.

```r
test_that("my_class validator rejects missing required property", {
  expect_error(
    my_class(...),
    class = "surveyweights_error_condition"
  )
})
```

**Layer 3 — Constructor/function input validation** (user-facing errors from
`cli::cli_abort()`). Test with the dual pattern.

```r
test_that("my_fn() rejects negative weights", {
  df <- data.frame(x = 1:5, w = c(1, -1, 1, 1, 1))

  expect_error(
    my_fn(df, weights = w),
    class = "surveyweights_error_weights_nonpositive"
  )
  expect_snapshot(error = TRUE, my_fn(df, weights = w))
})
```

---

## Synthetic Data Generator

> **TODO:** Define `make_weights_data()` in `tests/testthat/helper-test-data.R`
> after Phase 0 spec. It should:
> - Accept a `seed =` argument for reproducibility
> - Return a plain data.frame with realistic variation
> - Match the input requirements of the package's main constructors

---

## Numerical Tolerances

> **TODO:** Specify tolerances after Phase 0 functions are defined.
> Follow this pattern from surveycore as a reference:
>
> | Estimand | Tolerance |
> |----------|-----------|
> | Point estimates | `1e-10` |
> | SE / variance | `1e-8` |

---

## Test File Section Templates

### Constructor test files
```
# 1. Happy paths (one block per constructor variant)
# 2. Error paths (one block per error-messages.md row)
# 3. Edge cases (0-row data, all-NA, single-row, negative weights)
# 4. Roundtrip / property preservation
```

### Algorithm/computation test files
```
# Block 1: Correctness — compare to reference (skip_if_not_installed)
# Block 2: Edge cases — degenerate inputs
# Block 3: Error paths — all error classes covered
```
