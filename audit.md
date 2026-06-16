# audit.md — nps-calibration-path PR 2 (feature/nps-calib-dagjk)

**Verdict: PASS**
**Date:** 2026-06-16
**Tester:** claude-sonnet-4-6

---

## Profile Gate Results

| Gate | Result | Notes |
|------|--------|-------|
| `devtools::document()` NAMESPACE/man drift | PASS | `git diff --exit-code NAMESPACE man/` exits 0 |
| `devtools::test()` full suite | PASS | 3675 PASS, 0 FAIL, 4 SKIP, 851 WARN (expected) |
| `devtools::run_examples()` | PASS | 33 example files, all OK |
| `R CMD build .` | PASS | `surveywts_0.2.0.9000.tar.gz` built |
| `R CMD check --as-cran` | PASS | 0 errors, 0 warnings, 2 notes (both pre-approved) |
| `pkgdown::build_site()` | SKIPPED | Pre-pkgdown scope per test-spec |
| `covr::package_coverage()` | PASS | 97.86% (>=95% required; target 98%) |

### R CMD check notes (pre-approved)

1. `checking CRAN incoming feasibility` — version `0.2.0.9000` large component, vignette index missing, two dead URLs in Rd files. Informational; pre-approved.
2. `checking top-level files` — non-standard files `audit.md`, `implementation.md`, `review.md` in root. Pipeline artifacts not introduced by this PR.

---

## Per-Test Result Table

### Full suite

| Metric | Count |
|--------|-------|
| PASS | 3675 |
| FAIL | 0 |
| SKIP | 4 |
| WARN | 851 (incidental, expected) |

### DAGJK filter (`devtools::test(filter = "nps-group-jackknife")`)

| Metric | Count |
|--------|-------|
| PASS | 293 |
| FAIL | 0 |
| SKIP | 3 |
| WARN | 1 |

### Key scenario results

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| Calib-only Level A: survey_nonprob with 10 repweights | class survey_nonprob; length 10 | structural | exact | ✓ |
| Calib-only Level A: test_invariants() | passes | passes | n/a | ✓ |
| Calib-only Level A: history entry operation = "group_jackknife_weights" | present | present | structural | ✓ |
| Calib-only Level A: @variables$scale == 9/10 | 0.9 | 0.9 | 1e-12 | ✓ |
| Calib-only Level A: @variables$rscales = rep(1, 10) | rep(1, 10) | rep(1, 10) | exact | ✓ |
| Calib-only Level A: @variables$mse = TRUE | TRUE | TRUE | exact | ✓ |
| Calib-only Level A: @variables$type = "group-jackknife" | "group-jackknife" | "group-jackknife" | exact | ✓ |
| Calib-only Level A: each row exactly 1 zero across rep cols | all rows have 1 zero | 1 zero per row | structural | ✓ |
| Calib-only Level A: original columns unchanged | identical | identical | structural | ✓ |
| Calib-only Level A: weight conservation | rep_sum > 0 | positive | 1e-6 relative | ✓ |
| Calib-only Level A: seed reproducibility | repwt_1 identical on two runs | identical | structural | ✓ |
| Calib-only Level B: returns survey_nonprob | class survey_nonprob | structural | n/a | ✓ |
| Calib-only Level B: test_invariants() | passes | passes | n/a | ✓ |
| Dispatch calibrate_linear | survey_nonprob with >=1 repweights | structural | n/a | ✓ |
| Dispatch calibrate_logit | survey_nonprob with >=1 repweights | structural | n/a | ✓ |
| Dispatch poststratify | survey_nonprob with >=1 repweights | structural | n/a | ✓ |
| Regression: IPW-only path (datasets$A) | PASS | PASS | n/a | ✓ |
| Regression: doubly-robust Level A (datasets$B) | PASS | PASS | n/a | ✓ |
| Error surveywts_error_dagjk_requires_nonprob | class thrown | class thrown | dual pattern | ✓ |
| Error message: snapshot does NOT contain "IPW weighting history" | absent | absent | exact text | ✓ |
| Error surveywts_error_dagjk_no_history | class thrown | class thrown | dual pattern | ✓ |
| Error surveywts_error_dagjk_no_reference (Level B no ref) | class thrown | class thrown | dual pattern | ✓ |
| Error surveywts_error_reference_sample_class (data.frame ref) | class thrown | class thrown | dual pattern | ✓ |
| Error surveywts_error_dagjk_groups_invalid (groups = "10") | class thrown | class thrown | dual pattern | ✓ |
| Error surveywts_error_dagjk_groups_not_whole_number (groups = 10.5) | class thrown | class thrown | dual pattern | ✓ |
| Error surveywts_error_dagjk_groups_too_small (groups = 1L) | class thrown | class thrown | dual pattern | ✓ |
| Error surveywts_error_dagjk_groups_exceeds_n (groups = 501L on 500-row NPS) | class thrown | class thrown | dual pattern | ✓ |
| Error surveywts_error_dagjk_all_replicates_failed (corrupted formula) | class thrown | class thrown | dual pattern | ✓ |
| Warning surveywts_warning_dagjk_repweights_overwritten | class emitted | class emitted | expect_warning | ✓ |
| Warning surveywts_warning_dagjk_small_groups (groups = 499L on 500-row NPS) | class emitted | class emitted | expect_warning | ✓ |
| Warning surveywts_warning_dagjk_replicates_failed (partial failure) | class emitted | class emitted | expect_warning | ✓ |
| Edge: groups = 2L minimum | 1-2 repweights, no error | no error unless both fail | structural | ✓ |
| Edge: Level A with reference_sample supplied | no error | no error | structural | ✓ |
| Edge: groups ceiling uses n_A only (501 on 500-row) | error dagjk_groups_exceeds_n | error | structural | ✓ |
| IPW regression tests | 179 PASS, 0 FAIL | 0 FAIL | n/a | ✓ |

---

## Snapshot Verification

- `tests/testthat/_snaps/nps-group-jackknife.md`: does NOT contain "IPW weighting history". Confirmed.
- `tests/testthat/_snaps/replicate-weights.md`: does NOT contain "IPW weighting history". Confirmed.

---

## CRAN Cookbook Scan

Modified R/ file: `R/create_group_jackknife_weights.R`

| Pattern | Found | Status |
|---------|-------|--------|
| `library()` in R/ | None | PASS |
| `require()` in R/ (non-namespace) | None | PASS |
| `<<-` to global env | None in PR diff (1 pre-existing instance in utils.R is a tryCatch closure, not global) | PASS |
| `setwd()` | None | PASS |
| `T`/`F` bare logical in new code | None | PASS |

---

## Before/After Comparison

| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| Tests passing | 3621 | 3675 | +54 |
| Coverage | ~97.8% (estimated) | 97.86% | stable/slight gain |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 2 | 2 | 0 |

`create_group_jackknife_weights.R` coverage: 95.31% (above 95% floor). No regressions.
