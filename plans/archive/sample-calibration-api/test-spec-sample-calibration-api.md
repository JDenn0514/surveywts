# Test-spec — sample-calibration-api

## Reference oracle

- `svrep::calibrate_to_sample()` (svrep >= 0.6.0) — oracle for
  `calibrate_to_survey()` numerical results
- `svrep::calibrate_to_estimate()` (svrep >= 0.6.0) — oracle for
  `calibrate_to_estimate()` numerical results

Numerical comparisons: call svrep directly with the same inputs and compare
full-sample weights. Tolerance `1e-8`.

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `make_replicate_design(n, seed)` | Standard primary and control designs for calibration tests — see helper definition below |
| `make_surveywts_data(n = 200L, seed = N)` | Raw data for constructing custom replicate designs |
| `survey_taylor_obj` | `survey_taylor` object used as `reference_design` in provenance tests — see construction recipe below |
| `survey::apiclus1` | Primary design for `@examples` (cluster sample of California schools) |
| `survey::apisrs` | Control survey for `calibrate_to_survey()` example |
| Inline-constructed designs | Degenerate and edge-case inputs — never via generator parameters |

### Helper: `make_replicate_design(n, seed)`

```r
make_replicate_design <- function(n = 200L, seed = 42L) {
  df <- make_surveywts_data(n = n, seed = seed)
  taylor <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = "base_weight")
  )
  create_bootstrap_weights(taylor, replicates = 50L)
}
```

- **Returns**: A `survey_replicate` object.
- **Replicate type**: Bootstrap (`create_bootstrap_weights()`), 50 replicates.
- **Seed**: `seed` is passed to `make_surveywts_data()` which calls `set.seed(seed)` internally. The same `seed` always produces the same data and therefore the same design structure (though bootstrap replicate weights are random; use `set.seed()` at the call site if exact replicate-weight reproducibility is needed).
- **Purpose**: Provides a realistic, non-degenerate `survey_replicate` for standard test blocks without requiring inline construction each time.

### Object: `survey_taylor_obj`

```r
survey_taylor_obj <- surveycore::as_survey(
  survey::svydesign(id = ~1, data = survey::apisrs, weights = ~pw)
)
```

Returns a `survey_taylor` object suitable for passing as `reference_design`. Used in the two provenance-tracking test rows (one per function).

---

## Per-function test plan

### `calibrate_to_survey()`

#### Happy path

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| Default method (`"rake"`), single variable | `make_replicate_design(50L, 1L)` primary, `(50L, 2L)` control, `variables = c(sex)` | Returns `survey_replicate`; `test_invariants(result)` passes | — |
| Method `"linear"` | Same designs, `method = "linear"`, suppress negative-weight warning | Returns `survey_replicate`; `test_invariants(result)` passes | — |
| Method `"logit"` with finite bounds | Same designs, `method = "logit"`, `bounds = c(0.1, 10)` | Returns `survey_replicate`; all full-sample weights in `[0.1, 10]` | — |
| Multiple variables | Same designs, `variables = c(age_group, sex)` | Returns `survey_replicate`; calibration constraints satisfied | 1e-6 |
| Full-sample totals match control after calibration (`"rake"`) | Same designs, `variables = c(sex)` | For each level `lvl` of `sex`: `sum(w_new[sex == lvl])` equals `sum(w_ctrl[sex == lvl])` | 1e-6 |
| Weight sum equals control weight sum after calibration | Same designs, `variables = c(sex)` | `sum(w_new)` equals `sum(w_ctrl)` | 1e-6 |
| History entry operation field | Same designs | `result@metadata@weighting_history[[last]]$operation == "calibrate_to_survey"` | — |
| History entry parameters | Same designs, `bounds = c(0.1, 10)` | `parameters$variables` is character vector; `parameters$method == "rake"`; `"bounds" %in% names(parameters)` and `parameters$bounds == c(0.1, 10)`; `"n_replicates" %in% names(parameters)` | — |
| History entry design metadata | Same designs | `"control_design_class" %in% names(parameters)` and `"n_replicates_control" %in% names(parameters)` | — |
| History entry `weight_stats` structure | Same designs, `variables = c(sex)` | `"weight_stats" %in% names(entry)`; `names(entry$weight_stats) == c("before", "after")`; `names(entry$weight_stats$before) == c("n", "n_positive", "n_zero", "mean", "cv", "min", "p25", "p50", "p75", "max", "ess")`; `entry$weight_stats$before$mean != entry$weight_stats$after$mean` | — |
| Numerical identity with svrep direct call | Same designs, `variables = c(sex)` | `w_new` identical to `stats::weights(svrep::calibrate_to_sample(...), "sampling")` | 1e-8 |
| `reference_design` stored in history but not used in calibration | Same designs, `reference_design = survey_taylor_obj` | Result weights unchanged vs call without `reference_design`; history `parameters$targets_from_reference == TRUE`; history `parameters$reference_design` is a provenance proxy list with `class` and `n` fields (not the full object) | — |
| `control_col_matches` passed via `control`: not stored in history | Same designs, `control = list(control_col_matches = 1:50)` | History `parameters$control` does not contain key `"control_col_matches"` | — |
| `control_col_matches` reproducibility: same vector → identical weights | Two calls with same designs + `control = list(control_col_matches = 1:50)` | `expect_identical(weights(result1, "sampling"), weights(result2, "sampling"))` — results are bit-for-bit identical | — |
| Unknown `control` key: warning emitted | Same designs, `control = list(bad_key = 1)` | `surveywts_warning_control_param_ignored` emitted; result is valid `survey_replicate` | — |
| Replicate count mismatch (more in primary): no error | Primary 60 replicates, control 50 replicates, `variables = c(sex)` | `suppressWarnings(result <- calibrate_to_survey(...))` returns `survey_replicate`; no `surveywts_warning_replicate_scheme_mismatch` emitted (count mismatches never trigger that class — only type mismatches do) | — |
| Replicate count mismatch (fewer in primary): no error | Primary 30 replicates, control 50 replicates, `variables = c(sex)` | `suppressWarnings(result <- calibrate_to_survey(...))` returns `survey_replicate`; no `surveywts_warning_replicate_scheme_mismatch` emitted | — |

