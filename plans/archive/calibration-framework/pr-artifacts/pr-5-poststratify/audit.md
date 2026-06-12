# PR 5 Audit — poststratify()

**Verdict: BLOCK**

Block classification: contract-miss (missing tests W1, W2, CX4, EC6 value
assertion), coverage-miss (poststratify.R at 95.45% < 98% gate), and
namespace-drift (devtools::document() not run before commit).

---

## Profile gates

| # | Gate | Result | Notes |
|---|------|--------|-------|
| 1 | `devtools::document()` — NAMESPACE/man/ unchanged | FAIL | See BLOCK-1 |
| 2 | `devtools::test()` — all tests pass | PASS | 2910 pass, 0 fail, 3 skip |
| 3 | `devtools::run_examples()` — clean | PASS | 0 errors (20 benign warnings) |
| 4 | `R CMD build .` — tarball produced | PASS | surveywts_0.2.0.9000.tar.gz |
| 5 | `R CMD check --as-cran` — 0 errors/warnings | PASS | 2 pre-approved NOTEs only |
| 6 | `pkgdown::build_site()` | SKIPPED — pre-pkgdown scope per test-spec |
| 7 | `covr::package_coverage()` — overall ≥ 95% | PASS | 97.55% overall |
| 7b | `covr` — poststratify.R ≥ 98% | FAIL | 95.45% (gate: 98%) — see BLOCK-2 |

---

## Gate results

### Gate 1 — Function exists and is exported
FAIL. The committed NAMESPACE still exports `calibrate_poststrat`, not
`poststratify`. Running `devtools::document()` produces:

```
- export(calibrate_poststrat)
+ export(poststratify)
```

Additionally, `man/calibrate_poststrat.Rd` remains in the committed tree and
`man/poststratify.Rd` is untracked. The PR did not include the output of
`devtools::document()`.

### Gate 2 — History operation string
PASS. `R/poststratify.R:478` uses `operation = "poststratify"`. Test 8 (line
219) and tests 36/37 (lines 800, 819) all assert `"poststratify"`.

### Gate 3 — Named list rejection (EC1)
PASS. Test 21 (lines 457–471) uses dual pattern:
`expect_error(class = "surveywts_error_margins_format_invalid")` +
`expect_snapshot(error = TRUE, ...)`.

### Gate 4 — cell_factors assertion (EC6)
FAIL. Test PT-6 (lines 991–1004) asserts that `cell_factors` is non-NULL,
numeric, and has the correct length. It does NOT verify the mathematical
identity `cell_factors == target_counts / ht_estimates` per cell as required
by EC6. See BLOCK-3.

### Gate 5 — Cross-function test CX4
FAIL. No test in `test-04-poststratify.R` or `test-02-calibrate.R` asserts
that one call each to `calibrate_linear`, `calibrate_logit`, `calibrate_rake`,
`poststratify` produces four distinct `operation` values. See BLOCK-4.

### Gate 6 — Oracle tests N1/N2
PASS. Test 10 (line 248) uses `~age_group + sex` (two variables), covering
both N1 and N2 of the spec. `skip_if_not_installed("survey")` is inside the
block (not file-level). Tolerance `1e-8` is correct.

### Gate 7 — Error paths E1–E18
PASS. All 18 error paths present with dual pattern
(`expect_error(class=...)` + `expect_snapshot(error=TRUE,...)`).

| Spec | Error class | Test block | Status |
|------|-------------|------------|--------|
| E1 | `surveywts_error_unsupported_class` | Test 11 (line 276) | PASS |
| E2 | `surveywts_error_empty_data` | Test 13 (line 310) | PASS |
| E3 | `surveywts_error_wt_name_not_scalar` | Test 18 (line 404) | PASS |
| E4 | `surveywts_error_wt_name_empty` | Test 19 (line 421) | PASS |
| E5 | `surveywts_error_margins_format_invalid` | Test 21 (line 457) | PASS |
| E6 | `surveywts_error_no_strata_variables` | Test 22 (line 477) | PASS |
| E7 | `surveywts_error_targets_variable_not_found` | Test 23 (line 494) | PASS |
| E8 | `surveywts_error_reference_design_not_taylor` | Test 20 (line 438) | PASS |
| E9 | `surveywts_error_weights_not_found` | Test 14 (line 327) | PASS |
| E10 | `surveywts_error_weights_nonpositive` | Test 16 (line 364) | PASS |
| E11 | `surveywts_error_weights_na` | Test 17 (line 384) | PASS |
| E12 | `surveywts_error_variable_has_na` | Test 24 (line 515) | PASS |
| E13 | `surveywts_error_population_totals_invalid` (prop) | Test 25 (line 533) | PASS |
| E14 | `surveywts_error_population_totals_invalid` (count) | Test 26 (line 555) | PASS |
| E15 | `surveywts_error_population_cell_duplicate` | Test 27 (line 577) | PASS |
| E16 | `surveywts_error_population_cell_missing` | Test 28 (line 599) | PASS |
| E17 | `surveywts_error_population_cell_not_in_data` | Test 30 (line 643) | PASS |
| E18 | `surveywts_error_weights_not_numeric` | Test 15 (line 346) | PASS |

