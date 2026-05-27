# test-spec-ipw-extensions.md

**Version:** 0.2
**Date:** 2026-05-26
**Status:** METHODS_REVIEWED — Stage 2 PASS; proceed to Stage 3 spec review
**ID:** ipw-extensions

---

## Reference Oracle

| Test type | Oracle |
|-----------|--------|
| GEE covariate balance | Analytical: `sum(w * x) = sum(d * x)` at convergence (exact up to floating-point tolerance) |
| Valliant (2020) Eq. (1) adjustment | Analytical: `adjust_factor = (n_hat - n_nps) / n_hat` |
| Estimator label | Spec: `estimator == "ipw2"` (not `"ht"`) |
| Propensity score range | Analytical: all scores in (0, 1) exclusive |
| nps_fraction | Analytical: `nrow(data) / sum(ref_weights_after_na_deletion)` |
| New error/warning classes | Spec: class names in `plans/error-messages.md` |

---

## Datasets

| Dataset | Used for |
|---------|----------|
| `make_surveywts_data(n = 500, seed = 42)` + synthetic `survey_taylor` reference | All unit-level tests for new behavior; reproducible and avoids bundled dataset loading |
| `ns_wave1_ipw` + `gss_ipw_ref` | Smoke test: new args with realistic data; GEE convergence check |
| Inline synthetic data | All edge cases (large NPS fraction, numeric range extrapolation, absent factor levels) |

**Constructing a test `survey_taylor` from `make_surveywts_data()`:**
```r
ref_df <- make_surveywts_data(n = 2000, seed = 99)
ref_df$design_weight <- 1.0
ref_design <- surveycore::as_survey(ref_df, weights = design_weight)
nps_df <- make_surveywts_data(n = 500, seed = 42)
```

---

## Tolerances

| Estimand | Tolerance |
|----------|-----------|
| GEE covariate balance (`sum(w*x) - sum(d*x)`) | 1e-6 |
| Propensity scores in (0, 1) | `.Machine$double.eps` boundary |
| `nps_fraction` computation | 1e-10 |
| `adjust_factor` computation | 1e-10 |

---

## Per-Gap Test Plan

### C-1: `estimator = "ipw2"` in history entry

**Test block:** "ipw() history entry records estimator = 'ipw2'"

- Happy path: run `ipw()` with any valid inputs
- Assert: `history[[1]]$estimator == "ipw2"`
- Assert: `history[[1]]$estimator != "ht"` (explicit regression check)
- Use `test_invariants()` first if the result is a `survey_nonprob`

### C-2, H-5: Variance documentation (doc-only)

No code tests for doc-only changes. The roxygen text is verified by inspection
and snapshot tests of the rendered `?ipw` help page (if pkgdown is active).
The test plan does not include mechanical tests for text content.

### C-3: `adjust_reference` argument — reference weight adjustment

**Test block 1:** "adjust_reference = TRUE warns and adjusts when nps_fraction > 0.05"

Setup (inline):
```r
ref_df <- data.frame(
  age_group = sample(c("18-34", "35-54", "55+"), 2000, replace = TRUE),
  sex = sample(c("M", "F"), 2000, replace = TRUE),
  design_weight = rep(1.0, 2000),   # N_hat = 2000
  stringsAsFactors = FALSE
)
ref_design <- surveycore::as_survey(ref_df, weights = design_weight)
# NPS: 200 rows → nps_fraction = 200 / 2000 = 0.10 (> 0.05)
nps_df <- data.frame(
  age_group = sample(c("18-34", "35-54", "55+"), 200, replace = TRUE),
  sex = sample(c("M", "F"), 200, replace = TRUE)
)
```

Assertions:
- `expect_warning(result <- ipw(nps_df, ref_design, selection = ~age_group + sex), class = "surveywts_warning_ipw_reference_weight_adjusted")`
- `test_invariants(result)`
- `expect_snapshot(expect_warning(ipw(nps_df, ref_design, selection = ~age_group + sex), class = "surveywts_warning_ipw_reference_weight_adjusted"))`
- `hist <- result@metadata@weighting_history[[1]]`
- `expect_equal(hist$nps_fraction, 200 / 2000, tolerance = 1e-10)`
- `expect_equal(hist$adjust_factor, 1 - 200/2000, tolerance = 1e-10)`
- `expect_true(hist$adjust_reference)`

