# Decisions Log — surveywts rake-anesrake-port

This file records planning decisions made during rake-anesrake-port.
Each entry corresponds to one planning session.

---

## 2026-05-11 — Implementation Plan Stage 3 Review

### Context

Working through 6 issues found in the Stage 2 adversarial review of
`plans/impl-rake-anesrake-port.md`. Issues ranged from a blocking factual
error in the Implementation Notes to suggestions about test dataset validation.

### Questions & Decisions

**Q: How should the missing `skip_if_not_installed("anesrake")` guards be added — separate step or folded into Step 2?**
- Options considered:
  - **Option A:** Add a separate Step 2b for the guard additions
  - **Option B:** Fold guard additions into Step 2, since both are pre-implementation test-only changes
- **Decision:** Option B — expand Step 2's scope
- **Rationale:** Cleaner to group all pre-implementation test-only changes into one step; avoids a tiny step that exists solely to separate two related actions.

**Q: How to address `.call_anesrake_direct()` default cap and stale comment after the cap fix?**
- Options considered:
  - **Option A:** Update `.call_anesrake_direct()` default to `cap = Inf` and fix stale comment in test #1
  - **Option B:** Add explanatory comments to tests #1, #2, #5 explaining why cap=5 and cap=Inf give the same result for these seeds
- **Decision:** Option A — update the helper default and fix the comment
- **Rationale:** Tests should document correct post-fix semantics, not pass by coincidence. Relying on implicit dataset properties is fragile per engineering-preferences.md §5 (explicit over clever).

**Q: How to handle the pre-loop initialization of `precap_weightvec` (deviation from spec)?**
- Options considered:
  - **Option A:** Remove it; confirm spec's placement (inside loop) is sufficient
  - **Option B:** Retain it with a justification comment explaining it as a defensive initialization for static analysis tools
- **Decision:** Option B — retain with justification
- **Rationale:** The `repeat` loop always executes at least once, so correctness is not affected; the comment prevents future confusion about the deviation.

### Outcome

Plan updated with: (1) skip guards folded into Step 2, (2) `.call_anesrake_direct()` default fix and stale comment update added to Step 2, (3) coverage and changelog criteria added to acceptance criteria, (4) pre-loop initialization justified in Step 6, (5) dataset choice for cap-fires test verified (seed=1 + standard margins → max weight ~3.14, 28 weights > 1.5).

---
