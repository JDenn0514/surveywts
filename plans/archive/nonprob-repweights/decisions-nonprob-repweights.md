# Decisions Log — surveywts nonprob-repweights

This file records planning decisions made during nonprob-repweights.
Each entry corresponds to one planning session.

---

## 2026-06-15 — Stage 3 resolve: plan-review-nonprob-repweights.md (Pass 1)

### Context

Working through 6 issues from the Stage 2 plan review (4 REQUIRED, 2 SUGGESTION). All 4 required issues and 1 suggestion were resolved; 1 suggestion was declined.

### Questions & Decisions

**Q: Should documentation changes (roxygen @description, @param data, @section Replicate Weights) be in AC or only in Notes?**
- Options considered:
  - **Option A:** Add explicit AC items for each file's documentation requirements
  - **Option B:** Leave in Notes only and trust the builder to read them
- **Decision:** A — added explicit AC bullets for `trim_weights.R` and `stabilize_weights.R` documentation
- **Rationale:** Documentation changes are explicitly contractual in the spec. Without AC items, a reviewer has no checkpoint to verify spec compliance.

**Q: Should the per-group `stabilize_weights()` replicate criterion include the exact formula from the test-spec?**
- Options considered:
  - **Option A:** Replace vague "per-row factor applied to all replicate columns" with `sum(result_rep[h, j]) == sum(orig_rep[h, j]) * (n_h / W_h)` at `1e-10`
  - **Option B:** Leave vague and rely on the tester
- **Decision:** A — quantitative formula added to AC
- **Rationale:** The vague wording allowed a subtly wrong implementation (global factor applied to replicates) to pass review. The test-spec already had the exact formula; copying it into the AC costs nothing and closes a real gap.

**Q: Should changelog creation be an AC item or left as a Note?**
- Options considered:
  - **Option A:** Add AC item to both PR 1 and PR 2
  - **Option B:** Leave in Notes
- **Decision:** A — changelog AC items added to both PRs
- **Rationale:** Consistent with `github-strategy.md` PR template requirements. A note without an AC item has no enforcement gate.

**Q: Should `NULL` input safety ("must not throw") be a separate AC bullet from the FALSE-returning group?**
- Options considered:
  - **Option A:** Separate `NULL` into its own bullet explicitly naming the "must not throw" contract
  - **Option B:** Keep bundled — "returns FALSE" implies "does not throw"
- **Decision:** A — `NULL` safety separated into its own AC bullet
- **Rationale:** The "must not throw" constraint is qualitatively distinct from "returns FALSE". A guard using `stopifnot()` returns FALSE only after throwing. One extra bullet is a cheap, clear contract statement.

**Q: Should single-replicate-column edge cases get explicit AC bullets?**
- Options considered:
  - **Option A:** Add explicit bullets for each relevant function
  - **Option B:** Leave implicit — tester reads the test-spec which covers these scenarios
- **Decision:** B — left as implicit coverage
- **Rationale:** The test-spec is the tester's authoritative source and already has the exact scenarios. Adding AC bullets would duplicate the test-spec without adding reviewer value; the implicit "length ≥ 1" wording is sufficient.

### Outcome

`impl-nonprob-repweights.md` updated with 5 AC additions/edits. Plan is ready for Stage 4 freeze.

---
