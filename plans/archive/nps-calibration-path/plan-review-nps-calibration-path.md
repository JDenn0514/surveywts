## Plan Review: nps-calibration-path — Pass 1 (2026-06-15)

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — Calibration-only QR bootstrap path

**Issue 1: `surveywts_error_qr_bootstrap_no_reference` missing from test tasks and AC**
Severity: REQUIRED

The test-spec error paths table (`test-spec-nps-calibration-path.md`) includes
`surveywts_error_qr_bootstrap_no_reference` as a required dual test (error class
+ snapshot). The trigger is: `nps_calib_b` variant with no stored reference and
no `reference_sample` arg supplied. The spec also lists this error in the errors
table with trigger "Calibration-only Level B and no reference design available."

This error class does not appear in PR 1's task 2 (error path tests) or in the
acceptance criteria checklist. Task 2 lists three scenarios:
`surveywts_error_qr_bootstrap_no_history`, `surveywts_error_reference_sample_class`,
and a snapshot assertion on `surveywts_error_qr_bootstrap_requires_nonprob`. The
Level B no-reference error is absent. Task 5 (Level B and warning paths) covers
the Level B happy path and warnings but not this error.

Options:
- **[A]** Add a fourth dual block to task 2: construct `nps_calib_b` with
  `calib_entry$parameters$reference_design` cleared to `NULL`; call
  `create_bootstrap_weights(type = "quasi-randomization")` without
  `reference_sample`; assert `class = "surveywts_error_qr_bootstrap_no_reference"` +
  snapshot. Add the corresponding AC checkbox. — Effort: low, Risk: low, Impact:
  closes spec coverage gap; prevents a missing test reaching CI.
- **[B]** Move the test to task 5 (Level B section). — Effort: low, Risk: low,
  Impact: same coverage; grouping may be cleaner since the trigger requires a
  Level B fixture.
- **[C] Do nothing** — The error class is implemented (task 9 covers it) but
  has no corresponding test. Coverage gap ships to CI.

**Recommendation: A** — Keep all error path tests in task 2 for consistency;
the fixture is a small inline variant of `nps_calib_b`.

---

**Issue 2: Calibration dispatch table will be duplicated across PR 1 and PR 2**
Severity: REQUIRED
Violates `engineering-preferences.md §1 DRY — flag repetition aggressively`
and `surveywts-conventions.md §3 File Organization — Helpers shared by 2+
functions in the same family go to {family}-utils.R`.

PR 1 task 9 implements the calibration dispatch table inline inside the new
calibration-only branch of `.quasi_randomization_bootstrap()`. PR 2 task 9
implements the same dispatch table inline inside `.dagjk_single_replicate_calib()`.
The two call sites are different (SRSWR replicate vs. group-deleted replicate;
different starting weights), but the dispatch logic — which function to call and
which parameters to forward — is identical per the spec's explicit note:
"same dispatch table as PR 1."

`replicate-utils.R` is the declared family utils file for all `create_*_weights()`
functions. Per conventions, shared dispatch logic belongs there.

Options:
- **[A]** Extract `.dispatch_calibration_replay(data, calib_entry, ref_design, use_level_b)` as
  an internal helper in `replicate-utils.R` in PR 1. PR 2 calls it inside
  `.dagjk_single_replicate_calib()`. The helper handles all four operation
  strings, the `"raking"` legacy fallback, and the `poststratify` parameter
  exclusion rule. Add `replicate-utils.R` to PR 2's file list. — Effort: medium,
  Risk: low, Impact: eliminates ~20–30 lines of duplicate dispatch logic;
  future calibration operation additions are one-file changes.
- **[B]** Implement independently in both PRs with a comment cross-referencing.
  Mark for DRY cleanup in a follow-up chore PR. — Effort: low now, medium later,
  Risk: medium (implementations drift if one is updated and the other is not),
  Impact: defers the problem.
- **[C] Do nothing** — Both PRs ship with identical dispatch switch blocks in
  separate files; any future change to the dispatch table requires two coordinated
  edits.

