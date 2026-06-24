# Spec Review: ipw-gee-fix — Pass 1 (2026-06-24)

## New Issues

---

### Section: Scope / Architecture

No new issues found.

---

### Section: Function Contracts — `.fit_participation_propensity()` GEE branch

**Issue S1: termcd >= 4 edge case has no test in test-spec**
Severity: REQUIRED
Violates testing-standards.md §2 ("Every edge case in the spec gets a test row")

The spec's edge-cases table (Rule GEE-8 / edge cases table) explicitly lists:
> `termcd == 4L (singular Jacobian in nleqslv)` → `converged = FALSE`; warning issued

This is a documented edge case without a corresponding test row in test-spec.
The `surveywts_warning_propensity_nr_no_convergence` warning must fire for
`termcd >= 4`, but the test-spec only tests `termcd = 3` (via `maxit = 1L`).

The `termcd >= 4` path (singular/ill-conditioned Jacobian in nleqslv) is
difficult to trigger in practice because the Jacobian `−X^T diag((1−π)/π) X`
is positive semidefinite and becomes singular only when X is rank-deficient or
propensities are at 0/1. The level-not-in-reference guard (Rule 8) catches the
most common rank-deficiency case before nleqslv is called.

Options:
- **[A]** Add an explicit note to `test-spec-ipw-gee-fix.md` acknowledging that
  `termcd >= 4` is not directly testable in isolation and documenting why it is
  covered by the level-not-in-reference guard and the degenerate-scores post-fit
  check. Mark as "documented-untestable" edge case. Effort: low.
- **[B]** Add a test that passes a rank-deficient design matrix (e.g., only one
  NPS row, one constant predictor) that forces nleqslv to return termcd >= 4.
  This requires engineering a very specific numerical scenario. Effort: high,
  Risk: test fragility.
- **[C] Do nothing** — the warning path is tested via `termcd = 3` (maxit = 1L)
  and the warning-issuance logic is identical for all `termcd >= 3`. Leaves a
  gap in documentation.

**Recommendation: A** — document why this edge case is not directly tested. The
shared code path (`converged = FALSE` → warning) is verified by AC-4; the
specific trigger for termcd >= 4 is separately protected by pre-fitting guards.

---

### Section: Function Contracts — `ipw()` documentation updates

**Issue S2: spec does not specify which @details paragraph to update for MLE path**
Severity: SUGGESTION

The spec says: "Update [the `@details` non-convergence note] to distinguish:
'If the MLE algorithm does not converge…, or if the GEE path solver does not
converge…'." The spec names the details paragraph to update but does not quote
the existing text that is changing. This is sufficient for a builder who reads
the existing code, but could be made more precise.

Options:
- **[A]** Accept current spec wording as sufficient — builder can find the text.
- **[B]** Add exact existing text to replace and new text in the spec.

**Recommendation: A** — the builder has direct access to the source; quoting old
text in a spec is brittle.

---

### Section: Test-spec — Error paths

**Issue S3: degenerate-scores test note creates ambiguity for tester**
Severity: REQUIRED
Violates testing-standards.md §3 (warning capture must be unambiguous)

The test-spec for the degenerate-scores test (Rule 15 still fires) includes:
> "if nleqslv triggers non-convergence warning before the error, wrap the
> snapshot call in suppressWarnings() to isolate the error snapshot from the
> warning output."

This conditional instruction is ambiguous: the tester must decide at runtime
whether the warning fires, and must then choose between two forms of the same
test. The test-spec should specify unconditionally which form to use.

In the extreme-imbalance scenario described (1 reference row in "18-34" at
weight 1 vs. 499 rows at weight 2000 in "55+"), nleqslv will attempt to solve
the system and likely does NOT converge before the degenerate guard fires (the
post-fit check runs regardless of convergence). But if nleqslv issues
`termcd >= 4` the non-convergence warning will fire, meaning both the warning
and the error are expected. The tester should always use:

```r
suppressWarnings(
  expect_snapshot(error = TRUE, ipw(...))
)
```

for the snapshot call (the `expect_error(class = ...)` assertion does not need
wrapping — it captures the error class regardless of warnings). The test-spec
should state this unconditionally.

Options:
- **[A]** Update the test-spec degenerate-scores block to unconditionally wrap
  the `expect_snapshot()` call in `suppressWarnings()`. Add an explanatory note:
  "The extreme-imbalance scenario may also trigger `surveywts_warning_propensity_nr_no_convergence`
  before the degenerate error fires; wrapping the snapshot in `suppressWarnings()`
  prevents the warning from appearing in the snapshot." Effort: low.
- **[B]** Design a different degenerate scenario that does not trigger the
  non-convergence warning. Effort: medium, may not be possible.
- **[C] Do nothing** — ambiguous instruction leaves tester to figure it out.

**Recommendation: A** — unconditional suppressWarnings in the snapshot call.

---

### Section: Test-spec — Datasets

No new issues found. The use of inline synthetic datasets for the
population-scale scenario is correctly justified: no existing package dataset
provides the specific scale-divergence condition being tested.

