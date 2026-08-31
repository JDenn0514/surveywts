# Implementation Plan — class-system-refactor

**Status:** PLAN_READY
**Source plan:** `plans/class-system-refactor.md`
**Approach:** Single PR — removes `weighted_df` and plain `data.frame` dispatch
from all non-`ipw()` functions; functions will accept only `survey_base` objects.

---

## Overview

This plan converts the surveywts API to accept only `survey_base` objects
(`survey_nonprob`, `survey_taylor`, `survey_replicate`). It removes the
`weighted_df` S3 class and all plain `data.frame` input paths, replacing
them with a single `cli_abort()` that points users to the relevant surveycore
constructor. All function examples are updated to use surveycore constructors.
`ipw()` is explicitly excluded — its changes require a separate spec.

---

## PR map

- [x] PR 1: `refactor/drop-weighted-df` — Remove `weighted_df` class and
  plain `data.frame` input; update all functions to accept only `survey_base`
  objects; update all examples and tests.

---

### PR 1: Drop weighted_df; survey_base–only inputs

**Branch:** `refactor/drop-weighted-df`
**Depends on:** none

---

#### Task group A — Error class registration

**Tasks:**
1. Add `surveywts_error_not_survey_base` to `plans/error-messages.md` with
   trigger condition: "Input is not a `survey_base` object (e.g., a plain
   `data.frame`)". This class is used by all calibration, nonresponse, utility,
   and diagnostic functions after the refactor. Retire (mark deprecated)
   `surveywts_error_unsupported_class` — it is being replaced by the unified
   `surveywts_error_not_survey_base` class. **Do this before writing any R code.**

---

#### Task group B — Tests (write RED before touching source)

All new `expect_error(class = "surveywts_error_not_survey_base")` +
`expect_snapshot(error = TRUE)` pairs must be confirmed failing before any
source edits.

**Tasks:**
2. **`tests/testthat/test-00-classes.R`** — Delete the entire file. All
   `weighted_df`-specific tests (dplyr_reconstruct, print.weighted_df,
   class vector, weighting_history attribute) are removed. No replacements
   needed — `survey_nonprob` print tests already live in
   `test-replicate-print.R`.

3. **`tests/testthat/test-02-calibrate.R`** — Remove all `weighted_df` and
   `data.frame` happy-path blocks. Add one new block:
   ```r
   test_that("calibrate() aborts with cli error for data.frame input", {
     expect_error(
       calibrate(make_surveywts_data(), targets = targets_a),
       class = "surveywts_error_not_survey_base"
     )
     expect_snapshot(error = TRUE,
       calibrate(make_surveywts_data(), targets = targets_a)
     )
   })
   ```

4. **`tests/testthat/test-03-rake.R`** — Same pattern as test-02: remove
   `weighted_df`/`data.frame` blocks; add `surveywts_error_not_survey_base`
   error test.

5. **`tests/testthat/test-04-poststratify.R`** — Same.

6. **`tests/testthat/test-05-nonresponse.R`** — Remove `weighted_df`/
   `data.frame` blocks from `adjust_nonresponse()` and
   `redistribute_weights()` tests. Add `surveywts_error_not_survey_base`
   error tests for both functions.

7. **`tests/testthat/test-calibrate-linear.R`** — Remove all `weighted_df`
   and `data.frame` happy-path blocks (H1, H2, H5, H6b, and any others that
   assert `inherits(result, "weighted_df")`). Add
   `surveywts_error_not_survey_base` error test.

8. **`tests/testthat/test-calibrate-logit.R`** — Same.

9. **`tests/testthat/test-weight-utils.R`** — Remove `weighted_df`/
   `data.frame` paths from `trim_weights()` and `rescale_weights()` tests.
   Add `surveywts_error_not_survey_base` error tests for both.

10. **`tests/testthat/test-06-diagnostics.R`** — Remove `data.frame` and
    `weighted_df` input paths from `effective_sample_size()`,
    `weight_variability()`, and `summarize_weights()` tests. Add
    `surveywts_error_not_survey_base` error tests for each.

11. **`tests/testthat/test-nps-jackknife.R`** — Remove the
    `create_jackknife_weights() type='grouped' rejects weighted_df input`
    block. That test was for the replicate-functions' explicit rejection of
    `weighted_df`; after the refactor the general `survey_base` guard in
    `replicate-utils.R` handles this.

