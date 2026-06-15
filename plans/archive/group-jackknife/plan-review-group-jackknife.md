## Plan Review: group-jackknife — Pass 1 (2026-05-28)

### New Issues

#### Section: PR 2 — File List

**Issue 1: `R/replicate-weights.R` missing from PR 2 file list**
Severity: BLOCKING
Violates: File Completeness lens; spec §3.4 requires adding `data.frame` branch to `.validate_reference_sample()`

Spec §3.4 explicitly mandates: "the DAGJK implementation must add a `data.frame` branch to that helper
(or add a pre-check before calling it)." The file `R/replicate-weights.R` is where
`.validate_reference_sample()` lives (confirmed at line 182). This modification is required for
the `reference_sample = data.frame(...)` error path and its snapshot to contain the `'i'` bullet.

The plan's PR 2 notes section (final paragraph of PR 2 notes) mentions this work, but the
PR 2 **file list** (`R/nps-group-jackknife.R`, `R/replicate-dispatch.R`, helpers, tests) does
not include `R/replicate-weights.R`. An implementer following the file list to drive their
work will skip this modification entirely. The snapshot test for `reference_sample = data.frame(...)`
would then fail or — worse — pass without the required `'i'` bullet if the existing
"Only `survey_taylor` is accepted" message is returned without the new line.

Note: `R/replicate-weights.R` is already in PR 1's write surface (for the overwrite helper
refactor), so the dependency is correct — PR 2 picks it up again for this separate
modification. No circular dependency; just a missing entry in PR 2's file list.

Options:
- **[A]** Add `R/replicate-weights.R` to PR 2's file list with a bullet: "Add `data.frame`
  branch to `.validate_reference_sample()` per spec §3.4; run existing bootstrap and
  nonresponse test files to confirm no regressions." — Effort: low, Risk: low,
  Impact: prevents silent skip of a spec-required behavior.
- **[B]** Promote the modification to PR 1, treating it as part of the "shared helper"
  refactor. — Effort: low, Risk: low, Impact: same; slightly cleaner since both changes
  are to the same file in PR 1 anyway.
- **[C] Do nothing** — Implementer relies solely on the notes paragraph, risks missing
  the modification or implementing it without a regression guard.

**Recommendation: A** — Keeps PR boundaries stable; adds the file entry where the
implementer's checklist will look for it.

---

#### Section: PR 2 — Acceptance Criteria

**Issue 2: §3.1 structural invariant count is wrong (plan says 15; test spec has 17)**
Severity: REQUIRED
Violates: Acceptance Criteria lens; acceptance criterion must map to test-spec rows exactly

PR 2 acceptance criteria state: "§3.1 happy path: all 15 structural invariants pass."
The test spec §3.1 table has 17 rows:

1. Returns `survey_nonprob`
2. Returns G replicate columns
3. Column names `repwt_1`…`repwt_G`
4. All columns exist in `@data`
5. `@variables$scale` = (G-1)/G
6. `@variables$rscales` = rep(1, G)
7. `@variables$mse` = TRUE
8. `@variables$type` = "group-jackknife"
9. Zero weight in exactly one column per unit
10. Positive weight in G-1 columns per unit
11. Original `@data` columns unchanged
12. Original base weight unchanged
13. History entry added
14. History entry `operation` field
15. History entry `groups` field
16. **History entry `scale` field** ← row 16, not in the "15" count
17. **`reference_sample` resolves correctly** ← row 17, not in the "15" count

If an implementer reads "15 structural invariants" and stops after row 15, they will not
test that the history entry's `scale` field equals `@variables$scale`, and will not test
the reference resolution invariant. Both are observably testable and spec-required.

Options:
- **[A]** Change "all 15 structural invariants" to "all 17 structural invariants listed
  in test-spec §3.1" — Effort: trivial, Risk: none, Impact: prevents under-testing.
- **[B]** Change to "all structural invariants listed in test-spec §3.1" (no count) — Effort:
  trivial, Risk: none, Impact: same; more resilient to future spec row additions.