#### Error paths

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_primary_not_replicate` | `primary_design = make_surveywts_data()` (plain data frame) | `expect_error(class=)` + snapshot |
| `surveywts_error_control_not_replicate` | `control_design = make_surveywts_data()` (plain data frame) | `expect_error(class=)` + snapshot |
| `surveywts_error_variables_not_found` | `variables = c(no_such_col)` | `expect_error(class=)` + snapshot |
| `surveywts_error_variables_not_found` | Empty selection (zero columns resolve) | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (not numeric) | `unit_scale = "abc"` | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (wrong length) | `unit_scale = rep(1, nrow - 1)` | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (has NA) | `unit_scale = c(NA, rep(1, n-1))` | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (non-positive) | `unit_scale = c(0, rep(1, n-1))` | `expect_error(class=)` + snapshot |
| `surveywts_error_reference_design_not_taylor` | `reference_design = list(x = 1)` | `expect_error(class=)` + snapshot |
| `surveywts_error_calibration_not_converged` | Mock svrep to emit "converge" warning and return normally | `expect_error(class=)` + snapshot |
| `surveywts_error_calibration_failed` | Mock svrep to throw a hard error | `expect_error(class=)` + snapshot |

#### Warning paths

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_replicate_scheme_mismatch` | Primary bootstrap (50L), control JK random-groups (50L) | `expect_warning(class=)`; result still valid |
| `surveywts_warning_negative_calibrated_weights` | `method = "linear"`, conflicting targets forcing negative adjustments | `expect_warning(class=)`; all returned weights are `>= .Machine$double.eps` |
| `surveywts_warning_control_param_ignored` | `control = list(unknown_key = 1)` | `expect_warning(class=)` once per unknown key |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| Single variable `variables = c(sex)` | Standard designs | Valid result; calibration on one variable |
| `n_rep = 1` in both designs | Custom 1-replicate designs constructed directly | Returns `survey_replicate` without error |
| `bounds = c(-Inf, Inf)` with `method = "logit"` | Default bounds, `method = "logit"` | `surveywts_error_calibration_failed` (svrep rejects infinite logit bounds) |
| `bounds = c(0.1, 10)` with `method = "logit"` | Finite bounds | Returns valid result; full-sample weights in `[0.1, 10]` |
| `control_col_matches` in `control`: forwarded and excluded from history | `control = list(control_col_matches = 1:50)` | No error; history `parameters$control` has no `control_col_matches` key |
| `test_invariants()` passes on result | Standard designs | First assertion in every block constructing a result |

---

### `calibrate_to_estimate()`

