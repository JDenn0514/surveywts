## Plan Review: calibration-framework — Pass 1 (2026-06-08) — RESOLVED

All 5 issues resolved in Stage 3 (2026-06-08). Verdict: **PASS**.

---

### New Issues

---

#### Section: PR 2 — `calibrate_linear()` + delete `calibrate_greg.R`

**Issue 1: Deleting `calibrate_greg.R` in PR 2 breaks `devtools::check()` — `calibrate.R` still dispatches to `calibrate_greg()`**
Severity: BLOCKING
Violates: acceptance criterion "`devtools::check()` 0 errors, 0 warnings" (PR 2)

`calibrate.R` currently calls `calibrate_greg()` in two places: the `switch()` dispatch (`greg = calibrate_greg(...)`) and the `@examples` block (`result_greg <- calibrate(df, targets = targets)` — `"greg"` is the default method). When `calibrate_greg.R` is deleted in PR 2, `R CMD check` runs all `@examples` blocks, which invokes `calibrate()` with its current default `method = "greg"` and hits the undefined `calibrate_greg()`. This produces an error in example checking, which counts as an R CMD check error and fails the acceptance criterion. `calibrate.R` is not updated until PR 4, so there is no PR in between that resolves this contradiction.

The plan acknowledges the risk ("it may still reference calibrate_greg until PR 4") but the phrasing "confirm calibrate.R still compiles without calibrate_greg" cannot be confirmed given the current source — it cannot.

Options:
- **[A] Move `calibrate_greg.R` deletion from PR 2 to PR 4** — In PR 4, `calibrate.R` is already being updated (dispatcher retarget). Delete `calibrate_greg.R` in the same PR where `calibrate.R` stops referencing it. Update PR 4 file list and acceptance criteria to include the deletion; update PR 2 file list to remove it. PR 2 leaves `calibrate_greg.R` in place. Effort: low, Risk: low, Impact: clean CI on every PR.
- **[B] Update `calibrate.R` partially in PR 2** — In PR 2, update `calibrate.R`'s examples and dispatch to route `"greg"` → `calibrate_linear()` and drop `"logit"` until PR 3. Delete `calibrate_greg.R` in PR 2 as planned. PR 3 adds `"logit"` to the dispatch. Effort: medium, Risk: medium (calibrate.R write surface spans PR 2 and PR 3, creating overlap), Impact: keeps deletion in PR 2 but adds complexity.
- **[C] Do nothing** — PR 2 will fail `devtools::check()` with example errors. Cannot ship.

**Recommendation: A** — Fewest changes, no new write-surface overlaps. Deletion of `calibrate_greg.R` belongs in the same PR that overwrites its only caller.

---

#### Section: PR 2 — Acceptance Criteria

**Issue 2: `bounds_scale = "absolute"` has no happy-path test coverage in the plan or test-spec**
Severity: REQUIRED
Violates: engineering-preferences.md §4 "Handle more edge cases, not fewer"; testing-standards.md §2 "Three mandatory test categories"

The spec defines `bounds_scale = "absolute"` as a distinct mode for both `calibrate_linear()` and `calibrate_logit()` with different validation semantics (`0 < L < U`, not `L < 1 < U`) and a different conversion step: absolute bounds constrain `w_k` directly rather than the g-weight ratio `w_k / d_k`, which requires a per-unit scaling before the engine call. The plan's PR 2 notes acknowledge this is non-trivial ("scale the weights by `1/d_k` internally so the engine works in g-weight space, then convert back. Document this as an implementation gotcha").

Despite the acknowledged implementation complexity, neither the plan's acceptance criteria nor the test-spec contains a happy-path test for `bounds_scale = "absolute"`. The error paths (E17–E20) test bounds validation but only for the multiplicative rule; they don't verify that absolute-scale bounds are correctly converted before the engine call. An incorrect conversion could produce silently wrong weights that still satisfy the g-weight range check.

The same gap applies to PR 3 (`calibrate_logit`), which inherits the same `bounds_scale` argument.

Options:
- **[A] Add one happy-path test for `bounds_scale = "absolute"` in PR 2's acceptance criteria and a matching test in PR 3** — e.g., "H_abs: `bounds = c(200, 2000)`, `bounds_scale = 'absolute'` — verify all calibrated weights (not g-weights) are in `[200, 2000]`." Also add a bounds-invalid error test for the absolute-specific validation rule (`L <= 0`). Effort: low, Risk: low, Impact: catches conversion bugs before they reach production.
- **[B] Add a note that absolute bounds is tested via the error paths** — Does not cover the happy path. Effort: minimal, Risk: high (silent wrong output goes undetected).
- **[C] Do nothing** — `bounds_scale = "absolute"` happy path is untested; conversion bugs will not be caught by the test suite.

**Recommendation: A** — The spec explicitly specifies `"absolute"` as a supported value with distinct conversion semantics. Testing only the error condition for an alternative code path violates the minimum test-category requirement.

