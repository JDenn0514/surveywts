# Audit2 — PR 1: calibrate-unit-scale (re-validation after tolerance fix)

**Verdict:** PASS
**Date:** 2026-06-09
**Commit:** 842f8a9 (develop HEAD after tolerance fix)
**PR scope:** Wire `unit_scale` (q_k) through NR engine (D1–D3) and fix per-unit absolute bounds (D6) for `calibrate_linear()` and `calibrate_logit()`.
**Re-validation reason:** Previous audit (audit.md) reported HL-8 and HG-7 with tolerance `1e-6`. Reviewer issued STOP: test-spec requires `1e-8`. Tests have been updated; this audit confirms compliance.

---

## Profile Gates

| # | Gate | Result | Notes |
|---|------|--------|-------|
| 1 | `devtools::document()` — NAMESPACE/man drift | PASS | `git diff --exit-code NAMESPACE man/` exit code 0; no drift |
| 2 | `devtools::test()` | PASS | FAIL 0, WARN 154 (all pre-existing), SKIP 3, PASS 3208 |
| 3 | `devtools::run_examples()` | PASS | 22 warnings (all pre-existing); no errors |
| 4 | `R CMD build .` | PASS | `surveywts_0.2.0.9000.tar.gz` produced |
| 5 | `R CMD check --as-cran` | PASS | 0 errors, 0 warnings, 1 NOTE (pre-approved: `checking CRAN incoming feasibility` — informational only) |
| 6 | `pkgdown::build_site()` | SKIPPED — pre-pkgdown | No new exported functions; internal changes only |
| 7 | `covr::package_coverage()` | PASS | 98.35% (above 98% target; above 95% block threshold) |

---

## CRAN Cookbook Scan

Modified R/ files scanned: all 37 files reported by `git diff --name-only origin/main...HEAD -- 'R/*.R'`; primary focus on changed calibration files: `R/calibrate-utils.R`, `R/calibrate_linear.R`, `R/calibrate_logit.R`, `R/calibrate.R`.

Patterns checked: `library()`, `require()`, `Sys.sleep()`, `.GlobalEnv`, `<<-`, `setwd()`, `set.seed()` in source.

| File | Violation | Found |
|------|-----------|-------|
| All modified R/ files | Any pattern | None |

**No violations found.**

---

## Before/After Comparison

| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| Tests passing | 2933 | 3208 | +275 |
| Tests failing | 0 | 0 | 0 |
| Tests skipped | 3 | 3 | 0 |
| Coverage | (baseline: not measured pre-PR) | 98.35% | — |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 1 | 1 | 0 |

Coverage is above the 98% target and well above the 95% BLOCK threshold. No regression in passing tests.

---

## Per-Test Result Table

### `calibrate_linear()` — Happy Paths

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| HL-1: unit_scale=NULL vs unit_scale=rep(1,n) | 0 (machine precision) | 0 | 1e-14 | PASS |
| HL-RG: regression guard (same as HL-1) | 0 (machine precision) | 0 | 1e-14 | PASS |
| HL-2: q_unequal vs survey::calibrate(variance=1/q) | 7.55e-15 | ≤ 1e-8 | 1e-8 | PASS |
| HL-3: q_all_twos vs survey::calibrate(variance=0.5) | 5.33e-15 | ≤ 1e-8 | 1e-8 | PASS |
| HL-4: bounded multiplicative + q_unequal vs oracle | test suite PASS | ≤ 1e-8 | 1e-8 | PASS |
| HL-5: calibration constraint holds with q_unequal | 6.66e-16 | ≤ 1e-8 | 1e-8 | PASS |
| HL-6: history records unit_scale exactly | identical() == TRUE | identical | exact | PASS |
| HL-7: bounded vs unbounded differ | max(abs(diff)) > 1e-6 | outputs differ | exact inequality | PASS |
| HL-8: absolute bounds vs survey::calibrate(bounds.const=TRUE) | ≤ 1e-8 | ≤ 1e-8 | **1e-8** | PASS |
| HL-9: equal base weights pre/post-fix identical | bounds satisfied | bounds satisfied | 1e-8 | PASS |
| HL-10: unequal base weights: new != old mean approach | max_diff = 0.268 | > 0 | exact inequality | PASS |
| HL-11: absolute bounds + q_unequal combined oracle | ≤ 1e-8 | ≤ 1e-8 | **1e-8** | PASS |
| HL-12: NR converges in 1 iteration (unbounded linear) | 1L | 1L | exact | PASS |