12. **`tests/testthat/test-calibrate-utils-nr.R`** — Line 628 asserts
    `expect_true(inherits(result, "weighted_df"))` for a data.frame input
    through the NR raking engine. Remove this data.frame happy-path block;
    replace with a `surveywts_error_not_survey_base` error test for the NR
    code path:
    ```r
    test_that("NR raking engine aborts with cli error for data.frame input", {
      expect_error(
        calibrate_rake(make_surveywts_data(), targets = targets_a,
                       algorithm = "nr"),
        class = "surveywts_error_not_survey_base"
      )
    })
    ```

13. **`tests/testthat/test-03-rake.R` or `test-calibrate-utils-nr.R`** — Add
    one `wt_name` behavior test covering the new non-NULL path:
    ```r
    test_that("calibrate_rake() wt_name='cal_wt' writes new column, updates @variables$weights", {
      ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
      result <- calibrate_rake(ns_svy, targets = targets_a, wt_name = "cal_wt")
      # (a) new column present in @data
      expect_true("cal_wt" %in% names(result@data))
      # (b) @variables$weights updated
      expect_identical(result@variables$weights, "cal_wt")
      # (c) original weight column preserved
      expect_true("weight" %in% names(result@data))
    })
    ```
    This test covers the `.update_survey_weights()` wt_name branch for all
    functions (they share the same helper).

