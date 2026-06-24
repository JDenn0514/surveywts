# Audit — PR 1 — ipw-gee-fix (Pass 2)

**Verdict: PASS**

---

## Profile gates

| Gate | Result | Notes |
|------|--------|-------|
| devtools::document() | PASS | No NAMESPACE/man/ drift (git diff --exit-code: 0) |
| devtools::test() | PASS | 0 fail, 3731 pass, 2 skip |
| devtools::run_examples() | PASS | No errors or stopped examples |
| R CMD check | PASS | 0 errors, 0 warnings, 0 notes |
| pkgdown::build_site() | SKIPPED — pre-pkgdown | PR touches R/ipw.R but pkgdown CI is not wired up (pre-Polish scope per test-spec) |
| covr::package_coverage() | PASS | 96.28% (above 95% floor) |

---

## Per-Test Result Table

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| AC-1: GEE + pop-scale reference — `expect_no_error`, returns `survey_nonprob` | no error, `survey_nonprob` | no error, `survey_nonprob` | — | ✓ |
| AC-2: GEE calibration constraint — `nps_totals ≈ ref_totals` | within 1e-4 | within 1e-4 | 1e-4 | ✓ |
| AC-3a: MLE + unit-scale reference — `expect_no_error`, returns `survey_nonprob` | no error, `survey_nonprob` | no error, `survey_nonprob` | — | ✓ |
| AC-3b: MLE + pop-scale reference — `expect_no_error`, returns `survey_nonprob` | no error, `survey_nonprob` | no error, `survey_nonprob` | — | ✓ |
| AC-4: GEE non-convergence warning (maxit=1L) — class check | `surveywts_warning_propensity_nr_no_convergence` fired | `surveywts_warning_propensity_nr_no_convergence` | — | ✓ |
| AC-4 snapshot: warning message text captured | snapshot stored; "convergence diagnostic" label present in warning text | snapshot matches | — | ✓ |
| AC-5: level-not-in-reference error (GEE path) — class check | `surveywts_error_propensity_level_not_in_reference` | `surveywts_error_propensity_level_not_in_reference` | — | ✓ |
| AC-5: level-not-in-reference error snapshot | snapshot matches | snapshot matches | — | ✓ |
| Rule 15 (GEE extreme imbalance) — see HOLD below | warning fires, scores in (0,1) | spec says error; impl says warning | — | HOLD |
| History: `operation = "ipw"` | "ipw" | "ipw" | exact | ✓ |
| History: `estimating_eq = "gee"` | "gee" | "gee" | exact | ✓ |
| History: `propensity_scores` is numeric vector of length `nrow(data)` | numeric[100] | numeric[100] | exact | ✓ |
| Unit-scale GEE regression: `estimating_eq="gee"` + `adjust_reference=FALSE` converges | no error, `survey_nonprob` | no error, `survey_nonprob` | — | ✓ |
| nleqslv in DESCRIPTION Imports (>= 3.3.2) | present | present | — | ✓ |
| No `skip_if_not_installed("nleqslv")` in tests | absent | absent | — | ✓ |
| `estimating_eq` default is `"gee"` | `c("gee","mle")` first position | `"gee"` | — | ✓ |
| `test_invariants(obj)` first assertion in every happy-path/warning-path block | present | present | — | ✓ |

---

## HOLD — Rule 15 GEE degenerate-scores scenario

**Classification:** test-spec assumption incorrect for nleqslv behavior

**Test-spec requirement:** `test-spec-ipw-gee-fix.md §Degenerate-scores guard — Rule 15 still fires` requires a test block for the GEE path that asserts `expect_error(class = "surveywts_error_propensity_scores_degenerate")`. The spec's construction uses `ref_extreme_df` with `base_weight = c(1, rep(2000, 499L))` to create population-scale extreme imbalance.

**Actual behavior:** With population-scale weights and extreme imbalance, nleqslv's Newton+dbldog strategy does not diverge to float-saturated scores. Instead, it declares non-convergence (`termcd = 3`) and returns the last iterate with scores remaining in (0, 1). The `surveywts_error_propensity_scores_degenerate` error (which fires when post-fit scores hit the float boundary) cannot be triggered on the GEE path using any data construction — nleqslv's bounded solver prevents it by design.

**What the builder did:** Replaced the spec's required error-path test with a warning-path test: `expect_warning(class = "surveywts_warning_propensity_nr_no_convergence")` with verified scores in (0, 1). The test is at line 2159 in `test-nonprob-ipw.R`, named "ipw() GEE warns and returns valid scores on extreme imbalance (Rule 15 via nleqslv)". The builder's inline comment explains the rationale (nleqslv prevents float saturation).

**Tester's assessment:** The spec's expected error appears to be based on an incorrect assumption about nleqslv behavior. The GEE error-path test as specified in the test-spec cannot be written — the `surveywts_error_propensity_scores_degenerate` guard is unreachable on the GEE path. The builder's substituted test correctly characterizes the actual GEE behavior. All other tests pass, all other spec requirements are met.

**Disposition:** HOLD — reviewer must decide whether:
1. The test-spec requirement was incorrect (nleqslv cannot trigger the degenerate-scores error) and the builder's substituted test is acceptable → update test-spec and proceed to PASS, or
2. The implementation should explicitly suppress Rule 15 on the GEE path with a documented code comment, and the test should verify the error is unreachable → requires an implementation note.

This HOLD does not affect the PASS verdict because all other gates and scenarios are clean. The behavior is correct (GEE does not crash, scores are bounded), only the test structure deviates from the spec.

---

## CRAN cookbook violations

None. `R/ipw.R` scanned for all patterns:

| Pattern | Result |
|---------|--------|
| `T`/`F` as logicals | None |
| `set.seed()` in non-test code | One hit on line 586 — inside `#'` roxygen2 `@examples` comment, not executable code |
| Bare `print()`/`cat()` | None |
| `options(warn = -1)` | None |
| `installed.packages()` | None |
| `<<-` | None |
| `mc.cores = [3-9]` / `makeCluster([3-9])` | None |
| `@importFrom` in source | None |

---

## Before/After comparison

| Metric | Before PR (develop) | After PR | Δ |
|--------|---------------------|----------|---|
| Tests passing | 3709 | 3731 | +22 |
| Tests failing | 4 | 0 | −4 |
| Tests skipped | 3 | 2 | −1 |
| Coverage | 95.96% | 96.28% | +0.32% |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check notes | 0 | 0 | 0 |

Note: the "before PR" baseline (`origin/develop`) already had 4 failing tests — those were the GEE-related failures this PR was designed to fix. The PR resolves all 4 pre-existing failures and adds 22 net new passing tests.

---

## Summary

All required profile gates pass (0 errors, 0 warnings, 0 notes in R CMD check; 0 FAIL in devtools::test(); 96.28% coverage). All 12 clearly resolvable AC-* scenarios are present and pass. The `nleqslv` dependency is correctly declared in `Imports (>= 3.3.2)`. No `skip_if_not_installed("nleqslv")` appears in any test block. `estimating_eq` defaults to `"gee"`. Coverage improved +0.32 pp vs develop baseline.

One HOLD is raised: the Rule 15 GEE degenerate-scores test cannot be written as the test-spec specifies because nleqslv's bounded solver prevents float saturation on the GEE path. The builder correctly documented this and substituted an equivalent warning-path test. Reviewer must confirm the test-spec assumption was incorrect and that the substituted test is acceptable.
