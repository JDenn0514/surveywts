# Decisions Log — surveywts nps-bootstrap

This file records planning decisions made during nps-bootstrap.
Each entry corresponds to one planning session.

---

## 2026-05-20 — Methodology lock: quasi-randomization and hybrid bootstrap

### Context

Resolved 12 methodology issues from the Stage 2 review of the NPS bootstrap
methods (quasi-randomization and hybrid). Three issues were judgment calls;
nine were unambiguous fixes applied as a batch.

### Questions & Decisions

**Q: How should Level A and Level B of the quasi-randomization bootstrap be defined?**
- Options considered:
  - **Option A:** Both levels require reference data; split on `targets_from_reference` flag. Level A = reference held fixed. Level B = reference resampled.
  - **Option B:** Level A = no-reference fallback (holds propensity estimates fixed); Level B = reference resampled.
  - **Option C:** Do nothing (guaranteed implementation failure).
- **Decision:** Option A — split on `targets_from_reference` flag.
- **Rationale:** Statistically coherent and consistent with the stated goal of capturing adjustment uncertainty in every draw. Option B produces an inferior estimator that omits adjustment uncertainty, which contradicts the quasi-randomization framework.

**Q: What should the default `replicates` be for NPS bootstrap types?**
- Options considered:
  - **Option A:** B = 200 for NPS types (lower than 500 probability-sample default).
  - **Option B:** B = 500 (same as probability-sample types).
  - **Option C:** B = NULL (require user to specify).
- **Decision:** Option A — B = 200, with documentation that B = 500 is recommended for final estimates.
- **Rationale:** Within-draw cost for NPS types is O(n_A · model_fit_time) per replicate, orders of magnitude higher than static matrix construction. B = 200 balances variance estimation precision against exploratory runtime. Matches svrep guidance (200–500 range).

**Q: Where should reference survey design weight handling in the propensity model be specified?**
- Options considered:
  - **Option A:** Specify in bootstrap spec that reference units are weighted by design weights w_k^B.
  - **Option B:** Defer to `ipw()` spec — bootstrap spec notes it calls `ipw()` with the same formula/method from history; design weight handling is `ipw()`'s responsibility.
  - **Option C:** Do nothing.
- **Decision:** Option B — defer to the `ipw()` spec.
- **Rationale:** The propensity model specification belongs in the `ipw()` spec, which owns the model. Duplicating it in the bootstrap spec creates a maintenance hazard. The bootstrap spec now notes that it calls `ipw()` as-specified with the stored formula and method.

### Outcome

The spec is methodology-locked at v1.1. Level A/B distinction is now based on
`targets_from_reference` flag (not reference availability). Both levels require
a reference design. All formula gaps (Level B target re-estimation, hybrid
estimator formula, full-sample estimate definition, Hájek normalization) are
closed. Default B = 200 for NPS types. Validation table is internally consistent.

---
