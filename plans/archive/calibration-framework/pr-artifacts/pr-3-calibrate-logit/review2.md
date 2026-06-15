# Review 2 — PR 3: calibrate_logit()

**Verdict: PASS**
**Date:** 2026-06-09
**Branch:** `feature/calibrate-logit`
**Re-review of:** `review.md` (previous BLOCK: H7 happy path for `reference_design` not tested)

---

## Step 1 — Convergence check

### H7 gap: resolved

Previous BLOCK: test-spec H7 (`reference_design` non-NULL → `targets_from_reference = TRUE` in
history) had no passing validation row in the audit.

Fix applied: block `H7b` added at line 242 of
`tests/testthat/test-calibrate-logit.R`. The block:
- Constructs a `survey_taylor` object as `ref`
- Calls `calibrate_logit(taylor, targets = targets, reference_design = ref)`
- Calls `test_invariants(result)` as first assertion
- Asserts `entry$parameters$targets_from_reference == TRUE`

This directly validates spec contract: "`reference_design` non-`NULL` → stored
in the history entry with `targets_from_reference = TRUE`." The block passes
(confirmed by `devtools::test(filter = "calibrate-logit")`: FAIL 0, PASS 183).

All other spec coverage items were clean in audit2 and remain unchanged.

---

## Step 2 — Tolerance Integrity check

No tolerance changes since audit2. All tolerances match test-spec:
- Oracle N1: `1e-8` — matches.
- Calibration constraint satisfaction: `1e-6` — matches.
- EC4 NR lambda constraint: `1e-5` — tighter than any spec floor; acceptable.

Tolerance Integrity: clean.

---

## Step 3 — Scope discipline check

Write surface for PR 3 per `impl-calibration-framework.md`:
- `R/calibrate_logit.R` — CREATE
- `tests/testthat/test-calibrate-logit.R` — CREATE
- `man/calibrate_logit.Rd` — generated
- `NAMESPACE` — generated
- `changelog/calibration-framework/feature-calibrate-logit.md` — CREATE

No extra files written. No files outside this surface were modified. The
`_snaps/calibrate-logit.md` snapshot artifact is an expected side-effect of
`expect_snapshot()` calls. Scope discipline: clean.

---

## Step 4 — CRAN cookbook sanity

Audit2 reports no CRAN cookbook violations in `R/calibrate_logit.R`.
No new source files added in the fix. Clean.

---

## Step 5 — Coverage floor check

Audit2 reports 96.85% overall coverage (above 95% floor). The H7b addition
exercises the `reference_design` branch in `calibrate_logit()` — this adds
coverage, not removes it. No regression. Coverage gate: clean.

---

## Step 6 — Comprehension alignment

All gotchas from `comprehension-calibration-framework.md` covered per audit2:
- Bounds apply to g-weight ratio: EC3 tests `all(new_wt / base_wt > L) &&
  all(new_wt / base_wt < U)`.
- Converged NR lambda: EC4 verifies `lambda_nr` satisfies the logit constraint.
- Non-convergence path: E22b tests `surveywts_error_calibration_not_converged`.
- `reference_design` history flag: H7b now validates it.

Comprehension alignment: clean.

---

## Verdict: PASS

All seven checks pass:
- Convergence: H7b present and passing; all test-spec H1–H10, N1, E1–E23, W1–W3,
  EC1–EC4 rows have passing audit-table entries.
- Tolerance Integrity: no looser tolerances.
- Scope discipline: write surface matches impl plan exactly.
- CRAN cookbook: no violations.
- Coverage: 96.85%, above 95% floor, no regression in new lines.
- Comprehension alignment: all gotchas covered.
- `audit2.md` verdict: PASS (with E22b/E23b now present).
- `devtools::test(filter = "calibrate-logit")`: FAIL 0, PASS 183.
