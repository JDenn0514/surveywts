## Plan Review: calibrate-surveycore — Pass 1 (2026-06-04)

_Prior issues: none (Pass 1)._

---

### New Issues

#### Section: PR Map (both PRs)

**Issue 1: Changelog files absent from "Files touched" write surfaces**
Severity: REQUIRED
Violates Lens 5 — File Completeness

Both PRs list a changelog task (Task 12 for PR 1, Task 36 for PR 2) but
neither changelog file appears in the "Files touched — exact write surface"
section. Pipeline-ship uses the files-touched list as the authoritative write
surface for the shipper. A changelog omission here means the shipper may not
commit the changelog file before opening the PR.

Options:
- **[A]** Add `changelog/calibration/feature-calibrate-surveycore-pr1.md` to
  PR 1's files-touched list and `changelog/calibration/feature-calibrate-surveycore-pr2.md`
  to PR 2's files-touched list. Effort: trivial, Risk: none.
- **[B] Do nothing** — builder commits changelog manually but shipper has no
  record of it.

**Recommendation: A** — Changelog files belong in the write surface.

---

#### Section: PR 2 — Tests

**Issue 2: `helper-test-data.R` absent from PR 2's write surface**
Severity: REQUIRED
Violates Lens 5 — File Completeness / Lens 4 — Spec Coverage

PR 2 adds tests for `survey_replicate` inputs in `test-02-calibrate.R`,
`test-03-rake.R`, and `test-04-poststratify.R`. The test-spec names three
non-trivial test fixtures:

- `replicate_design` — constructed via `create_bootstrap_weights()` or
  `surveycore::as_survey_replicate()` with explicit replicate columns
- `brr_design` — `survey_replicate` with negative BRR replicate weights
- `empty_cell_replicate_design` — replicate where one column assigns zero
  weight to all members of one calibration category

These constructions are non-trivial and are reused across all three test files
(test-02, test-03, test-04). Per `testing-standards.md §4`: package-specific
generators live in `helper-*.R`. If these fixtures are constructed inline in
each test file, the construction logic is duplicated three times. The plan
does not mention updating `tests/testthat/helper-test-data.R` or specifying
where these fixtures are constructed.

Options:
- **[A]** Add `tests/testthat/helper-test-data.R` to PR 2's files-touched.
  Add helper functions `.make_replicate_design()`, `.make_brr_design()`, and
  `.make_empty_cell_replicate_design()` (or equivalent names) to
  `helper-test-data.R` before writing the test expansions. Effort: low,
  Risk: none; eliminates triple duplication.
- **[B]** Construct each fixture inline in each test file where it is first
  needed. Reference the inline construction in the two subsequent test files.
  Effort: low, Risk: none (slightly more duplication).
- **[C] Do nothing** — builder resolves ad hoc during coding; risk of
  inconsistent fixture construction across files.

**Recommendation: A** — `helper-test-data.R` already exists; adding three
helper functions is low effort and matches the established test-data pattern.

---

**Issue 3: Shared error paths for `calibrate_rake()` and `calibrate_poststrat()` not named in PR 2 tasks**
Severity: REQUIRED
Violates Lens 4 — Spec Coverage (every error class in spec requires a test)

The spec says: "Error paths for `calibrate_rake()`: same as `calibrate_greg()`
plus `surveywts_error_cap_not_supported_survey`." The test-spec says: "All
other error paths: same as `calibrate_greg()`." The plan's PR 2 Task 19
(rake) says only "Error path — `surveywts_error_cap_not_supported_survey`
(already tested; verify still passes)." It does not name the six new error
paths that were added to `calibrate_greg()` (from test-spec Issue 4 resolution):

- `surveywts_error_weights_not_found`
- `surveywts_error_weights_not_numeric`
- `surveywts_error_wt_name_not_scalar`
- `surveywts_error_wt_name_empty`
- `surveywts_error_variable_has_na`
- `surveywts_error_margins_format_invalid`

The same gap exists for `calibrate_poststrat()`. Task 26 lists only the five
poststrat-specific error paths. The six shared new paths are absent.

Per `testing-standards.md §2`: "Every exported function must have tests in
all three categories." Each function's test file must cover every error class
in that function's error table — not just the function-specific ones.

Options:
- **[A]** Explicitly add the six new shared error path tests to Tasks 15–19
  (rake) and Tasks 20–26 (poststrat) using the dual pattern (`expect_error(class=…)` +
  `expect_snapshot(error=TRUE,…)`). Effort: low, Risk: none.
- **[B] Do nothing** — builder may infer this from "same as calibrate_greg()"
  in the spec, but the plan lacks the explicit instruction.

**Recommendation: A** — Explicit coverage requirements prevent omissions.

