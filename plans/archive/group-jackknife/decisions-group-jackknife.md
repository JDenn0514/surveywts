# Decisions Log — surveywts group-jackknife

This file records planning decisions made during group-jackknife.
Each entry corresponds to one planning session.

---

## 2026-05-28 — Stage 3r Pass 2 resolution

### Context

All 23 issues from Pass 1 were already resolved. Pass 2 identified 8 new issues
(6 REQUIRED, 2 SUGGESTION) introduced during the Pass 1 resolution. This session
resolved all 8.

### Questions & Decisions

**Q: Issue A — `.handle_repweights_overwrite()` message template and bootstrap snapshot safety**
- Options considered:
  - **Option A:** Specify `fn_name` usage in `"i"` bullet template; confirm no bootstrap snapshot drift.
  - **Option B:** Require structural equivalence only; leave snapshot ownership to builder.
- **Decision:** Option A
- **Rationale:** Preventing silent invalidation of approved bootstrap snapshots outweighs the small spec verbosity cost.

**Q: Issue B — "floor (groups < 2)" wording ambiguous**
- Options considered:
  - **Option A:** Replace with "minimum-value check".
  - **Option B:** Leave as-is.
- **Decision:** Option A
- **Rationale:** Trivial fix; eliminates "floor" being misread as the R `floor()` function.

**Q: Issue C — "call helper from both" does not specify replace vs. supplement**
- Options considered:
  - **Option A:** Add "replaced, not supplemented" sentence.
  - **Option B:** Leave to builder judgment.
- **Decision:** Option A
- **Rationale:** Double-running the overwrite logic would be a silent bug; one sentence prevents it.

**Q: Issue E — `targets_from_reference = TRUE` raking path DRY**
- Options considered:
  - **Option A:** Point explicitly to `.reestimate_margins_from_reference()`.
  - **Option B:** Leave as implementation detail.
- **Decision:** Option A
- **Rationale:** The helper already exists and its interface is compatible; DRY violation risk is real.

**Q: Issue F — `trim_threshold` NULL/absent equivalence for pre-PR objects**
- Options considered:
  - **Option A:** Add clarifying sentence about R list-access behavior.
  - **Option B:** Leave as language property for builders to know.
- **Decision:** Option A
- **Rationale:** Prevents a subtle correctness bug from an unnecessary `is.element()` presence check.

**Q: Issue H — Calibration margin check circularity**
- Options considered:
  - **Option A:** Require literal targets in test.
  - **Option B:** Accept reading from history entry.
- **Decision:** Option A
- **Rationale:** Reading targets from history entry allows buggy within-replicate calibration to pass the test silently.

**Q: Issue I — `data.frame` branch in `.validate_reference_sample()` must be modified**
- Options considered:
  - **Option A:** Modify shared helper; run existing regression tests.
  - **Option B:** Handle `data.frame` separately in DAGJK before calling shared helper.
- **Decision:** Option A
- **Rationale:** Modifying the shared helper is cleaner and ensures the message is consistent across all callers.

**Q: Issues J + K — snapshot review note and `maxit`/`epsilon` formal arg confirmation**
- **Decision:** Both Option A
- **Rationale:** Both are trivial one-sentence additions with no trade-offs.

### Outcome

All 8 Pass 2 issues resolved. Spec is at version 1.2 and remains SPEC_READY.
Ready for `/implementation-workflow` in a new session.

---

## 2026-06-01 — Stage 3 Plan Review resolution (Pass 2)

### Context

All 6 Pass 1 issues were already resolved. Pass 2 review identified 3 new issues
(1 required, 2 suggestions). This session resolved all 3.

### Questions & Decisions

**Q: Issue 7 — "13 error classes" acceptance criterion undercounts test scenarios**
- Options considered:
  - **Option A:** Hard-code "18 scenarios + 1 direct internal test = 19."
  - **Option B:** Delegate to test-spec tables: "all test scenarios from test-spec-group-jackknife.md §3.6–3.10, using the dual pattern on each row."