#### Happy path

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| Default method (`"rake"`), single variable | `make_replicate_design(50L, 1L)` design; `targets` derived from control design totals | Returns `survey_replicate`; `test_invariants(result)` passes | — |
| Method `"linear"` | Same design, `method = "linear"`, suppress negative-weight warning | Returns `survey_replicate`; `test_invariants(result)` passes | — |
| Method `"logit"` with finite bounds | Same design, `method = "logit"`, `bounds = c(0.1, 10)` | Returns `survey_replicate`; all full-sample weights in `[0.1, 10]` | — |
| Full-sample weights satisfy calibration constraints (`"rake"`) | Single-variable `targets` | `sum(w_new * (var == lvl))` equals `targets$var[[lvl]]` for each level | 1e-6 |
| Numerical identity with svrep direct call | Same design and targets | `w_new` identical to `stats::weights(svrep::calibrate_to_estimate(...), "sampling")` | 1e-8 |
| History entry operation field | Standard design | `result@metadata@weighting_history[[last]]$operation == "calibrate_to_estimate"` | — |
| History entry parameters | Standard design, `bounds = c(0.1, 10)` | `parameters$variables` is names of `targets`; `parameters$method == "rake"`; `parameters$targets` is the list; `parameters$vcov_dim` is `c(k, k)`; `"bounds" %in% names(parameters)` and `parameters$bounds == c(0.1, 10)`; `"n_replicates" %in% names(parameters)` | — |
| History entry `weight_stats` structure | Standard design, single-variable `targets` | `"weight_stats" %in% names(entry)`; `names(entry$weight_stats) == c("before", "after")`; `names(entry$weight_stats$before) == c("n", "n_positive", "n_zero", "mean", "cv", "min", "p25", "p50", "p75", "max", "ess")`; `entry$weight_stats$before$mean != entry$weight_stats$after$mean` | — |
| `reference_design` stored in history but not used | Standard design, `reference_design = survey_taylor_obj` | Weights unchanged vs call without it; history `parameters$targets_from_reference == TRUE` | — |
| `col_selection` in `control`: not stored in history | Standard design, `control = list(col_selection = 1:50)` | History `parameters$control` does not contain key `"col_selection"` | — |
| `col_selection` reproducibility: same vector → identical weights | Two calls with same design + targets + `control = list(col_selection = 1:50)` | `expect_identical(weights(result1, "sampling"), weights(result2, "sampling"))` — results are bit-for-bit identical | — |
| Unknown `control` key: warning emitted | Standard design, `control = list(bad_key = 1)` | `surveywts_warning_control_param_ignored` emitted; result is valid `survey_replicate` | — |
| Identity vcov (zero uncertainty) | `vcov_estimate = diag(k)` where `k = length(unlist(targets))` | Valid result; calibration runs without error | — |
| Multi-variable `targets` | `targets` with two variables | Valid result; calibration constraints satisfied for each variable | 1e-6 |

#### `vcov_estimate` ordering contract test

| Scenario | Input | Expected behavior |
|----------|-------|-------------------|
| `vcov_estimate` rows/cols in unlist order | `targets = list(age_group = c("18-34" = 100, "35-54" = 200), sex = c("F" = 180, "M" = 120))`, `vcov_estimate` is `4 x 4` matching `unlist(targets)` order | Valid; result weights calibrated correctly |
| `vcov_estimate` wrong dimension (k+1 x k+1) | Same `targets`, `vcov_estimate` is `5 x 5` | `surveywts_error_vcov_dimension_mismatch` |

#### Error paths

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_design_not_replicate` | `design = make_surveywts_data()` (plain data frame) | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_not_named_list` | `targets = c(100, 200)` (unnamed numeric, not a list) | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_not_named_list` | `targets = list(100, 200)` (unnamed list) | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_element_not_named` | `targets = list(age_group = c(100, 200))` (unnamed element) | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_element_not_named` | `targets = list(age_group = "not_numeric")` (wrong type) | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_element_not_positive` | `targets = list(sex = c("F" = 0, "M" = 300))` (zero value) | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_element_not_positive` | `targets = list(sex = c("F" = -10, "M" = 300))` (negative value) | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_element_not_positive` | `targets = list(sex = c("F" = NA, "M" = 300))` (NA value) | `expect_error(class=)` + snapshot |
| `surveywts_error_variables_not_found` | `targets = list(no_such_col = c("a" = 100))` | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_levels_mismatch` (missing level) | `targets = list(sex = c("F" = 300))` when data has levels `c("F", "M")` | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_levels_mismatch` (extra level) | `targets = list(sex = c("F" = 200, "M" = 200, "X" = 100))` when data has levels `c("F", "M")` | `expect_error(class=)` + snapshot |
| `surveywts_error_targets_not_named_list` (empty list) | `targets = list()` | `expect_error(class=)` + snapshot |
| `surveywts_error_vcov_has_na` | `vcov_estimate` with one `NA` cell | `expect_error(class=)` + snapshot |
| `surveywts_error_vcov_dimension_mismatch` | `vcov_estimate` is `3 x 3` when `k = 2` | `expect_error(class=)` + snapshot |
| `surveywts_error_vcov_not_symmetric` | `vcov_estimate[1, 2] += 1e-5` (asymmetry > 1e-8) | `expect_error(class=)` + snapshot |
| `surveywts_error_vcov_cholesky_failed` | `vcov_estimate = matrix(c(1, 1, 1, 1), 2, 2)` (singular, rank-1) | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (not numeric) | `unit_scale = "abc"` | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (wrong length) | `unit_scale = rep(1, nrow - 1)` | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (has NA) | `unit_scale = c(NA, rep(1, n-1))` | `expect_error(class=)` + snapshot |
| `surveywts_error_unit_scale_invalid` (non-positive) | `unit_scale = c(-1, rep(1, n-1))` | `expect_error(class=)` + snapshot |
| `surveywts_error_reference_design_not_taylor` | `reference_design = list(x = 1)` | `expect_error(class=)` + snapshot |
| `surveywts_error_calibration_not_converged` | Mock svrep to emit "converge" warning and return normally | `expect_error(class=)` + snapshot |
| `surveywts_error_calibration_failed` | Mock svrep to throw a hard error | `expect_error(class=)` + snapshot |

