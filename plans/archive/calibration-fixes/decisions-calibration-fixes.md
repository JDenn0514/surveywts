# Decisions Log — surveywts calibration-fixes

This file records planning decisions made during calibration-fixes.
Each entry corresponds to one planning session.

---

## 2026-03-17 — Methodology lock: delegation to survey/anesrake

### Context

Resolved 11 methodology issues from the Stage 2 review of the Phase 0 Fixes
spec. Four required judgment calls; seven were unambiguous fixes applied in
batch.

### Questions & Decisions

**Q: How should the formula and population vector for `survey::calibrate()` be
constructed? (Issue 1)**
- Options considered:
  - **Option A (treatment contrasts + intercept):** R default encoding. k-1
    dummies + intercept per variable. Correct but fragile name-matching.
  - **Option B (full indicator, no intercept):** k columns per k-level factor,
    no reference-level dropping. Exact replication of vendored behavior.
  - **Option C (manual model matrix):** Maximum control, highest effort.
- **Decision:** Option B — full indicator encoding without intercept.
- **Rationale:** Replicates current vendored GREG behavior exactly. Avoids
  reference-level ambiguity and name-matching fragility with `model.matrix()`.

**Q: How much downstream behavior should the spec document for zero weights
after nonresponse adjustment? (Issue 4)**
- Options considered:
  - **Option A:** Full subsection covering Taylor linearization, all-zero PSUs,
    and re-calibration guidance.
  - **Option B:** Re-calibration note only; defer rest to roxygen.
  - **Option C:** Do nothing.
- **Decision:** Option A — full downstream behavior subsection.
- **Rationale:** This is a behavioral contract change. The spec should document
  implications rather than leaving them to implementation-time discovery.

**Q: The spec says `force1 = FALSE` with a comment "we handle total-weight
conservation" but nothing conserves totals. Fix comment or add conservation?
(Issue 6)**
- Options considered:
  - **Option A:** Fix the misleading comment. Note that weight totals are
    approximately but not exactly conserved by raking. No behavioral change.
  - **Option B:** Add post-raking normalization step for exact conservation.
    Small numerical change vs current output.
- **Decision:** Option A — fix the comment, no normalization.
- **Rationale:** Current vendored behavior does not conserve totals. Changing
  that would be a new feature, not a bug fix.

**Q: When logit calibration doesn't converge, `survey` emits a warning and we
throw an error. Suppress survey's warning or let both fire? (Issue 8)**
- Options considered:
  - **Option A:** Intercept via `withCallingHandlers()`, suppress, re-throw as
    typed error. Clean UX but fragile if survey changes warning text.
  - **Option B:** Let both fire. Slightly noisy, zero maintenance.
- **Decision:** Option A — intercept and suppress.
- **Rationale:** Clean UX. Single typed error class for all non-convergence
  cases. Fragility risk is low (survey's warning text rarely changes).

### Outcome

Spec updated to version 0.2, methodology-locked. All 11 methodology issues
resolved: 7 unambiguous fixes applied in batch, 4 judgment calls decided
individually.

---

## 2026-03-17 — Stage 4: Code review resolution + GAP closure

### Context

Resolved 12 code-review issues (2 blocking, 6 required, 4 suggestions) from
Stage 3 and closed 2 open GAPs. Three decisions required judgment calls.

### Questions & Decisions

**Q: Should `.diag_validate_input()` and `.check_input_class()` error messages
reference `survey_base`, list specific classes, or reference documentation?
(Issue 8)**
- Options considered:
  - **Option A (reference `as_survey()` constructor):** Actionable and
    future-proof, but `as_survey()` is only one of many constructors
    (`as_survey_nonprob()`, `as_survey_replicate()`, `as_survey_twophase()`,
    plus eventual `survey::svydesign()` / `srvyr::tbl_svy()` support).
  - **Option B (reference `survey_base`):** Technically precise but exposes
    internal class hierarchy that users don't know about.
  - **Option C (reference documentation):** Future-proof and avoids listing
    classes or constructors that will grow over time.
- **Decision:** Option C — "Use a data.frame or a supported survey design
  object. See package documentation for details."
- **Rationale:** The set of supported constructors is large and growing.
  Listing them creates maintenance burden; referencing `survey_base` exposes
  internals. Documentation reference is stable across all phases.

**Q: When `cap` is specified with `method = "survey"` in `rake()`, should we
apply post-hoc trimming with a warning or error outright? (GAP 1)**
- Options considered:
  - **Option A (post-hoc cap + warning):** Apply cap after `survey::rake()`
    completes. Warn that marginals are no longer exact. More permissive.
  - **Option B (error):** Reject the combination. Users must use
    `method = "anesrake"` for per-step capping. Simpler and more honest.
  - **Option C (keep vendored IPF):** Defeats the purpose of Change 1.
- **Decision:** Option B — error with `surveywts_error_cap_not_supported_survey`.
- **Rationale:** Post-hoc trimming silently violates marginal constraints,
  which is misleading. Erroring is honest and directs users to anesrake,
  which supports per-step capping natively.

**Q: How should the `survey_nonprob` S7 validator handle zero weights from
nonresponse adjustment? (Issue 6)**
- Options considered:
  - **Option A (relax validator):** Change "all > 0" to "all >= 0, at least
    one > 0." Calibration strictness enforced by `.validate_weights()`.
  - **Option B (return weighted_df):** Loses design structure, contradicts
    Change 2 motivation.
  - **Option C (add @nonresponse_mask):** High effort, every downstream
    function must check the mask.
- **Decision:** Option A — relax the validator. This is a surveycore change.
- **Rationale:** The validator should reflect valid object states.
  Post-nonresponse objects with zero weights are valid; the distinction
  between "can't start with zeros" and "can have zeros after adjustment"
  belongs in `.validate_weights()`, not the class contract.

### Outcome

Spec updated to version 0.3, approved. 12 review issues resolved (2 blocking,
6 required, 4 suggestions). Both GAPs closed. Ready for `/implementation-workflow`.

---