---

### Section: Test-spec — Calibration constraint (AC-2)

No new issues found. The 1e-4 tolerance is justified and the model-matrix
reconstruction approach is correct.

---

### Section: Quality gates

**Issue S4: quality gate for warning-label update not specified**
Severity: SUGGESTION

The spec adds a documentation requirement (Rule GEE-7: update warning message
label to "convergence diagnostic = …"). There is no quality gate that verifies
the warning message was actually updated. This could be caught by the
non-convergence snapshot test (AC-4), but only if a snapshot exists for the
non-convergence warning.

Options:
- **[A]** Add AC-4's warning as a snapshot test (`expect_snapshot(warning = TRUE, ...)`)
  in addition to the existing `expect_warning(class = ...)`. This would catch
  message-text regressions. Effort: low.
- **[B]** Add a quality gate: "Non-convergence warning message contains the text
  'convergence diagnostic'" as a manual check. Effort: low.
- **[C] Do nothing** — the label update is a cosmetic documentation change and
  its presence can be verified in code review.

**Recommendation: A** — add a warning snapshot to AC-4 to catch message text
regressions. This is consistent with the dual-pattern principle (class + content).

---

### Section: Lens 1 — DRY

No duplication found. The spec cleanly separates GEE-branch rules (GEE-1
through GEE-9) from the "Out of scope" MLE path. No behavior is described
twice.

---

### Section: Lens 2 — Test Completeness

- Happy paths: GEE + population-scale ✓, GEE + unit-scale ✓, MLE + unit-scale ✓, MLE + population-scale ✓
- Calibration constraint ✓
- Warning path (non-convergence) ✓
- Error paths: level-not-in-reference ✓, degenerate-scores ✓ (with S3 fix needed)
- History entry correctness ✓
- nleqslv dependency documented ✓
- `test_invariants(obj)` specified as first assertion ✓
- Dual pattern for Layer 3 errors ✓
- termcd >= 4 gap: flagged as Issue S1 (REQUIRED — resolution A documents why untestable)

---

### Section: Lens 3 — Contract Completeness

- `.fit_participation_propensity()` argument table ✓
- Return value documented (scores, converged, final_delta) ✓
- Edge cases table ✓
- Error table ✓
- Warning table ✓
- Documentation tier for `ipw()`: Tier 3 — Algorithmic ✓ (stated in spec)
- `@section Algorithm` update requirement documented ✓
- `@section Convergence` update requirement documented ✓
- `@details` update requirement documented ✓
- `@examples` update requirement documented ✓
- `@references` unchanged ✓

The spec correctly notes this is modification of an existing Tier 3 function;
no full documentation contract is required, only the changed sections.

---

### Section: Lens 4 — Edge Cases

Edge cases explicitly covered in spec edge-cases table:
- `maxit = 1L` ✓
- Population-scale reference ✓
- Unit-scale reference ✓
- `termcd == 4L` ✓ (documented; test coverage addressed by Issue S1)
- NPS level absent from reference ✓

No unaddressed edge cases found for this scope.

---

### Section: Lens 5 — Engineering Level

Not under-engineered: all nine GEE behavioral rules are specific and implementable.
The saturation-guard restructuring is explicitly called out (Rule GEE-2) — this
is a subtle code-structure requirement that the spec correctly captures.

Not over-engineered: the fix modifies only what is broken (GEE branch solver)
and leaves everything else untouched. No new abstractions introduced.

---

### Section: Lens 6 — API Coherence

`ipw()` signature is unchanged. The only user-visible behavior change is that
`estimating_eq = "gee"` now converges with population-scale reference weights.
This is strictly an improvement in reliability: behavior that previously threw
an error will now succeed. No narrowing of return type, no silent class change,
no new silent surprises.

The calibration guarantee (`sum(w*x) = sum(d*x)`) now actually holds in
practice with population-scale reference weights. Previously this guarantee
was documented but unreachable because the NR diverged. No API coherence issues.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 2 |

**Total issues:** 4

**Overall assessment:** The spec and test-spec are nearly implementable. Two
REQUIRED issues: (S1) the `termcd >= 4` edge case needs a documentation note
in the test-spec acknowledging it is not directly testable and explaining why;
(S3) the degenerate-scores snapshot test has an ambiguous conditional that must
be resolved to unconditionally use `suppressWarnings()`. Both are low-effort
fixes. No blocking ambiguities.

---

## Resolution Log (Pass 1)

| # | Issue | Resolution |
|---|---|---|
| S1 | termcd >= 4 untestable gap | Added "documented-untestable" note to test-spec with four-point justification |
| S2 | @details paragraph wording | SUGGESTION — accepted as-is; builder can find the text |
| S3 | degenerate snapshot conditional | Replaced conditional with unconditional `suppressWarnings()` + explanatory note |
| S4 | AC-4 warning snapshot | Added `expect_snapshot(warning = TRUE, ...)` block to test-spec |

**Revised verdict: PASS** — all REQUIRED issues resolved.