- **[C] Do nothing** — Builder passes "15 OK," misses two verifiable invariants.

**Recommendation: B** — Drop the count; cite the spec table directly.

---

**Issue 3: `trim_threshold` capture value not precisely specified in PR 1 acceptance criteria**
Severity: REQUIRED
Violates: Acceptance Criteria lens; "numeric or NULL" is not an objectively verifiable value

PR 1 acceptance criterion states: "trim_threshold (numeric or NULL) — verified by three
named test blocks." This tells the tester the type but not the value. Looking at the current
`nonprob-ipw.R` code (lines 1144–1152), when `trim = TRUE` the threshold is computed inline as
`stats::median(w) + 5 * stats::IQR(w)` and passed directly to `.trim_weights_internal(upper = ...)`.
There is no variable currently capturing this computed value separately.

The DAGJK needs to reproduce this exact threshold in every replicate (`pmin(w, trim_threshold)`
per the impl plan notes). If the implementer stores `trim = TRUE` as the boolean rather than the
computed numeric, or stores the wrong expression (e.g., post-trim weight ceiling rather than the
computed threshold), the acceptance criterion "trim_threshold (numeric or NULL)" would still pass
type-checking.

The precise value to capture is: `stats::median(w_before_trim) + 5 * stats::IQR(w_before_trim)`,
where `w_before_trim` is the weight vector immediately before the trim block executes. This value
must be stored as a local variable before `.trim_weights_internal()` is called, then placed in
the history entry.

Options:
- **[A]** Add a "Notes" bullet to PR 1 and update the acceptance criterion: "trim_threshold
  equals `median(w) + 5*IQR(w)` computed from the pre-trim weight vector when `trim = TRUE`;
  test verifies the stored numeric equals this computed value (within `1e-10`)." — Effort: low,
  Risk: low, Impact: makes the test verifiable and tells the builder what to capture.
- **[B]** Add a dedicated test case: `expect_equal(entry$trim_threshold, median(w) + 5*IQR(w),
  tolerance = 1e-10)` with a comment explaining the computation. — Effort: low, same as A.
- **[C] Do nothing** — Implementer must infer the captured value from "resolved numeric
  threshold"; if wrong, DAGJK trim replication silently differs from the full-sample run.

**Recommendation: A** — Specifying the expression now prevents a silent correctness bug
in the DAGJK per-replicate trimming step.

---

**Issue 4: `.validate_reference_sample()` regression guard missing from PR 2 acceptance criteria**
Severity: REQUIRED
Violates: Acceptance Criteria lens; "run existing tests" in Notes is not a criterion

PR 2 notes: "After modifying the helper, run existing tests for the bootstrap and non-response
functions to confirm no regressions." This is the correct safety check but it lives in the
notes section, not in the acceptance criteria. Acceptance criteria are what the implementer
checks off before opening the PR. Notes are often skimmed or skipped.

The risk: `.validate_reference_sample()` is called from `.quasi_randomization_bootstrap()`
(line 718 of replicate-weights.R) and from the nonresponse pipeline. Adding a `data.frame`
branch changes behavior for every existing call site. If the new branch inadvertently alters
the `is_rep` detection path or the `"v"` bullet for non-data.frame inputs, existing snapshots
for the bootstrap and nonresponse error paths would fail.

Options:
- **[A]** Add an explicit acceptance criterion to PR 2: "Existing bootstrap and nonresponse
  test snapshots pass without updates after `.validate_reference_sample()` modification
  (no snapshot diffs expected)." — Effort: trivial, Risk: none, Impact: makes regression
  check mandatory before PR opens.
- **[B]** Move the regression note from Notes to a bold callout in the file list entry for
  `R/replicate-weights.R`. — Effort: trivial, Risk: none, Impact: slightly less strong than A.
- **[C] Do nothing** — Regression check remains optional; a breaking change to existing
  error messages could ship undetected.