**Test block 2:** "adjust_reference = FALSE warns but does not adjust when nps_fraction > 0.05"

Same setup as Test block 1 but call with `adjust_reference = FALSE`.

Assertions:
- `expect_warning(result <- ipw(nps_df, ref_design, selection = ~age_group + sex, adjust_reference = FALSE), class = "surveywts_warning_ipw_reference_unadjusted_large_nps")`
- `test_invariants(result)`
- `expect_snapshot(expect_warning(ipw(nps_df, ref_design, selection = ~age_group + sex, adjust_reference = FALSE), class = "surveywts_warning_ipw_reference_unadjusted_large_nps"))`
- `hist <- result@metadata@weighting_history[[1]]`
- `hist$adjust_factor == 1.0` (no adjustment applied)
- `hist$adjust_reference == FALSE`

**Test block 3:** "no warning or adjustment when nps_fraction <= 0.05"

Setup: NPS = 50 rows, reference N_hat = 2000 → fraction = 0.025 (< 0.05).

Assertions:
- `expect_no_warning(result <- ipw(nps_small, ref_design, selection = ~age_group + sex))`
  (only checking for the adjustment warnings; other warnings may still fire)
- `test_invariants(result)`
- `hist <- result@metadata@weighting_history[[1]]`
- `hist$adjust_factor == 1.0`
- `hist$nps_fraction < 0.05` (approximately 0.025)

**Test block 4:** "adjust_reference validation — non-logical rejected"

```r
expect_error(
  ipw(nps_df, ref_design, selection = ~age_group + sex, adjust_reference = "yes"),
  class = "surveywts_error_adjust_reference_invalid"
)
expect_snapshot(
  error = TRUE,
  ipw(nps_df, ref_design, selection = ~age_group + sex, adjust_reference = "yes")
)
```

**Test block 5:** "adjust_reference = NA rejected"

```r
expect_error(
  ipw(nps_df, ref_design, selection = ~age_group + sex, adjust_reference = NA),
  class = "surveywts_error_adjust_reference_invalid"
)
```

### C-4, H-1, H-2, H-3, H-4, M-2, M-3, M-5, L-1, L-2, L-3: Documentation-only gaps

No code tests. Verified by reading the rendered `?ipw` documentation after
`devtools::document()` and comparing against the text specified in
`spec-ipw-extensions.md §IV.H`.

### H-6: `estimating_eq = "gee"`

**Test block 1:** "estimating_eq = 'gee' converges on balanced data"

Use synthetic unit-weight data (`make_surveywts_data(n = 200, seed = 1)` + `make_nps_reference(n = 1000, seed = 99)` with all reference design weights set to 1 via `survey_taylor(data = ref_df, variables = list(weights = "base_weight"))`).

Rationale: The bundled `gss_ipw_ref` has population-scaled design weights (N_hat ≈ 260M vs n_NPS ≈ 200), giving N_hat/n_NPS ≈ 40,000. GEE Newton-Raphson updates score from gamma=0 and the first step has magnitude |delta| ≈ log(40000) which saturates all NPS scores on iteration 2 before any balance can be achieved. This is a real numerical limitation of GEE with population-scaled data, not a code bug. Unit-weight data (N_hat/n_NPS ≈ 5) allows convergence and fully exercises the GEE code path and balance guarantee.

```r
nps_df  <- make_surveywts_data(n = 200L, seed = 1L)
ref_df  <- make_nps_reference(n = 1000L, seed = 99L)
ref_df$base_weight <- 1
ref_design <- surveycore::survey_taylor(
  data = ref_df,
  variables = list(weights = "base_weight")
)
result <- ipw(nps_df, ref_design, selection = ~age_group + sex, estimating_eq = "gee")
test_invariants(result)
```

Assertions:
- `test_invariants(result)` passes
- `result@metadata@weighting_history[[1]]$estimating_eq == "gee"`
- No error thrown

**Test block 2:** "GEE covariate balance guarantee at convergence (adjust_reference = FALSE)"

Setup: construct `nps_df` and `ref_design` with `make_surveywts_data()`.

