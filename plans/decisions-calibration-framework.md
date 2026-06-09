# Decisions Log — surveywts calibration-framework

This file records planning decisions made during calibration-framework.
Each entry corresponds to one planning session.

---

## 2026-06-08 — Stage 3r: Resolve Pass 3 spec review findings

### Context

Pass 3 of the spec review found 6 new issues (no blocking, 5 required, 1
suggestion) focused on test-spec coverage gaps (`unit_scale_invalid` and
`cap_not_positive` untested), an incomplete `@calibration` slot spec for
`calibrate_rake()`, a missing error-messages.md entry, stale "Thrown by"
entries in error-messages.md, and one unspecified classic_ipf edge case.

### Questions & Decisions

**Q: Issue 11 — Add E23 (`unit_scale_invalid`) to both calibrate_linear and calibrate_logit test-spec error paths?**
- Options considered:
  - **Option A:** Add E23 to both functions independently (not via cross-reference)
  - **Option B:** Do nothing — shared helper implicitly tested
- **Decision:** Option A
- **Rationale:** The cross-reference to E1–E16 silently excludes any error class not in that numbered list. Independent test entries are required per function.

**Q: Issue 12 — Add `surveywts_error_unit_scale_invalid` to error-messages.md now?**
- Options considered:
  - **Option A:** Add the row now
  - **Option B:** Defer to builder
- **Decision:** Option A
- **Rationale:** Builder cannot start without the error registry entry. Spec Scope acknowledged it as outstanding; completing it now is unambiguously correct.

**Q: Issue 13 — Add E20 (`cap_not_positive`) to calibrate_rake test-spec?**
- Options considered:
  - **Option A:** Add E20 (`cap = 0, algorithm = "classic_ipf"`)
  - **Option B:** Do nothing — implausible input
- **Decision:** Option A
- **Rationale:** Every row in the error table must have a test regardless of input plausibility.

**Q: Issue 14 — Complete calibrate_rake `@calibration` slot specification?**
- Options considered:
  - **Option A:** Add explicit field list referencing calibrate_linear fields with rake-specific NULL values
  - **Option B:** Rely on `.build_calibration_provenance()` helper
- **Decision:** Option A
- **Rationale:** The helper function's contract is not in the spec; builder cannot look it up without reading existing source, violating the independently-sufficient requirement.

**Q: Issue 15 — Update four stale error-messages.md entries referencing deleted functions?**
- Options considered:
  - **Option A:** Update all four entries now + extend spec Scope
  - **Option B:** Let auditor catch it post-implementation
- **Decision:** Option A
- **Rationale:** Building on a stale error registry produces false negatives from the auditor and incorrect "Thrown by" information for users.

**Q: Issue 16 — Specify `min_cell_n` all-excluded edge case behavior?**
- Options considered:
  - **Option A:** Add one sentence mapping to the already-calibrated path
  - **Option B:** Leave unspecified (user misconfiguration)
- **Decision:** Option A
- **Rationale:** One sentence closes the gap. "Nothing to do" is the consistent outcome regardless of cause (targets matched vs. variables excluded), and documenting it enables a targeted test.

### Outcome

All 6 Pass 3 issues resolved. Spec and test-spec are SPEC_READY. No blocking or
judgment-call issues remain. Ready for `/pipeline-implement`.

---

## 2026-06-08 — Stage 3: Resolve Pass 1 plan review findings

### Context

Pass 1 of the plan review found 5 issues: 1 blocking (PR 2 deletes
`calibrate_greg.R` before `calibrate.R` stops calling it), 2 required
(missing `bounds_scale = "absolute"` happy-path tests; `R/utils.R` absent
from write surface), and 2 suggestions (PR 1 coverage exemption note;
missing `@calibration$bounds_scale` and `$q_weights` assertions).

### Questions & Decisions

**Q: Issue 1 — Where should `calibrate_greg.R` deletion be scheduled?**
- Options considered:
  - **Option A:** Move deletion to PR 4 (same PR that stops calling it)
  - **Option B:** Partially update `calibrate.R` in PR 2 to allow PR 2 deletion
  - **Option C:** Do nothing (blocks CI)
- **Decision:** Option A
- **Rationale:** Fewest changes, no new write-surface overlaps. Deleting a file in the same PR that removes its only caller is the clean invariant.

**Q: Issue 2 — Add `bounds_scale = "absolute"` happy-path coverage to PR 2 and PR 3?**
- Options considered:
  - **Option A:** Add H_abs and E_abs to both PR 2 and PR 3 acceptance criteria
  - **Option B:** Treat error paths as sufficient
- **Decision:** Option A
- **Rationale:** The spec defines "absolute" as a distinct code path with different conversion semantics. Missing the happy path means a conversion bug produces silently wrong output.

**Q: Issue 3 — Does `.format_history_step()` in `R/utils.R` need changes?**
- Options considered:
  - **Option A:** Add `R/utils.R` to PR 5's write surface with explicit cases for `"calibrate_linear"` and `"calibrate_logit"`; remove stale `"calibrate_greg"` arm
  - **Option B:** Accept default fallback (bare string display), no changes
- **Decision:** Option A
- **Rationale:** Verified live: the default fallback produces bare operation strings with no variable info. New operations deserve the same display quality as existing ones. Stale arm should not linger after `calibrate_greg` deletion.

**Q: Issues 4 and 5 — Coverage exemption note for PR 1; `@calibration$bounds_scale`/`$q_weights` assertions?**
- **Decision:** Both accepted as low-cost additions (one-line note and two assertion lines per PR).
- **Rationale:** Issue 4 prevents a false CI failure surprise. Issue 5 closes a contract coverage gap the reviewer would flag.

### Outcome

All 5 Pass 1 issues resolved. Plan updated; proceeding to Stage 4 (freeze &
advance to PLAN_READY).

---
