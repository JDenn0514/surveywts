# Plan Review: class-system-refactor — Pass 1 (2026-06-28)

---

## New Issues

### Section: Task Group C — Delete weighted_df infrastructure

**Issue 1: Package fails to load after step 13 without an immediate devtools::document() call**
Severity: REQUIRED

After step 13 deletes `R/weighted-df-dplyr.R`, the existing NAMESPACE file still
contains `S3method(dplyr_reconstruct, weighted_df)`, `S3method(select, weighted_df)`,
etc. R's namespace loader will attempt to register these methods and fail with
"function not found" errors because the definitions were in the deleted file.
`devtools::test()` and `devtools::load_all()` will both fail with confusing errors
about missing functions, not about the refactor being incomplete.

Options:
- **[A]** Add a step 13.5 immediately after step 13: "Run `devtools::document()` to
  regenerate NAMESPACE without the deleted S3 methods. Confirm the package loads
  (`devtools::load_all()` succeeds) before proceeding." — Effort: low, Risk: low,
  Impact: implementer has a loadable package state throughout Group C.
- **[C] Do nothing** — Implementer encounters confusing namespace errors until
  Group E when devtools::document() is finally run; likely to waste time diagnosing.

**Recommendation: A** — Trivial fix; prevents confusing failure mode.

---

### Section: Task Group D — File write surface gaps

**Issue 2: `tests/testthat/test-calibrate-utils-nr.R` missing from write surface**
Severity: REQUIRED

`test-calibrate-utils-nr.R:628` contains:
```
expect_true(inherits(result, "weighted_df"))
```
This test passes a `data.frame` to a calibration function (via the NR engine) and
expects a `weighted_df` back. After the refactor, calibrate functions abort on
`data.frame` input with `surveywts_error_not_survey_base`. The test will fail with
an unexpected error, not the assertion failure it was expecting. The file must be
added to the write surface and updated.

Options:
- **[A]** Add `tests/testthat/test-calibrate-utils-nr.R` to the write surface in
  the file list; add task in Group B to update it (remove the data.frame/weighted_df
  happy-path test; add a `surveywts_error_not_survey_base` error test for the NR
  engine path). — Effort: low, Risk: low, Impact: test suite stays green.
- **[C] Do nothing** — CI fails on this test after the refactor.

**Recommendation: A** — Must fix.

---

### Section: Acceptance Criteria

**Issue 3: Changelog entry missing from acceptance criteria and file list**
Severity: REQUIRED

The standard acceptance criteria template requires:
> "Changelog entry written and committed on this branch"

Neither the acceptance criteria checklist nor the file list mentions a changelog
entry or a NEWS.md update for this PR.

Options:
- **[A]** Add to acceptance criteria: `[ ] Changelog entry written and committed on
  this branch`. Add `NEWS.md` or a changelog fragment file to the file list.
  — Effort: low, Risk: none.
- **[C] Do nothing** — PR lands without a release-visible record of the change.

**Recommendation: A** — Trivial omission; required by project workflow.

---

**Issue 4: No test for `wt_name = "new_col"` new-column creation behavior**
Severity: REQUIRED

The plan's Key Decisions specify a behavioral change: `wt_name = "new_col"` (non-NULL)
should write calibrated weights to a new column in `@data` AND update
`@variables$weights = "new_col"`, preserving the original column. This is new behavior
that has never existed. There is no test requirement in Group B, no acceptance criterion,
and no oracle description for this scenario.

Without a test, the implementer has no RED→GREEN signal for this behavior, and it
could silently be implemented incorrectly.

Options:
- **[A]** Add to Group B: "Add `test_that('calibrate_rake() wt_name = \"cal_wt\" writes
  new column and updates @variables$weights', ...)` covering: (a) new column present in
  `@data`, (b) `@variables$weights` equals `"cal_wt"`, (c) original weight column still
  present and unchanged." Add a corresponding acceptance criterion. Cover at least one
  function from the calibration family (the rest follow the same code path via
  `.update_survey_weights()`). — Effort: low, Risk: low.
- **[C] Do nothing** — New wt_name behavior ships untested; behavioral regression
  possible.

**Recommendation: A** — New behavior requires a test.

