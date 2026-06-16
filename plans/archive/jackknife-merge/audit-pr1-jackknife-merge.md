# Audit — PR 1: feature/jackknife-dagjk-engine

**Date:** 2026-06-16
**Auditor:** tester agent
**Branch audited:** develop (post-merge)
**Test-spec:** plans/test-spec-jackknife-merge.md
**Verdict: PASS**

---

## Profile Gates

| Gate | Result | Notes |
|------|--------|-------|
| `devtools::document()` — NAMESPACE/man drift | PASS | `git diff --exit-code NAMESPACE man/` returned exit 0 after document() |
| `devtools::test()` | PASS | 3676 passing, 0 failing, 4 skipped |
| `devtools::run_examples()` | Covered by check below | |
| `R CMD check --no-manual` | PASS | 0 errors, 0 warnings, 0 notes |
| `pkgdown::build_site()` | SKIPPED | Pre-pkgdown scope (skip condition per test-spec) |
| `covr::package_coverage()` | PASS | 97.86% (above 95% floor) |

---

## Before/After Comparison

| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| Tests passing | 3676 | 3676 | 0 |
| Tests failing | 0 | 0 | 0 |
| Tests skipped | 4 | 4 | 0 |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 0 | 0 | 0 |
| Coverage | (not recorded pre-PR) | 97.86% | — |

No regressions detected.

---

## Grep Check Results

| Check | Command | Result |
|-------|---------|--------|
| No `surveywts_*_dagjk` in `jackknife-dagjk-utils.R` | `grep -rn "surveywts_.*_dagjk" R/jackknife-dagjk-utils.R` | 0 hits — PASS |
| No `surveywts_*_dagjk` in `create_group_jackknife_weights.R` | `grep -rn "surveywts_.*_dagjk" R/create_group_jackknife_weights.R` | 0 hits — PASS |
| No `.validate_groups_arg` anywhere in `R/` | `grep -rn "\.validate_groups_arg" R/` | 0 hits — PASS |

---

## Structural Check: `R/jackknife-dagjk-utils.R`

File exists: YES

Helpers defined (exactly 3 expected):

| Helper | Present |
|--------|---------|
| `.validate_replicates_dagjk_arg()` | YES |
| `.dagjk_single_replicate()` | YES |
| `.dagjk_single_replicate_calib()` | YES |

No `dagjk_*` error/warning class strings appear in the file. The string `dagjk`
appears only in the internal function name `.validate_replicates_dagjk_arg()`
(correct — internal function names were not renamed, only error/warning classes).

---

## Targeted Test File: `test-nps-group-jackknife.R`

Run: `devtools::test(filter = "nps-group-jackknife")`

Result: 0 failures, 3 skips, 0 errors.

Skips recorded (all pre-existing, not regressions):

1. `create_group_jackknife_weights() errors when all replicates fail` — ipw() failed on tiny data; cannot test all-fail path
2. `create_group_jackknife_weights() errors (all fail) when N_hat_g < n_nps_g` — ipw() failed; cannot test negative adjustment factor path
3. `create_group_jackknife_weights() calibration-only: poststratify dispatch` — poststratify failed on fixture; skip

---

## CRAN Cookbook Scan (Modified R/ Files)

Files scanned: `R/jackknife-dagjk-utils.R`, `R/create_group_jackknife_weights.R`

| Pattern | Hits | Verdict |
|---------|------|---------|
| `<<-` (super-assignment) | 0 | PASS |
| `library()` / `require()` | 0 | PASS |
| `set.seed()` | 1 (in `create_group_jackknife_weights.R:328`) | PASS — appears inside a user function that accepts a `seed` argument to make randomness reproducible; this is correct and standard practice |
| `Sys.setenv()` | 0 | PASS |
| `options()` (top-level) | 0 | PASS |

No CRAN cookbook violations.

---

## Snapshot File Check

`tests/testthat/_snaps/nps-group-jackknife.md` — the 5 occurrences of `dagjk`
in this file are all the internal function name `.validate_replicates_dagjk_arg()`
(the R error traceback shows the calling function name). No error/warning class
strings with `dagjk_*` appear in the snapshots. All snapshot error classes use
`jackknife_*` naming. Snapshots are current (test suite passed without snapshot
failures).

---

## PR 2 Scope — Deferred Items

The following test-spec scenarios are NOT covered by the current test suite and
are deferred to PR 2. These are not BLOCK items.

| Scenario | Test file (PR 2) | Notes |
|----------|-----------------|-------|
| `create_jackknife_weights()` — all four dispatch paths | `test-replicate-weights.R` (additions) | New function, not yet in repo |
| JKn / JK1 happy paths with `gss_2024_svy` | `test-replicate-weights.R` | Requires `create_jackknife_weights()` |
| Numerical oracle: JKn/JK1 replicate count vs `survey::as.svrepdesign` | `test-replicate-weights.R` | Requires `create_jackknife_weights()` |
| `type = "grouped"` + `survey_taylor` happy path | `test-replicate-weights.R` | Requires `create_jackknife_weights()` |
| `replicates`/`seed` silently ignored for jkn/jk1 | `test-replicate-weights.R` | Requires `create_jackknife_weights()` |
| `...` non-empty error | `test-replicate-weights.R` | Requires `create_jackknife_weights()` |
| `create_replicate_weights(method = "jackknife", type = "grouped")` pass-through | `test-replicate-dispatch.R` | Requires `create_jackknife_weights()` |
| `create_replicate_weights(method = "group-jackknife")` errors | `test-replicate-dispatch.R` | Requires updated dispatcher |
| Test file rename: `test-nps-group-jackknife.R` → `test-nps-jackknife.R` | — | Rename happens in PR 2 |

---

## Verdict

**PASS**

- 0 new test failures vs baseline (3676/3676 tests passing)
- 0 errors, 0 warnings, 0 notes in `R CMD check`
- All 3 grep checks: 0 hits
- `R/jackknife-dagjk-utils.R` exists with exactly the 3 expected helpers
- No regressions in `test-nps-group-jackknife.R`
- Coverage at 97.86% (above 95% floor)
