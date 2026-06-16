# Audit — PR 2: jackknife-merge (re-validation after reviewer BLOCK — missing test blocks)

**Verdict: PASS**
**Date:** 2026-06-16
**Branch:** develop (feature/jackknife-merge — 4 missing test blocks added)

---

## What Changed Since Previous Audit

The reviewer BLOCKED the prior PASS because 4 test blocks were absent from
`tests/testthat/test-nps-jackknife.R`. Those blocks have now been added:

1. `adj_method = "variance-units"` alone triggers `surveywts_warning_jackknife_svrep_args_ignored`
   (line 744)
2. Multiple non-default svrep args together emit exactly ONE warning (line 755)
3. Default svrep args emit NO warning — positive case (line 774)
4. `replicates_failed` warning test asserts `length(result@variables$repweights) < 5L`
   and scale = `(G_success - 1) / G_success` (lines 703-721)

---

## Profile Gates

| Gate | Result | Notes |
|------|--------|-------|
| `devtools::document()` — NAMESPACE/man/ drift | PASS | No drift from previous audit; NAMESPACE unchanged by this fix |
| `devtools::test(filter = "nps-jackknife")` | PASS | 137 PASS, 0 FAIL, 2 SKIP |
| `devtools::test()` — full suite | PASS | 3573 PASS, 0 FAIL, 3 SKIP |
| `R CMD check --as-cran` | PASS | 0 errors, 0 warnings, 0 notes |
| `pkgdown::build_site()` | SKIPPED | Pre-pkgdown phase per `plans/decisions-jackknife-merge.md` §2026-06-16 and test-spec §Profile gates |
| `covr::package_coverage()` | WARNING | 96.42% — above 95% floor; below 98% target |

---

## Targeted Test Run — `test-nps-jackknife.R`

| Metric | Count |
|--------|-------|
| PASS | 137 |
| FAIL | 0 |
| SKIP | 2 |

Skips have documented reasons (`ipw()` fails on tiny pathological data;
`skip_if(is.null(tiny_ipw), ...)` per test-spec skip condition).

### Confirmation — 4 New Test Blocks

| Block | Location | Result |
|-------|----------|--------|
| `adj_method = "variance-units"` alone warns `jackknife_svrep_args_ignored` | line 744 | PASS |
| Multiple non-default svrep args emit exactly one warning | line 755 | PASS |
| Default svrep args emit no warning | line 774 | PASS |
| `replicates_failed` asserts `length(result@variables$repweights) < 5L` and scale = `(G_success-1)/G_success` | line 710-714 | PASS |

---

## Full Suite

| Metric | Count |
|--------|-------|
| PASS | 3573 |
| FAIL | 0 |
| SKIP | 3 |

Up from 3568 PASS in the previous audit (+5 from the 4 new blocks, one of
which is the replicates_failed block that was already present but now has
additional assertions).

---

## R CMD check

```
0 errors | 0 warnings | 0 notes
```

Duration: 2m 10s. Clean.

---

## CRAN Cookbook Scan

Modified `R/` files scanned for: bare `T`/`F`, `<<-`, `assign()`,
`Sys.sleep()`, `library()`, `require()`.

**Result: 0 violations**

---

## Per-Test Result Table — Key Scenarios (All 4 New Blocks)

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| `adj_method = "variance-units"` warns `surveywts_warning_jackknife_svrep_args_ignored` | correct class | correct class | exact | ✓ |
| `adj_method = "variance-units"` + `scale_method = "variance-units"` emits exactly 1 warning | `n_warnings == 1L` | `1L` | exact | ✓ |
| Default `adj_method` emits no `surveywts_warning_jackknife_svrep_args_ignored` | no warning | no warning | exact | ✓ |
| `replicates_failed` → `length(result@variables$repweights) < 5L` | TRUE | TRUE | exact | ✓ |
| `replicates_failed` → scale = `(G_success - 1) / G_success` | correct fraction | correct fraction | `1e-12` | ✓ |

---

## Before/After Comparison

| Metric | Before reviewer BLOCK | After fix | Delta |
|--------|----------------------|-----------|-------|
| Tests passing (nps-jackknife filter) | 132 | 137 | +5 |
| Tests passing (full suite) | 3568 | 3573 | +5 |
| Coverage | 95.75% | 96.42% | +0.67pp |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 0 | 0 | 0 |

---

## Coverage — WARNING (not BLOCK)

**Overall: 96.42%** — above the 95% floor; below the 98% target.

Files below 100%:

| File | Coverage |
|------|----------|
| `R/jackknife-dagjk-utils.R` | 70.90% |
| `R/create_jackknife_weights.R` | 85.71% |
| `R/utils.R` | 91.31% |
| `R/replicate-utils.R` | 94.40% |

Coverage improved by 0.67pp from 95.75% to 96.42% following addition of the
4 new test blocks. Coverage is above the 95% floor; BLOCK threshold not met.
Classified as WARNING per audit instructions.

---

## Verdict: PASS

All conditions for PASS are met:

- All 4 required test blocks confirmed present and passing
- 0 test failures in targeted filter (`nps-jackknife`) and full suite
- 0 errors, 0 warnings, 0 notes in `R CMD check --as-cran`
- CRAN cookbook scan: 0 violations
- pkgdown gate: SKIPPED — pre-pkgdown (authorized deferral in `plans/decisions-jackknife-merge.md` §2026-06-16)

**WARNING (not BLOCK):** Coverage 96.42%, below 98% target but above 95% floor.
Reviewer should decide whether to require additional coverage for
`R/jackknife-dagjk-utils.R` (70.90%) and `R/create_jackknife_weights.R`
(85.71%) before merge.
