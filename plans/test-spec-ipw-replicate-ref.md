# Test-spec — ipw-replicate-ref

## Reference oracle

No external reference package is needed for this change. The sole algorithmic
claim is that `survey_replicate` and `survey_taylor` references with identical
main weights and covariates produce numerically identical IPW weights. The
oracle is the existing `survey_taylor` path.

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `make_surveywts_data(n = 200, seed = 1)` | NPS data for all `ipw()` tests |
| `make_nps_reference(n = 1000, seed = 99)` returns `survey_taylor` | Existing Taylor reference fixture |
| Inline `survey_replicate` constructed from `make_nps_reference()@data` | Replicate reference fixture — wraps the same data as the Taylor fixture so weights are oracle-comparable |
| `cps_2023` (package data, now `survey_replicate` after Part B) | Live `survey_replicate` for example validation and happy-path test in `test-datasets.R` |
| `ns_wave1` (package data) | NPS for package data examples |

---

## Per-function test plan

### `ipw()`

#### Happy path — `survey_replicate` reference

| # | Scenario | Dataset | Expected | Notes |
|---|----------|---------|----------|-------|
| H-R1 | `survey_replicate` reference accepted without error | NPS = `make_surveywts_data(seed=1)`, ref = inline `survey_replicate` wrapping `make_nps_reference()@data` | Returns `survey_nonprob`; `test_invariants()` passes | Primary new happy-path test |
| H-R2 | All original NPS columns preserved; weight column present; nrow unchanged | Same as H-R1 | `"ipw_weight"` in `names(result@data)`; all NPS column names present; `nrow(result@data) == nrow(nps)` | |
| H-R3 | All IPW weights strictly positive | Same as H-R1 | `all(result@data$ipw_weight > 0)` | |
| H-R4 | History entry has `operation = "ipw"` and `reference_design` is the original `survey_replicate` object | Same as H-R1 | `entry$operation == "ipw"`; `S7::S7_inherits(entry$reference_design, surveycore::survey_replicate)` | Confirms the replicate object is stored without conversion |
| H-R5 | `survey_replicate` and equivalent `survey_taylor` references with same main weights produce identical IPW weights | Inline pair: same `data.frame`, one wrapped in `survey_taylor`, one in `survey_replicate` (both with identical main weight column) | `expect_equal(weights_replicate, weights_taylor, tolerance = 1e-10)` | Core correctness claim — reference design type is statistically irrelevant for point estimation |

#### Happy path — `survey_taylor` reference regression

| # | Scenario | Expected |
|---|----------|---------|
| H-T1 | `survey_taylor` reference still accepted and returns valid result | `test_invariants()` passes; `S7::S7_inherits(result, surveycore::survey_nonprob)` |

The full existing `survey_taylor` happy-path test suite must continue to pass
without modification. No existing tests need to be changed.

#### Error paths

| # | Error class | Trigger | Test pattern |
|---|-------------|---------|--------------|
| E-1 | `surveywts_error_reference_not_survey_design` | `reference` is a plain `data.frame` | `expect_error(class=...)` + `expect_snapshot(error=TRUE, ...)` |
| E-2 | `surveywts_error_reference_not_survey_design` | `reference` is a `survey_nonprob` object | `expect_error(class=...)` + `expect_snapshot(error=TRUE, ...)` |
| E-3 | `surveywts_error_reference_not_survey_design` | `reference` is `NULL` | `expect_error(class=...)` + `expect_snapshot(error=TRUE, ...)` |
| E-4 | `surveywts_error_reference_not_survey_design` | `reference` is a named list (non-S7) | `expect_error(class=...)` + `expect_snapshot(error=TRUE, ...)` |
| E-5 | `surveywts_error_reference_weights_nonpositive` | `survey_replicate` reference with a zero in its main weight column | `expect_error(class = "surveywts_error_reference_weights_nonpositive")` |

Note for E-1: the existing test `"ipw() errors when reference is a data.frame"` in
`test-nonprob-ipw.R` currently uses `class = "surveywts_error_svydesign_not_taylor"`.
After this change, that test must be updated to use
`class = "surveywts_error_reference_not_survey_design"` AND an updated snapshot.
The snapshot for that test must be regenerated.

Note: `surveywts_error_svydesign_not_taylor` must not appear in any `expect_error()`
call after this change. All references to the old class name in the test file must
be updated.

#### `test-datasets.R` — `acs_wy_2022` / `acs_wy_2022_svy` removal + `cps_2023` addition

Remove all blocks for `acs_wy_2022` and `acs_wy_2022_svy` (lines 18, 29,
244–324 in current file). Replace with `cps_2023` structural tests:

