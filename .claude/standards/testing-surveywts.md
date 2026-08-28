# surveywts Testing: Package-Specific Standards

Extends `testing-standards.md`. Read that document first; this file covers
only what is specific to surveywts.

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Invariant checker | `test_invariants(obj)` — defined in `helper-test-data.R` |
| Synthetic data generator | `make_surveywts_data(n, seed, include_nonrespondents)` |
| Layer 1 errors (S7 validators) | `class=` only — no snapshot; classes are `surveycore_error_*` |
| Layer 3 errors (constructors/functions) | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Weight computation tolerance | `1e-10` |
| Numerical correctness vs reference package | `1e-8` |

---

## File Mapping

| Source file(s) | Test file |
|---|---|
| `R/calibrate.R` | `tests/testthat/test-02-calibrate.R` |
| `R/calibrate_rake.R` | `tests/testthat/test-03-rake.R` |
| `R/poststratify.R` | `tests/testthat/test-04-poststratify.R` |
| `R/adjust_nonresponse.R`, `R/redistribute_weights.R`, `R/nonresponse-utils.R` | `tests/testthat/test-05-nonresponse.R` |
| `R/effective_sample_size.R`, `R/weight_variability.R`, `R/summarize_weights.R`, `R/diagnostics-utils.R` | `tests/testthat/test-06-diagnostics.R` |
| `R/calibrate_linear.R` | `tests/testthat/test-calibrate-linear.R` |
| `R/calibrate_logit.R` | `tests/testthat/test-calibrate-logit.R` |
| `R/calibrate-utils.R` | `tests/testthat/test-calibrate-utils-nr.R` |
| `R/calibrate_to_survey.R`, `R/calibrate_to_estimate.R` | `tests/testthat/test-sample-calibration.R` |
| `R/trim_weights.R`, `R/rescale_weights.R`, `R/weight-utils.R` | `tests/testthat/test-weight-utils.R` |
| `R/create_bootstrap_weights.R`, and other `create_*_weights.R`, `R/replicate-utils.R` | `tests/testthat/test-replicate-weights.R` |
| `R/create_replicate_weights.R`, `R/as_taylor_design.R` | `tests/testthat/test-replicate-dispatch.R` |
| `R/methods-print.R` | `tests/testthat/test-replicate-print.R` |
| `R/ipw.R` | `tests/testthat/test-nonprob-ipw.R` |
| `R/jackknife-dagjk-utils.R` | `tests/testthat/test-nps-jackknife.R` |
| `R/replicate-utils.R` — quasi-randomization bootstrap | `tests/testthat/test-08-nps-bootstrap.R` |
| `R/data.R` and the bundled datasets | `tests/testthat/test-datasets.R` |
| `R/surveywts-package.R` | `tests/testthat/test-package.R` |
| `R/utils.R` | (tested indirectly via all test files) |

---

## `test_invariants()` — required in every constructor test

Every `test_that()` block that creates a `survey_nonprob`, `survey_taylor`, or
`survey_replicate` object must call `test_invariants(obj)` as its **first**
assertion.

`test_invariants()` is defined in `tests/testthat/helper-test-data.R`. That
file is the real source of truth for the code; read it there.

Three branches, and an object can match more than one — every branch that
matches runs. The `survey_nonprob` and `survey_taylor` branches assert
`all(w >= 0) && any(w > 0)`, which matches what the surveycore validator
enforces. Only the `survey_replicate` branch asserts strict positivity, via
`all(obj@data[[wt_col]] > 0)`.

The `survey_nonprob` branch guards with `exists("survey_nonprob")` rather
than testing `surveycore::survey_nonprob` directly. surveywts does not
define or export `survey_nonprob`, so that guard is what keeps the branch
from erroring when the bare name does not resolve.

---

## S7 Error Testing Layers

**Layer 1 — S7 class validators** (structural invariants enforced by S7).
These validators live in surveycore, so their classes are `surveycore_error_*`
and surveywts does not own the message text. Test with `class=` only — no
snapshot.

```r
test_that("survey_nonprob validator rejects negative weights", {
  df <- make_surveywts_data(seed = 1)
  df$base_weight[1] <- -1

  expect_error(
    surveycore::survey_nonprob(df, variables = list(weights = "base_weight")),
    class = "surveycore_error_weights_negative"
  )
})
```

**Layer 3 — Constructor/function input validation** (user-facing errors from
`cli::cli_abort()`). Test with the dual pattern.

```r
test_that("calibrate() rejects negative weights", {
  df <- make_surveywts_data(seed = 1)
  df$base_weight[1] <- -1
  design  <- surveycore::as_survey(df, weights = base_weight)
  targets <- list(age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25))

  expect_error(
    calibrate(design, targets = targets, type = "prop"),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(design, targets = targets, type = "prop")
  )
})
```

A plain `data.frame` cannot reach either layer. `.check_input_class()` rejects
it first with `surveywts_error_not_survey_base`, so every function test must
build a survey object.

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

### Survey object fixtures

`make_surveywts_data()` returns a plain `data.frame`, which no weighting
function accepts. `helper-test-data.R` therefore also defines the survey
objects the tests actually pass in. Use these rather than building a design
inline:

| Fixture | Returns |
|---------|---------|
| `make_taylor_design()` | `survey_taylor` — clustered and stratified, with PSU IDs |
| `make_paired_design()` | `survey_taylor` — exactly 2 PSUs per stratum, for BRR |
| `make_replicate_design()` | `survey_replicate` — bootstrap replicates from a `survey_taylor` |
| `make_nps_reference()`, `make_nps_ref()` | `survey_taylor` — probability-sample reference for `ipw()` |
| `make_nps_level_a()`, `make_nps_level_b()` | `survey_nonprob` — post-`ipw()`, post-`calibrate_rake()` |
| `make_nonprob_replicate_design()` | `survey_nonprob` with replicate weights |
| `make_nonprob_no_repweights()` | `survey_nonprob` without replicate weights, for error paths |
| `make_dagjk_datasets()` | Named list of DAGJK inputs A–F plus `ref` |
| `make_gss_taylor()`, `make_npors_taylor()`, `make_ns_nonprob()` | Survey objects over the bundled datasets |
| `.pin_ts()` | The same object with every history timestamp pinned, for stable snapshots |

`.pin_ts()` is required before any snapshot that renders weighting history —
`.make_history_entry()` stamps `Sys.time()`, which would otherwise change on
every run.

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

### Print method test file (`test-replicate-print.R`)
```
# 1. survey_nonprob — print snapshot
# 2. survey_replicate — print snapshot
# 3. Weighting history rendering — pin timestamps with .pin_ts() first
```

### Calibration / nonresponse function test files (`test-02-*.R` through `test-05-*.R`)
```
# 1. Happy paths (one block per input class: survey_taylor,
#    survey_nonprob, survey_replicate)
# 2. Numerical correctness (skip_if_not_installed inside block)
# 3. Standard error paths SE-1 through SE-7
# 4. Function-specific error paths (one block per error class)
# 5. Edge cases
# 6. History / metadata correctness
```

### Diagnostics test file (`test-06-diagnostics.R`)
```
# 1. Correctness vs hand calculation
# 2. Weight auto-detection (survey_taylor, survey_nonprob, survey_replicate)
# 3. summarize_weights() — by = NULL and by = grouping
# 4. Error paths
```
