# Audit — sample-calibration-api PR 1 (Third Tester Cycle)

**Date:** 2026-06-12
**Verdict: PASS**

---

## Profile Gates

| # | Gate | Command | Result | Detail |
|---|------|---------|--------|--------|
| 1 | NAMESPACE/man drift | `devtools::document()` | PASS | `git diff --exit-code NAMESPACE man/` exit code 0 |
| 2 | All tests pass | `devtools::test()` | PASS | FAIL 0, WARN 154, SKIP 3, PASS 3272 |
| 3 | Examples run clean | `devtools::run_examples()` | PASS | No errors; 22 expected warnings (SRS no-weights advisory) |
| 4 | Build succeeds | `R CMD build .` | PASS | `surveywts_0.2.0.9000.tar.gz` produced |
| 5 | R CMD check | `R CMD check --as-cran` | PASS | 0 errors, 0 warnings, 2 notes (both pre-approved) |
| 6 | pkgdown | — | SKIPPED — pre-pkgdown phase | PR adds exports; however this phase has not wired pkgdown CI |
| 7 | Coverage >= 95% | `covr::package_coverage()` | PASS | 97.90% |

### Gate 5 Notes (both pre-approved)

| Note | Status |
|------|--------|
| `checking CRAN incoming feasibility` | Pre-approved: package not yet on CRAN |
| `checking for future file timestamps: unable to verify current time` | Pre-approved: transient network isolation — not a code issue |

---

## Sample-Calibration Gate Check

`devtools::test(filter = "sample-calibration")`: FAIL 0, WARN 0, SKIP 0, **PASS 132**

Spec requires >= 130. 132 >= 130: satisfied.

---

## Per-Test Result Table

| Check | Got | Expected | Tolerance | Pass |
|-------|-----|----------|-----------|------|
| sample-calibration PASS count | 132 | >= 130 | — | YES |
| All-suite FAIL count | 0 | 0 | — | YES |
| All-suite SKIP count | 3 | <= 3 | — | YES |
| Gate 1: NAMESPACE/man drift | none | none | — | YES |
| Gate 2: devtools::test() FAIL | 0 | 0 | — | YES |
| Gate 3: devtools::run_examples() | clean | clean | — | YES |
| Gate 5: R CMD check errors | 0 | 0 | — | YES |
| Gate 5: R CMD check warnings | 0 | 0 | — | YES |
| Gate 7: coverage | 97.90% | >= 95% | — | YES |
| History op field `calibrate_to_survey` | exact string | `"calibrate_to_survey"` | — | YES |
| History op field `calibrate_to_estimate` | exact string | `"calibrate_to_estimate"` | — | YES |
| `replicate_count_mismatch` absent from R/ | no hits | no hits | — | YES |
| `survey_replicate` branch in `test_invariants()` | present | present | — | YES |

---

## CRAN Cookbook Scan

Modified R/ files: `R/calibrate_to_survey.R`, `R/calibrate_to_estimate.R`

| Violation pattern | Hit? |
|-------------------|------|
| `T`/`F` as logical (bare) | No |
| `set.seed()` in function body (non-example code) | No — only in `#'` roxygen comment lines |
| Bare `print()`/`cat()` | No |
| `options(warn = -1)` | No |
| `installed.packages()` | No |
| `<<-` | No |
| `@importFrom` in source | No |

No CRAN cookbook violations.

---

## Helper Integrity Check

| Item | Present | Location |
|------|---------|----------|
| `make_replicate_design(n, seed)` | YES | helper-test-data.R:165 |
| `.make_replicate_design(df, ...)` | YES | helper-test-data.R:370 |
| `.make_empty_cell_replicate_design(df, ...)` | YES | helper-test-data.R:391 |
| `df_500` fixture | YES | helper-test-data.R:411 |
| `df_200` fixture | YES | helper-test-data.R:412 |
| `.pin_ts()` helper | YES | helper-test-data.R:421 |
| `survey_replicate` branch in `test_invariants()` | YES | helper-test-data.R:88-95 |

---

## Error Class Coverage

All 16 required error/warning classes confirmed present in the implementation.

### `R/calibrate_to_survey.R`

| Class | Verified |
|-------|---------|
| `surveywts_error_primary_not_replicate` | YES |
| `surveywts_error_control_not_replicate` | YES |
| `surveywts_error_variables_not_found` | YES |
| `surveywts_error_reference_design_not_taylor` | YES |
| `surveywts_error_calibration_not_converged` | YES |
| `surveywts_error_calibration_failed` | YES |
| `surveywts_error_unit_scale_invalid` | YES (calibrate-utils.R) |
| `surveywts_warning_replicate_scheme_mismatch` | YES |
| `surveywts_warning_negative_calibrated_weights` | YES |
| `surveywts_warning_control_param_ignored` | YES |

### `R/calibrate_to_estimate.R`

| Class | Verified |
|-------|---------|
| `surveywts_error_design_not_replicate` | YES |
| `surveywts_error_targets_not_named_list` | YES |
| `surveywts_error_targets_element_not_named` | YES |
| `surveywts_error_targets_element_not_positive` | YES |
| `surveywts_error_targets_levels_mismatch` | YES |
| `surveywts_error_vcov_has_na` | YES |
| `surveywts_error_vcov_dimension_mismatch` | YES |
| `surveywts_error_vcov_not_symmetric` | YES |
| `surveywts_error_vcov_cholesky_failed` | YES |
| `surveywts_error_unit_scale_invalid` | YES (calibrate-utils.R) |
| `surveywts_error_reference_design_not_taylor` | YES |
| `surveywts_error_calibration_not_converged` | YES |
| `surveywts_error_calibration_failed` | YES |
| `surveywts_warning_negative_calibrated_weights` | YES |
| `surveywts_warning_control_param_ignored` | YES |

---

## Retired Error Class Check

`grep -r "replicate_count_mismatch" R/` — no output. Confirmed absent.

---

## History Fields Check

| Check | Result |
|-------|--------|
| `operation == "calibrate_to_survey"` tested | YES (test-sample-calibration.R:52) |
| `operation == "calibrate_to_estimate"` tested | YES (test-sample-calibration.R:538) |
| `control_col_matches` NOT stored in history | YES (test-sample-calibration.R) |
| `col_selection` NOT stored in history | YES (test-sample-calibration.R) |

---

## Before/After Comparison

| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| Tests passing | 3208 | 3272 | +64 |
| Tests failing | 0 | 0 | 0 |
| Tests skipped | 3 | 3 | 0 |
| Coverage | 98.35% | 97.90% | -0.45% |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 1 | 2 | +1 (pre-approved: timestamp network check) |

Coverage drop of 0.45% is below the 0.5% HOLD threshold. Coverage remains above
95%. No HOLD or BLOCK triggered by coverage.