---

**Issue 5: `history_entry weight_col` field unspecified when `wt_name` is non-NULL**
Severity: REQUIRED

Currently, the history entry uses:
```r
weight_col = if (inherits(data, "data.frame")) { wt_name } else { data@variables$weights }
```
Task 17 says to remove the ternary (the `data.frame` branch goes away) but does not
specify what replaces it when `wt_name` is non-NULL (new column). The implementer must
decide: should `weight_col` in the history be the input column (`data@variables$weights`)
or the output column (`wt_name`)?

The history entry documents the column that was written (output), so it should be:
```r
weight_col = if (is.null(wt_name)) data@variables$weights else wt_name
```

Options:
- **[A]** Add a note to task 17 (and equivalently task 18, 19, 21, 24, 25, 26, 27)
  specifying: "History entry `weight_col` = `wt_name` when `wt_name` is non-NULL,
  else `data@variables$weights`." — Effort: low, Risk: low, Impact: consistent history.
- **[C] Do nothing** — Implementer guesses; likely inconsistency across functions.

**Recommendation: A** — Specifying this prevents subtle inconsistency in history.

---

**Issue 6: `devtools::run_examples()` missing from acceptance criteria**
Severity: REQUIRED

All 14 function files are getting new `@examples` blocks that use package datasets
and surveycore constructors. The acceptance criteria lists `devtools::check()` and
`devtools::document()` but not `devtools::run_examples()`. Broken examples can pass
`devtools::check()` if they use `\dontrun{}` (which this refactor avoids), but a
dedicated examples run during development catches issues earlier.

More importantly: the standard acceptance criteria template requires it, and the
updated examples are the most user-visible output of this PR.

Options:
- **[A]** Add to acceptance criteria: `[ ] devtools::run_examples() passes with 0
  errors`. — Effort: none (already in Group E task 33, just needs to be a criterion).
- **[C] Do nothing** — Broken examples may slip through.

**Recommendation: A** — Template requires it; cost is zero.

---

**Issue 7: `.check_weight_utils_class()` error class not updated in task notes**
Severity: REQUIRED

`R/weight-utils.R` has `.check_weight_utils_class()` which currently accepts
`data.frame` OR `survey_base` and errors with `surveywts_error_unsupported_class`.
After the refactor, `trim_weights()` and `rescale_weights()` should also reject
`data.frame` with `surveywts_error_not_survey_base`. The plan lists `weight-utils.R`
in the file list as "modified (remove weighted_df branches)" but task 26–27 do not
explicitly say to:
  1. Change `.check_weight_utils_class()` to reject `data.frame`
  2. Change the error class from `surveywts_error_unsupported_class` to
     `surveywts_error_not_survey_base`

The error class tables in `plans/error-messages.md` must stay consistent.

Options:
- **[A]** Add explicit sub-steps to tasks 26–27: "Update `.check_weight_utils_class()`
  in `R/weight-utils.R`: replace the `inherits(data, 'data.frame') || survey_base`
  check with survey_base–only; change error class to
  `surveywts_error_not_survey_base`." Add `surveywts_error_unsupported_class` as
  a retired class in `plans/error-messages.md` (or note that `weight-utils.R` and
  `calibrate-utils.R` will now use the unified class). — Effort: low, Risk: low.
- **[C] Do nothing** — `trim_weights()` and `rescale_weights()` throw a different
  error class than the rest of the package for `data.frame` input; inconsistent UX.

**Recommendation: A** — Uniform error class for `data.frame` input across all functions.

---

**Issue 8: `wt_name` passthrough to `.update_survey_weights()` unspecified for most callers**
Severity: REQUIRED

Task 17 says "Pass `wt_name` to `.update_survey_weights()`" for `calibrate_rake.R`.
But `.update_survey_weights()` is called by at least eight function files:
`calibrate_rake.R`, `calibrate_linear.R`, `calibrate_logit.R`, `poststratify.R`,
`adjust_nonresponse.R` (three calls), `redistribute_weights.R`, `trim_weights.R`,
`rescale_weights.R`. Tasks 18–27 do not mention updating the call-site signature
to pass `wt_name`.

