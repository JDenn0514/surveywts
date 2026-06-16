# Implementation Plan — calibrate-nonprob

**Status**: DRAFT
**Spec**: `plans/spec-calibrate-nonprob.md` (SPEC_READY)
**Test-spec**: `plans/test-spec-calibrate-nonprob.md`
**Spec review**: `plans/spec-review-calibrate-nonprob.md` (PASS)

---

## Overview

This plan delivers `survey_nonprob` support in `calibrate_to_survey()` and
`calibrate_to_estimate()`. Both functions currently reject anything that is not
a `survey_replicate`; the change relaxes that to also accept `survey_nonprob`
objects that carry replicate weights, adding two new validation checks and a
class-dispatching output constructor. No new exports, no new statistical
algorithms.

All work lands in a single PR — two source files are touched, and the change
is localized to validation logic and the final constructor call in each.

---

## PR map

- [x] PR 1: `feature/calibrate-nonprob` — Accept `survey_nonprob` with
  replicate weights in `calibrate_to_survey()` and `calibrate_to_estimate()`;
  preserve input class on output.

---

### PR 1: Accept `survey_nonprob` in sample-calibration functions

**Branch:** `feature/calibrate-nonprob`
**Depends on:** none

**Files (TDD order — error table → helpers → tests → implementation → docs):**

1. `plans/error-messages.md` — update 3 existing rows; add 3 new rows
2. `tests/testthat/helper-test-data.R` — add `make_nonprob_replicate_design()`
   and `make_nonprob_no_repweights()` helpers
3. `tests/testthat/test-sample-calibration.R` — add all new test scenarios;
   confirm red before touching source
4. `R/calibrate_to_survey.R` — expand validation, update error messages,
   dispatch on class for output constructor, update roxygen
5. `R/calibrate_to_estimate.R` — same pattern as above
6. Run `devtools::document()` — regenerates `man/calibrate_to_survey.Rd` and
   `man/calibrate_to_estimate.Rd`; commit generated files
7. `changelog/phase-3/feature-calibrate-nonprob.md` — changelog entry
   required by `commit-and-pr` before PR can be opened

**Acceptance criteria:**

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Happy path — `survey_nonprob` primary, `survey_replicate` control → returns `survey_nonprob`
- [ ] Happy path — `survey_replicate` primary, `survey_nonprob` control → returns `survey_replicate`
- [ ] Happy path — both `survey_nonprob` with repweights → returns `survey_nonprob`
- [ ] Happy path — `calibrate_to_estimate()` with `survey_nonprob` → returns `survey_nonprob`
- [ ] `test_invariants(result)` passes on all happy-path results
- [ ] `@metadata@weighting_history` grows by exactly one entry per call
- [ ] `control_design_class` in the last weighting history entry correctly records `class(control_design)[[1L]]` for both mixed-class and both-nonprob scenarios
- [ ] `surveywts_error_primary_no_repweights` fires and snapshot matches spec
- [ ] `surveywts_error_control_no_repweights` fires and snapshot matches spec
- [ ] `surveywts_error_design_no_repweights` fires and snapshot matches spec
- [ ] Regression guard: existing `survey_replicate` + `survey_replicate` path still returns `survey_replicate`
- [ ] Regression guard: `_not_replicate` errors still fire for wrong types (data.frame, survey_taylor)
- [ ] Regression guard `_not_replicate` snapshots updated and accepted via `snapshot_review()` for all three affected classes: `_primary_not_replicate`, `_control_not_replicate`, and `_design_not_replicate`
- [ ] Regression guard: `surveywts_error_targets_levels_mismatch` still fires when `design = make_nonprob_replicate_design()` and target level names are intentionally wrong
- [ ] Validation order tests pass (primary check fires before control check, design check fires before targets check)
- [ ] Edge cases: `@variables$repweights = character(0)` triggers `_no_repweights` errors
- [ ] `plans/error-messages.md` updated with all 3 new error classes and 3 updated condition descriptions
- [ ] Test coverage ≥ 98% overall (verify with `covr::package_coverage()`)

**Implementation notes:**

*Validation expansion (same pattern in both functions):*

In `calibrate_to_survey()`, the current step 1 check is a single
`if (!S7::S7_inherits(primary_design, surveycore::survey_replicate))` block.
Replace with a two-step structure:

```r
# Step 1a: class acceptability
is_nonprob_primary <- S7::S7_inherits(primary_design, surveycore::survey_nonprob)
if (!S7::S7_inherits(primary_design, surveycore::survey_replicate) &&
    !is_nonprob_primary) {
  cls <- class(primary_design)[[1L]]
  cli::cli_abort(
    c(
      "x" = paste0(
        "{.arg primary_design} must be a {.cls survey_replicate} or a ",
        "{.cls survey_nonprob} with replicate weights, got {.cls {cls}}."
      ),
      "i" = "...",
      "v" = "..."
    ),
    class = "surveywts_error_primary_not_replicate"
  )
}
# Step 1b: repweights populated check (survey_nonprob only)
if (is_nonprob_primary) {
  rw <- primary_design@variables$repweights
  if (is.null(rw) || length(rw) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg primary_design} is a {.cls survey_nonprob} but has
               no replicate weights.",
        "i" = "Replicate weights are required to propagate control-survey
               uncertainty.",
        "v" = "Use {.fn create_bootstrap_weights} or another
               {.fn create_*_weights} function to add replicate weights
               before calibrating."
      ),
      class = "surveywts_error_primary_no_repweights"
    )
  }
}
```

Apply the same pattern for `control_design` (step 2) and for `design` in
`calibrate_to_estimate()` (step 1, using `_design_` class names).

*Output constructor dispatch:*

At the end of `calibrate_to_survey()`, replace the hardcoded
`surveycore::survey_replicate(...)` call with:

```r
if (S7::S7_inherits(primary_design, surveycore::survey_nonprob)) {
  result <- surveycore::survey_nonprob(
    data      = new_data,
    variables = primary_design@variables,
    metadata  = primary_design@metadata
  )
} else {
  result <- surveycore::survey_replicate(
    data      = new_data,
    variables = primary_design@variables,
    metadata  = primary_design@metadata
  )
}
```

Apply the same pattern in `calibrate_to_estimate()` dispatching on `design`.

`.to_svyrep()` is NOT modified — it already reads `@variables$weights` and
`@variables$repweights` generically and works for both classes.

*Updated variables slot after svrep:*

After svrep may change the replicate count, `rep_names` is rebuilt. When
writing back to `primary_design@variables$repweights`, note that the current
code only updates `new_data` columns — the `variables` slot passed to the
constructor still carries the old `repweights` names. If svrep changes the
count, `primary_design@variables$repweights` will be stale. The existing code
already handles this by rebuilding `rep_names` when counts differ; the new
constructor call should pass `variables = primary_design@variables` and then
let the builder note that the `variables` slot's `repweights` key may need
updating when `n_rep != length(rep_names)`. Check the existing implementation
for this edge: the current code does NOT update `primary_design@variables$repweights`
before passing `variables` to the constructor. This pre-existing behavior is
unchanged by this PR — do not fix it here.

*Snapshot management:*

The three existing `_not_replicate` snapshot files will fail because their
error message text changes (they now mention `survey_nonprob` as an
additionally accepted type). After making the source changes and running tests,
run `testthat::snapshot_review()` and accept each updated diff individually.
Do not run `snapshot_accept()` blindly. Commit the updated `_snaps/` files.

*Test helpers to add in `helper-test-data.R`:*

```r
make_nonprob_replicate_design <- function(n = 200L, seed = 1L) {
  set.seed(seed)
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref_df <- make_surveywts_data(n = n * 5L, seed = seed + 100L)
  ref    <- surveycore::as_survey(ref_df, weights = base_weight)
  nps    <- ipw(data = nps_df, reference = ref,
                selection = ~sex + age_group)
  create_bootstrap_weights(
    nps,
    replicates = 50L,
    type       = "quasi-randomization",
    seed       = seed
  )
}

make_nonprob_no_repweights <- function(n = 200L, seed = 1L) {
  set.seed(seed)
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref_df <- make_surveywts_data(n = n * 5L, seed = seed + 100L)
  ref    <- surveycore::as_survey(ref_df, weights = base_weight)
  ipw(data = nps_df, reference = ref, selection = ~sex + age_group)
}
```

*`svrep` skip guard:*

Every `test_that()` block in `test-sample-calibration.R` that calls
`calibrate_to_survey()` or `calibrate_to_estimate()` must include
`skip_if_not_installed("svrep")` as the first line inside the block.

*Roxygen updates (both functions):*

- `@param primary_design` / `@param design`: change "A `survey_replicate`
  object" to "A `survey_replicate` or `survey_nonprob` object with replicate
  weights."
- `@param control_design`: same change.
- `@return`: add class-preservation rule (output class matches
  `primary_design` / `design`).
- `@details`: replace "Both `primary_design` and `control_design` must be
  `survey_replicate` objects" with "Both must carry replicate weights — either
  as `survey_replicate` objects or as `survey_nonprob` objects to which
  replicate weights have been added."