**Recommendation: A** — The criterion is already described in notes; promoting it to
acceptance criteria costs nothing and prevents a class of silent regressions.

---

#### Section: PR 2 — Spec Coverage

**Issue 5: `groups_failed` and `seed` history entry fields unverified**
Severity: SUGGESTION
Violates: Spec Coverage lens; spec §3.6 defines 10 history entry fields; only 3 are checked

Spec §3.6 defines the history entry with ten fields: `step`, `operation`, `timestamp`,
`groups`, `groups_used`, `groups_failed`, `seed`, `scale`, `reference_design`,
`source_design`. The plan's acceptance criteria verify `operation` (via §3.1 row 14),
`groups` (row 15), and `scale` (row 16, once Issue 2 is resolved). The test spec §3.4
verifies `groups_used`. That leaves `groups_failed` and `seed` unverified by any criterion.

`groups_failed` is especially important: if the implementer sets `groups_failed = 0L`
always rather than computing `G - G_success`, the warning for `> 10%` failure would still
fire (it uses the failure count from the loop), but the history entry would silently
misreport. Similarly, `seed` is a reproducibility guarantee — if the wrong value (e.g.,
always `NULL`) is stored, callers cannot reconstruct the group assignment.

Options:
- **[A]** Add two acceptance criteria: (1) "History entry `groups_failed` equals `G - groups_used`
  for a run where some replicates fail"; (2) "History entry `seed` matches the `seed`
  argument (including `NULL`)." — Effort: low, Risk: none, Impact: closes two silent
  correctness gaps.
- **[B]** Add one combined criterion: "All 10 history entry fields from spec §3.6 are
  present and hold correct values." — Effort: low, Impact: same; less precise but covers
  all fields at once.
- **[C] Do nothing** — `groups_failed` and `seed` are never checked; silent mis-recording
  is possible.

**Recommendation: A** — The two most risky unverified fields get targeted criteria;
`step`, `timestamp`, `reference_design`, `source_design` are already tested implicitly
(object construction succeeds; `.snapshot_variables_for_history()` is an existing helper).

---

#### Section: Both PRs — File Completeness

**Issue 6: Changelog entries missing from both PR file lists**
Severity: SUGGESTION
Violates: File Completeness lens; project changelog convention (changelog/replicate/)

The project uses per-feature changelog files under `changelog/replicate/` (e.g.,
`changelog/replicate/feature-nps-bootstrap.md`). Neither PR 1 nor PR 2 lists a changelog
file. Prior PRs in the replicate phase (NPS bootstrap, infrastructure, jackknife) all have
corresponding entries.

Options:
- **[A]** Add changelog entries to each PR's file list:
  - PR 1: `changelog/replicate/feature-dagjk-prerequisites.md`
  - PR 2: `changelog/replicate/feature-nps-group-jackknife.md`
  Effort: trivial, Risk: none, Impact: maintains project history convention.
- **[B]** Write a single changelog entry for PR 2 only (since PR 1 is infrastructure with
  no user-visible change). — Effort: trivial, Risk: none, Impact: acceptable; PR 1 is
  legitimately invisible to users.
- **[C] Do nothing** — DAGJK feature arrives with no changelog entry; release notes author
  must reconstruct from git log.

**Recommendation: B** — PR 1 is an internal refactor with no exported behavior change;
PR 2 is the user-visible feature that warrants the entry.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total issues:** 6

**Overall assessment:** The plan is structurally sound — PR split is correct, dependency
order is right, and the acceptance criteria cover the bulk of the spec. One blocking gap
requires immediate resolution before implementation starts: `R/replicate-weights.R` is
missing from PR 2's file list despite being required for the spec-mandated `data.frame`
branch in `.validate_reference_sample()`. Three required issues tighten criteria that are
currently under-specified or miscounted. Two suggestions address minor completeness gaps.
Ready to implement after resolving Issues 1–4.

---

