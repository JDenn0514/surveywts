## Plan Review: calibration-api — Pass 1 (2026-06-03)

### New Issues

#### Section: PR 1 Acceptance Criteria

**Issue 1: Acceptance criteria omit `calibrate_rake()` warning and message path requirements**
Severity: REQUIRED
Violates `testing-standards.md §2` — every error class must have a test requirement traceable in acceptance criteria.

The PR 1 acceptance criteria list `surveywts_warning_control_param_ignored` only for `calibrate_greg()`:
> "surveywts_warning_control_param_ignored fires for unrecognized control keys in calibrate_greg() (test in warning paths)"

But `test-spec-calibration-api.md §calibrate_rake()` requires two distinct warning triggers and one message:

| Path | Class | Trigger |
|------|-------|---------|
| Warning | `surveywts_warning_control_param_ignored` | `control = list(pval = 0.01)` with `algorithm = "survey"` |
| Warning | `surveywts_warning_control_param_ignored` | `control = list(epsilon = 1e-9)` with `algorithm = "anesrake"` |
| Message | `surveywts_message_already_calibrated` | `algorithm = "anesrake"` and data already matches targets |

The TDD file step (step 3) does mention "warning paths, message paths" but that is not an acceptance criterion — it is an instruction. A reviewer checking off acceptance criteria will not catch these if they are absent.

Options:
- **[A]** Add three explicit acceptance criteria to PR 1: one per rake warning trigger, one for the message path — Effort: low, Risk: low, Impact: prevents silent omission of `surveywts_message_already_calibrated`
- **[B]** Keep as-is and rely on the TDD step — Effort: none, Risk: medium (message path likely to slip unnoticed in code review)
- **[C] Do nothing** — `surveywts_message_already_calibrated` may not be implemented; no criterion to catch it.

**Recommendation: A** — `surveywts_message_already_calibrated` is a spec-level contract; it needs a verifiable acceptance criterion.

---

**Issue 2: Acceptance criteria omit the `calibrate_rake()` numerical oracle requirement**
Severity: REQUIRED
Violates `testing-standards.md §2` — "every error class and edge case in the spec gets a test."

The PR 1 acceptance criteria include:
> "Numerical oracle tolerance: 1e-8 for survey package comparisons (skipped if survey not installed; skip_if_not_installed inside the block)"

This criterion references the oracle but does not name which function's oracle is covered. `test-spec-calibration-api.md §calibrate_rake()` requires:

> `algorithm = "survey"` weights match `survey::rake` (dataset: `make_surveywts_data(500, 99)`, tolerance 1e-8)

`calibrate_greg()` oracle is implicitly covered by step 5 in the file list. The rake oracle is listed in step 3 TDD tasks but absent from acceptance criteria. A reviewer has no criterion to verify the rake oracle was implemented.

Options:
- **[A]** Add an explicit acceptance criterion: "`calibrate_rake()` oracle: `algorithm = "survey"` weights match `survey::rake` within 1e-8" — Effort: low, Risk: low, Impact: oracle gap caught in review
- **[B]** Reword existing oracle criterion to explicitly name both functions — Effort: low, Risk: low
- **[C] Do nothing** — rake oracle may be missing; no criterion to catch it.

**Recommendation: A** — Two separate oracle tests for two separate functions warrant two named criteria.

---

#### Section: PR 2 — error-messages.md Update (Step 1)

**Issue 3: `surveywts_error_reference_design_not_taylor` missing from `calibrate_poststrat()` section in error-messages.md update**
Severity: REQUIRED
Violates spec §V (calibrate_poststrat() Errors table).

`spec-calibration-api.md §V` explicitly lists `surveywts_error_reference_design_not_taylor` as an error thrown by `calibrate_poststrat()`. The current `plans/error-messages.md` `### poststratify()` section does not have this row. Plan PR 2 Step 1 specifies only:
- "Update 'Thrown by' for poststratify() section → calibrate_poststrat()"
- "Add `surveywts_error_no_strata_variables` row"
- "Add `surveywts_error_targets_variable_not_found` row"

It does **not** say to add `surveywts_error_reference_design_not_taylor` to the calibrate_poststrat() section. A builder following the plan literally will not add this row.

The test-spec §calibrate_poststrat() Error paths confirms:
> `surveywts_error_reference_design_not_taylor` | `reference_design = list()` (non-NULL, not `survey_taylor`)

