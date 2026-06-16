# Decisions Log — surveywts nps-calibration-path

This file records planning decisions made during nps-calibration-path.
Each entry corresponds to one planning session.

---

## 2026-06-15 — Stage 3r: Spec review Pass 2 resolution

### Context

Five issues from the Pass 2 spec review required resolution before the spec
could be approved for implementation. Three were REQUIRED gaps in the spec
and test-spec; two were SUGGESTIONS.

### Questions & Decisions

**Q: Issue 1 — DRY cross-reference for calibration entry definition in DAGJK section**
- Options considered:
  - **Option A:** Extract a shared definition block before both function contracts.
  - **Option B:** Add a parenthetical note in the DAGJK routing step referencing
    the definition in `create_bootstrap_weights` above.
- **Decision:** Option B (parenthetical cross-reference).
- **Rationale:** Minimal effort, no risk, eliminates the silent duplication without
  restructuring the spec layout.

**Q: Issue 9 — How to handle `calibrate_linear()` producing negative weights without erroring on the bootstrap calibration-only path**
- Options considered:
  - **Option A:** Treat negative-weight draws as failed (count toward
    `surveywts_warning_bootstrap_draws_failed`; exclude from replicate matrix).
  - **Option B:** Emit a warning analogous to DAGJK's
    `surveywts_warning_dagjk_negative_replicate_weights` but retain the replicate.
- **Decision:** Option A (treat as failed draw).
- **Rationale:** Methodologically clean — same as non-convergence in the
    "degenerate inputs" framing already in the spec. Avoids corrupted variance
    estimates silently entering the replicate weight matrix.

**Q: Issue 12 — Whether to add a parameter-storage verification note to the spec Architecture section**
- Options considered:
  - **Option A:** Add a verification note requiring the builder to inspect
    calibration history entries before implementing dispatch.
  - **Option B:** Note only in the review; let builder discover at implementation time.
- **Decision:** Option A (add to spec).
- **Rationale:** Explicit is better than implicit; the cost is one read of a
  history entry per function; the risk of silently wrong calibration replay
  (e.g., `bounds_scale = "absolute"` becoming `"multiplicative"`) is real.

### Outcome

All 5 Pass 2 issues resolved. Spec and test-spec updated. Spec review verdict
set to PASS. Ready for `/pipeline-implement`.

---

## 2026-06-15 — Stage 3: Plan review Pass 1 resolution

### Context

Six issues from the Pass 1 plan review required resolution before `impl-nps-calibration-path.md`
could be approved for implementation. Three were REQUIRED; three were SUGGESTIONS.

### Questions & Decisions

**Q: Issue 1 — `surveywts_error_qr_bootstrap_no_reference` missing from PR 1 task 2 and AC**
- Options considered:
  - **Option A:** Add fourth dual block to task 2 (error path section).
  - **Option B:** Move to task 5 (Level B section).
- **Decision:** Option A (add to task 2).
- **Rationale:** All error path tests belong together in the dedicated error path section; the fixture is a small inline variant.

**Q: Issue 2 — Calibration dispatch table duplicated across PR 1 and PR 2**
- Options considered:
  - **Option A:** Extract `.dispatch_calibration_replay()` into `replicate-utils.R` in PR 1; PR 2 calls it.
  - **Option B:** Implement independently in both PRs; schedule DRY cleanup chore PR.
- **Decision:** Option A (extract now).
- **Rationale:** DRY rule is mandatory; `replicate-utils.R` is the declared shared-helper home for all `create_*_weights()` functions; future dispatch additions become one-file changes.

**Q: Issue 3 — `surveywts_warning_dagjk_negative_replicate_weights` unreachable on calibration-only path**
- Options considered:
  - **Option A:** Replace with a defensive test documenting unreachability and verifying non-negative replicate matrix.
  - **Option B:** Remove the test entirely.
- **Decision:** Option A (defensive test following existing pattern at lines 694-708 and 955-965).
- **Rationale:** Preserves documentation value; prevents implementer from spending time on an unfulfillable fixture.

**Q: Issue 6 — PR 2 task 9 `"raking"` legacy fallback mention**
- **Decision:** Closed as moot by Issue 2 resolution — `.dispatch_calibration_replay()` owns the legacy fallback.

### Outcome

All 6 Pass 1 issues resolved. `impl-nps-calibration-path.md` updated. Plan review verdict set to PASS.

---
