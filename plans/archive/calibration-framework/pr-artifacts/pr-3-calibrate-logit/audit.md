# Audit — PR 3: `calibrate_logit()`

**Verdict: BLOCK**
**Block classification: missing-test-coverage**
**Date:** 2026-06-09

---

## Profile Gates

| Gate | Command | Result | Notes |
|------|---------|--------|-------|
| 1 | `devtools::document()` | PASS | NAMESPACE unchanged. `man/` diffs are only `@family` cross-ref additions from `calibrate_logit.Rd` joining the calibration family — expected, not drift. |
| 2 | `devtools::test()` | PASS | FAIL 0, WARN 101, SKIP 3, PASS 3061 |
| 3 | `devtools::run_examples()` | PASS | 17 warnings (expected, from test helpers); no errors |
| 4 | `R CMD build .` | PASS | `surveywts_0.2.0.9000.tar.gz` produced |
| 5 | `R CMD check --as-cran` | PASS | 0 errors, 0 warnings, 1 NOTE (CRAN incoming feasibility — pre-approved) |
| 6 | `pkgdown::build_site()` | SKIPPED — pre-pkgdown | PR adds a new export, but pre-pkgdown phase logged per profile. |
| 7 | `covr::package_coverage()` | PASS | 96.85% overall (above 95% threshold). `calibrate_logit.R` file: 92.3% (275/298 lines). See uncovered lines below. |

---

## Before/After Comparison

| Metric | Before PR (c3a2a9a) | After PR | Delta |
|--------|---------------------|----------|-------|
| Tests passing | 2887 | 3061 | +174 |
| Tests failing | 0 | 0 | 0 |
| Coverage (package) | 97.07% | 96.85% | -0.22% |
| R CMD check NOTEs | 1 | 1 | 0 |
| R CMD check errors/warnings | 0 | 0 | 0 |

Coverage dropped 0.22% — below the 0.5% / 98% threshold that would require a HOLD. No coverage regression block applies.

---

## Per-Test Result Table: calibrate_logit

### Happy Paths

| Test | Result | Pass |
|------|--------|------|
| H1: data.frame, prop, default bounds | PASS | ✓ |
| H2: data.frame, count | PASS | ✓ |
| H3: survey_taylor, @calibration populated, method="logit", lambda is numeric | PASS | ✓ |
| H4: survey_nonprob, class preserved | PASS | ✓ |
| H5: weighted_df, history appended (2 entries) | PASS | ✓ |
| H6: bounds_scale="multiplicative" stored | PASS | ✓ |
| H6b: data.frame default bounds, all weights finite/positive | PASS | ✓ |
| H7: unit_scale populates @calibration$q_weights | PASS | ✓ |
| H8: unit_scale=NULL → q_weights=NULL | PASS | ✓ |
| H9: Format B (long data frame) targets | PASS | ✓ |
| H10: custom bounds = c(0.5, 2), g-weights in (0.5, 2) | PASS | ✓ |
| H_abs: absolute bounds, output weights in (200, 2000) | PASS | ✓ |
| H_abs: absolute bounds_scale stored in @calibration | PASS | ✓ |

Mapping note: Spec H1-H10 re-map to test H1-H10 with some additions. Spec H1=test H1, H2=test H6 (type="prop" default bounds handled), H3=test H3, H4=test H4, H5=test H5, H6=test H10 (custom bounds), H7=test H2 (type="count"), H8=covered by test_invariants+history checks, H9=test H9, H10 (W1, SRS warning) is tested in W1. All spec happy-path scenarios are covered.

### Numerical Oracle

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| N1: calibrate_logit() vs survey::calibrate(calfun="logit") | weights match | survey package output | 1e-8 | ✓ |

`skip_if_not_installed("survey")` is inside the N1 block (line 292). ✓

### Error Paths

