# Decisions Log — surveywts calibrate-unit-scale

This file records planning decisions made during calibrate-unit-scale.
Each entry corresponds to one planning session.

---

## 2026-06-09 — Stage 3r: Spec review resolution

### Context

Resolving 8 issues from the Stage 3 spec review (Pass 1): 4 REQUIRED and 4
SUGGESTION. All REQUIRED issues were in the test-spec, not the implementation
spec. No BLOCKING issues.

### Questions & Decisions

**Q: Issue 1 — Should `error-messages.md` update be called out in the Architecture section?**
- Options considered:
  - **Option A:** Add a sentence to the Architecture section instructing the builder to extend the `surveywts_error_bounds_invalid_calibration` row for the new logit per-unit trigger.
  - **Option B:** Add `plans/error-messages.md` to the write-surface list explicitly.
  - **Option C:** Do nothing (CI will catch it).
- **Decision:** Option A — one sentence in the Architecture section.
- **Rationale:** Low-effort prevention of CI failure; keeps canonical table accurate without expanding the write-surface list.

**Q: Issue 2 — Should the spec provide a message template for the new logit precondition check?**
- Options considered:
  - **Option A:** Add `"x"` / `"i"` / `"v"` template distinguishing L_abs vs U_abs violations.
  - **Option B:** Leave to builder; snapshot test locks in quality.
- **Decision:** Option B — keep as-is.
- **Rationale:** Builder follows `code-style.md` conventions; snapshot provides quality control; no special message specificity required.

**Q: Issue 3 — Should the D6 breaking change produce a user-facing signal?**
- Options considered:
  - **Option A:** Add `cli_inform()` in the absolute-bounds path.
  - **Option B:** NEWS.md note at release time.
  - **Option C:** Do nothing (pre-1.0).
- **Decision:** Option C — do nothing in this PR.
- **Rationale:** Pre-1.0 package; the post-fix behavior is unambiguously correct; NEWS.md handles it at release.

**Q: Issue 4 — Should the 2-line per-unit bounds computation be extracted to a shared helper?**
- Options considered:
  - **Option A:** Extract `.make_per_unit_bounds(abs_L, abs_U, wt)` helper.
  - **Option B/C:** Leave inline at all 4 call sites.
- **Decision:** Option B/C — leave inline.
- **Rationale:** Two lines does not warrant a helper; engineering-preferences.md §3 flags premature abstraction.

**Q: Issue 5 — How to mandate `test_invariants()` in all happy-path test blocks?**
- Options considered:
  - **Option A:** Add a general rule at the top of the Per-function test plan section; remove HL-7 and HG-7 as separate rows.
  - **Option B:** Add a `test_invariants` column per row.
- **Decision:** Option A — one-sentence rule at the top, HL-7/HG-7 rows removed.
- **Rationale:** Single authoritative rule is cleaner than per-row repetition; original HL-7/HG-7 rows were redundant once the rule exists.

**Q: Issue 6 — How to clarify dual pattern for HLE-5 and HGE-1–HGE-3?**
- Options considered:
  - **Option A:** Explicitly annotate each affected row with dual-pattern instructions.
  - **Option B:** Add a general "all error paths use dual pattern" statement.
- **Decision:** Option A — per-row explicit annotation.
- **Rationale:** HLE-5 has different framing from HLE-1 through HLE-4; explicit per-row annotation removes all ambiguity for the tester.

**Q: Issue 7 — EC-2 has incorrect behavioral prediction and untestable dual-outcome expectation. Fix?**
- Options considered:
  - **Option A:** Replace with deterministic convergence test and correct behavioral explanation.
  - **Option B:** Replace with near-singular Jacobian edge case.
- **Decision:** Option A — deterministic convergence test.
- **Rationale:** Uniform q_k cancels in the NR update; convergence is mathematically guaranteed. The deterministic test is runnable without `tryCatch()` and serves as a clean regression guard.

**Q: Issue 8 — HL-4 oracle note has double-wrapped `survey::make.calfun()` call. Fix?**
- Options considered:
  - **Option A:** Fix double-wrap; add `packageVersion("survey") >= "4.1"` skip condition.
  - **Option B:** Remove only the double-wrap.
- **Decision:** Option A — fix double-wrap and add version guard.
- **Rationale:** The double-wrapped form is a copy-paste error that will confuse the tester; version guard is consistent with the `bounds.const = TRUE` guard already present in the test-spec.

### Outcome

5 edits applied to `plans/test-spec-calibrate-unit-scale.md` and 1 edit to
`plans/spec-calibrate-unit-scale.md`. Spec is SPEC_READY with all REQUIRED
issues resolved and SUGGESTION items deferred per decisions above.

---

## 2026-06-09 — Stage 3: Plan review resolution (Pass 1)

### Context

Working through 5 issues from `plan-review-calibrate-unit-scale.md` Pass 1:
2 REQUIRED, 3 SUGGESTION. All 5 resolved in one session.

### Questions & Decisions

**Q: Where should shared test fixtures (df_500, df_200, q_unequal, q_all_twos) be defined?**
- Options considered:
  - **helper-test-data.R (file top level):** Extends the established shared infrastructure pattern; one unambiguous location; keeps test files free of setup boilerplate.
  - **local() block per test file:** Same DRY benefit without touching the helper.
- **Decision:** `helper-test-data.R` (option A).
- **Rationale:** Consistent with existing pattern; prevents seed-interaction bugs between blocks; no ambiguity for builder.