#### Warning paths

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_negative_calibrated_weights` | `method = "linear"`, conflicting extreme targets | `expect_warning(class=)`; returned weights `>= .Machine$double.eps` |
| `surveywts_warning_control_param_ignored` | `control = list(bad_key = 1)` | `expect_warning(class=)` once per unknown key; two unknown keys -> two warnings |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| Single-variable `targets` | `targets = list(sex = c("F" = 255, "M" = 245))` | Valid; `test_invariants(result)` passes |
| `bounds = c(-Inf, Inf)` with `method = "logit"` | Default bounds, `method = "logit"` | `surveywts_error_calibration_failed` |
| `bounds = c(0.1, 10)` with `method = "logit"` | Finite bounds | Returns valid result; full-sample weights in `[0.1, 10]` |
| Near-zero vcov (very small uncertainty) | `vcov_estimate = diag(1e-10, k)` | Valid; treated as any PD matrix |
| `col_selection` in `control`: forwarded and excluded from history | `control = list(col_selection = 1:50)` | No error; history `parameters$control` has no `col_selection` key |
| `targets` NA check fires before dimension check | `targets` valid shape, `vcov_estimate` has NA in wrong-size matrix | `surveywts_error_vcov_has_na` (not `surveywts_error_vcov_dimension_mismatch`) |

---

## Validation order tests

The following test the spec-mandated validation order:

**`calibrate_to_survey()`**: error for `primary_design` non-replicate must
fire even when `control_design` is also non-replicate (primary check is
first).

**`calibrate_to_estimate()`**: `surveywts_error_design_not_replicate` fires
before any `targets` validation. `surveywts_error_vcov_has_na` fires before
`surveywts_error_vcov_dimension_mismatch` (NA check precedes dimension check).
`surveywts_error_targets_not_named_list` fires before
`surveywts_error_targets_element_not_named`.

---

## Tolerances

- Calibration constraint satisfaction: `1e-6` (svrep default `epsilon = 1e-7`
  convergence achieves this precision in practice)
- Numerical identity vs svrep direct call (full-sample weights): `1e-8`
- vcov symmetry tolerance (within spec): `1e-8` — a matrix with max asymmetry
  `1e-9` passes; a matrix with max asymmetry `1e-7` triggers the error

---

## Invariants

`test_invariants(obj)` is the first assertion in every test block that
constructs a result from either function. It validates:
- `obj` is `survey_replicate`
- Weight column exists, is numeric, and all values are strictly positive

The existing `test_invariants()` definition in `helper-test-data.R` handles
only `weighted_df` and `survey_nonprob`. The tester must extend it by adding a
`survey_replicate` branch:

```r
if (S7::S7_inherits(obj, surveycore::survey_replicate)) {
  testthat::expect_true(S7::S7_inherits(obj, surveycore::survey_replicate))
  wt_col <- obj@variables$weights
  testthat::expect_true(is.character(wt_col) && length(wt_col) == 1)
  testthat::expect_true(wt_col %in% names(obj@data))
  testthat::expect_true(is.numeric(obj@data[[wt_col]]))
  testthat::expect_true(all(obj@data[[wt_col]] > 0))
}
```

This branch must be added to `helper-test-data.R` before any `calibrate_to_survey()` or `calibrate_to_estimate()` test is run.

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown phase)
- [ ] `covr::package_coverage()` — >= 95% (target 98%)

`skip_if_not_installed("svrep")` and `skip_if_not_installed("survey")` inside
blocks that call svrep or use the `api` dataset — never at file level.
