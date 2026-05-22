# Implementation Plan: calibration-nps-compat

**Spec:** `plans/spec-calibration-nps-compat.md` (v0.2 — Stage 4 resolve complete)
**Plan version:** 1.0
**Date:** 2026-05-20

---

## Overview

This plan delivers small, backward-compatible additions to `rake()` and
`calibrate()` that make both functions NPS bootstrap-compatible: a new
`reference_design = NULL` argument and two new fields in each function's
history entry (`targets_from_reference`, `reference_design`). A shared
validation helper `.validate_reference_design()` is added to `R/utils.R`
since both call sites are in separate source files.

---

## PR Map

- [x] PR 1: `feature/calibration-nps-compat` — Add `reference_design` arg and history fields to `rake()` and `calibrate()`

---

## PR 1: Add `reference_design` to `rake()` and `calibrate()`

**Branch:** `feature/calibration-nps-compat`
**Depends on:** none

### Files (in TDD order — tests first)

- `plans/error-messages.md` — add `surveywts_error_reference_design_not_taylor`
  before writing any R code
- `tests/testthat/test-03-rake.R` — add 3 new blocks: two happy-path and one
  error-path for `rake()` changes; confirm red before implementation
- `tests/testthat/test-02-calibrate.R` — add 3 new blocks: two happy-path and
  one error-path for `calibrate()` changes; confirm red before implementation
- `R/utils.R` — add `.validate_reference_design()` after `.validate_wt_name()`
- `R/rake.R` — add `reference_design = NULL` to signature, call helper after
  arg capture, add `type`, `targets_from_reference`, `reference_design` to
  history parameters; add `@param reference_design` to roxygen
- `R/calibrate.R` — same changes as `rake.R` (signature, helper call, history,
  roxygen)
- `.claude/rules/surveywts-conventions.md` — update §6 argument-order table to
  include `reference_design = NULL` at the end of both function signatures
- `changelog/calibration/feature-calibration-nps-compat.md` — created last,
  before opening PR

### Step-by-step (TDD order)

