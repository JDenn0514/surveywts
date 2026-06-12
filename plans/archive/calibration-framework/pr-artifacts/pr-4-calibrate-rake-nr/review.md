# Review — PR 4: calibrate_rake() NR path + calibrate() dispatcher

**Verdict: STOP**
**Date:** 2026-06-09
**Reviewer:** reviewer agent (claude-sonnet-4-6)
**Audit reviewed:** `plans/calibration-framework/pr-4-calibrate-rake-nr/audit3.md`

---

## Step 1 — Convergence check

Spec §calibrate_rake defines 14 happy-path scenarios, 20 error paths, 4 warning
paths, 1 message path, and 9 edge cases. The audit table covers H1–H8, H10–H13,
N1, EC3, EC5–EC8, E17–E18, W1–W3, and the "survey" algorithm arg_match case.

**Gaps:**

1. **H14 / W1 — SRS warning absent from test file and implementation.**
   Test-spec H14 requires `calibrate_rake()` to emit
   `surveywts_warning_srs_no_weights` when called with a plain `data.frame` and
   `weights = NULL`. The implementation (`R/calibrate_rake.R`) never calls
   `cli::cli_warn(..., class = "surveywts_warning_srs_no_weights")`. The test
   file (`tests/testthat/test-03-rake.R`) has no `expect_warning` block for this
   class. The audit table rows for H14 and W1 claim pass — these are phantom
   entries with no corresponding test or implementation. This is an audit
   integrity failure.

2. **N2 oracle test missing.**
   Test-spec §calibrate_rake §Numerical oracle and impl-plan PR 4 acceptance
   criteria both require N2: `classic_ipf` results must match
   `survey::rake()` within `1e-6`. `test-03-rake.R` contains N1 (NR vs
   `survey::calibrate(calfun="raking")`) but has no N2 block. The audit table
   does not mention N2. Gap is traceable to the tester.

---

## Step 2 — Tolerance Integrity check

Test-spec §calibrate_rake EC7: "Weight conservation (`type = "count"`) —
tolerance `1e-10`."

`tests/testthat/test-03-rake.R` line 1442:
```r
expect_equal(sum(w), 300, tolerance = 1e-6)
```

The audit EC8 row records tolerance `1e-6`. This is a looser tolerance than the
test-spec mandates (`1e-10`). This is a **Tolerance Integrity violation**.

EC7 (`type = "prop"`, tolerance `1e-10`) is correctly implemented at line 1420.
Only the count-conservation path is relaxed.

---

## Step 3 — Scope discipline check

Implementation write surface matches `impl-calibration-framework.md` PR 4 entry
with one deliberate deviation: `R/utils.R` was modified (NA-error fn_name update
and `.format_history_step()` legacy arm retained), but the `"calibrate_linear"`
and `"calibrate_logit"` switch cases were not added. The File Surface Summary
assigns those additions to PR 5, so this is correctly deferred — not a scope
violation. All other file changes match the declared write surface.

`R/calibrate_greg.R` is deleted. `grep -r "calibrate_greg(" R/` returns only
comments in `calibrate-utils.R` and `utils.R` (comment text, not function
calls). Zero actual call sites remain. Scope discipline is clean for this item.

---

## Step 4 — CRAN cookbook check

Audit3 §CRAN Cookbook Violations: "None." No violations in changed files.
All profile gates have a result or documented skip. Clean.

---

## Step 5 — Coverage floor check

Package total: 97.59% (above 95% block threshold and 98% target).
No file falls below 92%. Coverage increased +0.74 pp vs baseline.
The `# nocov` markers in `calibrate_rake.R` cover the anesrake partial-
convergence and re-raking branches; both are correctly documented as defensive
unreachable paths. Coverage gate: OK.

---

## Step 6 — Comprehension alignment

`comprehension.md` gotcha "Unbounded upper g-weights" and "Redundant equation
in marginal calibration" are flagged as documentation-only and engine-internal
respectively in the test-spec — not standalone test items. Both are covered
implicitly by N1 oracle. N1 passes. No comprehension gap.

---

## Violations requiring resolution before PASS

| # | Category | Severity | Description |
|---|----------|----------|-------------|
| 1 | Tolerance Integrity | **STOP** | EC8 audit row uses tolerance `1e-6`; spec EC7 mandates `1e-10` for `type = "count"` weight conservation in `calibrate_rake()` |
| 2 | Audit integrity | **STOP** | Audit H14 and W1 claim pass for `surveywts_warning_srs_no_weights` in `calibrate_rake()`; no such test exists in `test-03-rake.R` and the implementation does not emit this warning |
| 3 | Spec coverage gap | **BLOCK** | N2 oracle test (`classic_ipf` vs `survey::rake()`, tolerance `1e-6`) absent from `test-03-rake.R` and the audit; traceable to tester |

---

## Required actions before resume

1. **STOP #1 (Tolerance Integrity):** Change `test-03-rake.R` line 1442 from
   `tolerance = 1e-6` to `tolerance = 1e-10`. If the renormalization in
   `calibrate_rake.R` (post-hoc `new_weights * (nr_target_total / sum(new_weights))`)
   does not achieve 1e-10 for count targets, the renormalization logic must be
   corrected so it does.

2. **STOP #2 (Audit integrity):** Add `surveywts_warning_srs_no_weights` emission
   to `calibrate_rake()` for the plain `data.frame` + `weights = NULL` path
   (matching the pattern in `calibrate_linear.R` lines 228–234). Write the
   corresponding `expect_warning(class = "surveywts_warning_srs_no_weights")`
   test block. Re-run audit.

3. **BLOCK #3 (N2 missing):** Add the N2 oracle test block to `test-03-rake.R`:
   `classic_ipf` calibrated weights vs `survey::rake()` within `1e-6`;
   `skip_if_not_installed("survey")` inside the block.

All three items must be resolved in a re-implementation and re-audit pass before
this PR may be re-submitted for review.
