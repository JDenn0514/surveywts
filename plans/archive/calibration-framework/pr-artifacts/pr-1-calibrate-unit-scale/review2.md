# Review2 — PR 1: calibrate-unit-scale

**Verdict:** PASS
**Date:** 2026-06-09
**Audit reviewed:** audit2.md

---

## Step 1 — Convergence check

All spec §Function contracts items (D1 u_vec, D2 Jacobian, D3 step-halving,
D6 per-unit absolute bounds, q_weights = NULL resolution, logit calfun vector
L/U fix, precondition check for logit absolute-bounds) have corresponding rows
in audit2 §Per-Test Result Table. Edge cases EC-1 through EC-10 and error paths
HLE-1 through HLE-5, HGE-1 through HGE-5 are all present and PASS.

No convergence gaps.

## Step 2 — Tolerance Integrity

Primary focus (the STOP reason from review.md):

| Test | test-spec tolerance | audit2 tolerance | Match |
|------|---------------------|------------------|-------|
| HL-8 | `1e-8` | `1e-8` | YES |
| HL-11 | `1e-8` | `1e-8` | YES |
| HG-7 | `1e-8` | `1e-8` | YES |
| HG-10 | `1e-8` | `1e-8` | YES |
| HL-1/HG-1 regression guards | `1e-14` | `1e-14` | YES |
| HL-2/HL-3/HL-4 oracle | `1e-8` | `1e-8` | YES |

All tolerances in audit2 match test-spec. No looser tolerance violations.

## Step 3 — Scope discipline

Implementation.md write surface (three R source files, two test files,
helper-test-data.R, changelog entry) matches impl-plan write surface.
`plans/error-messages.md` listed in impl-plan as a file to modify, but
implementation.md documents it was already updated in prior PRs — no new
error classes were added. Spec confirms "No new error or warning classes."
No extra files; no missing files.

## Step 4 — CRAN cookbook + profile gates

Audit2 reports no CRAN cookbook violations. `R CMD check --as-cran`: 0 errors,
0 warnings, 1 pre-approved note (`checking CRAN incoming feasibility`). All
profile gates pass. `pkgdown::build_site()` skipped per allowed condition
(no new exported functions).

## Step 5 — Coverage

98.35% — above 98% target and well above 95% STOP threshold. No drop in new
lines; new q_weights NULL/non-NULL branches covered.

## Step 6 — Comprehension alignment

No `comprehension.md` present for this PR. Step skipped.

---

**Verdict: PASS**

All convergence gaps: none. Tolerance violations: none. Scope: matches plan.
CRAN cookbook: clean. Coverage: 98.35%. Audit2 verdict: PASS.