14. **Confirm RED:** Run `devtools::test()`. The new `expect_error()` and
    `expect_snapshot(error = TRUE)` blocks must fail (the abort is not fired
    yet because source hasn't changed). The `wt_name = "cal_wt"` test must
    also fail (the new-column logic does not yet exist). All pre-existing
    survey-path tests should still pass.

---

#### Task group C — Delete weighted_df infrastructure

Do NOT proceed until task 14 (RED confirmation) is complete.

**Tasks:**
15. **Delete `R/weighted-df-dplyr.R`** entirely. This removes
    `dplyr_reconstruct.weighted_df()`, `select.weighted_df()`,
    `rename.weighted_df()`, `mutate.weighted_df()`, and
    `.reconstruct_weighted_df()`.

16. **Run `devtools::document()` immediately after step 15.** The existing
    NAMESPACE contains `S3method(dplyr_reconstruct, weighted_df)` and related
    entries. Until NAMESPACE is regenerated, R cannot load the package
    namespace (it will fail with "function not found" for the deleted methods).
    After this step, run `devtools::load_all()` to confirm the package loads
    cleanly. The package will still not compile fully until Groups C–D are
    complete, because function files still call `.make_weighted_df()`.

17. **`R/methods-print.R`** — Delete `print.weighted_df()` and its
    roxygen2 block. Keep the S7 print methods for `survey_nonprob`,
    `survey_replicate`, and `survey_taylor` untouched.

18. **`R/utils.R`** — Make the following targeted edits:
    - **Remove `.make_weighted_df()`** and its comment block (lines ≈593–625).
    - **Update `.validate_wt_name()`**: add `if (is.null(wt_name)) return(invisible(TRUE))`
      as the first line, so `NULL` is valid (the new default). The existing
      error classes `surveywts_error_wt_name_not_scalar` and
      `surveywts_error_wt_name_empty` continue to apply to non-NULL invalid
      values.
    - **Update `.get_weight_vec()`**: remove the `weighted_df` branch (the
      `inherits(x, "weighted_df")` block) and remove the trailing plain
      `data.frame` uniform-weight fallback (`rep(1 / nrow(data_df), nrow(data_df))`).
      The only remaining paths: explicit `weights_quo` → use that column;
      S7 survey_base object → use `x@variables$weights`.
    - **Update `.get_history()`**: remove the `weighted_df` branch; keep only
      the `survey_base` branch and the `list()` fallback.
    - **Update `.check_input_class()`**: replace the current body with a
      strict `survey_base`-only check:
      ```r
      if (!S7::S7_inherits(data, surveycore::survey_base)) {
        cls <- class(data)[[1L]]
        cli::cli_abort(
          c(
            "x" = "{.arg data} must be a {.cls survey_nonprob}, {.cls survey_taylor}, or {.cls survey_replicate}.",
            "i" = "Got {.cls {cls}}.",
            "v" = "Use {.fn surveycore::as_survey_nonprob}, {.fn surveycore::as_survey}, or {.fn surveycore::as_survey_replicate} to construct a survey object."
          ),
          class = "surveywts_error_not_survey_base"
        )
      }
      invisible(TRUE)
      ```
    - **Update `.update_survey_weights()`**: add `wt_name = NULL` as a new
      optional argument. When `wt_name` is non-`NULL`: write new weights to a
      new `wt_name` column in `@data` and set `design@variables$weights = wt_name`
      (original weight column preserved). When `wt_name` is `NULL` (default):
      overwrite the existing `@variables$weights` column (current behavior).
    - Remove header comment references to `weighted_df` and `data.frame`.

19. **`R/weight-utils.R`** — Update `.check_weight_utils_class()`:
    - Change from `data.frame || survey_base` to `survey_base`-only check.
    - Change error class from `surveywts_error_unsupported_class` to
      `surveywts_error_not_survey_base` (consistent with `.check_input_class()`).
    - Update the comment at line 44 to remove `weighted_df` reference.

20. **`R/diagnostics-utils.R`** — Remove the `is_plain_df` branch and the
    `weighted_df` auto-detection branch in the weight-resolution helper.
    After the edit, the helper should only handle S7 survey objects and
    explicit `weights` quosures. Update the error class in any remaining
    `cli_abort()` to `surveywts_error_not_survey_base`.

---

#### Task group D — Update function source files

**Important pre-condition:** Grep for `.update_survey_weights(` in `R/` before
starting Group D. Every call site must be updated to pass `wt_name = wt_name`
as a keyword argument (or `wt_name = NULL` where that function does not expose
a `wt_name` parameter to users). Failing to update any call site means the
`wt_name = "new_col"` behavior silently does nothing for that function.

Each function file in this group needs these changes:
- Update `@param data` to list only `survey_nonprob`, `survey_taylor`, and
  (where applicable) `survey_replicate`.
- Update `@returns` to remove `weighted_df` return mentions; use class-
  preservation language only.
- Remove `data.frame` / `weighted_df` dispatch branches from the function body.
  Replace the leading input guard with `.check_input_class()` (or, for
  `trim_weights()` / `rescale_weights()`, the updated `.check_weight_utils_class()`).
- Change `wt_name = "wts"` default to `wt_name = NULL` in the function signature.
- Update `@param wt_name` docs: `` `NULL` (the default): calibrated weights
  overwrite the registered weight column (`@variables$weights` is unchanged).
  `"new_col"`: calibrated weights are written to a new `"new_col"` column and
  `@variables$weights` is updated to `"new_col"`; the original column is
  preserved. ``
- Update history entry `weight_col` field:
  ```r
  weight_col = if (is.null(wt_name)) data@variables$weights else wt_name
  ```
  (Remove the old `if (inherits(data, "data.frame")) { wt_name } else { ... }` ternary.)
- Pass `wt_name = wt_name` to every `.update_survey_weights()` call.
- Update `@examples` to use the agreed examples from
  `plans/class-system-refactor.md §Functions Reviewed`.

**Tasks:**
21. **`R/calibrate_rake.R`** — Apply all changes above. In the output
    section (≈line 722), remove the `if (inherits(data, "data.frame"))` branch;
    keep only `.update_survey_weights(data, new_weights, history_entry, wt_name = wt_name, caldata = caldata)`.

22. **`R/calibrate_linear.R`** — Apply all changes. Remove the `is_plain_df`
    flag (line 247) and all code paths conditioned on it. The `out_df`
    construction at the bottom is replaced by `.update_survey_weights(...)` 
    with `wt_name = wt_name`.

23. **`R/calibrate_logit.R`** — Same as calibrate_linear.R.

24. **`R/calibrate.R`** — Update `@param data` and `@returns`; the dispatcher
    body does not have its own weighted_df dispatch paths (it delegates), but
    update `@param wt_name` and update examples.

25. **`R/poststratify.R`** — Remove `data.frame`/`weighted_df` branches.
    Remove `.make_weighted_df()` call (line ≈517). Replace output section with
    `.update_survey_weights(..., wt_name = wt_name)`. Update `@param data`,
    `@returns`, history `weight_col`, and examples.

26. **`R/calibrate_to_survey.R`** — No dispatch changes needed (already
    survey-only; no `wt_name` parameter). Add `summarize_weights()` call
    to examples per the agreed example in the plan.

27. **`R/calibrate_to_estimate.R`** — Same as 26.

28. **`R/adjust_nonresponse.R`** — Remove `data.frame`/`weighted_df` dispatch
    branches throughout (three `.make_weighted_df()` calls at lines ≈471, 704,
    855). Remove the `!inherits(data, "weighted_df")` guard at line ≈189.
    Replace all three output sites with `.update_survey_weights(..., wt_name = wt_name)`.
    Update `@param data`, `@returns`, history `weight_col`, and examples.

29. **`R/redistribute_weights.R`** — Remove `data.frame`/`weighted_df`
    branches (`.make_weighted_df()` at line ≈434, the `wt_name` conflict
    check at lines ≈144–169). Replace output with
    `.update_survey_weights(..., wt_name = wt_name)`. Update `@param data`,
    `@returns`, history `weight_col`, and examples.

30. **`R/trim_weights.R`** — Remove `data.frame`/`weighted_df` paths from
    the function body. The `is_plain_df` / `is_null_wt_df` flags go away.
    Input guard switches to `.check_weight_utils_class()` (already updated in
    task 19). Pass `wt_name = wt_name` to any `.update_survey_weights()` call.
    Update `@param data`, `@returns`, history `weight_col`, and examples.

31. **`R/rescale_weights.R`** — Remove `is_plain_df` flag (line ≈68) and
    `.make_weighted_df()` call (line ≈204). Input guard switches to
    `.check_weight_utils_class()`. Pass `wt_name = wt_name` to
    `.update_survey_weights()`. Update `@param data`, `@returns`, history
    `weight_col`, and examples.

32. **`R/effective_sample_size.R`** — Update `@param x` to remove
    `data.frame` and `weighted_df`; update examples to use
    `surveycore::as_survey_nonprob()`.

33. **`R/weight_variability.R`** — Same as 32.

34. **`R/summarize_weights.R`** — Same as 32.

---

#### Task group E — Document, check, and snapshots

**Tasks:**
35. Run `devtools::document()`. Verify NAMESPACE no longer exports
    `dplyr_reconstruct.weighted_df`, `select.weighted_df`,
    `rename.weighted_df`, `mutate.weighted_df`, or `print.weighted_df`.
    Verify `man/` has no orphaned `weighted_df` Rd files.

36. Run `devtools::test()`. All tests should be GREEN. Delete stale snapshot
    files in `tests/testthat/_snaps/` for any removed test descriptions. Run
    `testthat::snapshot_review()` to approve new error message snapshots.

37. Run `devtools::run_examples()` to verify all updated `@examples` blocks
    execute cleanly. This is a required gate — all 14 updated example blocks
    must run without error.

38. Run `devtools::check()`. Target: 0 errors, 0 warnings, ≤2 pre-approved
    notes.

39. Run `covr::package_coverage()`. Coverage must be ≥ 98% overall.

40. Write a `NEWS.md` entry describing the breaking change:
    `calibrate()`, `calibrate_rake()`, etc. no longer accept `data.frame`
    or `weighted_df` input; use `surveycore::as_survey_nonprob()` and friends.

---

**Acceptance criteria:**
- [ ] `plans/error-messages.md` has `surveywts_error_not_survey_base` entry
- [ ] `R/weighted-df-dplyr.R` deleted; `NAMESPACE` no longer exports its methods
- [ ] `print.weighted_df()` removed from `methods-print.R`
- [ ] `.make_weighted_df()` removed from `utils.R`
- [ ] All calibration, nonresponse, utility, and diagnostic functions abort
  with `surveywts_error_not_survey_base` when passed a `data.frame`
- [ ] `wt_name = NULL` is the new default across all affected functions;
  `NULL` means "overwrite the existing weight column in-place"
- [ ] `wt_name = "new_col"` (non-NULL) writes to a new column in `@data`,
  updates `@variables$weights`, and preserves the original column — verified
  by test in task 13
- [ ] All `@examples` use `surveycore::as_survey_nonprob()`,
  `surveycore::as_survey()`, or `surveycore::as_survey_replicate()`; no
  bare `data.frame` examples remain
- [ ] `summarize_weights()` call present in first two examples of each function
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] `devtools::run_examples()` 0 errors
- [ ] `covr::package_coverage()` ≥ 98% overall
- [ ] All new error tests pass (dual pattern: `expect_error(class=)` +
  `expect_snapshot(error = TRUE)`)