**HL-8 note:** Test uses `control = list(epsilon = 1e-10)` to tighten NR convergence; `tolerance = 1e-8` in `expect_equal()`. Matches test-spec exactly.

**HL-11 note:** Test uses `control = list(epsilon = 1e-10)` to tighten NR convergence; `tolerance = 1e-8` in `expect_equal()`. Matches test-spec exactly.

### `calibrate_linear()` — Warning Paths

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| HLW-1: negative weights warning with unit_scale != NULL | `surveywts_warning_negative_calibrated_weights` | same class | exact | PASS |

### `calibrate_linear()` — Error Paths

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| HLE-1: non-positive unit_scale | `surveywts_error_unit_scale_invalid` | same class | exact | PASS |
| HLE-2: wrong-length unit_scale | `surveywts_error_unit_scale_invalid` | same class | exact | PASS |
| HLE-3: NA in unit_scale | `surveywts_error_unit_scale_invalid` | same class | exact | PASS |
| HLE-4: non-numeric unit_scale | `surveywts_error_unit_scale_invalid` | same class | exact | PASS |
| HLE-5: tight bounds causing non-convergence | `surveywts_error_calibration_not_converged` | same class | exact | PASS |

### `calibrate_logit()` — Happy Paths

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| HG-1: unit_scale=NULL vs unit_scale=rep(1,n) | 0 (machine precision) | 0 | 1e-14 | PASS |
| HG-RG: regression guard | 0 (machine precision) | 0 | 1e-14 | PASS |
| HG-2: q_unequal vs survey::calibrate(calfun="logit", variance=1/q) | 9.77e-15 | ≤ 1e-8 | 1e-8 | PASS |
| HG-3: q_all_twos vs oracle | 8.44e-15 | ≤ 1e-8 | 1e-8 | PASS |
| HG-4: narrow bounds c(0.3,3) + q_unequal vs oracle | 9.33e-15 | ≤ 1e-8 | 1e-8 | PASS |
| HG-5: calibration constraint with q_unequal | 9.58e-9 | ≤ 1e-6 | 1e-6 | PASS |
| HG-6: history records unit_scale exactly | identical() == TRUE | identical | exact | PASS |
| HG-7: absolute bounds logit vs oracle (bounds.const=TRUE) | ≤ 1e-8 | ≤ 1e-8 | **1e-8** | PASS |
| HG-8: bounded vs wide bounds produce different weights | max_diff > 1e-6 | outputs differ | exact inequality | PASS |
| HG-9: unequal base weights: new != old mean approach | max_diff = 0.063 | > 0 | exact inequality | PASS |
| HG-10: absolute bounds + q_unequal logit oracle | ≤ 1e-8 | ≤ 1e-8 | **1e-8** | PASS |

**HG-7 note:** Test uses `tolerance = 1e-8` in `expect_equal()`. Matches test-spec exactly.

**HG-10 note:** Test uses `tolerance = 1e-8` in `expect_equal()`. Matches test-spec exactly.

### `calibrate_logit()` — Error Paths

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| HGE-1: non-positive unit_scale | `surveywts_error_unit_scale_invalid` | same class | exact | PASS |
| HGE-2: wrong-length unit_scale | `surveywts_error_unit_scale_invalid` | same class | exact | PASS |
| HGE-3: NA in unit_scale | `surveywts_error_unit_scale_invalid` | same class | exact | PASS |
| HGE-4: base weight below L_abs (logit precondition violation) | `surveywts_error_bounds_invalid_calibration` | same class | exact | PASS |
| HGE-5: base weight above U_abs (logit precondition violation) | `surveywts_error_bounds_invalid_calibration` | same class | exact | PASS |