| Test | Error class | Dual pattern | Pass |
|------|-------------|--------------|------|
| E1: unsupported class | `surveywts_error_unsupported_class` | class= + snapshot | ✓ |
| E2: empty data | `surveywts_error_empty_data` | class= + snapshot | ✓ |
| E3: wt_name not scalar | `surveywts_error_wt_name_not_scalar` | class= + snapshot | ✓ |
| E4: wt_name empty (NA) | `surveywts_error_wt_name_empty` | class= + snapshot | ✓ |
| E4b: wt_name empty ("") | `surveywts_error_wt_name_empty` | class= only | ✓ |
| E5: reference_design not taylor | `surveywts_error_reference_design_not_taylor` | class= + snapshot | ✓ |
| E6: weights not found | `surveywts_error_weights_not_found` | class= + snapshot | ✓ |
| E7: weights not numeric | `surveywts_error_weights_not_numeric` | class= + snapshot | ✓ |
| E8: weights nonpositive | `surveywts_error_weights_nonpositive` | class= + snapshot | ✓ |
| E9: weights NA | `surveywts_error_weights_na` | class= + snapshot | ✓ |
| E10: targets variable not found | `surveywts_error_targets_variable_not_found` | class= + snapshot | ✓ |
| E11: variable not categorical | `surveywts_error_variable_not_categorical` | class= + snapshot | ✓ |
| E12: variable has NA | `surveywts_error_variable_has_na` | class= + snapshot | ✓ |
| E13: population level missing | `surveywts_error_population_level_missing` | class= + snapshot | ✓ |
| E14: population level extra | `surveywts_error_population_level_extra` | class= + snapshot | ✓ |
| E15: population totals invalid (prop != 1) | `surveywts_error_population_totals_invalid` | class= + snapshot | ✓ |
| E16: population totals invalid (count <= 0) | `surveywts_error_population_totals_invalid` | class= + snapshot | ✓ |
| E17: margins format invalid (targets=42) | `surveywts_error_margins_format_invalid` | class= + snapshot | ✓ |
| E18: bounds invalid (L >= 1) | `surveywts_error_bounds_invalid_calibration` | class= + snapshot | ✓ |
| E19: bounds invalid (U <= 1) | `surveywts_error_bounds_invalid_calibration` | class= + snapshot | ✓ |
| E20: unit_scale not numeric | `surveywts_error_unit_scale_invalid` | class= + snapshot | ✓ |
| E21: unit_scale wrong length | `surveywts_error_unit_scale_invalid` | class= only | ✓ |
| E22: singular system (collinear vars) | `surveywts_error_calibration_singular_system` | class= only | ✓ |
| E23: inconsistent count marginals | `surveywts_error_population_totals_invalid` | class= only | ✓ |
| Additional: bounds length != 2 | `surveywts_error_bounds_invalid_calibration` | class= + snapshot | ✓ |
| Additional: bounds with NA | `surveywts_error_bounds_invalid_calibration` | class= only | ✓ |
| Additional: bounds non-numeric | `surveywts_error_bounds_invalid_calibration` | class= only | ✓ |
| E_abs: absolute bounds L <= 0 | `surveywts_error_bounds_invalid_calibration` | class= + snapshot | ✓ |
| E_abs: absolute bounds L >= U | `surveywts_error_bounds_invalid_calibration` | class= only | ✓ |
| **SPEC E22: calibration_not_converged (maxit=1)** | `surveywts_error_calibration_not_converged` | **MISSING** | **FAIL** |
| **SPEC E23: unit_scale non-positive value** | `surveywts_error_unit_scale_invalid` | **MISSING** | **FAIL** |

### Warning Paths

| Test | Warning class | Pattern | Pass |
|------|--------------|---------|------|
| W1: SRS no weights for plain df + NULL weights | `surveywts_warning_srs_no_weights` | expect_warning(class=) + result returned | ✓ |
| W2: replicate calibration failed | `surveywts_warning_replicate_calibration_failed` | expect_warning(class=) + result returned | ✓ |
| W3: unknown control parameter | `surveywts_warning_control_param_ignored` | expect_warning(class=) + result returned | ✓ |

### Edge Cases

| Test | Input | Expected | Pass |
|------|-------|----------|------|
| EC1: trivially calibrated weights | already-at-targets data | converges, weights positive | ✓ |
| EC2: all output weights strictly positive | standard data | all(w > 0) | ✓ |
| EC3: g-weights in open interval (L, U) | multiplicative bounds | all(g > L) and all(g < U) — strict inequalities | ✓ |
| EC4: @calibration$lambda is NR converged solution | survey_taylor, non-trivial targets | lambda satisfies logit calibration constraint within 1e-5 | ✓ |
| EC1 from shared: infeasible targets → not_converged error | **MISSING** — no test for infeasible targets that push g-weight past bounds | | **FAIL** |