`adjust_reference = FALSE` is set explicitly to isolate the GEE balance property
from reference weight adjustment. With the fixture below (`nps_fraction = 0.25 > 0.05`),
the default `adjust_reference = TRUE` would scale `ref_weights_for_fit` by 0.75 before
the engine runs, causing convergence against adjusted rather than original reference totals.
Test block 2b covers that interaction separately.

```r
result_gee <- ipw(
  nps_df, ref_design,
  selection = ~age_group + sex,
  estimating_eq = "gee",
  adjust_reference = FALSE
)
w <- result_gee@data[["ipw_weight"]]
# Weighted NPS covariate totals
x_nps_age_34 <- as.integer(nps_df$age_group == "18-34")  # indicator for one level
x_nps_sex_m  <- as.integer(nps_df$sex == "M")
# Reference covariate totals (using original design weights)
d_ref <- ref_design@data[[ref_design@variables$weights]]
x_ref_age_34 <- as.integer(ref_design@data$age_group == "18-34")
x_ref_sex_m  <- as.integer(ref_design@data$sex == "M")
```

Assertions:
- `expect_equal(sum(w * x_nps_age_34), sum(d_ref * x_ref_age_34), tolerance = 1e-6)`
- `expect_equal(sum(w * x_nps_sex_m),  sum(d_ref * x_ref_sex_m),  tolerance = 1e-6)`

Note: the balance guarantee holds for the model matrix columns (after
treatment coding). Use the indicator form above rather than comparing means
to avoid scale ambiguity.

**Test block 2b:** "GEE balance holds against Valliant-adjusted reference totals when nps_fraction > 0.05"

Same `nps_df` / `ref_design` fixture (n=500 NPS, n=2000 reference → `nps_fraction = 0.25`,
`adjust_factor = 0.75`). Verifies that with the default `adjust_reference = TRUE` the
GEE engine converges against the adjusted totals `adjust_factor × sum(d_ref × x)`.

```r
result_gee_adj <- suppressWarnings(
  ipw(
    nps_df, ref_design,
    selection = ~age_group + sex,
    estimating_eq = "gee",
    adjust_reference = TRUE
  )
)
w_adj <- result_gee_adj@data[["ipw_weight"]]
d_ref <- ref_design@data[[ref_design@variables$weights]]
n_hat <- sum(d_ref)
nps_fraction <- nrow(nps_df) / n_hat    # 0.25
adjust_factor <- 1 - nps_fraction       # 0.75
x_nps_age_34 <- as.integer(nps_df$age_group == "18-34")
x_nps_sex_m  <- as.integer(nps_df$sex == "M")
x_ref_age_34 <- as.integer(ref_design@data$age_group == "18-34")
x_ref_sex_m  <- as.integer(ref_design@data$sex == "M")
```

Assertions:
- `expect_equal(sum(w_adj * x_nps_age_34), adjust_factor * sum(d_ref * x_ref_age_34), tolerance = 1e-6)`
- `expect_equal(sum(w_adj * x_nps_sex_m),  adjust_factor * sum(d_ref * x_ref_sex_m),  tolerance = 1e-6)`

**Test block 3:** "estimating_eq = 'gee' recorded in history entry"

```r
result_gee <- ipw(nps_df, ref_design, selection = ~age_group + sex, estimating_eq = "gee")
hist <- result_gee@metadata@weighting_history[[1]]
expect_identical(hist$estimating_eq, "gee")
```

And for MLE (confirming the default):
```r
result_mle <- ipw(nps_df, ref_design, selection = ~age_group + sex)
expect_identical(result_mle@metadata@weighting_history[[1]]$estimating_eq, "mle")
```

**Test block 4:** "estimating_eq = 'gee' and = 'mle' produce different weights"

```r
result_gee <- ipw(nps_df, ref_design, selection = ~age_group + sex, estimating_eq = "gee")
result_mle <- ipw(nps_df, ref_design, selection = ~age_group + sex, estimating_eq = "mle")
w_gee <- result_gee@data[["ipw_weight"]]
w_mle <- result_mle@data[["ipw_weight"]]
expect_false(isTRUE(all.equal(w_gee, w_mle)))
```

**Test block 5:** "GEE degeneration triggers surveywts_error_propensity_scores_degenerate"

Setup: force NPS/reference imbalance extreme enough that GEE NPS scores → 0.

