# Audit — PR 2 calibrate_linear() — Second Pass

**Branch:** `feature/calibrate-linear`
**Commit:** `2db7e85`
**Date:** 2026-06-09
**Verdict:** PASS

---

## Profile Gates

| # | Gate | Result | Notes |
|---|------|--------|-------|
| 1 | `devtools::document()` — NAMESPACE/man/ drift | PASS | `git diff --exit-code NAMESPACE man/` → exit 0 |
| 2 | `devtools::test()` | PASS | FAIL 0 \| WARN 101 \| SKIP 3 \| PASS 2887 |
| 3 | `devtools::run_examples()` | PASS | 17 expected warnings; no errors |
| 4 | `R CMD build .` | PASS | `surveywts_0.2.0.9000.tar.gz` produced |
| 5 | `R CMD check --as-cran` | PASS | 0 errors, 0 warnings, 1 NOTE (pre-approved: CRAN incoming feasibility) |
| 6 | `pkgdown::build_site()` | SKIPPED — pre-pkgdown | pkgdown CI not yet wired; pre-Polish scope |
| 7 | `covr::package_coverage()` | PASS | 97.07% (above 95% floor; above 95% threshold) |

---

## CRAN Cookbook Violations

Scanned files: `R/calibrate_linear.R`, `R/calibrate-utils.R`

| File | Line | Violation | Class |
|------|------|-----------|-------|
| — | — | (none) | — |

---

## Per-Test Result Table — calibrate_linear() (PR 2 scope)

`calibrate_linear()` test file: `tests/testthat/test-calibrate-linear.R`
Total: 211 tests, 0 failures.

### Happy paths

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| H1: data.frame prop, no bounds — constraint satisfaction | proportions match per level | targets within 1e-8 | 1e-8 | ✓ |
| H2: data.frame count — column sum satisfaction | weighted sums match targets | per-level count within 1e-6 | 1e-6 | ✓ |
| H3: survey_taylor — @calibration populated, method="linear" | `cal$method == "linear"`, numeric lambda | as specified | exact | ✓ |
| H4: survey_nonprob — class preserved | S7_inherits survey_nonprob | TRUE | exact | ✓ |
| H5: weighted_df input — history appended | length(h) == 2L | 2L | exact | ✓ |
| H6: bounds=c(0.3,3) — method="truncated", bounds_scale="multiplicative" | both fields correct | as specified | exact | ✓ |
| H7: unit_scale provided — q_weights stored | q_weights matches input | within 1e-12 | 1e-12 | ✓ |
| H8: unit_scale=NULL — q_weights NULL | is.null(q_weights) | TRUE | exact | ✓ |
| H9: Format B targets accepted | returns weighted_df | inherits("weighted_df") | exact | ✓ |
| H10: extreme targets produce negative-weights warning | warning class emitted, result returned | surveywts_warning_negative_calibrated_weights | exact | ✓ |

### Numerical oracle

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| N1: calibrate_linear vs survey::calibrate(calfun="linear") | weights match | survey::calibrate weights | 1e-8 | ✓ |
| N2: calibrate_linear(bounds=c(0.3,3)) vs survey::calibrate(calfun="linear", bounds=c(0.3,3)) | weights match | survey::calibrate truncated weights | 1e-8 | ✓ |

### Error paths (spec E1–E23 + spec E19/E20/E21)

