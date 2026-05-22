# Decisions Log — surveywts calibration-nps-compat

This file records planning decisions made during calibration-nps-compat.
Each entry corresponds to one planning session.

---

## 2026-05-19 — Stage 4 Resolve: calibration NPS bootstrap compatibility

### Context

Resolving 5 issues from the Stage 3 spec review of
`plans/spec-calibration-nps-compat.md`. The spec adds `reference_design`
argument and `targets_from_reference` history field to `rake()` and
`calibrate()`.

### Questions & Decisions

**Q: Should the shared `reference_design` validation logic be extracted to a helper in `utils.R`, or kept inline in both `rake.R` and `calibrate.R`?**
- Options considered:
  - **Extract to `.validate_reference_design()` in `utils.R`:** Follows `code-style.md §4` (promote shared logic to `utils.R`). Eliminates message-drift risk.
  - **Keep inline with documented exception:** Acknowledges but preserves the duplication.
- **Decision:** Extract to `utils.R`.
- **Rationale:** The helper is trivial; the rule is unambiguous (two call sites in two files); follows the `.validate_weights()` precedent.

**Q: Should `type` be added to the `rake()` history `parameters` list?**
- Options considered:
  - **Add `type = type`:** Closes a silent correctness hole — bootstrap replay always defaults to `type = "prop"` without it.
  - **Document that bootstrap assumes `type = "prop"`:** Restricts the API and is silently wrong for count-target users.
- **Decision:** Add `type = type` to the parameters list and update §VIII replay pseudo-code.
- **Rationale:** One-line fix; the spec is already touching the parameters list; no reason to leave a known correctness gap.

**Q: Should `test_invariants()` be added to the happy-path test blocks in §VI?**
- Options considered:
  - **Add as first assertion:** Complies with `testing-surveywts.md` requirement.
  - **Do nothing:** Violates the documented standard.
- **Decision:** Add `test_invariants(result)` as the first assertion in all four happy-path blocks.
- **Rationale:** Mandatory per `testing-surveywts.md`; trivial to add.

**Q: Should the §V error table message text be updated to match the §II helper text?**
- Options considered:
  - **Update §V to match §II:** Consistent; avoids confusion between the two sections.
  - **Keep §V as-is:** Two sections with different wording.
- **Decision:** Update §V to match the helper (`"Got class {.cls ...}."` + `"v"` bullet).
- **Rationale:** The helper in §II is the authoritative implementation; §V should be consistent.

**Q: Does `reference_design` need a no-content-validation statement in §III and §IV, or is §II sufficient?**
- Options considered:
  - **§II is sufficient:** The helper's docstring explicitly states the validation boundary.
  - **Add redundant notes to §III/IV:** Extra defensive documentation.
- **Decision:** §II is sufficient.
- **Rationale:** Clear and definitive in one place; repeating it in §III/IV would be redundant noise.

### Outcome

Spec v0.2 approved. Five issues resolved (3 REQUIRED, 2 SUGGESTION). Ready
for `/implementation-workflow`.

---

## 2026-05-20 — Stage 3 Resolve: implementation plan review (calibration-nps-compat)

### Context

Resolving 4 issues from the Stage 2 adversarial review of
`plans/impl-calibration-nps-compat.md`. All issues were editorial/clarification
rather than architectural.

### Questions & Decisions

**Q: Should the `type`-in-history test be gated by an acceptance criterion, or left as a conditional step instruction?**
- Options considered:
  - **Add explicit acceptance criterion:** Eliminates the silent-skip risk for a behavior explicitly identified as a bootstrap-replay correctness gap.
  - **Leave as conditional in step 2:** Technically present but not enforced.
- **Decision:** Add acceptance criterion: "A test verifies `type` is present in `rake()` history `parameters` after this PR."
- **Rationale:** REQUIRED behaviors belong in acceptance criteria, not conditional step text.

**Q: How should `surveywts_error_reference_design_not_taylor` be added to `plans/error-messages.md`?**
- Options considered:
  - **One identical row in both `### rake()` and `### calibrate()` sections:** Consistent with the file's per-function layout.
  - **One row in `### rake()` with a cross-reference in `### calibrate()`:** Less duplication but creates a new pattern with no precedent for input-validation errors.
- **Decision:** One identical row in each section.
- **Rationale:** No cross-reference pattern exists for input-validation errors; duplicating the row is more consistent.

**Q: Should `ref_taylor` fixture be built inline or use existing helpers?**
- Options considered:
  - **Use existing `.make_test_taylor_rake()` / `.make_test_taylor()` helpers:** DRY-compliant; helpers already exist for exactly this purpose.
  - **Build inline per original Notes text:** Creates duplicate fixture code.
- **Decision:** Use existing file-level helpers.
- **Rationale:** DRY is a first-tier engineering preference; the helpers exist precisely for this use case.

**Q: Should `.validate_reference_design()` return `invisible(NULL)` (per spec) or `invisible(TRUE)` (per convention)?**
- Options considered:
  - **Keep `invisible(NULL)` with a clarifying comment in the plan:** Follows the spec; return value is unused so behavior is identical; costs nothing.
  - **Change to `invisible(TRUE)` in plan and spec:** Full convention alignment, requires a spec amendment.
- **Decision:** Keep `invisible(NULL)` with a clarifying comment added to step 5.
- **Rationale:** Return value is provably unused; the comment prevents future "is this a bug?" confusion without requiring a spec amendment.

### Outcome

Implementation plan v1.0 approved. Four issues resolved (2 REQUIRED, 2 SUGGESTION).
Ready to hand off to `/r-implement`.

---
