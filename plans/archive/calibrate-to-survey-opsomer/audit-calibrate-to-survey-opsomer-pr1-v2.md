# Audit — calibrate-to-survey-opsomer PR 1 (v2)

**Date:** 2026-06-17
**Branch:** develop (commit bfa1322 + follow-up fixes merged)
**Verdict:** PASS

---

## Profile Gate Results

| # | Gate | Command | Result | Notes |
|---|------|---------|--------|-------|
| 1 | `devtools::document()` | `Rscript -e 'devtools::document()'` | PASS | `git diff --exit-code NAMESPACE man/` → NO DRIFT |
| 2 | `devtools::test()` | `Rscript -e 'devtools::test()'` | PASS | FAIL 0, WARN 624, SKIP 3, PASS 3630 |
| 3 | `devtools::run_examples()` | `Rscript -e 'devtools::run_examples()'` | PASS | Completed with 15 pre-existing warnings (no errors) |
| 4 | `R CMD build` | `R CMD build .` | PASS | Produced `surveywts_0.2.0.9000.tar.gz` |
| 5 | `R CMD check --as-cran` | `R CMD check --as-cran --no-manual <tarball>` | PASS | 0 errors, 0 warnings, 1 NOTE (pre-approved: CRAN incoming feasibility) |
| 6 | `pkgdown::build_site()` | — | SKIPPED — pre-pkgdown phase | No new exported functions; pre-pkgdown scope per roadmap |
| 7 | `covr::package_coverage()` | `Rscript -e 'covr::package_coverage()'` | PASS | 96.47% (above 95% gate; above 95% block threshold) |

---

## CRAN Cookbook Violations

Scan target: `R/calibrate_to_survey.R` (the only file changed by the PR in `R/`).

| File | Line | Violation | Class | Found |
|------|------|-----------|-------|-------|
| R/calibrate_to_survey.R | — | T/F as logicals | surveywts_error_tf_abbrev | None |
| R/calibrate_to_survey.R | — | Hardcoded `set.seed()` | surveywts_error_hardcoded_seed | Line 89 is in `@examples` block (not functional code) — no violation |
| R/calibrate_to_survey.R | — | Bare `print()`/`cat()` | surveywts_error_bare_print | None |
| R/calibrate_to_survey.R | — | `options(warn = -1)` | surveywts_error_suppress_warn_global | None |
| R/calibrate_to_survey.R | — | `installed.packages()` | surveywts_error_installed_packages | None |
| R/calibrate_to_survey.R | — | `<<-` | surveywts_error_global_assign | None |
| R/calibrate_to_survey.R | — | `@importFrom` | surveywts_error_importfrom | None |

**No violations found.**

---

## Before/After Comparison

| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| Tests passing | 3589 | 3630 | +41 |
| Tests failing | 0 | 0 | 0 |
| Tests skipped | 3 | 3 | 0 |
| Test warnings | 851 | 624 | -227 |
| Coverage | not recorded (baseline: 95%+) | 96.47% | — |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 0 | 1 (pre-approved) | +1 (pre-approved CRAN feasibility note) |

No regressions. Test count increased by 41 (new PR 1 tests). Coverage at 96.47% is above the 95% gate and well above the 95% block threshold.

---

## New Error Class Dual-Pattern Coverage

All 6 new error classes from the test-spec error table, each with both `expect_error(class=)` AND `expect_snapshot(error=TRUE)` in `tests/testthat/test-sample-calibration.R`.

| Error class | Triggers tested | expect_error | expect_snapshot | Snapshots present |
|-------------|----------------|--------------|-----------------|-------------------|
| `surveywts_error_scale_not_found` | primary NULL (targets=NULL), primary NULL (targets non-NULL), control NULL (targets non-NULL), control NULL (targets=NULL) | 4 | 4 | 4 in `_snaps/sample-calibration.md` |
| `surveywts_error_control_level_missing` | targets=NULL, targets non-NULL | 2 | 2 | 2 in `_snaps/sample-calibration.md` |
| `surveywts_error_targets_not_named_list` | unnamed element, empty list, not a list | 3 | 3 | 3 in `_snaps/sample-calibration.md` |
| `surveywts_error_targets_variable_not_found` | nonexistent column | 1 | 1 | 1 in `_snaps/sample-calibration.md` |
| `surveywts_error_targets_element_invalid` | string element, unnamed numeric vector | 2 | 2 | 2 in `_snaps/sample-calibration.md` |
| `surveywts_error_targets_totals_invalid` | count=0, count<0, count=NA, prop sum!=1 | 4 | 4 | 4 in `_snaps/sample-calibration.md` |

Total: 16 snapshot entries, 16 expect_error calls — complete dual-pattern coverage for all 6 new classes.

---

## Regression Guard Coverage

Existing error classes tested with `targets = NULL` (regression guards, sections 25+ in the test file):

| Error class | Guard test present |
|-------------|-------------------|
| `surveywts_error_primary_not_replicate` | Yes (section 25) |
| `surveywts_error_primary_no_repweights` | Yes (section 25) |
| `surveywts_error_control_not_replicate` | Yes (section 25) |
| `surveywts_error_control_no_repweights` | Yes (section 25) |
| `surveywts_error_reference_design_not_taylor` | Yes (section 25) |
| `surveywts_error_unit_scale_invalid` | Yes (section 25) |
| `surveywts_error_variables_not_found` | Yes (section 25) |

---

## New Argument Smoke Tests

| Scenario | Test block | Result |
|----------|-----------|--------|
| `type = "prop"` with `targets = NULL` accepted without error | Section 18 | PASS |
| `algorithm = "nr"` with `method = "linear"` accepted without error | Section 18 | PASS |
| `rlang::arg_match()` applied to `type` and `algorithm` in function signature | Code inspection of R/calibrate_to_survey.R lines 157-159 | Confirmed |

---

## `plans/error-messages.md` Update

All 6 new error classes are present and documented in `plans/error-messages.md`. Verified by grep.

---

## Summary

All profile gates passed. CRAN cookbook scan clean. Before/After shows +41 tests, no regressions. All 6 new error classes have complete dual-pattern coverage with snapshots committed. Regression guards for all 7 pre-existing error classes are present.

**Verdict: PASS**