| Test | Error class | Pattern | Pass |
|------|-------------|---------|------|
| E1: unsupported class | surveywts_error_unsupported_class | class= + snapshot | ✓ |
| E2: empty data | surveywts_error_empty_data | class= + snapshot | ✓ |
| E3: wt_name not scalar | surveywts_error_wt_name_not_scalar | class= + snapshot | ✓ |
| E4: wt_name empty (NA + "") | surveywts_error_wt_name_empty | class= + snapshot | ✓ |
| E5: reference_design not taylor | surveywts_error_reference_design_not_taylor | class= + snapshot | ✓ |
| E6: weights not found | surveywts_error_weights_not_found | class= + snapshot | ✓ |
| E7: weights not numeric | surveywts_error_weights_not_numeric | class= + snapshot | ✓ |
| E8: weights nonpositive | surveywts_error_weights_nonpositive | class= + snapshot | ✓ |
| E9: weights NA | surveywts_error_weights_na | class= + snapshot | ✓ |
| E10: targets variable not found | surveywts_error_targets_variable_not_found | class= + snapshot | ✓ |
| E11: variable not categorical | surveywts_error_variable_not_categorical | class= + snapshot | ✓ |
| E12: variable has NA | surveywts_error_variable_has_na | class= + snapshot | ✓ |
| E13: population level missing | surveywts_error_population_level_missing | class= + snapshot | ✓ |
| E14: population level extra | surveywts_error_population_level_extra | class= + snapshot | ✓ |
| E15: pop totals invalid (prop) | surveywts_error_population_totals_invalid | class= + snapshot | ✓ |
| E16: pop totals invalid (count <= 0) | surveywts_error_population_totals_invalid | class= + snapshot | ✓ |
| E17: margins format invalid | surveywts_error_margins_format_invalid | class= + snapshot | ✓ |
| E18: bounds L >= 1 | surveywts_error_bounds_invalid_calibration | class= + snapshot | ✓ |
| E19 (test-file): bounds U <= 1 | surveywts_error_bounds_invalid_calibration | class= + snapshot | ✓ |
| E20 (test-file): unit_scale invalid (not numeric) | surveywts_error_unit_scale_invalid | class= + snapshot | ✓ |
| E21 (test-file): unit_scale invalid (wrong length) | surveywts_error_unit_scale_invalid | class= only | ✓ |
| E22: singular system | surveywts_error_calibration_singular_system | class= only | ✓ |
| E23: inconsistent count marginals | surveywts_error_population_totals_invalid | class= only | ✓ |
| Spec E19: bounds length != 2 | surveywts_error_bounds_invalid_calibration | class= + snapshot | ✓ |
| Spec E20: bounds with NA | surveywts_error_bounds_invalid_calibration | class= + snapshot | ✓ |
| Spec E21: tight bounds + extreme targets | surveywts_error_calibration_not_converged | class= + snapshot | ✓ |

### Warning paths

| Test | Warning class | Pass |
|------|---------------|------|
| W1: SRS no weights (data.frame + weights=NULL) | surveywts_warning_srs_no_weights | ✓ |
| W2: negative calibrated weights | surveywts_warning_negative_calibrated_weights | ✓ |
| W3: unrecognized control key | surveywts_warning_control_param_ignored | ✓ |
| W4: replicate calibration failed | surveywts_warning_replicate_calibration_failed | ✓ |

### Edge cases

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| EC1: 0-row data | surveywts_error_empty_data | error class | exact | ✓ |
| EC2: single-row data | returns weighted_df | no error | exact | ✓ |
| EC3: already-calibrated data | weights unchanged | within 1e-8 | 1e-8 | ✓ |
| EC4: bounds_scale="absolute" accepted | returns weighted_df | no error | exact | ✓ |
| EC5: survey_replicate class preserved | S7_inherits survey_replicate | TRUE | exact | ✓ |
| EC6: reference_design in history | targets_from_reference = TRUE | TRUE | exact | ✓ |
| EC7: g-weights in [L,U] for multiplicative bounds | all(g >= L-1e-9 & g <= U+1e-9) | TRUE | 1e-9 | ✓ |
| EC8: weight conservation type="count" | sum(w_new) == N_expected | 500 | 1e-10 | ✓ |
| EC9: weight conservation type="prop" | sum(w_new) == sum(w_orig) | preserved | 1e-10 | ✓ |
| EC10: n_iterations == 1L for plain linear | 1L | 1L | exact | ✓ |
| EC11: n_iterations > 1L for truncated linear when bounds bind | > 1L (seed=200, n=500, bounds=(0.85,1.15)) | > 1L | exact | ✓ |

---

## Before/After Comparison

| Metric | Before PR (develop) | After PR | Delta |
|--------|---------------------|----------|-------|
| Tests passing | 2676 | 2887 | +211 |
| Tests failing | 0 | 0 | 0 |
| Tests skipped | 3 | 3 | 0 |
| Coverage | 96.85% | 97.07% | +0.22% |
| R CMD check notes | 1 (pre-approved) | 1 (pre-approved) | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check errors | 0 | 0 | 0 |

---

## Acceptance Criteria Checklist

| Criterion | Status |
|-----------|--------|
| Spec E19 test: `bounds = c(0.5, 2, 3)` → `surveywts_error_bounds_invalid_calibration` | PASS (line 888, with class= + snapshot) |
| Spec E20 test: `bounds = c(NA, 2)` → `surveywts_error_bounds_invalid_calibration` | PASS (line 906, with class= + snapshot) |
| Spec E21 test: tight bounds + extreme targets → `surveywts_error_calibration_not_converged` | PASS (line 924, with class= + snapshot) |
| EC11 asserts `> 1L` (not `>= 1L`) | PASS (line 1224: `expect_true(result@calibration$n_iterations > 1L)`) |
| Oracle tests N1–N2 still pass after calfun fix | PASS (both pass within 1e-8 tolerance) |
| All 211 calibrate-linear tests pass | PASS |
| No CRAN cookbook violations | PASS |
| Coverage >= 95% | PASS (97.07%) |

---

## Verdict: PASS