**Recommendation: A** — Extract now. The signature is clean, the two call sites
differ only in the input data frame and starting weights (handled by the caller),
and `replicate-utils.R` is the right home. Add `R/replicate-utils.R` to PR 2's
file list since it is now read by `.dagjk_single_replicate_calib()`.

---

#### Section: PR 2 — Calibration-only DAGJK path

**Issue 3: `surveywts_warning_dagjk_negative_replicate_weights` is unreachable on the calibration-only path**
Severity: REQUIRED

PR 2 task 5 lists "Warning: `surveywts_warning_dagjk_negative_replicate_weights`"
as a test to write. The test-spec describes it as: "Construct a `survey_nonprob`
calibrated to tight count targets where group deletion forces `calibrate_rake()`
to produce negative weights." This test cannot be implemented as described.

Two reasons:
1. `calibrate_rake()` uses iterative proportional fitting (IPF), which multiplies
   existing positive weights by non-negative correction factors at every margin.
   IPF cannot produce negative weights by construction.
2. For `calibrate_linear()` (which CAN produce negative weights when `bounds = NULL`),
   the surveycore S7 validator fires when calibration tries to write negative weights
   back into a `survey_nonprob`'s `@data` property. This converts the calibration
   result into `surveywts_error_dagjk_degenerate_replicate`, which marks the
   replicate as failed. The negative weights never reach the post-loop matrix check.

This exact situation is already documented in the existing test suite:

```r
# test-nps-group-jackknife.R, line 694-708
test_that("create_group_jackknife_weights() negative-weight warning path is defensive", {
  # Note: surveywts_warning_dagjk_negative_replicate_weights cannot be triggered
  # via the public API because:
  #   1. rake() (IPF) always produces strictly positive weights by construction.
  #   2. calibrate() with method="linear" would produce negative weights only when
  #      multiple margins simultaneously push the reference-category units below zero.
  #      However, when this occurs, the surveycore survey_nonprob S7 validator fires
  #      during .update_survey_weights(), converting the case into a
  #      surveywts_error_dagjk_degenerate_replicate.
  # This test documents the defensive nature of the check.
```

The same logic applies to the calibration-only path. The `surveywts_warning_dagjk_negative_replicate_weights`
post-loop check is defensive code for both paths; it fires only if a future change
allows negative weights to bypass all current interception points.

Task 5's warning test as written will leave the implementer unable to construct a
working fixture, or will produce a test that triggers a different error
(`surveywts_error_dagjk_degenerate_replicate` or `surveywts_error_dagjk_all_replicates_failed`)
instead of the expected warning.

Options:
- **[A]** Replace the `surveywts_warning_dagjk_negative_replicate_weights` test
  requirement in task 5 with a defensive test following the existing pattern (lines
  694-708 and 955-965 of `test-nps-group-jackknife.R`). Write a `test_that()` block
  that documents the unreachability and verifies the assembled replicate matrix
  contains only non-negative values under normal calibration-only operation. Do NOT
  include `expect_warning(class = 'surveywts_warning_dagjk_negative_replicate_weights')`
  since this cannot be triggered via the public API. — Effort: low, Risk: low,
  Impact: prevents wasted implementation time; adds useful documentation test.
- **[B]** Remove the test entirely from task 5; note that the warning is already
  covered by the existing defensive tests for the IPW path. — Effort: low, Risk:
  low, Impact: slightly less coverage documentation.
- **[C] Do nothing** — Implementer will spend time on an unfulfillable test
  scenario, or will ship a test that doesn't test what it claims.

**Recommendation: A** — Follow the existing defensive test pattern. The implementer
has clear prior art at lines 694-708 and 955-965 to follow.

---

**Issue 4: PR 2 acceptance criteria missing explicit checkbox for `surveywts_error_dagjk_no_reference`**
Severity: SUGGESTION