Options:
- **[A]** Add `surveywts_error_reference_design_not_taylor` to PR 2 Step 1 instructions with "Thrown by: calibrate_poststrat()" — Effort: low, Risk: low, Impact: error-messages.md stays in sync with spec and test coverage
- **[B]** Note it in implementation notes only — Effort: low, Risk: medium (not in acceptance criteria or step instructions; easy to miss)
- **[C] Do nothing** — error-messages.md will be out of sync with spec §V; error-class-auditor will catch it later.

**Recommendation: A** — error-messages.md is the canonical table; the step instructions must enumerate every new row.

---

**Issue 4: `surveywts_error_margins_format_invalid` missing from `calibrate_poststrat()` section in error-messages.md update**
Severity: REQUIRED
Violates spec §V (calibrate_poststrat() Errors table).

`spec-calibration-api.md §V` lists:
> `surveywts_error_margins_format_invalid` | `targets` is not a `data.frame` (e.g., a named list or scalar)

The current `plans/error-messages.md` has this class in the `### rake()` section (thrown by `rake()`). Plan PR 2 Step 1 does not include adding this class to the calibrate_poststrat() section. A builder following the plan will not add it.

The test-spec §calibrate_poststrat() Error paths confirms:
> `surveywts_error_margins_format_invalid` | `targets` is a named list (not a data frame)

This is a distinct new trigger (non-data-frame targets for poststrat) not covered by the existing rake() row.

Options:
- **[A]** Add `surveywts_error_margins_format_invalid` to PR 2 Step 1 instructions under calibrate_poststrat() section — Effort: low, Risk: low, Impact: error-messages.md sync maintained
- **[B]** Combine with Issue 3 resolution in a single "add missing calibrate_poststrat() errors" instruction — Effort: low, Risk: low
- **[C] Do nothing** — error-messages.md out of sync; error-class-auditor CI will flag it.

**Recommendation: A** (or B in conjunction with Issue 3) — same reasoning as Issue 3.

---

#### Section: PR 2 — surveywts-conventions.md Update (Step 8)

**Issue 5: New `calibrate()` dispatcher row absent from the file mapping update instructions**
Severity: SUGGESTION
Minor omission in step 8 write surface.

Plan PR 2 Step 8 says to:
> "Replace `calibrate.R → calibrate()` (old entry) with updated entries for all new files; add rows for `calibrate_greg.R`, `calibrate_rake.R`, `calibrate_poststrat.R`, `calibrate-utils.R`"

The new `R/calibrate.R` (the thin dispatcher, created in PR 2 Step 5) is not in the "add rows for" list. It is a new file with a new export (`calibrate()` dispatcher) and should have its own row in the file mapping table.

Options:
- **[A]** Add `calibrate.R → calibrate()` (dispatcher) to the explicit "add rows for" list in Step 8 — Effort: minimal, Risk: low, Impact: conventions doc stays complete
- **[B]** Leave it to the builder's judgment (the old calibrate.R row being replaced implies the new one) — Effort: none, Risk: low
- **[C] Do nothing** — Conventions doc missing the dispatcher row; minor inconsistency.

**Recommendation: A** — the list in step 8 is explicit; the dispatcher file should be named.

---

#### Section: PR 1 — surveywts-conventions.md Staleness

**Issue 6: surveywts-conventions.md file mapping table is stale between PR 1 merge and PR 2 merge**
Severity: SUGGESTION

After PR 1 merges, the `surveywts-conventions.md` file mapping table still shows:
- `calibrate.R → calibrate()` (old, deleted)
- `rake.R → rake()` (old, deleted)

The new files `calibrate_greg.R`, `calibrate_rake.R`, `calibrate-utils.R` exist but are absent from the table. The table is not updated until PR 2 (Step 8). During the PR 1 → PR 2 review window, the conventions doc is stale.

Options:
- **[A]** Add a partial surveywts-conventions.md update to PR 1 covering the files PR 1 creates/deletes; complete the update in PR 2 for PR 2 files — Effort: low, Risk: low, Impact: conventions doc always reflects current codebase
- **[B]** Accept the staleness; keep the full update in PR 2 — Effort: none, Risk: low (internal doc; unlikely to cause implementation errors)
- **[C] Do nothing** — same as B.

**Recommendation: B** — the review window between two sequential PRs is short and the doc is internal; the staleness is acceptable.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 6

**Overall assessment:** The plan is well-structured and sequenced. All four REQUIRED issues are localized to PR 2's error-messages.md update step (Issues 3 & 4) and PR 1's acceptance criteria (Issues 1 & 2). None require restructuring the PR map or reordering work — all four are additive fixes to the plan text that can be resolved in Stage 3 without touching the implementation files.