---

**Issue 4: `@return` documentation update for partial replicate calibration not in plan**
Severity: REQUIRED
Violates Lens 4 — Spec Coverage (spec review Issue 10 resolution: Option A)

The spec review (Issue 10, resolved with Option A) specified: "Add to the
`survey_replicate` output description: 'When some replicates fail (see
`$replicate_converged`), the returned object has uncalibrated weights for
those replicates. Variance estimates from this object will mix calibrated and
uncalibrated replicate draws; users should inspect
`output@calibration$replicate_converged` before computing variance estimates.'"

The plan's PR 2 implementation steps (29a, 30a, 31a) mention updating
`@param data` to add `survey_replicate` support. None mention updating `@return`
to add the partial-calibration caveat. This is a spec-mandated doc change that
is not tracked in the plan.

Options:
- **[A]** Add to PR 2 tasks (steps 29a, 30a, 31a): also update `@return` in
  each function's roxygen to include the `survey_replicate` partial-calibration
  caveat. One sentence per function. Effort: trivial, Risk: none.
- **[B] Do nothing** — roxygen changes are made informally; caveat may be
  missed.

**Recommendation: A** — The spec review explicitly required this wording;
the plan should track it.

---

**Issue 5: `test_invariants()` requirement for `survey_nonprob` outputs not in PR 2 acceptance criteria**
Severity: REQUIRED
Violates Lens 3 — Acceptance Criteria / `testing-surveywts.md §test_invariants()`

`testing-surveywts.md` states: "Every `test_that()` block that creates a
`weighted_df` or `survey_nonprob` object must call `test_invariants(obj)` as
its **first** assertion."

PR 2's HN tests (HN-1 through HN-4) create `survey_nonprob` output from
`calibrate_greg(nonprob_design, targets)`. None of the acceptance criteria
mention `test_invariants(output)` as the first assertion for these tests.
Similarly, HN-equivalent tests for `calibrate_rake()` and
`calibrate_poststrat()` (which are referenced by pattern reference but not
listed individually in the tasks) would also produce `survey_nonprob` outputs.

Options:
- **[A]** Add to PR 2 acceptance criteria: "HN tests (and rake/poststrat
  nonprob equivalents): `test_invariants(output)` is first assertion in each
  block that produces `survey_nonprob`." Effort: trivial, Risk: none.
- **[B] Do nothing** — builder may know the convention but the plan does not
  enforce it.

**Recommendation: A** — `test_invariants()` is a hard package requirement;
acceptance criteria should enforce it.

---

#### Section: PR 1 — Task Ordering and Snapshot Creation

**Issue 6: No mention of snapshot creation/commit for new `expect_snapshot()` tests**
Severity: SUGGESTION
Violates Lens 3 — Acceptance Criteria (procedural completeness)

PR 1 adds tests using the `@calibration` structure checks. PR 2 adds many
new `expect_snapshot(error = TRUE, ...)` blocks for the 6 shared error paths
that are new in each of rake and poststrat test files. On first run, testthat
auto-creates snapshot files in `tests/testthat/_snaps/`. The plan does not
mention that new snapshots must be reviewed (via `testthat::snapshot_review()`)
and committed before opening the PR.

`testing-standards.md §3`: "Snapshot failures block PRs. They are not
auto-updated — they represent deliberate decisions about error message text."

Options:
- **[A]** Add a task after the first full `devtools::test()` run in each PR:
  "Run `testthat::snapshot_review()` to review and accept new snapshots; commit
  the new `_snaps/*.md` files on this branch." Effort: trivial, Risk: none.
- **[B] Do nothing** — builder knows the `testthat` workflow; snapshots
  are created and committed as part of normal test iteration.

**Recommendation: A** — Explicit for completeness, though experienced builders
may not need it.

---

#### Section: PR 1 → PR 2 Intermediate State

**Issue 7: Between PR 1 and PR 2, `survey_replicate` input silently returns partial result**
Severity: SUGGESTION
Violates Lens 2 — Dependency Ordering (intermediate state correctness)

After PR 1 merges, `.check_input_class()` no longer throws for
`survey_replicate`. But `calibrate_greg()`, `calibrate_rake()`, and
`calibrate_poststrat()` have no replicate loop yet. A caller passing a
`survey_replicate` between PR 1 and PR 2 would:

1. Pass `.check_input_class()` silently
2. Run the full-sample calibration (replicates untouched)
3. Return a `survey_replicate` with calibrated full-sample weights, uncalibrated
   replicate columns, and `@calibration = NULL`

This is worse than the previous behavior (an explicit error). While this
intermediate state only exists on the `develop` branch (not `main`), and CI
should still pass because no tests exercise `survey_replicate` input in the
calibrate functions until PR 2, a developer who pulls `develop` between the
two PRs would see misleading behavior.