### Gate 8 — .format_history_step() display
PASS. `R/utils.R` switch in `.format_history_step()` (lines 45–94):
- `"calibrate_linear"` and `"calibrate_logit"` arms (lines 53–56) show
  variable names.
- `"poststratify"` arm (lines 57–60) shows strata variable names.
- No `"calibrate_greg"` arm present (removed in prior PR).

### Gate 9 — Coverage ≥ 98% for poststratify.R
FAIL. `R/poststratify.R`: 95.45% (126/132 coverable lines). Gate requires
98%. See BLOCK-2.

### Gate 10 — R CMD check
PASS. 0 errors, 0 warnings. 2 NOTEs:
- `checking CRAN incoming feasibility` — pre-approved
- `checking for future file timestamps` — pre-approved

### Gate 11 — test_invariants() first assertion
PASS. All applicable test blocks (creating `weighted_df` or `survey_nonprob`)
call `test_invariants(result)` as the first assertion. Verified at lines 81,
105, 120, 144, 171, 187, 692, 709, 852, 866.

### Gate 12 — No calibrate_poststrat references in functional code
PASS. All occurrences of `calibrate_poststrat` in `R/` and `tests/` are
in comments only — no functional code references remain.

### Missing warning path tests (W1, W2)
FAIL. Neither W1 nor W2 from the spec has a test.

- W1: `surveywts_warning_srs_no_weights` — Plain `data.frame` + `weights =
  NULL` should emit this warning. `poststratify()` does NOT emit this warning
  (no `cli_warn()` call in `R/poststratify.R` for the SRS case), and no test
  exists. See BLOCK-5.
- W2: `surveywts_warning_replicate_calibration_failed` — The code implements
  this warning (lines 443–459 of `R/poststratify.R`), but no test exists in
  `test-04-poststratify.R`. See BLOCK-5.

---

## Per-test result table (spot checks)

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| Test 10: poststratify() vs survey::postStratify() | oracle comparison | tolerance 1e-8 | 1e-8 | PASS (all 165 poststratify tests pass) |
| Test 8: history operation string | "poststratify" | "poststratify" | exact | PASS |
| Test PT-4: @calibration$method | "poststrat" | "poststrat" | exact | PASS |
| Test PT-11: @calibration$converged | TRUE | TRUE | exact | PASS |
| Test PT-12: @calibration$n_iterations | 1L | 1L | exact | PASS |
| EC6 value assertion | MISSING | target_counts / ht_estimates | 1e-10 | FAIL |

---

## CRAN cookbook violations

None found. Scan of `R/poststratify.R`:
- No `T`/`F` abbreviations
- No `set.seed()`
- No bare `print()`/`cat()`
- No `options(warn = -1)`
- No `installed.packages()`
- No `<<-`
- No `@importFrom`

---

## Before/After comparison

| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| Tests passing | 2909 | 2910 | +1 |
| Tests failing | 2 | 0 | -2 |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| Overall coverage | ~97% (est.) | 97.55% | ~+0.5% |
| poststratify.R coverage | N/A (new file) | 95.45% | N/A |

---

## Issues (BLOCK)

### BLOCK-1 — NAMESPACE/man drift
**Gate:** Profile gate 1 (devtools::document())
**Files:** `NAMESPACE`, `man/calibrate_poststrat.Rd`, `man/poststratify.Rd`,
`man/calibrate.Rd`, `man/calibrate_linear.Rd`, `man/calibrate_logit.Rd`,
`man/calibrate_rake.Rd`, `man/adjust_nonresponse.Rd`

The PR added `R/poststratify.R` with `@export` and `@family calibration`
roxygen tags, deleted `R/calibrate_poststrat.R`, and updated cross-references
in other files — but did not run `devtools::document()` before committing.

The committed `NAMESPACE` still exports `calibrate_poststrat` (not
`poststratify`). The committed `man/calibrate_poststrat.Rd` still exists;
`man/poststratify.Rd` is untracked.

**Fix:** Run `devtools::document()` in the package root, then stage and commit:
- `NAMESPACE`
- `man/poststratify.Rd` (new)
- `man/calibrate_poststrat.Rd` (delete)
- `man/calibrate.Rd`, `man/calibrate_linear.Rd`, `man/calibrate_logit.Rd`,
  `man/calibrate_rake.Rd`, `man/adjust_nonresponse.Rd` (updated `@family`
  cross-references)

### BLOCK-2 — poststratify.R coverage below 98% gate
**Gate:** Profile gate 9 (coverage)
**File:** `R/poststratify.R`
**Measured:** 95.45% (126/132 coverable lines)
**Gate:** ≥ 98%

The 6 uncovered lines are inside the `# nocov` block (lines 317–334, the
`n_hat_h <= 0` defensive guard). However even with those excluded, coverage
should account for other reachable paths that may be untested. The
`# nocov` block is legitimate, but the measured coverage percentage including
those lines is 95.45%.

