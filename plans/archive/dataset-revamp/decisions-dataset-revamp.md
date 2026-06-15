# Decisions Log — surveywts dataset-revamp

This file records planning decisions made during dataset-revamp.
Each entry corresponds to one planning session.

---

## 2026-06-14 — Dataset revamp plan review (Stage 3 resolution)

### Context

Resolving issues from plan-review-dataset-revamp.md Pass 1. HOLD #1
(weight column for gss/npors `_svy` companions) was raised in spec-review
Pass 1 but never formally closed in a decisions file.

### Questions & Decisions

**Q: Should `_svy` companions use the normalized weight (`wtssps`/`weight`) or
the population-scaled weight (`wt_pop`)?**
- Options considered:
  - **Option A:** `_svy` companions use normalized weight (`wtssps`/`weight`);
    `wt_pop` column lives in the tibble for users who construct their own IPW
    reference design.
  - **Option B:** `_svy` companions use `wt_pop` directly; no separate `wt_pop`
    column in the tibble.
- **Decision:** Option A.
- **Rationale:** Normalized weights are correct for standard survey estimation
  (the primary use case of `_svy` objects). IPW workflows require
  population-scaled weights, which users construct from the `wt_pop` column in
  the tibble — this pattern is already shown in the `@examples` and README.
  Separation keeps `_svy` objects suitable for `svymean()`/`svytotal()` out of
  the box without confusion about scale.

### Outcome

All seven `_svy` companions use normalized weights; each tibble carries a
`wt_pop` column for IPW reference design construction.

---