### Replicate Loop

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| RL-1: linear replicate, q_unequal, full-sample matches oracle | ≤ 1e-8 | ≤ 1e-8 | 1e-8 | PASS |
| RL-2: linear replicate NULL vs rep(1,n) identical | 0 (machine precision) | ≤ 1e-14 | 1e-14 | PASS |
| RL-3: logit replicate, q_unequal, full-sample matches oracle | ≤ 1e-8 | ≤ 1e-8 | 1e-8 | PASS |
| RL-4: logit replicate NULL vs rep(1,n) identical | 0 (machine precision) | ≤ 1e-14 | 1e-14 | PASS |
| RL-5: linear replicate, absolute bounds, all weights in [L,U] | all TRUE | bounds satisfied | exact | PASS |
| RL-6: logit replicate, absolute bounds, constraint holds | 3.93e-9 | ≤ 1e-6 | 1e-6 | PASS |

### Edge Cases

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| EC-1: single-row with unit_scale=2.0 | test_invariants PASS; finite weight | converges | — | PASS |
| EC-2: uniform small q=0.01 — constraint holds | ≤ 1e-8 | ≤ 1e-8 | 1e-8 | PASS |
| EC-3: uniform large q=100 — constraint holds | ≤ 1e-8 | ≤ 1e-8 | 1e-8 | PASS |
| EC-4: extreme single q=1e8 — converges or singular error | PASS (either branch) | converges or errors cleanly | — | PASS |
| EC-5: explicit rep(1,n) identical to NULL | 0 (machine precision) | ≤ 1e-14 | 1e-14 | PASS |
| EC-6: linear bounded c(0.5,2) + q_unequal — g-weights in [0.5,2] | all TRUE | bounds satisfied | exact | PASS |
| EC-7: logit bounded c(0.3,3) + q_unequal — g-weights in (0.3,3) | all TRUE | bounds satisfied | exact | PASS |
| EC-8: equal base weights absolute bounds — pre/post-fix identical | bounds satisfied | bounds satisfied | 1e-8 | PASS |
| EC-9: unequal base weights linear — all final weights in [L_abs, U_abs] | all TRUE | bounds satisfied | exact | PASS |
| EC-10: unequal base weights logit — all final weights in (L_abs, U_abs) | all TRUE; constraint 3.93e-9 | ≤ 1e-6 | 1e-6 | PASS |

---

## Tolerance Compliance Verification (HL-8, HL-11, HG-7, HG-10)

This section documents the specific fix that triggered re-validation.

**Previous audit (audit.md):** HL-8 and HG-7 were reported with tolerance `1e-6`. This did not match test-spec which requires `1e-8` for oracle comparisons against `survey::calibrate()`.

**Fix applied:** Tests updated to use:
- HL-8 (`test-calibrate-linear.R` line 1608): `tolerance = 1e-8`; plus `control = list(epsilon = 1e-10)` to ensure NR converges tight enough to meet the tolerance.
- HL-11 (`test-calibrate-linear.R` line 1752): `tolerance = 1e-8`; plus `control = list(epsilon = 1e-10)`.
- HG-7 (`test-calibrate-logit.R` line 1472): `tolerance = 1e-8`.
- HG-10 (`test-calibrate-logit.R` line 1611): `tolerance = 1e-8`.

**Verification:** All four tests pass at `tolerance = 1e-8` in the full test run (FAIL 0, PASS 3208). The tolerances now match the test-spec oracle comparison requirement of `1e-8` exactly.

---

## Summary

All profile gates pass. CRAN cookbook scan is clean. Before/After shows +275 tests passing over baseline, 0 regressions, coverage 98.35%. The four tests previously flagged (HL-8, HL-11, HG-7, HG-10) now use `tolerance = 1e-8` as required by the test-spec and all pass at that tolerance.

**Verdict: PASS**