`surveywts_error_dagjk_no_reference` is listed in PR 2 task 2 (dual error block to
write) and in the test-spec error paths table, but does not appear as an explicit
AC checkbox in the PR 2 acceptance criteria section. All other tested error classes
(`surveywts_error_dagjk_requires_nonprob`, `surveywts_error_dagjk_no_history`) have
explicit AC checkboxes.

Options:
- **[A]** Add: `- [ ] surveywts_error_dagjk_no_reference fires on calibration-only
  Level B with no reference available (snapshot + class assertion)` to the PR 2 AC.
- **[B]** Do nothing — the test is covered by task 2; the AC omission is cosmetic.

**Recommendation: A** — Keeps the AC checklist complete and self-consistent.

---

**Issue 5: PR 2 acceptance criteria missing seed reproducibility checkbox**
Severity: SUGGESTION

The test-spec has a reproducibility row: "Both runs produce identical `repwt_1`
vectors" for `nps_calib_a` with `seed = 99L`. This is in task 3 (PR 2 happy
path) but not in the acceptance criteria checklist. PR 1 does have the corresponding
seed reproducibility checkpoint: "Reproducibility: same seed gives identical `repwt_1`."

Options:
- **[A]** Add: `- [ ] Reproducibility: same seed produces identical repwt_1 column
  for calibration-only DAGJK` to PR 2 AC.
- **[B]** Do nothing — the test is written in task 3; the AC omission is cosmetic.

**Recommendation: A** — Symmetry with PR 1 AC.

---

**Issue 6: PR 2 task 9 should explicitly repeat the `"raking"` legacy fallback**
Severity: SUGGESTION

PR 2 task 9 says to "Dispatch to calibration function using same dispatch table as
PR 1." The legacy `"raking"` operation fallback (`calib_entry$parameters$margins`
when `$targets` is NULL`) is described in PR 1 task 9 but not repeated in PR 2
task 9. If option A of Issue 2 is adopted (shared dispatch helper), this is moot.
If not, the implementer of PR 2 could miss the legacy fallback.

Options:
- **[A]** Add one sentence to PR 2 task 9: "Include the `"raking"` → `margins`
  legacy fallback when `$targets` is NULL (same as PR 1 task 9)." — Effort: trivial.
- **[B]** Adopt Issue 2 option A (shared dispatch helper) and this becomes moot.
- **[C] Do nothing** — Low risk since the builder is expected to read PR 1 task 9.

**Recommendation: B** — If Issue 2 resolves to a shared dispatch helper, this
issue disappears. If not, adopt A.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 3 |

**Total issues:** 6

**Overall assessment:** The plan is structurally sound — PR split is clean, TDD
ordering is correct, spec coverage is good, and the AC are mostly complete. Three
required fixes are needed before coding starts: add the missing
`surveywts_error_qr_bootstrap_no_reference` test to PR 1, extract the duplicated
dispatch table into a shared helper, and correct the unreachable negative-weight
warning test in PR 2 task 5.

---

## Resolution — Pass 1 (2026-06-15)

All 6 issues resolved. Verdict: **PASS**

| Issue | Resolution |
|---|---|
| 1 — `surveywts_error_qr_bootstrap_no_reference` missing from PR 1 task 2 + AC | Fixed: added fourth dual block to task 2 and corresponding AC checkbox |
| 2 — Dispatch table duplicated across PR 1 and PR 2 | Fixed: extracted `.dispatch_calibration_replay()` helper to `replicate-utils.R` in PR 1; PR 2 calls it |
| 3 — `surveywts_warning_dagjk_negative_replicate_weights` unreachable | Fixed: replaced with defensive test pattern following lines 694-708 / 955-965 |
| 4 — PR 2 AC missing `surveywts_error_dagjk_no_reference` checkbox | Fixed: added checkbox |
| 5 — PR 2 AC missing seed reproducibility checkbox | Fixed: added checkbox |
| 6 — PR 2 task 9 missing `"raking"` legacy fallback mention | Closed as moot: shared dispatch helper owns the fallback |
