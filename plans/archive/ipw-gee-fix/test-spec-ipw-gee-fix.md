# Test-spec — ipw-gee-fix

## Reference oracle

None. No external package provides a ground-truth GEE propensity solver
against which surveywts output can be numerically compared. Correctness is
verified through the calibration constraint (AC-2): at convergence, the
weighted NPS covariate totals must match the reference totals to within 1e-4.

## Datasets

**Inline synthetic datasets only.** The regression scenario (AC-1) requires
reference weights with `sum(d) ~ 1e6` to reproduce the exact population-scale
condition that previously caused divergence. No existing package dataset
provides this combination of large-scale reference weights with a small NPS.
The scale-divergence scenario is the functional definition of the bug; inline
construction is the only correct approach for these tests.

All datasets for this spec are constructed inline within their respective
`test_that()` blocks. `set.seed()` is called at the top of each block that
uses random data.

**Shared construction pattern — population-scale scenario:**

```r
set.seed(42L)
ref_df <- data.frame(
  age_group   = sample(c("18-34", "35-54", "55+"), 500L, replace = TRUE,
                       prob = c(0.3, 0.4, 0.3)),
  sex         = sample(c("M", "F"), 500L, replace = TRUE),
  base_weight = rep(2000, 500L),
  stringsAsFactors = FALSE
)
# ref_big is a survey_taylor built from ref_df
nps_df <- data.frame(
  age_group = sample(c("18-34", "35-54", "55+"), 100L, replace = TRUE),
  sex       = sample(c("M", "F"), 100L, replace = TRUE),
  stringsAsFactors = FALSE
)
```

`ref_big` is constructed inline in each test using `surveycore::survey_taylor()`
or an equivalent survey constructor with `variables = list(weights = "base_weight")`.

**Shared construction pattern — unit-scale scenario:**

```r
set.seed(7L)
ref_unit_df <- data.frame(
  age_group   = sample(c("18-34", "35-54", "55+"), 500L, replace = TRUE,
                       prob = c(0.3, 0.4, 0.3)),
  sex         = sample(c("M", "F"), 500L, replace = TRUE),
  base_weight = 1,
  stringsAsFactors = FALSE
)
nps_unit_df <- data.frame(
  age_group = sample(c("18-34", "35-54", "55+"), 200L, replace = TRUE),
  sex       = sample(c("M", "F"), 200L, replace = TRUE),
  stringsAsFactors = FALSE
)
```

## Per-function test plan

### `ipw()` — GEE path

---

#### Happy paths

| Scenario | Dataset | Expected | Tolerance |
|---|---|---|---|
| GEE + population-scale reference (AC-1 primary bug fix) | `nps_df` (100 rows), `ref_big` (`sum(d)=1,000,000`) | `expect_no_error()`; result is a `survey_nonprob` | — |
| GEE + unit-scale reference (existing behavior preserved) | `nps_unit_df` (200 rows), `ref_unit` (`base_weight=1`) | `expect_no_error()`; result is a `survey_nonprob` | — |

For every test that constructs a `survey_nonprob`, `test_invariants(obj)` is
the first assertion.

**AC-1 test block structure:**

```r
test_that("ipw() GEE converges with population-scale reference weights (AC-1)", {
  set.seed(42L)
  # ... construct nps_df, ref_big inline ...
  result <- ipw(nps_df, ref_big, selection = ~age_group + sex,
                estimating_eq = "gee")
  test_invariants(result)
  expect_true(inherits(result, "survey_nonprob"))
})
```

**Unit-scale regression test block structure:**

```r
test_that("ipw() GEE converges with unit-scale reference weights", {
  set.seed(7L)
  # ... construct nps_unit_df, ref_unit inline ...
  result <- ipw(nps_unit_df, ref_unit, selection = ~age_group + sex,
                estimating_eq = "gee", adjust_reference = FALSE)
  test_invariants(result)
  expect_true(inherits(result, "survey_nonprob"))
})
```

---

#### Calibration constraint (AC-2)

| Scenario | Dataset | Expected | Tolerance |
|---|---|---|---|
| GEE calibration constraint at convergence | `nps_df` (100 rows), `ref_big` (`sum(d)=1,000,000`) | weighted NPS covariate totals match reference totals | 1e-4 |

The calibration constraint is verified by computing the weighted NPS covariate
column sums and comparing them to the reference design-weighted column sums.
The model matrix is constructed from the same `selection` formula used in the
`ipw()` call.

**AC-2 test block structure:**

```r
test_that("ipw() GEE satisfies calibration constraint at convergence (AC-2)", {
  set.seed(42L)
  # ... construct nps_df, ref_big inline ...
  result <- ipw(nps_df, ref_big, selection = ~age_group + sex,
                estimating_eq = "gee")
  test_invariants(result)
  # Retrieve weights
  w <- result@data[["ipw_weight"]]
  # Construct model matrices from the returned data (same selection formula)
  sel <- ~age_group + sex
  X_nps <- model.matrix(sel, data = result@data)
  X_ref <- model.matrix(sel, data = ref_big@data)
  d_ref <- ref_big@data[["base_weight"]]
  nps_totals <- colSums(X_nps * w)
  ref_totals  <- colSums(X_ref * d_ref)
  expect_equal(nps_totals, ref_totals, tolerance = 1e-4)
})
```