```r
# cps_2023 structural tests -------------------------------------------------

test_that("cps_2023 is a survey_replicate", {
  data(cps_2023)
  expect_true(S7::S7_inherits(cps_2023, surveycore::survey_replicate))
})

test_that("cps_2023 has approximately 10000 rows", {
  data(cps_2023)
  expect_gte(nrow(cps_2023@data), 9000L)
  expect_lte(nrow(cps_2023@data), 11000L)
})

test_that("cps_2023 uses wtfinl as weight column", {
  data(cps_2023)
  expect_identical(cps_2023@variables$weights, "wtfinl")
})

test_that("cps_2023 has 160 SDR replicate weight columns", {
  data(cps_2023)
  expect_length(cps_2023@variables$repweights, 160L)
  expect_true(all(grepl("^repwtp", cps_2023@variables$repweights)))
})

test_that("cps_2023 derived factor columns are factors with expected levels", {
  data(cps_2023)
  expect_true(is.factor(cps_2023@data$sex))
  expect_identical(levels(cps_2023@data$sex), c("Male", "Female"))
  expect_true(is.factor(cps_2023@data$age_f3))
  expect_identical(levels(cps_2023@data$age_f3), c("18-34", "35-54", "55+"))
  expect_true(is.factor(cps_2023@data$race_f4))
})

test_that("cps_2023 can be passed directly to ipw() as reference", {
  data(ns_wave1)
  data(cps_2023)
  result <- ipw(ns_wave1, cps_2023, selection = ~sex + age_f3 + race_f4)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})
```

This last test (happy-path `ipw()` with `cps_2023`) subsumes the old
`"acs_wy_2022_svy cannot be passed to ipw()"` error test that was
converted in Stage 3r — now using `cps_2023` as the live reference.

#### Warning paths (regression — must continue to fire with `survey_replicate` reference)

| # | Warning class | Scenario |
|---|---------------|---------|
| W-1 | `surveywts_warning_ipw_reference_na_omitted` | `survey_replicate` reference with NA in a selection variable |
| W-2 | `surveywts_warning_ipw_reference_weight_adjusted` | `survey_replicate` reference where NPS fraction > 5% of `sum(main_weight)` |
| W-3 | `surveywts_warning_ipw_covariate_range_extrapolation` | `survey_replicate` reference where NPS numeric covariate range exceeds reference range |

These warning paths do not require new tests if the existing tests cover them for
`survey_taylor`. They are listed to confirm the warning logic runs identically
regardless of reference class. If not already covered by existing tests, add at
least W-1 for the `survey_replicate` path.

#### Edge cases

| # | Case | Input | Expected behavior |
|---|------|-------|-------------------|
| EC-1 | `survey_replicate` with BRR zeros in replicate columns, positive main weight | Inline `survey_replicate` with some replicate-weight column values = 0, main weight all positive | Accepted; only main weight checked; passes Behavior Rule 3; weights computed normally |
| EC-2 | `survey_replicate` reference; `wt_name` conflicts with existing column | `wt_name = "base_weight"` where `base_weight` column exists in NPS | Errors with `surveywts_error_wt_name_conflict` (unchanged behavior) |
| EC-3 | `survey_replicate` reference; selection variable absent from reference | Selection variable not in `reference@data` | Errors with `surveywts_error_formula_variable_not_in_reference` |
| EC-4 | `survey_replicate` reference; NPS factor level not in reference | A level of a factor covariate present in NPS but absent from reference | Errors with `surveywts_error_propensity_level_not_in_reference` |
| EC-5 | `survey_replicate` reference; `trim = TRUE` | Standard `survey_replicate` reference with `trim = TRUE` | `test_invariants()` passes; `entry$trim == TRUE`; `entry$n_trimmed >= 0L` |

#### Invariants

`test_invariants(result)` is the first assertion in every test that constructs
a `survey_nonprob` via `ipw()` with a `survey_replicate` reference.

---

## Tolerances

- IPW weights (`survey_replicate` vs `survey_taylor` oracle comparison): `1e-10`
- Deviations: none required

---

## Snapshot management

The existing snapshot for `"ipw() errors when reference is a data.frame"` will
no longer match after the error class rename. The snapshot must be regenerated
via `testthat::snapshot_review()` before the PR is merged. No other existing
snapshots are affected.

New snapshots required:
- E-1: snapshot of `surveywts_error_reference_not_survey_design` when
  `reference` is a `data.frame`
- E-2: snapshot of `surveywts_error_reference_not_survey_design` when
  `reference` is a `survey_nonprob`

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — `NAMESPACE` and `man/` unchanged after run
- [ ] `devtools::test()` — all tests pass, including updated snapshot
- [ ] `devtools::run_examples()` — all `@examples` run clean, including the
      updated `ipw()` example using `cps_2023` directly as a `survey_replicate`
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown scope)
- [ ] `covr::package_coverage()` — >= 95% (target 98%); confirm Behavior
      Rule 2 branch for `survey_replicate` is covered