**Q: Should replicate absolute-bounds paths have dedicated failing tests (RL-5, RL-6)?**
- Options considered:
  - **Add RL-5 and RL-6:** Two new blocks driving the replicate D6 fix; also resolves the abs_L/abs_U scope concern flagged in the plan's Notes section.
  - **Rely on 98% coverage gate:** Risk of silently missing the replicate path.
- **Decision:** Add RL-5 and RL-6 (option A).
- **Rationale:** The replicate path is independent of the full-sample path; coverage alone cannot distinguish a correct fix from an incidental hit.

**Q: Should HL-RG/HG-RG be separate test blocks from HL-1/HG-1?**
- Options considered:
  - **Merge:** Remove HL-RG/HG-RG; relabel HL-1/HG-1 as the regression guard.
  - **Keep both with a note:** Slightly different scope framing.
- **Decision:** Merge (option A).
- **Rationale:** Identical assertion; separate block adds maintenance burden with no additional safety.

**Q: Should EC-4 prescribe a concrete test pattern for its "either/or" expected outcome?**
- Options considered:
  - **Prescribe tryCatch pattern:** Eliminates ambiguity; both outcomes verifiable.
  - **Leave as-is:** Builder invents pattern; risk of a test that always passes.
- **Decision:** Prescribe the tryCatch pattern (option A).
- **Rationale:** Zero cost; prevents a test that vacuously passes regardless of which outcome occurs.

**Q: Should HL-6, HG-6, and HL-7 be named acceptance criteria?**
- Options considered:
  - **Add as named criteria:** Reviewer can check each off explicitly.
  - **Rely on "all new tests pass" catch-all:** Weaker gate.
- **Decision:** Add as named criteria (option A).
- **Rationale:** weighting_history is consumed downstream by diagnostics; HL-6/HG-6 failure is consequential enough to warrant an explicit named check.

### Outcome

`impl-calibrate-unit-scale.md` updated with: `helper-test-data.R` added to write
surface; RL-5 and RL-6 added as test blocks and acceptance criteria; HL-RG/HG-RG
merged into HL-1/HG-1; EC-4 prescribes a tryCatch pattern; HL-6, HG-6, and HL-7
added as named acceptance criteria. Plan is PLAN_READY.

---

## 2026-06-09 — Stage 3: Plan review resolution (Pass 2)

### Context

Resolving 4 issues from `plan-review-calibrate-unit-scale.md` Pass 2: 2 REQUIRED,
2 SUGGESTION. Pass 2 caught a stale task 7 description, a test-spec/impl-plan
divergence for RL-5/RL-6, a tolerance mismatch for HG-5, and a missing shared
fixture.

### Questions & Decisions

**Q: Should task 7 (n_iterations tracking) be deleted from the calibrate-utils.R task list?**
- Options considered:
  - **Delete task 7 + fix acceptance criterion path:** n_iterations already tracked via `$n_iterations` list return → `$convergence$iterations`; the task would add redundant attr-based tracking and introduce a wrong field path in HL-12.
  - **Rewrite task 7 as a no-op note:** Preserves the task slot; confirms existing mechanism is in place.
- **Decision:** Delete task 7 and update HL-12 + "History records n_iterations" acceptance criterion to use `$convergence$iterations` (option A).
- **Rationale:** Dead tasks are noise; the wrong field path in the acceptance criterion would cause builder and tester to check different things.

**Q: Should RL-5 and RL-6 be added to the test-spec (not just the impl plan)?**
- Options considered:
  - **Add to test-spec:** Tester reads only test-spec; without this, D6 replicate fix is never audited.
  - **Accept as builder-only tests:** Defeats the purpose of adding them in Pass 1.
- **Decision:** Add RL-5 and RL-6 to `test-spec-calibrate-unit-scale.md` (option A).
- **Rationale:** The pipeline isolation contract requires tester to find the tests in test-spec; the Pass 1 resolution was only half-complete without this update.

**Q: Should HL-5 and HG-5 calibration constraint tolerances be split?**
- Options considered:
  - **Split (HL-5 at 1e-8, HG-5 at 1e-6):** Matches test-spec; avoids inconsistent outcomes between tester and acceptance review.
  - **Leave bundled at 1e-8:** Logit usually achieves 1e-8 in practice.
- **Decision:** Split (option A).
- **Rationale:** Zero-cost change; eliminates the scenario where a logit result at 1e-7 passes tester but fails acceptance review.

**Q: Should `q_all_ones` be added to the helper-test-data.R task description?**
- Options considered:
  - **Add to helper:** Consistent with test-spec dataset table; no builder ambiguity.
  - **Note as inline-only:** Also valid; the object is trivial.
- **Decision:** Add to helper (option A).
- **Rationale:** Consistency with the test-spec dataset table costs nothing and removes the builder's need to decide.

### Outcome

`impl-calibrate-unit-scale.md` updated with: task 7 deleted from calibrate-utils.R;
items 6/5 deleted from calibrate_linear.R/calibrate_logit.R (attr extraction); HL-12
and "History records n_iterations" acceptance criteria updated to `$convergence$iterations`;
HL-5/HG-5 split to 1e-8/1e-6; `q_all_ones` added to helper-test-data.R task.
`test-spec-calibrate-unit-scale.md` updated with RL-5 and RL-6 in replicate loop table.
Plan is PLAN_READY.

---
