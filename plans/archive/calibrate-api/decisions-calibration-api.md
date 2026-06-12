# Decisions Log — surveywts calibration-api

This file records planning decisions made during calibration-api.
Each entry corresponds to one planning session.

---

## 2026-06-03 — Stage 3r Spec Review Resolution

### Context

Resolving 11 issues raised in `spec-review-calibration-api.md` Pass 1: one
BLOCKING architectural contradiction, seven REQUIRED gaps, and three
SUGGESTIONS.

### Questions & Decisions

**Q: Where should `.parse_margins()` live, given both `calibrate_greg()` and `calibrate_rake()` call it?**
- Options considered:
  - **`R/utils.R`:** Cross-family shared helpers file; correct per conventions but `.parse_margins()` is calibration-specific.
  - **`R/calibrate_rake.R` (status quo):** Inconsistent — cannot be called by greg without cross-file dependency.
  - **`R/calibrate-utils.R`:** New calibration-family shared utils file, consistent with `surveywts-conventions.md §3` family-utils pattern.
- **Decision:** `R/calibrate-utils.R` (user's directive)
- **Rationale:** Calibration-family helper used by 2+ calibration functions belongs in a calibration-family utils file, following the established `diagnostics-utils.R`, `nonresponse-utils.R`, `replicate-utils.R` pattern.

**Q: What happens when `calibrate_greg()` receives an unrecognized `control` key?**
- Options considered:
  - **Warn:** Consistent with `calibrate_rake()` behavior; reuses `surveywts_warning_control_param_ignored`.
  - **Error:** Stricter; asymmetric.
  - **Silent ignore:** User mistakes undetected.
- **Decision:** Warn with `surveywts_warning_control_param_ignored` per unrecognized key.
- **Rationale:** API consistency with rake; reuses existing warning class.

**Q: Should the error class for "a targets variable name not found in data" be harmonized across greg and rake?**
- Options considered:
  - **`surveywts_error_targets_variable_not_found`:** New name aligned with the new `targets` argument across all three functions.
  - **`surveywts_error_population_variable_not_found`:** Reuse greg's existing name; rename rake to match.
  - **Keep split:** Document divergence as intentional.
- **Decision:** Standardize on `surveywts_error_targets_variable_not_found` for both greg, rake, and poststrat.
- **Rationale:** New API redesign is the right moment to align error class names with the new `targets` argument. Users catching dispatcher errors need one class, not two.

**Q: What error class should the zero-strata-variables edge case use in `calibrate_poststrat()`?**
- Options considered:
  - **`surveywts_error_no_strata_variables` (new):** Most informative; unambiguous.
  - **`surveywts_error_margins_format_invalid`:** Semantically plausible reuse.
  - **`surveywts_error_population_cell_missing` (status quo):** Wrong semantics.
- **Decision:** New class `surveywts_error_no_strata_variables`.
- **Rationale:** User chose maximum clarity; the error is structurally different from all existing classes.

### Outcome

Spec updated to version SPEC_REVIEWED with all 11 issues resolved. New file
`R/calibrate-utils.R` added to the architecture. New error class
`surveywts_error_no_strata_variables` added to `plans/error-messages.md`.
Error class `surveywts_error_targets_variable_not_found` standardized across
all three functions (replaces `surveywts_error_population_variable_not_found`
in greg and `surveywts_error_margins_variable_not_found` in rake).

---

## 2026-06-03 — Stage 3 Plan Issue Resolution

### Context

Working through 6 issues found in `plan-review-calibration-api.md` (Pass 1).
All issues were additive fixes to acceptance criteria and error-messages.md
step instructions; no PR map restructuring was needed.

### Questions & Decisions

**Q: Should `calibrate_rake()` warning/message paths appear as explicit acceptance criteria in PR 1?**
- Options considered:
  - **Option A:** Add three explicit acceptance criteria (two warning triggers, one message path)
  - **Option B:** Rely on TDD step instructions mentioning "warning paths, message paths"
- **Decision:** Option A — add explicit criteria
- **Rationale:** `surveywts_message_already_calibrated` is a spec-level contract; TDD step instructions are not verifiable at review time.

**Q: Should the `calibrate_rake()` numerical oracle be named separately from the existing generic oracle criterion in PR 1?**
- Options considered:
  - **Option A:** Add a named criterion for the rake oracle separately
  - **Option B:** Reword existing criterion to name both functions
- **Decision:** Option A — separate named criteria for each function's oracle
- **Rationale:** Two separate oracle tests for two separate functions; a reviewer needs to verify each independently.

**Q: Should `surveywts_error_reference_design_not_taylor` and `surveywts_error_margins_format_invalid` be added to PR 2 Step 1 `error-messages.md` instructions for `calibrate_poststrat()`?**
- Options considered:
  - **Option A:** Add both to Step 1 instructions explicitly
  - **Option B:** Note in implementation notes only
- **Decision:** Option A — enumerate every new row in the step instructions
- **Rationale:** `error-messages.md` is the canonical error table; a builder following the plan literally must see every row to add.

**Q: Should the `calibrate.R` dispatcher file be explicitly named in the PR 2 Step 8 file mapping list?**
- Options considered:
  - **Option A:** Add `calibrate.R → calibrate()` (dispatcher) explicitly to the "add rows for" list
  - **Option B:** Leave to builder's judgment
- **Decision:** Option A — the list is explicit; the dispatcher file should be named
- **Rationale:** Explicit over clever (engineering-preferences.md §5).

**Q: Should `surveywts-conventions.md` be partially updated in PR 1 to avoid staleness between PRs?**
- Options considered:
  - **Option A:** Add partial update to PR 1 covering its created/deleted files
  - **Option B:** Accept staleness; keep full update in PR 2
- **Decision:** Option B — accept the staleness
- **Rationale:** The review window between sequential PRs is short; the conventions doc is internal; the staleness risk is low and doesn't affect implementation correctness.

### Outcome

`impl-calibration-api.md` updated with 5 additive fixes across PR 1 acceptance criteria and PR 2 Step 1/Step 8 instructions. Plan is ready for PLAN_READY freeze.

---
