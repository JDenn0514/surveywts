## Plan Review: calibration-nps-compat — Pass 1 (2026-05-20)

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — Add `reference_design` to `rake()` and `calibrate()`

**Issue 1: `type`-in-history test not in acceptance criteria**
Severity: REQUIRED
Violates `testing-standards.md §2` (every behavior must have a test) and `engineering-preferences.md §2` (more tests is better).

Step 2 says: *"Also add a check for `'rake() records type in history'` if `type` is not already tested in the history blocks."* Since `type` is confirmed absent from `test-03-rake.R`'s existing history test (line 760 checks only `method`, `cap`, `control`), this test WILL be written — but no acceptance criterion gates on it. An implementer under time pressure could skip the new test block, tick "All new tests passing," and the check would pass, leaving the `type` addition silently untested.

The existing test at line 745 uses `expect_true("method" %in% names(entry$parameters))` — it checks for presence of specific keys, not absence of others — so it will not catch a missing `type` field.

Options:
- **[A]** Add an explicit acceptance criterion: *"A test verifies `type` is present in `rake()` history `parameters` after this PR."* — Effort: low, Risk: low, Impact: eliminates the silent-skip risk.
- **[B]** Promote the conditional instruction in step 2 to mandatory ("Add a `'rake() records type in history'` block regardless of existing coverage") — Effort: low, Risk: low, Impact: same as A.
- **[C] Do nothing** — The instruction in step 2 is technically correct and the implementer probably follows it. But nothing enforces it.

**Recommendation: A** — An acceptance criterion is the project's verification gate. Relying on step-text alone is insufficient for a behavior that was explicitly identified as a bootstrap-replay correctness gap.

---

**Issue 2: `plans/error-messages.md` placement is ambiguous**
Severity: REQUIRED
Violates `code-style.md §3` goal of canonical, unambiguous error documentation.

Step 1 says: *"Add row for `surveywts_error_reference_design_not_taylor` under the Errors table with function `rake()` / `calibrate()` and the trigger condition."*

The file organizes errors into per-function subsections: `### calibrate()`, `### rake()`, etc. The notation `rake() / calibrate()` is ambiguous about whether to:

- Add one row in the `rake()` section AND one row in the `calibrate()` section (most consistent with the current per-function layout), or
- Add a single row in some shared section (no shared section currently exists for shared args), or
- Add one row in `rake()` and a cross-reference `_See also:_` in `calibrate()` (like the existing `surveywts_error_calibration_not_converged` pattern at the bottom of the calibrate() table).

If two implementers run this step independently they may produce different table structures. Step 1 completes before any code is written, so any rework here would also require rebasing the error test.

Options:
- **[A]** Specify: add one row to the `### rake()` section and one row to the `### calibrate()` section (same content, identical row). — Effort: low, Risk: low, Impact: fully consistent with the file's existing per-function layout.
- **[B]** Specify: add one row to `### rake()` and a `_See also:_` cross-reference in `### calibrate()`, following the `surveywts_error_calibration_not_converged` precedent. — Effort: low, Risk: low, Impact: less duplication.
- **[C] Do nothing** — A reasonable implementer picks one. Risk is only cosmetic.

**Recommendation: A** — The file has no cross-reference pattern for input-validation errors (only for shared engine errors). Adding a full row in each section is the most consistent choice and avoids creating a new pattern that isn't documented elsewhere.

---

**Issue 3: Plan directs "build `ref_taylor` inline" but file-level helpers already exist**
Severity: SUGGESTION
Violates `engineering-preferences.md §1` (DRY — flag repetition aggressively).

The Notes section says: *"Build it inline in the test using `surveycore::survey_taylor()` with the same `make_surveywts_data()` output."*

Both test files already define minimal `survey_taylor` fixture helpers:
- `test-03-rake.R` line 18: `.make_test_taylor_rake(df, weight_col = "base_weight")`
- `test-02-calibrate.R` line 16: `.make_test_taylor(df, weight_col = "base_weight")`

Following the plan literally produces inline code that duplicates these helpers exactly. The spec notes that `ref_taylor` does not need to match the margin variables — a minimal design is correct — which is exactly what both helpers produce.

Options:
- **[A]** Update step 2 and step 3 to say: *"Use the existing `.make_test_taylor_rake(df)` / `.make_test_taylor(df)` helper — do not build inline."* — Effort: trivial, Risk: low, Impact: DRY-compliant tests.
- **[B] Do nothing** — Tests work either way; the duplication is only within the test files and has no production impact.

**Recommendation: A** — The helpers exist precisely for this use case. Directing the implementer to them is one sentence of change and prevents the creation of duplicate fixture code.

---

**Issue 4: `invisible(NULL)` deviates from the `.validate_*()` convention without a note**
Severity: SUGGESTION
Relates to `code-style.md §4` (Internal validators return `invisible(TRUE)` on success) and `surveywts-conventions.md §3`.

Step 5 includes `.validate_reference_design()` returning `invisible(NULL)` (matching the spec's implementation block verbatim). The style guide says internal validators return `invisible(TRUE)` on success. The spec overrides this with `invisible(NULL)`, which is fine since the return value is unused by all callers — but the plan doesn't flag the departure.

A future reader of `utils.R` will see a `.validate_*()` function that returns `NULL` instead of `TRUE` and may wonder if it's intentional or a bug.

Options:
- **[A]** Add a note in step 5: *"Note: `invisible(NULL)` is intentional here per spec §II — the return value is unused, so `NULL` vs `TRUE` is equivalent. This departs from the `.validate_*()` `invisible(TRUE)` convention."* — Effort: trivial, Risk: none.
- **[B]** Change to `invisible(TRUE)` in both the plan and spec — aligns with convention, zero behavioral change since return value is unused. Requires a spec amendment.
- **[C] Do nothing** — A senior implementer will recognize this is harmless.

**Recommendation: A** — A one-line comment in step 5 costs nothing and prevents a future "is this a bug?" moment. Changing the spec is disproportionate effort for an invisible return value.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 2 |

**Total issues:** 4

**Overall assessment:** The plan is structurally sound — one PR is the right scope, TDD ordering is correct, all spec deliverables are covered, and file completeness is clean. The two REQUIRED issues are both acceptance-criteria gaps (not architectural problems): add an explicit criterion for the `type`-in-history test, and clarify error-message table placement before the implementer touches the file.