- [ ] `NEWS.md` entry written describing the breaking API change
- [ ] `ipw()` is NOT modified in this PR

**Files touched — exact write surface:**
- `plans/error-messages.md` — add `surveywts_error_not_survey_base`; mark `surveywts_error_unsupported_class` retired
- `R/weighted-df-dplyr.R` — **deleted**
- `R/methods-print.R` — modified (remove `print.weighted_df`)
- `R/utils.R` — modified (remove `.make_weighted_df`; update `.validate_wt_name`, `.get_weight_vec`, `.get_history`, `.check_input_class`, `.update_survey_weights`)
- `R/weight-utils.R` — modified (update `.check_weight_utils_class` to survey_base–only + new error class)
- `R/diagnostics-utils.R` — modified (remove `weighted_df` / plain df branches; update error class)
- `R/calibrate.R` — modified (@param, @returns, @param wt_name, examples)
- `R/calibrate_rake.R` — modified (dispatch, @param, @returns, @param wt_name, history weight_col, examples)
- `R/calibrate_linear.R` — modified (same)
- `R/calibrate_logit.R` — modified (same)
- `R/poststratify.R` — modified (same)
- `R/calibrate_to_survey.R` — modified (examples only)
- `R/calibrate_to_estimate.R` — modified (examples only)
- `R/adjust_nonresponse.R` — modified (dispatch, @param, @returns, @param wt_name, history weight_col, examples)
- `R/redistribute_weights.R` — modified (same)
- `R/trim_weights.R` — modified (same)
- `R/rescale_weights.R` — modified (same)
- `R/effective_sample_size.R` — modified (@param, examples)
- `R/weight_variability.R` — modified (@param, examples)
- `R/summarize_weights.R` — modified (@param, examples)
- `tests/testthat/test-00-classes.R` — **deleted**
- `tests/testthat/test-02-calibrate.R` — modified
- `tests/testthat/test-03-rake.R` — modified
- `tests/testthat/test-04-poststratify.R` — modified
- `tests/testthat/test-05-nonresponse.R` — modified
- `tests/testthat/test-calibrate-linear.R` — modified
- `tests/testthat/test-calibrate-logit.R` — modified
- `tests/testthat/test-weight-utils.R` — modified
- `tests/testthat/test-06-diagnostics.R` — modified
- `tests/testthat/test-nps-jackknife.R` — modified
- `tests/testthat/test-calibrate-utils-nr.R` — modified (remove data.frame happy-path; add error test)
- `tests/testthat/_snaps/` — stale snapshot entries deleted; new ones approved via `testthat::snapshot_review()`
- `NAMESPACE` — regenerated by `devtools::document()`
- `man/` — regenerated by `devtools::document()` (stale Rd files removed)
- `NEWS.md` — updated with breaking change entry

