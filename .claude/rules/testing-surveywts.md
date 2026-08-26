# surveywts Testing: Package-Specific Standards

**Version:** 1.1 — Calibration complete
**Status:** Stable for Calibration — extends `testing-standards.md`. Read
that document first; this file covers only what is specific to surveywts.

## Quick Reference

| Decision | Choice |
|----------|--------|
| Invariant checker | `test_invariants(obj)` — defined in `helper-test-data.R` |
| Synthetic data generator | `make_surveywts_data(n, seed, include_nonrespondents)` |
| Layer 1 errors (S7 validators) | `class=` only — no snapshot |
| Layer 3 errors (constructors/functions) | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Weight computation tolerance | `1e-10` |
| Numerical correctness vs reference package | `1e-8` |

## File mapping

| Source file(s) | Test file |
|---|---|
| `R/weighted-df-dplyr.R` + constructors | `tests/testthat/test-00-classes.R` |
| `R/calibrate.R` | `tests/testthat/test-02-calibrate.R` |
| `R/rake.R` | `tests/testthat/test-03-rake.R` |
| `R/poststratify.R` | `tests/testthat/test-04-poststratify.R` |
| `R/adjust_nonresponse.R`, `R/redistribute_weights.R`, `R/nonresponse-utils.R` | `tests/testthat/test-05-nonresponse.R` |
| `R/effective_sample_size.R`, `R/weight_variability.R`, `R/summarize_weights.R`, `R/diagnostics-utils.R` | `tests/testthat/test-06-diagnostics.R` |
| `R/calibrate_to_survey.R`, `R/calibrate_to_estimate.R` | `tests/testthat/test-sample-calibration.R` |
| `R/trim_weights.R`, `R/rescale_weights.R`, `R/weight-utils.R` | `tests/testthat/test-weight-utils.R` |
| `R/create_bootstrap_weights.R`, and other `create_*_weights.R`, `R/replicate-utils.R` | `tests/testthat/test-replicate-weights.R` |
| `R/create_replicate_weights.R`, `R/as_taylor_design.R` | `tests/testthat/test-replicate-dispatch.R` |
| `R/methods-print.R` | `tests/testthat/test-replicate-print.R` |
| `R/ipw.R` | `tests/testthat/test-nonprob-ipw.R` |
| `R/jackknife-dagjk-utils.R` | `tests/testthat/test-nps-jackknife.R` |
| `R/utils.R` | (tested indirectly via all test files) |

## `test_invariants()` — required in every constructor test

Every `test_that()` block that creates a `weighted_df` or `survey_nonprob`
object calls `test_invariants(obj)` as its **first** assertion. It is
defined in `tests/testthat/helper-test-data.R` and checks, per class: for
`weighted_df` — the weight column name is a character scalar, that column
exists in the data and is numeric, and `weighting_history` is a list; for
`survey_nonprob` — `@variables$weights` is a character scalar naming a
numeric column in `@data` with all values strictly positive.

## S7 error testing layers

- **Layer 1 — S7 class validators**: structural invariants; messages not
  CLI-formatted. Test with `class=` only, no snapshot.
- **Layer 3 — Constructor/function input validation**: user-facing
  `cli::cli_abort()` errors. Test with the dual pattern (`class=` +
  snapshot).

## Synthetic data generator

`make_surveywts_data(n = 500, seed = 42, include_nonrespondents = FALSE)`,
defined in `tests/testthat/helper-test-data.R`. Returns a plain
`data.frame`:

| Column | Type | Values |
|--------|------|--------|
| `id` | `integer` | `1L..nL` |
| `age_group` | `character` | `"18-34"`, `"35-54"`, `"55+"` (unequal probabilities) |
| `sex` | `character` | `"M"`, `"F"` |
| `education` | `character` | `"<HS"`, `"HS"`, `"College"`, `"Graduate"` |
| `region` | `character` | `"Northeast"`, `"South"`, `"Midwest"`, `"West"` |
| `base_weight` | `numeric` | Positive, log-normally distributed |
| `responded` | `integer` | `0`/`1`; ≥ 20% nonrespondents; only if `include_nonrespondents = TRUE` |

Groups are NOT equal-sized (unequal `prob =`); `base_weight` is
`exp(rnorm(n, 0, 0.4))`. Edge case inputs (0-row, NA columns, negative
weights) are constructed inline in each test, never via generator
parameters.

## Numerical tolerances

| Estimand | Tolerance |
|----------|-----------|
| Weight computations (ESS, CV, conservation) | `1e-10` |
| Numerical correctness vs `survey` package | `1e-8` |

Reference package comparisons use `skip_if_not_installed("survey")` inside
the relevant `test_that()` block, never at file level.

---
Worked examples (`test_invariants()` body, both error-layer examples,
test-file section templates): `.claude/references/testing-detail.md`
§surveywts test templates. Read it when writing a new surveywts test file.