```r
nps_extreme <- data.frame(
  age_group = rep("18-34", 10),
  sex = rep("M", 10)
)
ref_extreme_df <- data.frame(
  age_group = rep("55+", 100),
  sex = rep("F", 100),
  design_weight = rep(1000, 100)  # massive weight → huge N_hat; all in opposite cell
)
ref_extreme <- surveycore::as_survey(ref_extreme_df, weights = design_weight)
expect_error(
  ipw(nps_extreme, ref_extreme, selection = ~age_group + sex, estimating_eq = "gee"),
  class = "surveywts_error_propensity_scores_degenerate"
)
```

**Test block 6:** "estimating_eq = 'gee' + missing_method = 'separate' — no runtime warning"

Resolved in Stage 2 methodology review (Issue 1, Option A): no runtime warning
is emitted. The limitation is documented in `@param estimating_eq` and
`@param missing_method`. No new warning class is defined.

Test: call `ipw()` with `estimating_eq = "gee"` and `missing_method = "separate"`;
assert that no `surveywts_warning_ipw_gee_calibration_partial` class warning
is thrown (verifies Option A was implemented, not Option B).

```r
nps_with_na <- nps_df
nps_with_na$sex[1:5] <- NA
expect_no_warning(
  ipw(nps_with_na, ref_design,
      selection = ~age_group + sex,
      estimating_eq = "gee",
      missing_method = "separate"),
  class = "surveywts_warning_ipw_gee_calibration_partial"
)
```

HOLD: **CLOSED** — resolved 2026-05-26, Stage 2 methodology review.

### M-1: Common support — new checks

**Test block 1:** "numeric covariate range extrapolation warns"

```r
nps_df_wide <- make_surveywts_data(n = 100, seed = 42)
# Force NPS to have numeric age beyond reference range (if age is numeric)
# For make_surveywts_data which uses age_group (character), add a synthetic numeric:
nps_df_wide$score <- runif(100, 0, 100)
ref_df_narrow <- ref_df  # reference score column present but with narrower range
ref_df_narrow$score <- runif(2000, 20, 80)
ref_design_narrow <- surveycore::as_survey(ref_df_narrow, weights = design_weight)

expect_warning(
  ipw(nps_df_wide, ref_design_narrow,
      selection = ~age_group + sex + score,
      missing_method = "omit"),
  class = "surveywts_warning_ipw_covariate_range_extrapolation"
)
expect_snapshot(
  expect_warning(
    ipw(nps_df_wide, ref_design_narrow, selection = ~age_group + sex + score,
        missing_method = "omit"),
    class = "surveywts_warning_ipw_covariate_range_extrapolation"
  )
)
```

**Test block 2:** "numeric covariate within reference range — no range warning"

```r
nps_df_narrow <- nps_df_wide
nps_df_narrow$score <- runif(100, 25, 75)  # within reference range [20, 80]
expect_no_warning(
  ipw(nps_df_narrow, ref_design_narrow, selection = ~age_group + sex + score,
      missing_method = "omit"),
  class = "surveywts_warning_ipw_covariate_range_extrapolation"
)
```

**Test block 3:** "reference factor levels absent from NPS warns"

```r
# Reference has "Rural" in region; NPS has only "Urban" and "Suburban"
nps_no_rural <- data.frame(
  region = sample(c("Urban", "Suburban"), 100, replace = TRUE),
  stringsAsFactors = FALSE
)
ref_with_rural_df <- data.frame(
  region = sample(c("Urban", "Suburban", "Rural"), 2000,
                  replace = TRUE, prob = c(0.4, 0.4, 0.2)),
  design_weight = rep(1.0, 2000),
  stringsAsFactors = FALSE
)
ref_with_rural <- surveycore::as_survey(ref_with_rural_df, weights = design_weight)
expect_warning(
  ipw(nps_no_rural, ref_with_rural, selection = ~region),
  class = "surveywts_warning_ipw_reference_levels_absent_from_nps"
)
expect_snapshot(
  expect_warning(
    ipw(nps_no_rural, ref_with_rural, selection = ~region),
    class = "surveywts_warning_ipw_reference_levels_absent_from_nps"
  )
)
```

**Test block 4:** "NPS levels absent from reference still errors (existing behavior unchanged)"

The existing `surveywts_error_propensity_level_not_in_reference` error for NPS
levels absent from the reference must still trigger. Verify this is not broken
by the new checks:

```r
nps_extra_level <- data.frame(
  region = c("Urban", "Suburban", "Rural", "Exurban"),
  stringsAsFactors = FALSE
)
ref_no_exurban <- data.frame(
  region = c("Urban", "Suburban", "Rural"),
  design_weight = rep(1.0, 3),
  stringsAsFactors = FALSE
)
ref_no_exurban_design <- surveycore::as_survey(ref_no_exurban, weights = design_weight)
expect_error(
  ipw(nps_extra_level, ref_no_exurban_design, selection = ~region),
  class = "surveywts_error_propensity_level_not_in_reference"
)
```

**Test block 5:** "both warning types can fire simultaneously"

NPS has both a numeric variable outside reference range AND reference has a
factor level absent from the NPS. Both warnings should be emitted.

Setup: `both_issue_nps` has `score` range [0, 10] (wider than reference) and
`age_group` missing the "55+" level present in the reference. `both_issue_ref`
has `score` range [2, 8] (narrower) and an "55+" `age_group` level absent from
the NPS.

```r
both_issue_nps <- data.frame(
  age_group = c("18-34", "18-34", "35-54", "35-54", "18-34"),
  score     = c(0, 3, 5, 7, 10),   # range [0, 10] — wider than reference
  stringsAsFactors = FALSE
)
both_issue_ref_df <- data.frame(
  age_group     = c("18-34", "35-54", "55+", "55+"),   # "55+" absent from NPS
  score         = c(2, 4, 6, 8),                        # range [2, 8] — narrower than NPS
  design_weight = c(100, 100, 100, 100),
  stringsAsFactors = FALSE
)
both_issue_ref <- surveycore::as_survey(both_issue_ref_df, weights = design_weight)

expect_warning(
  ipw(both_issue_nps, both_issue_ref, selection = ~age_group + score),
  class = "surveywts_warning_ipw_covariate_range_extrapolation"
)
expect_warning(
  ipw(both_issue_nps, both_issue_ref, selection = ~age_group + score),
  class = "surveywts_warning_ipw_reference_levels_absent_from_nps"
)
```

### M-4: `nps_fraction` in history

**Test block:** "nps_fraction is correctly recorded in history entry"

```r
result <- ipw(nps_df, ref_design, selection = ~age_group + sex)
test_invariants(result)
hist <- result@metadata@weighting_history[[1]]
n_hat <- sum(ref_design@data[[ref_design@variables$weights]])
expected_fraction <- nrow(nps_df) / n_hat
expect_equal(hist$nps_fraction, expected_fraction, tolerance = 1e-10)
expect_true(is.numeric(hist$nps_fraction))
expect_true(length(hist$nps_fraction) == 1L)
```

Note: `n_hat` must be computed from the reference **after** NA deletion. If
there are no NAs in the reference selection variables, this equals
`sum(ref_design@data$design_weight)` directly.

### M-6: `propensity_scores` in history

**Test block 1:** "propensity_scores are in history entry as numeric vector"

```r
result <- ipw(nps_df, ref_design, selection = ~age_group + sex)
test_invariants(result)
hist <- result@metadata@weighting_history[[1]]
expect_true(is.numeric(hist$propensity_scores))
expect_true(length(hist$propensity_scores) == nrow(nps_df))
```

**Test block 2:** "all propensity_scores are in (0, 1)"

```r
scores <- hist$propensity_scores
eps <- .Machine$double.eps
expect_true(all(scores > eps))
expect_true(all(scores < 1 - eps))
```

**Test block 3:** "propensity_scores length equals n_nps after omit"

When `missing_method = "omit"` and some rows are dropped:

```r
nps_with_na <- nps_df
nps_with_na$sex[1:10] <- NA
suppressWarnings(
  result_omit <- ipw(nps_with_na, ref_design, selection = ~age_group + sex,
                     missing_method = "omit")
)
test_invariants(result_omit)
hist_omit <- result_omit@metadata@weighting_history[[1]]
expect_equal(length(hist_omit$propensity_scores), hist_omit$n_nps)
```

**Test block 4:** "propensity_scores matches 1/weights before trimming"

Since `w = 1 / propensity_scores`, the scores are recoverable from the weights:

```r
result <- ipw(nps_df, ref_design, selection = ~age_group + sex, trim = FALSE)
test_invariants(result)
hist <- result@metadata@weighting_history[[1]]
weights_from_scores <- 1 / hist$propensity_scores
weights_in_data <- result@data[["ipw_weight"]]
expect_equal(weights_in_data, weights_from_scores, tolerance = 1e-10)
```

### L-4: `population_size` argument

**Test block 1:** "population_size = NULL → population_size_known = FALSE"

```r
result <- ipw(nps_df, ref_design, selection = ~age_group + sex)
test_invariants(result)
hist <- result@metadata@weighting_history[[1]]
expect_false(hist$population_size_known)
```

**Test block 2:** "population_size supplied → population_size_known = TRUE, estimated_population_size = supplied value"

```r
result_known_n <- ipw(nps_df, ref_design, selection = ~age_group + sex,
                      population_size = 50000)
test_invariants(result_known_n)
hist_known <- result_known_n@metadata@weighting_history[[1]]
expect_true(hist_known$population_size_known)
expect_equal(hist_known$estimated_population_size, 50000, tolerance = 1e-10)
```

**Test block 3:** "population_size does not change the weights"

```r
result_null <- ipw(nps_df, ref_design, selection = ~age_group + sex)
result_50k  <- ipw(nps_df, ref_design, selection = ~age_group + sex,
                   population_size = 50000)
test_invariants(result_null)
test_invariants(result_50k)
expect_equal(
  result_null@data[["ipw_weight"]],
  result_50k@data[["ipw_weight"]],
  tolerance = 1e-10
)
```

**Test block 4:** "population_size = 0 or negative → error"

```r
expect_error(
  ipw(nps_df, ref_design, selection = ~age_group + sex, population_size = 0),
  class = "surveywts_error_population_size_invalid"
)
expect_snapshot(
  error = TRUE,
  ipw(nps_df, ref_design, selection = ~age_group + sex, population_size = 0)
)
expect_error(
  ipw(nps_df, ref_design, selection = ~age_group + sex, population_size = -100),
  class = "surveywts_error_population_size_invalid"
)
```

**Test block 5:** "population_size = non-numeric → error"

```r
expect_error(
  ipw(nps_df, ref_design, selection = ~age_group + sex, population_size = "50000"),
  class = "surveywts_error_population_size_invalid"
)
expect_snapshot(
  error = TRUE,
  ipw(nps_df, ref_design, selection = ~age_group + sex, population_size = "50000")
)
```

**Test block 6:** "population_size = Inf → error"

```r
expect_error(
  ipw(nps_df, ref_design, selection = ~age_group + sex, population_size = Inf),
  class = "surveywts_error_population_size_invalid"
)
```

---

## Invariants

All test blocks that construct a `survey_nonprob` object must call
`test_invariants(result)` as the first assertion (from `helper-test-data.R`).

All new history entry fields must be present in the returned list and of the
correct type:

| Field | Expected type check |
|-------|---------------------|
| `estimating_eq` | `is.character(x) && length(x) == 1L` |
| `estimator` | `identical(x, "ipw2")` |
| `adjust_reference` | `is.logical(x) && length(x) == 1L` |
| `nps_fraction` | `is.numeric(x) && length(x) == 1L && x > 0` |
| `adjust_factor` | `is.numeric(x) && length(x) == 1L && x > 0 && x <= 1` |
| `population_size_known` | `is.logical(x) && length(x) == 1L` |
| `propensity_scores` | `is.numeric(x) && length(x) >= 1L` |

---

## Profile Gates

Before closing this feature branch:

```r
devtools::test(filter = "08-ipw")   # all test blocks above pass
devtools::check()                   # 0 errors, 0 warnings
covr::package_coverage()            # ≥ 98% for R/nonprob-ipw.R
devtools::document()                # no warnings; man/ipw.Rd updated
testthat::snapshot_review()         # approve all new snapshots individually
```

---

## HOLDs

| Hold | Description | Resolution path |
|------|-------------|-----------------|
| H-6 + M-3 interaction | ~~Does GEE + `missing_method = "separate"` warrant a runtime warning?~~ | **CLOSED 2026-05-26**: Option A (doc-only). No runtime warning. Test block 6 for H-6 updated accordingly. |