**Notes:**
- `ipw()` is explicitly excluded from this PR. Do not touch `R/ipw.R`,
  `tests/testthat/test-nonprob-ipw.R`, or any ipw-related tests.
- The replicate-weight family (`create_*_weights()`, `as_taylor_design()`)
  already rejects `data.frame` and `weighted_df` via `.validate_replicate_input()`.
  No source changes needed for those functions. Verify they still pass.
  The tests in `test-replicate-weights.R` that use `structure(df, class = c("weighted_df", ...))`
  will still pass (the fake objects inherit from `data.frame` which is rejected).
  No changes needed to those test files.
- `test-08-nps-bootstrap.R` line 307 uses the same `structure()` approach to
  construct a fake `weighted_df` for the "rejects weighted_df" test. This will
  continue to pass because the fake object inherits from `data.frame`. No changes
  needed.
- After deleting `test-00-classes.R` (task 2), immediately run
  `devtools::test()` to confirm no other test file depended on its local
  fixture helpers (`make_weighted_df_fixture()`). That helper is used nowhere
  else in the test suite.
- **Compilation state during Group C:** After task 15 (delete weighted-df-dplyr.R)
  and task 16 (devtools::document()), the package loads cleanly but still has
  compilation errors from function files calling `.make_weighted_df()` (which
  is removed in task 18). The package will not pass `devtools::check()` until
  Group D is complete. This is expected. Run `devtools::check()` only in Group E.