---

#### MLE regression (AC-3)

| Scenario | Dataset | Expected | Tolerance |
|---|---|---|---|
| MLE + unit-scale reference (existing behavior unchanged) | `nps_unit_df` (200 rows), `ref_unit` (`base_weight=1`) | no error; returns `survey_nonprob` | — |
| MLE + population-scale reference | `nps_df` (100 rows), `ref_big` (`sum(d)=1,000,000`) | no error; returns `survey_nonprob` | — |

Both MLE tests verify that the existing MLE logic is unaffected. The
population-scale MLE test confirms that the fix did not inadvertently break the
MLE path.

```r
test_that("ipw() MLE converges with unit-scale reference weights (AC-3)", {
  set.seed(7L)
  # ... construct nps_unit_df, ref_unit inline ...
  result <- ipw(nps_unit_df, ref_unit, selection = ~age_group + sex,
                estimating_eq = "mle", adjust_reference = FALSE)
  test_invariants(result)
  expect_true(inherits(result, "survey_nonprob"))
})

test_that("ipw() MLE converges with population-scale reference weights (AC-3)", {
  set.seed(42L)
  # ... construct nps_df, ref_big inline ...
  result <- ipw(nps_df, ref_big, selection = ~age_group + sex,
                estimating_eq = "mle")
  test_invariants(result)
  expect_true(inherits(result, "survey_nonprob"))
})
```

---

#### Warning paths

| Warning class | Trigger | Pattern |
|---|---|---|
| `surveywts_warning_propensity_nr_no_convergence` | GEE + population-scale reference + `maxit = 1L` (AC-4) | `expect_warning(class = "surveywts_warning_propensity_nr_no_convergence")` |

**AC-4 test block structure:**

```r
test_that("ipw() GEE issues non-convergence warning with maxit = 1L (AC-4)", {
  set.seed(42L)
  # ... construct nps_df, ref_big inline ...
  expect_warning(
    result <- ipw(nps_df, ref_big, selection = ~age_group + sex,
                  estimating_eq = "gee", maxit = 1L),
    class = "surveywts_warning_propensity_nr_no_convergence"
  )
  test_invariants(result)
})
```

This test verifies that with `maxit = 1L` the GEE path issues the
non-convergence warning (not the degenerate-scores error) and still returns a
`survey_nonprob` object from the last iterate.

---

#### Error paths (guards still intact)