**Fix:** Verify which non-nocov lines are uncovered and add tests to cover
them, OR confirm that all uncovered lines are properly annotated with
`# nocov` and the effective coverage of non-nocov lines meets the gate.
If all 6 uncovered lines are inside `# nocov` blocks, mark the file as
excluded from coverage measurement or verify the exclusion is registered.

### BLOCK-3 — EC6 cell_factors value assertion missing
**Gate:** Gate 4 (cell_factors assertion)
**File:** `tests/testthat/test-04-poststratify.R`
**Test:** PT-6 (line 991)

Test PT-6 verifies that `cell_factors` exists, is numeric, has the right
length, and has names — but does NOT verify the mathematical identity:
`cell_factors[cell] == target_count[cell] / sum(base_weights[cell_indices])`.

**Fix:** Extend PT-6 (or add a new PT-6b block) to compute the expected
`cell_factors` values independently and compare with tolerance `1e-10`:
```r
# For each cell i: expected = target_vals[i] / sum(base_weights[cell_i_indices])
cf <- result@calibration$cell_factors
pre_weights <- design@data[[design@variables$weights]]
targets_count <- targets$target  # already count type in this test
for (i in seq_along(cf)) {
  cell_key <- names(cf)[i]
  # build indices for this cell
  data_key_i <- paste(df$age_group, df$sex, sep = "//")[...]
  ht_est <- sum(pre_weights[data_key_i == cell_key])
  expect_equal(cf[[cell_key]], targets_count[[i]] / ht_est, tolerance = 1e-10)
}
```

### BLOCK-4 — CX4 cross-function test missing
**Gate:** Gate 5 (cross-function test CX4)
**Files:** `tests/testthat/test-04-poststratify.R`,
`tests/testthat/test-02-calibrate.R`

No test in either file asserts that one call each to `calibrate_linear`,
`calibrate_logit`, `calibrate_rake`, and `poststratify` produces four
distinct `operation` values in their history entries.

**Fix:** Add a `test_that()` block to `test-04-poststratify.R`:
```r
test_that("CX4: four calibration functions produce four distinct operation strings", {
  df  <- make_surveywts_data(seed = 99)
  pop <- .make_targets_ps("count")
  targets_marg <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  r1 <- calibrate_linear(df, targets = targets_marg)
  r2 <- calibrate_logit(df, targets = targets_marg)
  r3 <- calibrate_rake(df, targets = targets_marg)
  r4 <- poststratify(df, targets = pop, type = "count")

  ops <- c(
    attr(r1, "weighting_history")[[1L]]$operation,
    attr(r2, "weighting_history")[[1L]]$operation,
    attr(r3, "weighting_history")[[1L]]$operation,
    attr(r4, "weighting_history")[[1L]]$operation
  )
  expect_length(unique(ops), 4L)
})
```

### BLOCK-5 — Warning path tests W1 and W2 missing
**Gate:** Gate 7 (error paths — warning paths)
**File:** `tests/testthat/test-04-poststratify.R`

Neither W1 nor W2 has a test. Additionally, W1 reveals a code gap:
`poststratify()` does not emit `surveywts_warning_srs_no_weights` for plain
`data.frame` + `weights = NULL`, whereas `calibrate_linear()`,
`calibrate_logit()`, and `calibrate_rake()` all emit this warning in the
same scenario.

**Fix (W1 — code + test):**
Add the SRS warning emission to `R/poststratify.R` in the block that detects
plain `data.frame` + `weights = NULL` (after line 242 where uniform weights
are set):
```r
cli::cli_warn(
  c(
    "!" = "No {.arg weights} supplied for a plain {.cls data.frame}. Using uniform starting weights (all 1/n).",
    "i" = "This assumes a simple random sample (SRS). Supply design weights for unequal-probability designs."
  ),
  class = "surveywts_warning_srs_no_weights"
)
```
Then add a test:
```r
test_that("poststratify() emits srs_no_weights for plain data.frame + weights = NULL", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps("count")
  expect_warning(
    result <- poststratify(df, targets = pop, type = "count"),
    class = "surveywts_warning_srs_no_weights"
  )
  test_invariants(result)
})
```

**Fix (W2 — test only):**
The replicate calibration failure warning IS implemented in `R/poststratify.R`
(lines 443–459). Add a test that manually zeroes one replicate column's
weights for a cell to trigger the warning:
```r
test_that("poststratify() emits replicate_calibration_failed when a replicate cell has zero weights (W2)", {
  df <- make_surveywts_data(seed = 1)
  targets <- .make_targets_ps("count")
  rep_design <- .make_replicate_design(df)
  # Zero all weights in first replicate column for "55+" cells
  rep_col <- rep_design@variables$repweights[[1L]]
  rep_design@data[[rep_col]][rep_design@data$age_group == "55+"] <- 0

  expect_warning(
    result <- poststratify(rep_design, targets = targets, type = "count"),
    class = "surveywts_warning_replicate_calibration_failed"
  )
  expect_false(result@calibration$replicate_converged[[rep_col]])
  out_wts <- result@data[[result@variables$weights]]
  # Full-sample weights should be calibrated (not affected by replicate failure)
  expect_true(all(out_wts > 0))
})
```