Options:
- **[A]** Accept the intermediate state. Solo development, CI passes, and the
  plan's PR sequence is clear. Document the intermediate state in the PR 1
  description. Effort: none, Risk: low.
- **[B]** Move the `.check_input_class()` change to PR 2. PR 1 only delivers
  `.update_survey_weights()` and `.build_calibration_provenance()`. PR 2 then
  removes the replicate error AND adds the replicate loop atomically. Write
  surfaces of PR 1 (`R/utils.R`) would still be touched in PR 2 (`R/utils.R`
  for `.check_input_class()`). Effort: low (move one change to PR 2),
  Risk: requires accepting write-surface overlap between PRs (allowed for
  sequential PRs).
- **[C] Do nothing** — intermediate state exists; solo dev, no real-world
  impact.

**Recommendation: A or B** — For solo development, option A is fine. If the
author wants cleaner atomicity, option B ensures that `survey_replicate` goes
from "error" to "fully supported" in one PR.

---

#### Section: PR 2 Size

**Issue 8: PR 2 modifies 6 files across 3 functions; may exceed review clarity threshold**
Severity: SUGGESTION
Violates Lens 1 — PR Granularity (spirit of the ~3-new-files rule)

PR 2 modifies 3 source files and 3 test files. While the files are modified
(not new), and the rule targets "new R files + their test files," the
behavioral additions are substantial: each source file gains a replicate loop,
x_matrix construction, and `.build_calibration_provenance()` call; each test
file gains 15–30 new test blocks.

An alternative split:
- **PR 2a**: `calibrate_greg()` only (establishes the replicate loop pattern)
- **PR 2b**: `calibrate_rake()` + `calibrate_poststrat()` (follow established
  pattern)

The spec says "PR range: PR 1–2" (2 PRs total), suggesting the author intended
the current split. Splitting further would deviate from the spec's recommendation
but would make each PR easier to review.

Options:
- **[A]** Keep current split (PR 1 + PR 2). The spec recommended 2 PRs; all
  3 functions follow the same pattern, so reviewing them together is coherent.
  Effort: none, Risk: none.
- **[B]** Split into 3 PRs: PR 1 infra, PR 2 greg, PR 3 rake + poststrat.
  Effort: low (update plan only), Risk: none.
- **[C] Do nothing** — keep as is.

**Recommendation: A** — The spec recommended 2 PRs; the behavioral pattern is
identical across functions; bundling is justified.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 8

**Overall assessment:** The plan is well-structured with clear TDD ordering
and comprehensive spec coverage. No blocking issues — the dependency order is
correct, the PR split is defensible, and the acceptance criteria are largely
objective and verifiable. Five required issues need resolution before handing
off to the builder: two are file-tracking gaps (changelog and helper-test-data),
one is missing explicit error-path coverage for rake and poststrat, one is a
missing @return doc update from a spec-review resolution, and one is a
missing `test_invariants()` requirement in the criteria. All five are low-effort
fixes. With these resolved, the plan is ready for `/r-implement`.

---

## Plan Review: calibrate-surveycore — Pass 2 (Stage 3 resolution) (2026-06-04)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Changelog files absent from "Files touched" write surfaces | ✅ Resolved — added to both PRs' files-touched lists |
| 2 | `helper-test-data.R` absent from PR 2's write surface | ✅ Resolved — added to files-touched; Task 0 added with three helper functions |
| 3 | Shared error paths for rake and poststrat not named in PR 2 tasks | ✅ Resolved — Tasks 19 and 26 now list the six shared new error paths explicitly |
| 4 | `@return` documentation update for partial replicate calibration not in plan | ✅ Resolved — Steps 29a, 30a, 31a now include `@return` update instruction |
| 5 | `test_invariants()` requirement for `survey_nonprob` outputs not in acceptance criteria | ✅ Resolved — added to HN-1 through HN-4 criteria and acceptance criteria list |
| 6 | No mention of snapshot creation/commit | ✅ Resolved — snapshot review step added to both PRs (Task 11 in PR 1, Task 35 in PR 2); `_snaps/` in PR 2 files-touched |
| 7 | Intermediate state between PR 1 and PR 2 | ✅ Accepted (Option A) — solo development, CI passes; no plan change |
| 8 | PR 2 size (6 files modified) | ✅ Accepted (Option A) — spec recommends 2 PRs; pattern is identical; no split |

### New Issues

No new issues found. All five required issues from Pass 1 are resolved. The
plan accurately reflects the spec, test-spec, and package conventions.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total issues:** 0

**Overall assessment:** PASS. All required issues resolved. The plan is ready
for `/r-implement`.
