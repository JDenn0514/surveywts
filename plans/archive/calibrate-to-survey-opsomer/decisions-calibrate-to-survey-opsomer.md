# Decisions Log — surveywts calibrate-to-survey-opsomer

This file records planning decisions made during calibrate-to-survey-opsomer.
Each entry corresponds to one planning session.

---

## 2026-06-17 — Stage 3r resolve: spec review Pass 1 (17 issues)

### Context

The spec review for the Opsomer & Erciulescu (2022) variance-adjustment
implementation surfaced 17 issues: 3 BLOCKING, 10 REQUIRED, 4 SUGGESTION.
This session resolved all 17.

### Questions & Decisions

**Q: Should `type` default to `"prop"` or `"count"` for `targets`?**
- Options considered:
  - **Option A (chosen):** Keep `type = "prop"` default; update Format A example
    to proportions; add a prominent note to `@param type` about the default.
  - **Option B:** Change default to `"count"` for `targets`.
- **Decision:** Keep `"prop"` default; change example to proportions.
- **Rationale:** Maintains consistency with sibling functions
  (`calibrate_rake()`, `calibrate_logit()`). The Format A example was showing
  counts under a prop-default — fixed by changing the example to proportions
  summing to 1.0. Added a prominent note to `@param type`.

**Q: How should the combined target set handle overlap between `variables` and `targets`?**
- Options considered:
  - **Option A (chosen):** Exclude overlapping variables from the `variables`
    part; combined set = `{ t̂_{Cx} (for variables NOT in targets), T_fixed }`.
  - **Option B:** Disallow overlap with a new error class.
- **Decision:** Option A — explicitly exclude from the `variables` part.
- **Rationale:** Low effort, consistent with the existing edge-case table
  statement that "fixed margin takes precedence." Avoids adding an error class
  for a case the spec already supports.

**Q: Should there be a runtime warning when the default method changes for existing callers?**
- Options considered:
  - **Option A (chosen):** Prominent NEWS.md entry only; note added to Scope.
  - **Option B:** One-time runtime warning for one version cycle.
- **Decision:** NEWS.md entry only.
- **Rationale:** The behavioral change is intentional (svrep delegation
  removed). A runtime warning adds complexity. Callers who need the prior
  linear GREG behavior can pass `method = "linear"`.

**Q: What contracts should `make_replicate_design()` and `make_nonprob_replicate_design()` have?**
- **Decision:** Added full helper specifications to the test-spec, including
  return types, required columns, `@variables$scale = 1 / R`, and construction
  guidance using `create_bootstrap_weights()`.
- **Rationale:** Both helpers are prerequisites for every test. Without a
  contract, the builder would have to reverse-engineer the required shape from
  how the functions are called.

### Outcome

Spec updated to SPEC_READY. All 3 BLOCKING issues resolved, all REQUIRED
issues addressed, all 4 SUGGESTION issues accepted. spec-calibrate-to-survey-opsomer.md
and test-spec-calibrate-to-survey-opsomer.md are ready for `/pipeline-implement`.

---

## 2026-06-17 — HOLD: PR 2 reviewer STOP

### Context

The reviewer returned STOP on PR 2 (`feature/cts-opsomer-algorithm`) due to
two findings:

**STOP-1 — Tolerance Integrity violation (3 assertions)**
The test-spec §Tolerances table mandates `1e-6` for full-sample constraint
satisfaction assertions. The builder wrote `tolerance = 1e-4` on three blocks:
- `tests/testthat/test-sample-calibration.R` — full-sample random-margin constraint
- `tests/testthat/test-sample-calibration.R` — full-sample fixed-margin constraint
- `tests/testthat/test-sample-calibration.R` — `type = "prop"` N preservation

**STOP-2 — Missing acceptance criterion (Format B / mixed-format targets)**
The acceptance criterion `spec-contract: Format A, Format B, and mixed-format targets all accepted`
has zero test coverage.

### Options

**Option A (re-dispatch builder):** Fix 3 tolerances + add Format B/mixed-format tests.
**Option B (user override):** Explicitly accept `1e-4` for full-sample assertions
and defer Format B to a future PR.

### Status: HOLD — awaiting user resolution

