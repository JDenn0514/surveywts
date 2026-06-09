# Review — calibration-framework PR 1: NR engine infrastructure

**Branch:** `feature/calibration-nr-engine`
**Reviewer:** claude-sonnet-4-6
**Date:** 2026-06-08
**Verdict:** PASS

---

## Step 1 — Convergence check

PR 1 is infrastructure-only. No public-API function contracts from
`spec-calibration-framework.md §Function contracts` ship in this PR. The
test-spec explicitly assigns oracle tests (N1, N2) and all public-function
scenarios to PRs 2–4. All 87 new tests in `test-calibrate-utils-nr.R` cover
the internal helpers that are the spec scope of PR 1: validators, calfun
objects, the NR engine, and the updated `.build_calibration_provenance()`.

Every internal helper listed in `impl-calibration-framework.md §PR 1` has
a corresponding test row in `audit.md §Per-Test Result Table`. No gap.

**Note — convergence criterion wording:** `spec-calibration-framework.md`
describes the NR convergence criterion as `max_j |sum_k w_k x_kj - t_xj| <
epsilon` (absolute). The impl plan overrides this with `max(|misfit| /
(1 + |population|)) < epsilon` (relative, from grake.R), which is what the
`survey` package actually uses. The implementation follows the impl plan
correctly. The spec text is imprecise about what "matches survey::calibrate()
epsilon semantics" means. This is a planner inaccuracy, not a builder error.
It is a BLOCK for the planner on a future PR that adds oracle tests — if the
oracle tests pass (they will, because the criterion matches survey), no
observable difference exists.

---

## Step 2 — Tolerance Integrity check

`test-spec-calibration-framework.md §Tolerances` applies to PRs 2–5 (public
functions). PR 1 has no per-function tolerance table. The audit's numerical
assertions use tolerances consistent with the test-spec defaults (`1e-6` for
calibration constraint satisfaction, `1e-10` for weight computation). No
relaxation detected.

---

## Step 3 — Scope discipline check

`git diff develop..feature/calibration-nr-engine -- 'R/*.R'` shows exactly
one file modified: `R/calibrate-utils.R`. This matches the impl plan's PR 1
write surface. No NAMESPACE changes, no man/ changes, no other R/ files
touched.

The audit's write surface lists: `R/calibrate-utils.R`, `plans/error-messages.md`,
test file, snapshot file, changelog, and `implementation.md`. All are in scope.

The impl plan stated `.calibrate_engine()` would be "moved from
`R/calibrate_greg.R` into `calibrate-utils.R`." In fact, `.calibrate_engine()`
has always lived in `R/utils.R` (not `calibrate_greg.R`), and was not moved.
`.calibrate_nr_engine()` was added as a new function to `calibrate-utils.R`.
The acceptance criterion — "`calibrate_rake()` still passes all existing tests
after migration" — passes (149 tests, 0 failures). The impl plan description
was inaccurate about the source location, but the behavioral requirement is
satisfied and the write surface is clean.

No regressions in tests outside PR 1 scope (0 failures vs 0 before; audit
before/after table confirms).

---

## Step 4 — CRAN cookbook sanity

`audit.md §CRAN Cookbook Violations` shows "None" for all 9 categories.
Audit verdict is PASS. Clean.

---

## Step 5 — Coverage floor check

Coverage: 96.85% (up from 96.77%). Above the 95% block threshold. No
regression in new lines. The impl plan explicitly exempts PR 1 from the
98% target; NR engine coverage lands in PR 2.

---

## Step 6 — Comprehension alignment

`comprehension-calibration-framework.md` gotchas relevant to PR 1:

- **Bounds apply to g-weight ratio, not raw weight**: The `calfun` objects
  operate on `u = x' * lambda` and return `F(u)`, which is the g-weight.
  Tests assert g-weights are in `(0.3, 3)` for logit calfun. Aligned.
- **Linear method is single-step**: Tests confirm `n_iterations = 1L`.
  Aligned.
- **Singular T_x matrix**: `surveywts_error_calibration_singular_system`
  added to error-messages.md and tested. Aligned.
- **NR convergence tolerance**: The impl plan documents the grake.R origin.
  The implementation follows this. Aligned.
- **Redundant equation in marginal calibration**: Deferred to PR 2+ oracle
  tests as permitted by test-spec. Aligned.

---

## Verdict: PASS

All checks pass. No tolerance violations, no scope creep, no coverage
regression, no CRAN cookbook violations, no comprehension gaps.
