## Plan Review: ipw-extensions — Pass 1 (2026-05-26)

### New Issues

#### Section: PR Map

**Issue 1: PR 4 dependency field understates the dependency**
Severity: REQUIRED
[Violates github-strategy.md strict sequencing; Lens 2 — Dependency Ordering]

The PR 4 header says `Depends on: PR 2`. PRs 2, 3, and 4 all write to
`R/nonprob-ipw.R` and `tests/testthat/test-nonprob-ipw.R`. The plan itself
says "Five PRs in strict sequence." A builder who reads "Depends on: PR 2"
might attempt PR 4 while PR 3 is in review, causing a merge conflict or
out-of-sequence write to the same files. The correct declaration is
"Depends on: PR 3."

The GEE implementation (PR 4) does not technically need the common-support
code (PR 3) to be correct, but the strict sequential write surface makes the
dependency real regardless.

Options:
- **[A]** Change `Depends on: PR 2` to `Depends on: PR 3` in the PR 4 header. — Effort: low, Risk: low, Impact: eliminates potential sequencing confusion for the builder
- **[B]** Add a note "(PRs 3 and 4 are independent in logic but share the same file write surfaces; strict sequencing required)" to the PR map overview. — Effort: low, Risk: low, Impact: same
- **[C] Do nothing** — Builder reads the PR map overview ("all PRs strictly sequential") and infers the correct sequence; the explicit field may be misleading but is not acted on.

**Recommendation: A** — The dependency field is the first thing a builder reads; make it accurate.

---

#### Section: PR 1 — History entry fixes and `population_size`

No issues found.

---

#### Section: PR 2 — Reference weight adjustment

No issues found.

---

#### Section: PR 3 — Common support checks

**Issue 2: `test_invariants()` first-assertion criterion absent from PR 3**
Severity: REQUIRED
[Violates testing-standards.md §3 and testing-surveywts.md invariants section; Lens 3 — Acceptance Criteria]

PR 3 test blocks (M-1 blocks 1–5) construct `survey_nonprob` objects and
check for warning classes. The test-spec Invariants section states: "All test
blocks that construct a `survey_nonprob` object must call
`test_invariants(result)` as the first assertion." PR 3's acceptance criteria
include no such criterion, and tester would have no checklist item prompting
this check.

PRs 1 and 2 both include `[ ] test_invariants(result) is the first assertion
in every result-constructing block` as their final acceptance criterion.

Options:
- **[A]** Add `[ ] test_invariants(result) is the first assertion in every result-constructing block` to PR 3's acceptance criteria list. — Effort: low, Risk: low, Impact: aligns PR 3 with PRs 1 and 2
- **[B] Do nothing** — The testing-standards.md rule applies globally; the tester will know. — Risk: inconsistency creates confusion

**Recommendation: A** — Explicit is better than inherited convention.

---

#### Section: PR 4 — GEE estimating equation

**Issue 3: `test_invariants()` first-assertion criterion absent from PR 4**
Severity: REQUIRED
[Same as Issue 2; Lens 3 — Acceptance Criteria]

PR 4 test blocks (H-6 blocks 1–4, 6) construct `survey_nonprob` objects
(blocks 1, 3, 4, 6 assign `result_gee`, `result_mle`, etc.). The acceptance
criteria have no `test_invariants()` criterion. Block 1 already says
`test_invariants(result)` in the test-spec test code, but the acceptance
criterion in the plan is absent.

Options:
- **[A]** Add `[ ] test_invariants(result) is the first assertion in every result-constructing block` to PR 4's acceptance criteria. — Effort: low, Risk: low
- **[B] Do nothing** — Risk: tester may skip this step since it is not in the PR checklist.

**Recommendation: A**

---

#### Section: PR 2 + PR 3 — `nps_fraction` pre-NA-deletion boundary tests

**Issue 4: No test verifies `nps_fraction` is computed before NPS NA deletion**
Severity: REQUIRED
[Violates spec §IV.D Rule 9a-ii "using `data` before any NPS NA deletion"; Lens 4 — Spec Coverage]

The spec states: `nps_fraction <- nrow(data) / n_hat`, "using `data` before
any NPS NA deletion, i.e., full NPS row count." If a builder accidentally
places Rule 9a-ii after Rule 9b (which reduces `nrow(data)` when
`missing_method = "omit"`), `nps_fraction` would use the post-deletion count,
suppressing the Valliant adjustment for samples where NAS are present.

No test in PR 2 (C-3 blocks 1–5) or PR 3 (M-1 blocks 1–5) uses a fixture
with NPS rows containing NAs combined with `missing_method = "omit"` to
verify that `nps_fraction = nrow(original_data) / n_hat` (not
`nrow(na_dropped_data) / n_hat`).

The C-3 test fixtures all use NPS rows with no NAs; M-6 block 3 drops rows
but doesn't cross-check `nps_fraction`.

Options:
- **[A]** Add a test block to PR 2: "nps_fraction uses pre-NA-deletion row count" — construct an NPS with NAs in selection variables, call `ipw()` with `missing_method = "omit"`, and assert `hist$nps_fraction == nrow(nps_original) / n_hat` (not `nrow(nps_after_drop) / n_hat`). — Effort: low, Risk: low, Impact: catches a specific correctness bug that no other test would detect
- **[B]** Accept the existing tests; the plan Notes make the ordering requirement explicit and the builder can be trusted. — Risk: ordering bug would pass all tests
- **[C] Do nothing** — Risk: same as B

**Recommendation: A** — This is an explicitly called-out spec invariant that has no test coverage. The effort is minimal (inline fixture).

---

#### Section: File Write Surface Map

**Issue 5: Snapshot files absent from write surface map**
Severity: SUGGESTION
[Lens 5 — File Completeness]

PRs 2, 3, and 4 each add one or more snapshot tests (using
`expect_snapshot()` or `expect_snapshot(error = TRUE)`). Each snapshot causes
testthat to write a file under `tests/testthat/_snaps/`. These files are
committed to version control. The write surface map does not list them, and
neither do the acceptance criteria for any PR.

This is not blocking — testthat creates these files automatically — but the
tester might not notice they need to be staged and committed if the write
surface doesn't mention them.

Options:
- **[A]** Add a row for `tests/testthat/_snaps/test-nonprob-ipw.md` to the file write surface map, noting "auto-created by snapshot tests on first run." — Effort: low
- **[B]** Add a note to PR 2 acceptance criteria: "New snapshot files in `tests/testthat/_snaps/` are committed." — Effort: low
- **[C] Do nothing** — testthat snapshot workflow is documented in testing-standards.md; tester knows.

**Recommendation: B** — A one-line criterion is lower overhead than modifying the table.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 1 |

**Total issues:** 5

**Overall assessment:** The plan is structurally sound and spec coverage is complete — every gap has a PR and every test-spec block appears in the plan. Four required fixes are needed before implementation: a dependency field correction (Issue 1), two missing `test_invariants()` criteria (Issues 2–3), and a missing NA-boundary test for the `nps_fraction` computation (Issue 4). These are all small editorial or single-block additions, not plan restructuring. Resolve and this plan is ready to ship.
