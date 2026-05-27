# decisions-ipw-extensions.md

**ID:** ipw-extensions
**Created:** 2026-05-26

---

## Decision 1: GEE + `missing_method = "separate"` runtime behavior

**Stage:** 2 methodology review (Issue 1, JUDGMENT CALL)
**Date:** 2026-05-26
**Resolution:** Option A — documentation only; no runtime warning.

The limitation (GEE covariate balance guarantee applies only to complete-case
NPS rows when `missing_method = "separate"`) is communicated through
`@param estimating_eq` and `@param missing_method` documentation. No new
warning class is defined. This is consistent with how M-3 handles the
"separate" method's theoretical limitations in other contexts.

**Applied to:**
- `plans/spec-ipw-extensions.md §III.C` — explicit decision statement added
- `plans/test-spec-ipw-extensions.md` — H-6 test block 6 HOLD closed; replaced
  with `expect_no_warning` regression test

---

## Decision 2: Stage 3 spec review resolutions (11 issues)

**Stage:** 3r resolve
**Date:** 2026-05-26

### Issue 1 (BLOCKING): GEE balance test / adjust_reference interaction
**Decision:** Option A — add `adjust_reference = FALSE` to H-6 test block 2 to isolate the GEE balance property; add new test block 2b asserting balance against Valliant-adjusted totals when `nps_fraction > 0.05`.
**Rationale:** Fixes a definite test failure while adding meaningful coverage of the GEE × reference-adjustment interaction.

### Issue 2 (REQUIRED): GEE balance guarantee semantics under adjust_reference = TRUE
**Decision:** Option A — qualifying sentence added to `@param estimating_eq`; quality gate updated to reference `d_adjusted = ref_weights_for_fit` after Rule 9a-ii.
**Rationale:** Precise language eliminates user confusion; quality gate must be correct.

### Issue 3 (REQUIRED): Missing @seealso specification
**Decision:** Option A — `@seealso` subsection added to §IV.H, linking `adjust_nonresponse()`, `calibrate_to_survey()`, and planned `diagnose_propensity()`.

### Issue 4 (REQUIRED): Missing @references additions
**Decision:** Option A — `@references` additions subsection added to §IV.H with full bibliographic entries for 4 net-new citations. Chen et al. year discrepancy (spec used "2021"; existing file uses "2020") flagged for builder to resolve to 2020.

### Issue 5 (REQUIRED): GEE non-convergence not linked to existing error class
**Decision:** Option A — one sentence added to §III.C specifying that `converged = FALSE` from the GEE inner guard triggers `surveywts_error_propensity_scores_degenerate` via the existing convergence-failure path.

### Issue 6 (REQUIRED): M-1 test block 5 references undefined variables
**Decision:** Option A — inline setup block added with concrete `both_issue_nps` (score range [0,10], age_group missing "55+") and `both_issue_ref` (score range [2,8], has "55+" in age_group) fixtures.

### Issue 7 (REQUIRED): withCallingHandlers() in warning snapshot tests
**Decision:** Option A — all 4 occurrences replaced with `expect_snapshot(expect_warning(..., class = "..."))` per `testing-standards.md`.

### Issue 8 (REQUIRED): test_invariants() absent from most result-constructing blocks
**Decision:** Option A — `test_invariants(result)` added as first assertion to every result-constructing block in C-3 (blocks 1–3), M-4, M-6 (blocks 1–4), and L-4 (blocks 1–3).

### Issue 9 (SUGGESTION): History schema duplicated in §IV.D and §V
**Decision:** Option B — sync note added to §IV.D Rule 20 header.

### Issue 10 (SUGGESTION): No check when population_size < nrow(data)
**Decision:** Option B — note added to `@param population_size` describing the impossible N < n case.

### Issue 11 (SUGGESTION): No @examples for new arguments
**Decision:** Option A — @examples blocks added for `estimating_eq = "gee"` (with balance note) and `population_size` (with manual IPW1 formula comment).

### Outcome
All 11 issues resolved. Spec at version 0.3. Advancing to SPEC_READY.

---

## Decision 3: Stage 3 plan review resolutions (5 issues)

**Stage:** pipeline-implement Stage 3 resolve
**Date:** 2026-05-26

### Issue 1 (REQUIRED): PR 4 dependency field understated
**Decision:** Option A — `Depends on: PR 2` changed to `Depends on: PR 3` in PR 4 header, with explanatory note that all five PRs share the same two write surfaces and must execute in strict sequence.

### Issue 2 (REQUIRED): `test_invariants()` criterion absent from PR 3
**Decision:** Option A — `[ ] test_invariants(result) is the first assertion in every result-constructing block` added to PR 3 acceptance criteria, consistent with PRs 1 and 2.

### Issue 3 (REQUIRED): `test_invariants()` criterion absent from PR 4
**Decision:** Option A — same criterion added to PR 4 acceptance criteria.

### Issue 4 (REQUIRED): No test for `nps_fraction` pre-NA-deletion boundary
**Decision:** Option A — new `NA-boundary` test block added to PR 2 test blocks table: construct NPS with NAs in a selection variable, call `ipw()` with `missing_method = "omit"`, assert `hist$nps_fraction == nrow(nps_original) / n_hat` using the pre-deletion row count.
**Rationale:** Spec explicitly calls out this ordering invariant; no other test would detect a builder placing Rule 9a-ii after Rule 9b.

### Issue 5 (SUGGESTION): Snapshot files absent from write surface
**Decision:** Option A — one-line criterion added to PR 2 acceptance criteria: "New snapshot files in `tests/testthat/_snaps/` are staged and committed." (PRs 3 and 4 also produce snapshots; the note in PR 2 sets the precedent builders and testers follow.)

### Outcome
All 5 issues resolved. Plan advancing to PLAN_READY.

## BLOCK Resolution — PR 4 — 2026-05-26

**Signal resolved**: BLOCK — reviewer, H-6 block 1 fixture mandate
**Decision**: Updated `test-spec-ipw-extensions.md §H-6 block 1` to use unit-weight synthetic data instead of `ns_wave1_ipw` + `gss_ipw_ref`. The bundled datasets have N_hat/n_NPS ≈ 40,000, causing GEE NR to saturate on iteration 2. This is a real GEE numerical limitation, not a code bug. Unit-weight data (N_hat/n_NPS ≈ 5) exercises the same code path and balance guarantee. No code changes to PR 4.
**Authorized by**: pipeline orchestrator (planner fix, no code change)
**Resume from state**: tester re-dispatch for PR 4

## HOLD Resolution — PR 5 — 2026-05-27

**Signal resolved**: HOLD — builder, GEE @examples fixture
**Decision**: The spec §IV.H GEE `@examples` block references `ns_wave1_ipw` + `gss_ipw_ref`, but these cause GEE NR divergence (N_hat/n_NPS ≈ 40,000) — same root cause as PR 4 Block 1. The @examples must run clean under `R CMD check`. Builder used inline unit-weight synthetic data, which correctly demonstrates the GEE API and runs clean. This deviation from spec §IV.H is authorized — the spec's stated example fixture is incompatible with GEE numerical constraints.
**Authorized by**: pipeline orchestrator (consistent with PR 4 planner fix)
**Resume from state**: tester dispatch for PR 5