Without explicit instructions, the implementer may update `calibrate_rake.R` but
forget to update the other seven files.

Options:
- **[A]** Add a general note at the top of Task Group D: "Every call to
  `.update_survey_weights()` must be updated to pass `wt_name = wt_name` as the
  new keyword argument. Grep for `.update_survey_weights(` in R/ to find all
  call sites before starting Group D." — Effort: low, Risk: low.
- **[C] Do nothing** — Several functions implement `wt_name = "new_col"` inconsistently
  (some pass it, others silently ignore it), causing test failures.

**Recommendation: A** — A grep reminder prevents a systematic miss.

---

### Section: Suggestions

**Issue 9: Task 20 text starts with a cross-reference that reads like task 17 is being repeated**
Severity: SUGGESTION

Task 20 begins: `**`R/calibrate_rake.R`** is task 17. **`R/calibrate.R`** —`. This
is confusing—an implementer scanning task numbers could think calibrate_rake.R has a
second task. Rewrite task 20 to start with `**`R/calibrate.R`**` directly.

**Recommendation:** Fix task 20 wording.

---

**Issue 10: `test-replicate-weights.R` "rejects weighted_df" tests will still pass but become misleading**
Severity: SUGGESTION

`test-replicate-weights.R` has five tests that construct a `structure(df, class = c("weighted_df", ...))` fixture to verify replicate functions reject it. After the refactor, `weighted_df` no longer exists as a package concept, but these tests will still pass because the fake `weighted_df` inherits from `data.frame`, which the replicate validator already rejects as a non-survey-design object. The tests themselves remain correct (they test rejection of non-survey inputs), but their descriptions refer to a defunct class.

This is not a failure condition and the plan correctly excludes the replicate family from changes. However, consider updating these test descriptions in a future minor cleanup PR.

**Recommendation:** Note for future cleanup; no action required in this PR.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 8 |
| SUGGESTION | 2 |

**Total issues:** 10

**Overall assessment:** The plan is well-structured and complete in its high-level scope.
Eight required issues need to be resolved — primarily: a missing `devtools::document()`
call after deleting `weighted-df-dplyr.R`, a missing test file in the write surface
(`test-calibrate-utils-nr.R`), missing changelog criterion, missing `wt_name` behavior
test, an underspecified history entry field, missing `devtools::run_examples()` criterion,
an unspecified error class update in `weight-utils.R`, and an underspecified `wt_name`
passthrough requirement for all `.update_survey_weights()` callers. After resolving these,
the plan is ready to implement.

---

## Plan Review: class-system-refactor — Pass 2 (2026-06-28)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Package fails to load after step 13 without devtools::document() | ✅ Resolved — task 16 added |
| 2 | test-calibrate-utils-nr.R missing from write surface | ✅ Resolved — task 12 added; file added to write surface |
| 3 | Changelog entry missing from acceptance criteria and file list | ✅ Resolved — NEWS.md criterion + task 40 + file list entry added |
| 4 | No test for wt_name = "new_col" behavior | ✅ Resolved — task 13 added |
| 5 | history_entry weight_col unspecified for new wt_name behavior | ✅ Resolved — specified in Group D pre-condition |
| 6 | devtools::run_examples() missing from acceptance criteria | ✅ Resolved — added as criterion + task 37 |
| 7 | .check_weight_utils_class() error class not updated | ✅ Resolved — task 19 specifies class change |
| 8 | wt_name passthrough to .update_survey_weights() underspecified | ✅ Resolved — Group D pre-condition specifies grep + update requirement |
| 9 | Task 20 text confusion (calibrate_rake labeled twice) | ✅ Resolved — task renumbered; calibrate.R is now task 24 |
| 10 | test-replicate-weights.R "rejects weighted_df" tests misleading | ⚠️ Still open by design — plan Notes section explains why no change is needed; tests will continue to pass |

### New Issues

No new issues found. All Pass 1 REQUIRED findings are resolved in the updated plan.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total new issues:** 0

**Overall assessment:** PASS. All eight required issues from Pass 1 have been
resolved. The plan is complete, internally consistent, and ready to implement.
Next step: `/r-implement` on branch `refactor/drop-weighted-df`.