---

#### Section: File Surface Summary (all PRs)

**Issue 3: `R/utils.R` absent from plan file surface despite spec calling for `.format_history_step()` update**
Severity: REQUIRED
Violates: Lens 5 (file completeness); spec §Architecture "Modify R/utils.R — `.format_history_step()` in R/utils.R to handle new operation strings"

The spec §Architecture file table explicitly lists `R/utils.R` as `Modify` with note "`.format_history_step()` in R/utils.R to handle new operation strings." The plan's File Surface Summary does not list `R/utils.R` in any PR's write surface, and no PR's acceptance criteria or file list mentions it.

If `.format_history_step()` already handles arbitrary operation strings without hardcoding (i.e., it just passes the string through), the spec item is trivially satisfied with no code change. But the plan needs to explicitly verify this and document the conclusion; otherwise the reviewer has no way to confirm the spec item is covered.

Options:
- **[A] Verify `.format_history_step()` implementation and add a one-line note to the plan** — Read `R/utils.R`, confirm the function does not hard-code operation strings, and add "Verified no change needed to `R/utils.R`: `.format_history_step()` passes operation strings through without hard-coding" to either PR 2 or PR 5's notes. Effort: minimal, Risk: low, Impact: confirms a spec coverage item.
- **[B] Add `R/utils.R` to PR 5's file list** — If changes are needed (e.g., new operation strings must be registered), schedule them in PR 5 alongside the other cleanup. Effort: low, Risk: low.
- **[C] Do nothing** — The spec item is unaccounted for. Tester will flag it.

**Recommendation: A or B** — Determine during Stage 3 whether a change is actually needed. If yes, add to PR 5; if no, document the verification.

---

#### Section: PR 1 — Acceptance Criteria

**Issue 4: PR 1 has no explicit test coverage exemption or handoff statement**
Severity: SUGGESTION
Violates: testing-standards.md "Coverage target: 98%+ line coverage; PRs blocked below 95%"

PR 1 adds ~60 lines of NR engine code, 3 calfun factory functions, and 2 validators to `calibrate-utils.R`. None of these are covered by tests in PR 1 itself (the plan correctly notes "engine is tested through public API in PR 2–3"). If CI enforces a per-PR coverage gate (as the standards require — "PRs blocked below 95%"), PR 1 will fail the coverage check even though the code is correct and will be covered in the subsequent PR.

The plan should explicitly state the coverage posture for PR 1 so the CI gate is not a surprise and the implementer knows what to expect.

Options:
- **[A] Add an acceptance criterion note: "PR 1 is exempt from the standalone 98% coverage gate. Coverage over the NR engine code lands in PR 2. Full coverage verified post-PR 2."** — Effort: trivial, Risk: none, Impact: no false CI failure surprise.
- **[B] Do nothing** — Implementer may be confused when CI coverage check fails on an otherwise correct PR 1.

**Recommendation: A** — One line in the acceptance criteria removes ambiguity.

---

#### Section: PR 2 and PR 3 — Acceptance Criteria

**Issue 5: `@calibration$bounds_scale` field not verified in any PR's acceptance criteria**
Severity: SUGGESTION
Violates: spec §calibrate_linear `@calibration` slot fields: "`bounds_scale` (the resolved `bounds_scale` value, or `NULL` when `bounds = NULL`)"

The spec lists `bounds_scale` as an explicit `@calibration` field. PR 1's plan says to add `bounds_scale` as a parameter to `.build_calibration_provenance()`, but no acceptance criterion in PR 2 or PR 3 asserts that `@calibration$bounds_scale` is correctly populated (e.g., `"multiplicative"` for H6, `NULL` for H1 where `bounds = NULL`). Similarly, `@calibration$q_weights` (the stored `unit_scale` vector) has no assertion in the acceptance criteria.

Options:
- **[A] Add two assertions to PR 2's acceptance criteria** — (1) `@calibration$bounds_scale == "multiplicative"` for H6 (`bounds = c(0.3, 3)`, default scale); (2) `is.null(@calibration$bounds_scale)` for H1 (`bounds = NULL`). Same pattern for PR 3. Effort: low, Risk: none, Impact: confirms the provenance contract is populated correctly.
- **[B] Do nothing** — The `@calibration` slot is partially verified; `bounds_scale` and `q_weights` could be absent or wrong without failing the existing criteria.

**Recommendation: A** — Two quick assertions close the contract coverage gap.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 2 |
| SUGGESTION | 2 |

**Total issues:** 5

**Overall assessment:** The plan is nearly implementation-ready — the PR sequence is well-ordered and criteria are comprehensive — but Issue 1 is a genuine blocker: deleting `calibrate_greg.R` before `calibrate.R` stops calling it will break R CMD check on PR 2. Resolve Issues 1–3 before cutting branches; Issues 4–5 are low-cost additions that close coverage and documentation gaps.