1. **Add error class to `plans/error-messages.md`.**
   Add one identical row for `surveywts_error_reference_design_not_taylor` to
   both the `### rake()` section and the `### calibrate()` section (same
   content, two rows — consistent with the file's per-function layout).
   Include the trigger condition in both rows.

2. **Write failing tests in `tests/testthat/test-03-rake.R`.**
   Add three `test_that()` blocks at the end of the existing test file:

   - `"rake() records reference_design and targets_from_reference = TRUE in history"`:
     Call `rake(data, margins = margins, reference_design = ref_taylor)`.
     First assertion: `test_invariants(result)`. Then:
     `expect_true(entry$parameters$targets_from_reference)` and
     `expect_identical(entry$parameters$reference_design, ref_taylor)`.
     (`ref_taylor` is a `survey_taylor` object built from `make_surveywts_data()`.)

   - `"rake() records targets_from_reference = FALSE when reference_design = NULL"`:
     Call `rake(data, margins = margins)` (no `reference_design`).
     First assertion: `test_invariants(result)`. Then:
     `expect_false(entry$parameters$targets_from_reference)` and
     `expect_null(entry$parameters$reference_design)`.

   - `"rake() rejects non-taylor reference_design"`:
     `expect_error(rake(..., reference_design = list()), class = "surveywts_error_reference_design_not_taylor")`
     and `expect_snapshot(error = TRUE, rake(..., reference_design = list()))`.

   Also add a check for `"rake() records type in history"` if `type` is not
   already tested in the history blocks (read existing history tests before
   adding — avoid duplication).

3. **Write failing tests in `tests/testthat/test-02-calibrate.R`.**
   Same three blocks as step 2, substituting `calibrate()` and `population`:

   - `"calibrate() records reference_design and targets_from_reference = TRUE in history"`
   - `"calibrate() records targets_from_reference = FALSE when reference_design = NULL"`
   - `"calibrate() rejects non-taylor reference_design"`

4. **Run `devtools::test(filter = "test-03-rake|test-02-calibrate")` and confirm
   all new blocks fail (red).** Expected failure mode: "unused argument
   (reference_design = ...)" for the happy-path and error-path blocks.
   If any new block passes before implementation, something is wrong — stop
   and investigate.

5. **Add `.validate_reference_design()` to `R/utils.R`.**
   Insert after the `.validate_wt_name()` section. Content per spec §II:

   ```r
   .validate_reference_design <- function(reference_design) {
     if (!is.null(reference_design) &&
           !S7::S7_inherits(reference_design, surveycore::survey_taylor)) {
       cli::cli_abort(
         c(
           "x" = "{.arg reference_design} must be a {.cls survey_taylor}.",
           "i" = "Got class {.cls {class(reference_design)[[1L]]}}.",
           "v" = "Pass the {.cls survey_taylor} object used to compute the targets."
         ),
         class = "surveywts_error_reference_design_not_taylor"
       )
     }
     invisible(NULL)    # intentional: return value unused by all callers;
                        # NULL vs TRUE is equivalent here. Departs from the
                        # .validate_*() invisible(TRUE) convention per spec §II.
   }
   ```

   Also update the `# Contents:` comment block at the top of `utils.R` to
   list `.validate_reference_design()`.

6. **Update `R/rake.R`.**

   a. Add `reference_design = NULL` as the last parameter in the function
      signature (after `control = list()`).

   b. Call `.validate_reference_design(reference_design)` immediately after
      `.validate_wt_name(wt_name)` (i.e., after arg capture, before cap guard).

   c. In the `parameters` list passed to `.make_history_entry()`, add three
      fields (per spec §III — note `type` was missing from the existing
      implementation and must also be added now):

      ```r
      parameters = list(
        variables              = margin_var_names,
        margins                = margins_a,
        type                   = type,            # add this (was missing)
        method                 = method,
        cap                    = cap,
        control                = control_resolved,
        targets_from_reference = !is.null(reference_design),   # new
        reference_design       = reference_design              # new
      )
      ```

   d. Add `@param reference_design` to the roxygen block (after `@param control`,
      before `@return`):

      ```r
      #' @param reference_design A `survey_taylor` object or `NULL` (default). The
      #'   reference probability survey from which `margins` were estimated. When
      #'   non-`NULL`, stored in the history entry and `targets_from_reference` is
      #'   set to `TRUE`. Pass the same `survey_taylor` object used to compute the
      #'   margin targets. `NULL` means targets are fixed population benchmarks.
      ```

7. **Update `R/calibrate.R`.**
   Same four sub-steps as step 6:

   a. Add `reference_design = NULL` at the end of the function signature.

   b. Call `.validate_reference_design(reference_design)` immediately after
      `.validate_wt_name(wt_name)`.

   c. In the `parameters` list:

      ```r
      parameters = list(
        variables              = variable_names,
        population             = population,
        method                 = method,
        type                   = type,
        control                = control,
        targets_from_reference = !is.null(reference_design),   # new
        reference_design       = reference_design              # new
      )
      ```

   d. Add `@param reference_design` roxygen (after `@param control`, before
      `@return`) — same wording as `rake()` but replacing "margins" with
      "population targets".

8. **Run `devtools::test(filter = "test-03-rake|test-02-calibrate")` and confirm
   all new blocks pass (green).** Fix any failures before continuing.

9. **Run `devtools::document()`** to update NAMESPACE and man/ files. Stage
   the updated NAMESPACE and any regenerated man/ files.

10. **Review and accept snapshot tests.**
    `testthat::snapshot_review()` — accept the new snapshots for the
    `"rake() rejects non-taylor reference_design"` and
    `"calibrate() rejects non-taylor reference_design"` error-path blocks.
    Commit the snapshots.

11. **Update `.claude/rules/surveywts-conventions.md` §6.**
    In the argument-order table, update both rows:

    | Function | Old | New |
    |---|---|---|
    | `calibrate()` | `..., control = list()` | `..., control = list(), reference_design = NULL` |
    | `rake()` | `..., control = list()` | `..., control = list(), reference_design = NULL` |

12. **Run `devtools::check()`** — must pass: 0 errors, 0 warnings, ≤2 notes.

13. **Run `covr::package_coverage()`** — must be ≥ 98%.

14. **Write `changelog/calibration/feature-calibration-nps-compat.md`.**

---

### Acceptance Criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::test()` passes (0 failures)
- [ ] New snapshot tests reviewed individually via `snapshot_review()` and committed
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `covr::package_coverage()` ≥ 98%
- [ ] `plans/error-messages.md` has `surveywts_error_reference_design_not_taylor`
- [ ] `surveywts-conventions.md` §6 table updated with `reference_design = NULL`
- [ ] History entry for `rake()` now includes `type`, `targets_from_reference`,
      and `reference_design`
- [ ] History entry for `calibrate()` now includes `targets_from_reference`
      and `reference_design`
- [ ] A test verifies `type` is present in `rake()` history `parameters`
- [ ] Changelog entry written and committed on this branch

---

### Notes

**`type` was missing from `rake()` history before this PR.** The `rake()`
implementation stores `variables`, `margins`, `method`, `cap`, `control` in
the history entry but not `type`. `calibrate()` does store `type`. The spec
review (Issue 2) identified this as a silent bootstrap-replay correctness
hole. Add `type = type` to the `rake()` parameters list in this same PR — it
costs nothing and fixes the correctness gap.

**Test setup for `ref_taylor`.** The happy-path blocks need a `survey_taylor`
object to pass as `reference_design`. Use the existing file-level helper —
`.make_test_taylor_rake(df)` in `test-03-rake.R` and `.make_test_taylor(df)`
in `test-02-calibrate.R` — do not build inline. The `ref_taylor` object does
not need to contain the same variables as `margins` — the spec explicitly says
content validation is deferred to bootstrap-replay time. The minimal design
these helpers produce is sufficient.

**No changes to `.make_history_entry()`.** The function already accepts
arbitrary `parameters` lists; the new fields are passed in from the calling
function. No signature change to the shared helper is needed.

**`reference_design` is stored by reference, not copied.** R's copy-on-modify
semantics mean the stored object is shared. This is intentional and matches
how the bootstrap reads it back.

**Error class goes in `plans/error-messages.md` before any code.** This is the
project convention (`code-style.md §3`). Step 1 must complete before step 2.
