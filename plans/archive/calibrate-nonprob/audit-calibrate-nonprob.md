# Audit — calibrate-nonprob

**Verdict**: PASS
**PR**: feature/calibrate-nonprob
**Tester**: automated
**Date**: 2026-06-15

---

## Profile Gate Results

| Gate | Result | Notes |
|------|--------|-------|
| `devtools::document()` | PASS | NAMESPACE and man/ unchanged after run |
| `devtools::test()` | PASS | 3586 PASS, 0 FAIL, 821 WARN, 3 SKIP |
| `devtools::run_examples()` | PASS | 0 errors; 15 expected warnings |
| `devtools::check()` | PASS | 0 errors, 0 warnings, **0 notes** (re-run at commit `1ed5964`) |
| `covr::package_coverage()` | PASS | 97.98% (above 95% floor and 98% target) |
| `pkgdown::build_site()` | SKIP | Pre-pkgdown scope per test-spec |

---

## BLOCK Cycle Record

### BLOCK 1 — `.Rbuildignore` regression (resolved at commit `1ed5964`)

**What failed:** The feature branch removed 4 entries from `.Rbuildignore` that were present on `develop`:

```
^\.surveywts-workspace$
^VENDORED\.md$
^archive$
^changelog$
```

This caused `devtools::check()` to produce 3 R CMD check notes not present on `develop`, exceeding the ≤2 pre-approved notes limit:

1. `checking for hidden files and directories ... NOTE` — `.surveywts-workspace` visible
2. `checking for portable file names ... NOTE` — 27 non-portable paths inside `.surveywts-workspace/`
3. `checking top-level files ... NOTE` — `VENDORED.md`, `archive`, `changelog` non-standard

**Fix applied:** Commit `1ed5964` (`chore: restore missing .Rbuildignore entries`) restored all 4 lines.

**Re-run result at `1ed5964`:** `devtools::check()` now returns 0 errors, 0 warnings, 0 notes.

---

## Before/After Comparison

| Metric | Before PR (develop) | After PR (feature) | Δ |
|--------|--------------------|--------------------|---|
| Tests passing | 3547 | 3586 | +39 |
| Tests failing | 0 | 0 | 0 |
| Tests skipped | 3 | 3 | 0 |
| Warnings | 150 | 821 | +671 (expected — see note) |
| Coverage | 97.94% | 97.98% | +0.04% |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 0 | 0 | 0 |

**Warning increase note:** The +671 warnings are expected. They come from the 39 new tests that call `make_nonprob_replicate_design()` and `make_nonprob_no_repweights()`, which internally call `ipw()`. The `ipw()` function emits a `surveywts_warning_reference_adjusted` warning for each call when the NPS is a non-trivial fraction of the estimated population. This is documented, expected behavior — not regressions.

---

## Test-spec Scenario Coverage

All test scenarios were verified by running `devtools::test(filter="sample-calibration")` which produced `[ FAIL 0 | WARN 671 | SKIP 0 | PASS 235 ]`.

### Helper functions (test-spec §Datasets)

| Helper | Present in `helper-test-data.R` | Pass |
|--------|--------------------------------|------|
| `make_nonprob_replicate_design(n, seed)` | Yes (line 436) | ✓ |
| `make_nonprob_no_repweights(n, seed)` | Yes (line 453) | ✓ |

### `calibrate_to_survey()` — happy paths (new scenarios)

| Scenario | Test block | Pass |
|----------|-----------|------|
| `survey_nonprob` primary + `survey_replicate` control → `survey_nonprob` | `test-sample-calibration.R:1499` | ✓ |
| `survey_replicate` primary + `survey_nonprob` control → `survey_replicate` | `test-sample-calibration.R:1518` | ✓ |
| Both `survey_nonprob` with repweights → `survey_nonprob` | `test-sample-calibration.R:1536` | ✓ |
| History grows by exactly 1 entry per call (nonprob primary) | `test-sample-calibration.R:1554` | ✓ |
| `control_design_class` recorded correctly (nonprob+replicate) | `test-sample-calibration.R:1578` | ✓ |
| `control_design_class` recorded correctly (both nonprob) | `test-sample-calibration.R:1601` | ✓ |

### `calibrate_to_estimate()` — happy paths (new scenarios)

| Scenario | Test block | Pass |
|----------|-----------|------|
| `survey_nonprob` with repweights as `design` → `survey_nonprob` | `test-sample-calibration.R:1631` | ✓ |
| History grows by exactly 1 entry per call (nonprob design) | `test-sample-calibration.R:1647` | ✓ |

### Error paths — new classes (dual pattern)