---

## CRAN Cookbook Scan

File scanned: `R/calibrate_logit.R`

| Violation pattern | Result |
|-------------------|--------|
| `T`/`F` as logicals | NONE |
| `set.seed()` in non-test code | NONE |
| Bare `print()`/`cat()` | NONE |
| `options(warn = -1)` | NONE |
| `installed.packages()` | NONE |
| `<<-` | NONE |
| `par()`/`options()` without `on.exit()` | NONE |
| `@importFrom` in source | NONE |

No violations found.

---

## Invariant Coverage

`test_invariants(obj)` verified as first assertion in blocks producing `weighted_df` or `survey_nonprob`:

- H1 (line 63): first assertion ✓
- H2 (line 96): first assertion ✓
- H3 (line 120): first assertion ✓
- H4 (line 142): first assertion ✓
- H5 (line 166): first assertion ✓
- H6b (line 200): first assertion ✓
- H7 (line 219): first assertion ✓
- H8 (line 234): first assertion ✓
- H9 (line 256): first assertion ✓
- W1 (line 885): after warning capture ✓
- W2 (line 905): after warning capture ✓
- W3 (line 924): after warning capture ✓
- EC1 (line 952): first assertion ✓
- H_abs (line 1062): first assertion ✓

---

## Uncovered Lines in `calibrate_logit.R`

| Lines | Branch |
|-------|--------|
| 317–322 | Intercept-only model matrix (all calibration variables have only 1 level) |
| 469–470 | `type = "count"` replicate weight scaling |
| 491–507 | Absolute bounds path within the replicate-weight calibration loop |

These are not `# nocov` marked but represent defensible untested branches. The test spec does not include a test for the intercept-only model case for logit. Lines 469–470 and 491–507 correspond to `survey_replicate` + `type="count"` and `survey_replicate` + `bounds_scale="absolute"` — neither is in the spec's required test scenarios for `calibrate_logit`.

---

## BLOCK Items

### BLOCK 1 — Missing spec-required error test: `surveywts_error_calibration_not_converged`

The test spec (§calibrate_logit, Error paths, E22) requires:

> E22 | `surveywts_error_calibration_not_converged` | `control = list(maxit = 1)` with non-trivial targets | `expect_error(class=...)` + snapshot

No test in `test-calibrate-logit.R` exercises this error class. The block labeled E22 (line 782) tests `surveywts_error_calibration_singular_system` (spec E21), leaving spec E22 uncovered.

**Required fix:** Add a `test_that()` block that calls `calibrate_logit(...)` with `control = list(maxit = 1)` and non-trivial targets, asserting `class = "surveywts_error_calibration_not_converged"` plus `expect_snapshot(error = TRUE, ...)`.

### BLOCK 2 — Missing spec-required error test: `surveywts_error_unit_scale_invalid` (non-positive value)

The test spec (§calibrate_logit, Error paths, E23) requires:

> E23 | `surveywts_error_unit_scale_invalid` | `unit_scale = c(-1, rep(1, nrow(data) - 1))` (non-positive value) | `expect_error(class=...)` + snapshot

The test file covers `unit_scale` being non-numeric (E20) and wrong-length (E21), but not a non-positive value. Spec E23 is not covered.

**Required fix:** Add a `test_that()` block using `unit_scale = c(-1, rep(1, nrow(df) - 1))`, asserting `class = "surveywts_error_unit_scale_invalid"` plus `expect_snapshot(error = TRUE, ...)`.

---

## Summary

All profile gates pass. All 174 new tests pass. No CRAN cookbook violations. No test regressions vs the 2887-test baseline. Two spec-required error tests are absent: spec E22 (`calibration_not_converged` via `maxit=1`) and spec E23 (`unit_scale_invalid` via non-positive value). Both require the dual `expect_error(class=...)` + `expect_snapshot(error=TRUE, ...)` pattern per testing-surveywts.md.

**Verdict: BLOCK** (missing-test-coverage, 2 missing error path tests from spec)
