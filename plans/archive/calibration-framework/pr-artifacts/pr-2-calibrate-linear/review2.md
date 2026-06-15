# Review — PR 2 calibrate_linear() — Second Pass

**Branch:** `feature/calibrate-linear`
**Audit:** `audit2.md` (verdict PASS)
**Date:** 2026-06-09
**Reviewer verdict:** PASS

---

## Step 1 — Convergence check

Held `spec-calibration-framework.md §calibrate_linear contracts` against
`audit2.md §Per-Test Result Table`.

All 23 spec error classes covered (dual pattern confirmed for E1–E21 where
required; `class=` only for E22/E23 per testing-standards.md for non-CLI
paths). Note: the test file uses a shifted numbering scheme (test-file E18 =
spec E17 for bounds L>=1; test-file E19 = spec E18 for bounds U<=1; "Spec
E19/E20/E21" blocks cover the three new cases from first BLOCK). The
coverage is complete despite the renumbering.

All 4 warning paths present. All 11 edge cases present, including EC11 with
`> 1L` assertion. H_abs and E_abs (absolute bounds) present per impl plan
acceptance criteria. Spec quality gates 6 and 7 covered by EC8/EC9 and EC10.
No gap found.

**Comprehension alignment (comprehension.md gotchas):**
- Bounds-apply-to-g-weight gotcha → EC7 (multiplicative: assert g = new/base
  in [L, U], not raw weight) — COVERED.
- Linear-is-single-step gotcha → EC10 (`n_iterations == 1L`) — COVERED.
- Singular T_x gotcha → E22 (collinear variables) — COVERED.
- Negative-weights gotcha → W2/H10 — COVERED.

No comprehension gaps.

---

## Step 2 — Tolerance Integrity check

| Test | audit2 tolerance | test-spec tolerance | Match |
|------|-----------------|---------------------|-------|
| N1/N2 oracle | 1e-8 | 1e-8 | ✓ |
| Margin constraint (H1, H2) | 1e-8 / 1e-6 | 1e-8 / 1e-6 | ✓ |
| Weight conservation EC8/EC9 | 1e-10 | 1e-10 | ✓ |
| EC3 already-calibrated | 1e-8 | 1e-8 | ✓ |

No tolerance relaxations. No Tolerance Integrity violation.

---

## Step 3 — Scope discipline check

`implementation.md §Write surface`:
- Created: `R/calibrate_linear.R`, `tests/testthat/test-calibrate-linear.R`
- Generated: `man/calibrate_linear.Rd`, `NAMESPACE`
- NOT modified: `R/calibrate-utils.R` (read-only in PR 2 per impl plan)
- `R/calibrate_greg.R` NOT deleted (deferred to PR 4 per impl plan) — confirmed present.

`impl-calibration-framework.md §PR 2 Files`: identical list. No extra files
written. No missing files. No regressions outside PR scope (before/after table
shows 0 failures in both states).

---

## Step 4 — CRAN cookbook

`audit2.md §CRAN Cookbook Violations`: None. Profile gate 5 (R CMD check
--as-cran): 0 errors, 0 warnings, 1 pre-approved note. Clean.

---

## Step 5 — Coverage floor

`audit2.md §Profile gates`: `covr::package_coverage()` = 97.07%. Above 95%
floor. Delta vs baseline: +0.22% (no regression). New lines added by this PR
are exercised by 211 tests covering all branches in `calibrate_linear.R`.

---

## Step 6 — dF=1 correctness check

`R/calibrate-utils.R` `.make_calfun_linear()` lines 529–533: truncated-linear
case uses `dF = function(u) rep(1, length(u))` everywhere. Comment explicitly
notes this matches `survey::calfun.truncated`. The NR Jacobian remains
well-defined at the boundary (no zero columns) so the step direction is
always computed; clamping in `Fm1` creates the residuals that drive
subsequent iterations. This is the correct convention. Oracle test N2 passes
within 1e-8 against `survey::calibrate(calfun="linear", bounds=c(0.3,3))`
confirming numerical agreement.

---

## Verdict: PASS

All checks pass. No BLOCK or STOP conditions.