## Plan Review: group-jackknife — Pass 2 (2026-06-01)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `R/replicate-weights.R` missing from PR 2 file list | ✅ Resolved |
| 2 | §3.1 structural invariant count wrong (plan said 15; spec has 17) | ✅ Resolved |
| 3 | `trim_threshold` capture value not precisely specified in PR 1 acceptance criteria | ✅ Resolved |
| 4 | `.validate_reference_sample()` regression guard missing from PR 2 acceptance criteria | ✅ Resolved |
| 5 | `groups_failed` and `seed` history entry fields unverified | ✅ Resolved |
| 6 | Changelog entries missing from both PR file lists | ✅ Resolved |

### New Issues

#### Section: PR 2 — Acceptance Criteria

**Issue 7: "13 error classes" acceptance criterion undercounts required test scenarios**
Severity: REQUIRED
Violates: Acceptance Criteria lens; acceptance criteria must match the test spec scenario count, not the distinct class count.

The PR 2 acceptance criterion reads: "§3.6–3.10 all error paths: dual pattern (class= + snapshot) for all 13 error classes (including surveywts_error_dagjk_degenerate_replicate via direct internal call)."

The test spec §3.6–3.10 defines 18 distinct test scenarios (plus 1 direct internal test = 19 total), but only 13 distinct error classes. An implementer who reads "13 error classes" as the completion count would write 13 dual-pattern tests and declare the acceptance criterion met, missing 6 scenarios:

| Class | Test spec scenarios | Scenarios missed if "13 classes" read literally |
|---|---|---|
| `surveywts_error_not_survey_design` | `data.frame` + `weighted_df` (2 scenarios) | 1 (only 1 tested) |
| `surveywts_error_reference_sample_class` | `survey_replicate` + plain `data.frame` (2 scenarios) | 1 |
| `surveywts_error_dagjk_groups_too_small` | `groups=1`, `groups=0`, `groups=-1` (3 scenarios) | 2 |
| `surveywts_error_dagjk_groups_invalid` | `NA`, `"50"`, `c(10, 20)` (3 scenarios) | 2 |

Total missed: 6 test scenarios. These aren't redundant — each scenario exercises a different branch of the argument-parsing logic and produces a different snapshot (e.g., the error message for `groups = -1` will show `groups = -1`, which is structurally different from the `groups = 0` message). Without these tests, message formatting bugs for those cases go undetected.

Note: the PR 2 file list entry for `test-nps-group-jackknife.R` correctly says "§3.6–3.10 all error paths." The conflict is between the file list (correct) and the acceptance criteria (undercounts). Acceptance criteria are the "done" checklist — they must agree.

Options:
- **[A]** Change "for all 13 error classes" to "for all test scenarios from §3.6–3.10 (18 scenarios plus 1 direct internal test for surveywts_error_dagjk_degenerate_replicate)." — Effort: trivial, Risk: none, Impact: eliminates the ambiguity and ensures the checklist matches the test spec.
- **[B]** Change to "for all test scenarios from test-spec-group-jackknife.md §3.6–3.10, using the dual pattern on each row in the tables." — Effort: trivial, Risk: none, Impact: same; delegates the count to the test spec tables.
- **[C] Do nothing** — Builder writes 13 tests, acceptance criterion is satisfied on paper, 6 scenarios are untested.

**Recommendation: B** — Delegates to the test spec tables, which are authoritative and already enumerate each scenario. Avoids hard-coding a count that could silently drift if the test spec is updated.

---

#### Section: PR 2 — File List / Test Structure

**Issue 8: `make_dagjk_datasets()` helper conflicts with test spec "construct inline" instruction for Dataset D**
Severity: SUGGESTION
Violates: testing-standards.md §4 "Edge case data: inline in tests"; test spec §2 explicitly marks Dataset D as "Inline."