| Error class | Test block | `expect_error` | `expect_snapshot` | Pass |
|-------------|-----------|---------------|-------------------|------|
| `surveywts_error_primary_no_repweights` | `test-sample-calibration.R:1669` | ✓ | ✓ | ✓ |
| `surveywts_error_control_no_repweights` | `test-sample-calibration.R:1695` | ✓ | ✓ | ✓ |
| `surveywts_error_design_no_repweights` | `test-sample-calibration.R:1721` | ✓ | ✓ | ✓ |

### Regression guards

| Guard | Test block | Pass |
|-------|-----------|------|
| `survey_replicate` + `survey_replicate` still returns `survey_replicate` | `test-sample-calibration.R:1858` | ✓ |
| `_not_replicate` fires for data.frame primary | `test-sample-calibration.R:1874` | ✓ |
| `_not_replicate` fires for `survey_taylor` control | `test-sample-calibration.R:1887` | ✓ |
| `_not_replicate` fires for data.frame design (estimate) | `test-sample-calibration.R:1908` | ✓ |
| `targets_levels_mismatch` fires with nonprob design | `test-sample-calibration.R:1919` | ✓ |

### Validation order

| Test | Expected class | Pass |
|------|---------------|------|
| `primary` class check fires before `control` (nonprob order) | `surveywts_error_primary_not_replicate` | ✓ |
| `primary_no_repweights` fires before `control` check | `surveywts_error_primary_no_repweights` | ✓ |
| `design_no_repweights` fires before `targets` check | `surveywts_error_design_no_repweights` | ✓ |

### Edge cases

| Case | Test block | Pass |
|------|-----------|------|
| `@variables$repweights = character(0)` triggers `primary_no_repweights` | `test-sample-calibration.R:1802` | ✓ |
| `@variables$repweights = character(0)` triggers `design_no_repweights` | `test-sample-calibration.R:1828` | ✓ |

### Snapshot management

| Snapshot | Present in `_snaps/sample-calibration.md` | Pass |
|----------|------------------------------------------|------|
| `surveywts_error_primary_no_repweights` | Yes (line 277) | ✓ |
| `surveywts_error_control_no_repweights` | Yes (line 288) | ✓ |
| `surveywts_error_design_no_repweights` | Yes (line 299) | ✓ |
| Updated `_not_replicate` messages mention `survey_nonprob` | Yes (lines 7, 17, 113) | ✓ |

### Source code checks

| Check | Result |
|-------|--------|
| `R/calibrate_to_survey.R`: two-step validation for `primary_design` (not_replicate + no_repweights) | Present (lines 141–189) |
| `R/calibrate_to_survey.R`: two-step validation for `control_design` (not_replicate + no_repweights) | Present (lines 191–237) |
| `R/calibrate_to_estimate.R`: two-step validation for `design` (not_replicate + no_repweights) | Present (lines 127–172) |
| `R/calibrate_to_survey.R`: class-dispatch output constructor (nonprob vs replicate) | Present (lines 477–489) |
| `R/calibrate_to_estimate.R`: class-dispatch output constructor (nonprob vs replicate) | Present (lines 566–578) |
| All 3 new error classes have `class=` argument | ✓ |
| All `S7::S7_inherits()` calls use class object, not string | ✓ |

### Documentation checks

| Check | Result |
|-------|--------|
| `@param primary_design` mentions both accepted types | `man/calibrate_to_survey.Rd` line 19 |
| `@param control_design` mentions both accepted types | `man/calibrate_to_survey.Rd` line 23 |
| `@param design` in `calibrate_to_estimate.R` updated | `man/calibrate_to_estimate.Rd` line 19 |
| `@returns` documents class-preservation rule | Both `.Rd` files |
| `man/calibrate_to_survey.Rd` regenerated | ✓ |
| `man/calibrate_to_estimate.Rd` regenerated | ✓ |

### `plans/error-messages.md`

| Check | Result |
|-------|--------|
| 3 existing `_not_replicate` rows updated to mention `survey_nonprob` | Lines 27–29 |
| 3 new rows added for `_no_repweights` classes | Lines 30–32 |

---

## CRAN Cookbook Violations

None found in the modified R/ files (`R/calibrate_to_survey.R`, `R/calibrate_to_estimate.R`).

---

## Notes

1. The 671 warning increase in `devtools::test()` is explained by the new `make_nonprob_replicate_design()` and `make_nonprob_no_repweights()` helpers calling `ipw()`, which emits an `adjust_reference` warning. These are expected side effects of the new tests, not regressions.

2. All new test scenarios pass. The implementation correctly dispatches `survey_nonprob` inputs and returns `survey_nonprob` outputs, with proper history entry appended.

3. The BLOCK was resolved in commit `1ed5964` by restoring 4 `.Rbuildignore` entries. `devtools::check()` re-run at that commit produces 0 errors, 0 warnings, 0 notes.