- **Decision:** Option B
- **Rationale:** Cites the tables directly; more resilient if the test spec adds rows without a corresponding plan update.

**Q: Issue 8 — Dataset D in `make_dagjk_datasets()` vs. inline**
- Options considered:
  - **Option A:** Remove Dataset D from the helper; construct it inline in boundary tests.
  - **Option B:** Keep all four datasets in the helper with an optional-inline note.
- **Decision:** Option A
- **Rationale:** Dataset D is a 4+4-unit edge case used only in boundary tests; testing-standards.md §4 requires edge case data to be inline. No DRY benefit from the helper.

**Q: Issue 9 — §3.4 calibration assertion literal targets placement**
- Options considered:
  - **Option A:** Add a sentence to the test file description: assertion must re-state raking targets as named literals, not read from the helper or history entry.
  - **Option B:** Embed the literal target values in the acceptance criterion.
- **Decision:** Option A
- **Rationale:** One sentence closes the ambiguity without over-specifying exact values in the plan itself.

### Outcome

All 3 Pass 2 issues resolved. `impl-group-jackknife.md` is implementation-ready. Ready for Stage 4.

---

## 2026-05-28 — Stage 3 Plan Review resolution (Pass 1)

### Context

Pass 1 review of `impl-group-jackknife.md` found 6 issues (1 blocking, 3 required, 2
suggestions). This session resolved all 6.

### Questions & Decisions

**Q: Issue 1 — `R/replicate-weights.R` missing from PR 2 file list**
- Options considered:
  - **Option A:** Add the file entry to PR 2's file list.
  - **Option B:** Promote the change to PR 1 (same file touched there).
- **Decision:** Option A
- **Rationale:** Keeps PR scope boundaries stable; the modification is logically part of the DAGJK implementation, not the prerequisite refactor.

**Q: Issue 2 — §3.1 invariant count wrong (plan: "15", spec: 17 rows)**
- Options considered:
  - **Option A:** Update count to 17.
  - **Option B:** Drop the count; cite the spec table by reference.
- **Decision:** Option B
- **Rationale:** A quoted count is brittle and will drift if the spec adds rows; citing the spec table directly is more robust.

**Q: Issue 3 — `trim_threshold` capture value not precisely specified**
- Options considered:
  - **Option A:** Specify the exact expression (`median(w) + 5*IQR(w)`) in both the Notes and acceptance criteria.
  - **Option B:** Leave for builder to infer from the code.
- **Decision:** Option A
- **Rationale:** The DAGJK per-replicate trimming silently diverges if the wrong expression is captured; one sentence prevents it.

**Q: Issue 4 — `.validate_reference_sample()` regression guard not in acceptance criteria**
- Options considered:
  - **Option A:** Promote from Notes to an explicit acceptance criterion.
  - **Option B:** Bold the note; leave out of criteria.
- **Decision:** Option A
- **Rationale:** Acceptance criteria are checked before opening the PR; notes are skimmable.

**Q: Issue 5 — `groups_failed` and `seed` history fields unverified**
- Options considered:
  - **Option A:** Two targeted criteria for the two riskiest unverified fields.
  - **Option B:** One combined criterion covering all 10 history fields.
- **Decision:** Option A
- **Rationale:** Targeted criteria are easier to verify; `step`, `timestamp`, `reference_design`, `source_design` are covered implicitly by object construction success.

**Q: Issue 6 — Changelog entries missing**
- Options considered:
  - **Option A:** Changelog entry for both PRs.
  - **Option B:** Changelog entry for PR 2 only (PR 1 is an internal refactor with no user-visible behavior change).
- **Decision:** Option B
- **Rationale:** Consistent with project convention — changelog files track user-visible changes; the PR 1 refactor introduces no exported symbols.

### Outcome

All 6 Pass 1 issues resolved. `impl-group-jackknife.md` updated with corrected file list, tightened acceptance criteria, and precise `trim_threshold` specification. Ready for Stage 4.

---