The PR 2 plan directs the builder to create `make_dagjk_datasets()` in `helper-test-data.R`, returning all four datasets (A, B, C, D) as a named list. Test spec §2 says "Inline" for Dataset D and "Construct inline in tests" for Dataset A. For Datasets A–C (standard shared setup used across many test blocks), the helper approach is consistent with `testing-standards.md`'s "repeated test setup → move to helper-*.R" rule. But Dataset D ("minimal NPS for boundary tests — at least 4 NPS units and 4 reference units") is an edge-case input by the test spec's own description: it is used only for boundary value tests and should stay inline per the edge-case rule.

If Dataset D is included in the helper, the implementation deviates from the testing-standards.md edge-case convention and makes the boundary test less self-contained (reader must jump to `helper-test-data.R` to see what "minimal NPS" means).

Options:
- **[A]** Revise the plan: `make_dagjk_datasets()` returns only Datasets A, B, C; Dataset D is constructed inline in each boundary test that needs it. — Effort: trivial, Risk: none, Impact: aligns with both testing-standards.md and test spec.
- **[B]** Keep all four in the helper but add a note: "Dataset D is returned by the helper for consistency, but its inline construction is simple enough that tests may also reproduce it locally if desired." — Effort: trivial, Risk: low, Impact: allows either approach.
- **[C] Do nothing** — Dataset D goes into the helper; boundary tests lose self-containment.

**Recommendation: A** — Dataset D is a 4+4 unit dataset that fits in three lines inline; there is no DRY benefit from putting it in the helper. Keeping it inline makes boundary tests easier to read and follow testing-standards.md.

---

**Issue 9: §3.4 calibration test must re-state literal raking targets in the assertion, not reference the helper**
Severity: SUGGESTION
Violates: test spec §3.4 explicit guidance; plan acceptance criterion is partially ambiguous.

The plan says:
- Helper note: "Dataset B: same + `rake()` with literal margin targets."
- Acceptance criterion: "within-replicate margins match literal targets within `1e-6`."

The test spec §3.4 is explicit: "The raking targets must be specified as literals in the test (e.g., `list(age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3))`), not read from the history entry — reading from the history entry is circular and would allow a buggy implementation that skips within-replicate calibration to pass."

The plan's acceptance criterion says "literal targets" but doesn't say *where* those literals must appear. An implementer might interpret "the helper uses literal targets when calling `rake()`" as satisfying the criterion, then write the test assertion as:

```r
expected <- result@metadata@weighting_history[[2]]$targets  # reads from history entry
```

or:

```r
expected <- make_dagjk_datasets()$rake_targets  # reads from helper state
```

Both would be circular for the same reasons the test spec warns about.

The plan should note explicitly that the §3.4 test assertion must re-state the raking target values as named literals in the test file, independent of the helper and independent of the history entry.

Options:
- **[A]** Add a note to the test file item (file #2 of PR 2): "The §3.4 within-replicate calibration verification must re-state the raking target values as named numeric literals in the test assertion — do not read targets from the helper function or from the history entry." — Effort: trivial, Risk: none, Impact: closes a subtle but spec-documented gap.
- **[B]** Add the raking target literals to the PR 2 acceptance criterion itself: "within-replicate margins match `<literal targets here>` within `1e-6`." — Effort: low, Risk: none, Impact: same; slightly more prescriptive.
- **[C] Do nothing** — "Literal targets" in the acceptance criterion is ambiguous; an implementer may write a circular assertion that passes despite a buggy implementation.

**Recommendation: A** — A single sentence added to the test file description eliminates the ambiguity without over-specifying the exact target values in the plan.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 2 |

**Total new issues:** 3

**Overall assessment:** All six Pass 1 issues are resolved. The plan is very close to implementation-ready. One required issue must be fixed before coding starts: the "13 error classes" acceptance criterion undercounts the test scenarios the test spec requires and will produce a false "done" signal if not corrected. Two suggestions address edge-case test placement and calibration assertion specificity — both are low effort and high value before implementation. Resolve Issue 7 and the plan is ready to ship to `/pipeline-ship`.