| Error class | Trigger | Pattern |
|---|---|---|
| `surveywts_error_propensity_level_not_in_reference` | NPS covariate level absent from reference (AC-5) | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_propensity_scores_degenerate` | Extreme imbalance causing post-fit score saturation (Rule 15 still fires) | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |

**AC-5 test block — level-not-in-reference guard:**

```r
test_that("ipw() GEE still errors when NPS level is absent from reference (AC-5)", {
  set.seed(99L)
  # NPS has a level ("65+") that does not exist in the reference
  nps_missing_level <- data.frame(
    age_group = c("18-34", "35-54", "65+"),
    sex       = c("M", "F", "M"),
    stringsAsFactors = FALSE
  )
  ref_no_65plus_df <- data.frame(
    age_group   = c("18-34", "35-54", "55+"),
    sex         = c("M", "F", "M"),
    base_weight = rep(2000, 3L),
    stringsAsFactors = FALSE
  )
  # ... construct ref_no_65plus as survey_taylor from ref_no_65plus_df ...
  expect_error(
    ipw(nps_missing_level, ref_no_65plus, selection = ~age_group + sex,
        estimating_eq = "gee"),
    class = "surveywts_error_propensity_level_not_in_reference"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps_missing_level, ref_no_65plus, selection = ~age_group + sex,
        estimating_eq = "gee")
  )
})
```

**Degenerate-scores guard — Rule 15 still fires:**

Construct a scenario where the post-fit scores are at the float boundary even
after nleqslv returns. This requires extreme imbalance in a covariate that
is present in both samples but with near-zero probability in the reference.

```r
test_that("ipw() GEE degenerate-scores error still fires via Rule 15", {
  set.seed(55L)
  # All NPS in one level ("18-34"); reference has effectively zero mass
  # for that level — achieved by having many reference rows with weight 2000
  # in "55+" and only 1 reference row with weight 1 in "18-34".
  nps_extreme <- data.frame(
    age_group = rep("18-34", 50L),
    stringsAsFactors = FALSE
  )
  ref_extreme_df <- data.frame(
    age_group   = c("18-34", rep("55+", 499L)),
    base_weight = c(1, rep(2000, 499L)),
    stringsAsFactors = FALSE
  )
  # ... construct ref_extreme as survey_taylor ...
  expect_error(
    ipw(nps_extreme, ref_extreme, selection = ~age_group,
        estimating_eq = "gee"),
    class = "surveywts_error_propensity_scores_degenerate"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps_extreme, ref_extreme, selection = ~age_group,
        estimating_eq = "gee")
  )
})
```

The extreme-imbalance scenario may also trigger `surveywts_warning_propensity_nr_no_convergence`
before the degenerate error fires (nleqslv may declare non-convergence at the
same iterate where scores saturate). Always wrap the `expect_snapshot()` call in
`suppressWarnings()` to prevent the warning from appearing in the error snapshot.
The `expect_error(class = ...)` assertion does not need wrapping — it captures
the error class independently of any warnings.

**Warning snapshot for AC-4 (message-text regression guard):**

In addition to the `expect_warning(class = ...)` assertion, add a warning
snapshot to catch regressions in the warning message text. The snapshot verifies
that the updated "convergence diagnostic" label appears:

```r
test_that("ipw() GEE non-convergence warning snapshot (AC-4)", {
  set.seed(42L)
  # ... construct nps_df, ref_big inline ...
  expect_snapshot(
    warning = TRUE,
    ipw(nps_df, ref_big, selection = ~age_group + sex,
        estimating_eq = "gee", maxit = 1L)
  )
})
```

---

**termcd >= 4 (singular Jacobian in nleqslv) — documented-untestable:**

The spec documents that `termcd >= 4` (singular/ill-conditioned Jacobian
detected by nleqslv) produces `converged = FALSE` and
`surveywts_warning_propensity_nr_no_convergence`. This termcd value is not
directly testable in isolation for the following reasons:

1. The Jacobian `−X^T diag((1−π)/π) X` becomes singular only when `X` is
   rank-deficient or propensities are at the float boundary (0 or 1).
2. The `surveywts_error_propensity_level_not_in_reference` guard (Rule 8 in
   `ipw()`) catches the most common rank-deficiency cause (NPS level absent
   from reference) before nleqslv is called.
3. The degenerate-scores post-fit check (Rule 15) catches the float-boundary
   case after nleqslv returns.
4. The warning-issuance code path (`converged = FALSE` → warning) is verified
   by AC-4 with `termcd = 3`. The same code path handles all `termcd >= 3`.

No separate test for `termcd >= 4` is required.

---

#### Invariants

`test_invariants(obj)` is the first assertion in every `test_that()` block that
constructs a `survey_nonprob` object. This covers all happy-path and warning-path
tests. Error-path tests do not construct a successful result and therefore do not
call `test_invariants()`.

---

#### History entry correctness

| Scenario | Expected |
|---|---|
| GEE + population-scale reference | History entry has `operation = "ipw"`, `estimating_eq = "gee"` |
| GEE + population-scale reference | History entry `propensity_scores` is a numeric vector of length `nrow(nps_df)` |

```r
test_that("ipw() GEE history entry records estimating_eq = 'gee'", {
  set.seed(42L)
  # ... construct nps_df, ref_big inline ...
  result <- ipw(nps_df, ref_big, selection = ~age_group + sex,
                estimating_eq = "gee")
  test_invariants(result)
  history <- result@metadata@weighting_history
  entry <- history[[length(history)]]
  expect_identical(entry$operation, "ipw")
  expect_identical(entry$estimating_eq, "gee")
  expect_true(is.numeric(entry$propensity_scores))
  expect_equal(length(entry$propensity_scores), nrow(result@data))
})
```

---

#### nleqslv dependency

| Scenario | Expected |
|---|---|
| `nleqslv` is installed (package is in `Imports`) | All GEE tests run without `skip_if_not_installed` |

Because `nleqslv` is in `Imports` (not `Suggests`), it is always available
when the package is installed. Do not add `skip_if_not_installed("nleqslv")`
to any block.

---

## Tolerances

| Estimand | Tolerance | Justification |
|---|---|---|
| Calibration constraint — `nps_totals ≈ ref_totals` (AC-2) | 1e-4 | Population-scale weights mean nleqslv convergence tolerance (`epsilon = 1e-8`) maps to an absolute tolerance of ~`1e-4` when multiplied by the reference weight scale (~`1e6`); per acceptance criteria AC-2 |
| Weight computations (ESS, CV, conservation) | 1e-10 | Standard package tolerance |
| History entry numeric fields | exact match via `expect_identical()` where discrete; `expect_equal()` with 1e-10 where numeric | Standard |

Deviation from default tolerances: the 1e-4 calibration constraint tolerance
is specific to AC-2 and is justified by the population-scale scenario. All
other assertions use standard tolerances.

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] devtools::document() — NAMESPACE/man/ unchanged after run
- [ ] devtools::test() — all tests pass
- [ ] devtools::run_examples() — all @examples run clean
- [ ] R CMD check --as-cran — 0 errors, 0 warnings, notes reviewed
- [ ] pkgdown::build_site() — SKIPPED (pre-pkgdown scope)
- [ ] covr::package_coverage() — ≥ 95% (target 98%)
