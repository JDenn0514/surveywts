# Decisions Log — surveywts calibrate-surveycore

This file records planning decisions made during calibrate-surveycore.
Each entry corresponds to one planning session.

---

## 2026-06-04 — Stage 3r Spec Review Resolution

### Context

Working through 11 issues raised by the Stage 3 adversarial spec review. Issues ranged from a blocking cross-package contract ambiguity to required coverage gaps and suggestions for clarity and API coherence.

### Questions & Decisions

**Q: What value should `@calibration$method` store for `calibrate_greg(model = "logit")`?**
- Options considered:
  - **Option A:** Four valid values — store actual model argument (`"linear"` or `"logit"`); both map to GREG variance in surveycore.
  - **Option B:** Map logit → `"linear"`; three valid values; update test-spec CS-12.
- **Decision:** Option A — four valid values; store actual model argument.
- **Rationale:** Test-spec CS-12 already committed to four values; updating the contract to match is the smaller change. Surveycore uses both `"linear"` and `"logit"` to select the GREG formula, so the distinction is meaningful for audit purposes even if variance estimation behavior is identical.

**Q: Should step 4 (explicit full-sample weight write) be retained in the survey_replicate calibration path?**
- Options considered:
  - **Option A:** Remove step 4 (redundant with `.update_survey_weights()` step 5).
  - **Option B:** Keep with an inline comment.
- **Decision:** Option A — removed.
- **Rationale:** `.update_survey_weights()` already performs the weight write. Keeping a redundant step risks a builder omitting step 5 entirely (losing history and @calibration assignment).

**Q: What does `.calibrate_engine()` actually return for `$convergence$iterations` when called from `calibrate_greg(model = "logit")`?**
- Options considered: 1L (same as linear) vs. NA_integer_.
- **Decision:** `NA_integer_` — confirmed from source at `R/utils.R:929`. Logit path uses `survey::calibrate()` internally which does not expose an iteration count. Spec updated to document this explicitly.
- **Rationale:** User's intuition was that it would be 1L like linear GREG, but the engine source shows `NA_integer_` for the logit path. Spec now states this unambiguously to align builder and tester.

**Q: Should the `discrepancy` field be renamed to remove ambiguity with post-calibration residuals?**
- Options considered:
  - **Option A:** Rename to `pre_cal_deficit`.
  - **Option B:** Keep name; add clarifying note.
- **Decision:** Option B — keep name, add note.
- **Rationale:** Renaming is a medium-effort change that would propagate to surveycore's reader code. A clarifying note in the contract table is sufficient to prevent misinterpretation.

### Outcome

All 11 review issues resolved. Spec advanced to SPEC_READY at version 1.1.

---

## 2026-06-04 — Stage 3 Plan Review Resolution (Pass 1 → Pass 2)

### Context

Working through 8 issues from the Stage 2 adversarial review of
`impl-calibrate-surveycore.md`. All 5 required issues were low-effort fixes;
3 suggestions resolved by acceptance of recommended option.

### Questions & Decisions

**Q: Where should survey_replicate test fixtures be defined?**
- **Decision:** Add three helper functions to `helper-test-data.R`:
  `.make_replicate_design()`, `.make_brr_design()`, `.make_empty_cell_replicate_design()`.
- **Rationale:** The fixtures are used across all three calibrate function test
  files; centralizing in helper avoids triple duplication, consistent with the
  existing test-data generator pattern.

**Q: What is the intermediate state between PR 1 and PR 2?**
- **Decision:** Accept Option A (no plan change). Solo development; CI passes.
- **Rationale:** Between PRs, passing `survey_replicate` silently runs a partial
  calibration but doesn't crash. Acceptable for a development branch on a solo
  project.

**Q: Should PR 2 be split into greg vs rake+poststrat?**
- **Decision:** No split. Keep 2-PR plan.
- **Rationale:** Spec recommended 2 PRs; behavioral pattern is identical across
  all three functions; reviewing them together is coherent.

### Outcome

All 8 plan review issues resolved. Plan advanced to PLAN_READY.
`impl-calibrate-surveycore.md` status updated to PLAN_READY.

---
