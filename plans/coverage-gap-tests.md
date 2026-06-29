# Coverage Gap Tests

**Goal:** Bring package coverage from 94.6% to ≥ 98% by writing missing tests
and removing unreachable code.

**Current overall:** 94.59%
**Threshold to unblock PRs:** 95%
**Project target:** 98%

---

## Phase 0 — Dead Code Removal (before tests)

These three items are unreachable code that inflate the denominator. Remove
them first so the coverage numbers reflect real gaps only.

### 0a. Remove `.to_svyrep_design()` — `R/utils.R` lines 788–819

Zero callers anywhere in the package. Written for a `calibrate_to_survey()`
path that ended up using `survey::calibrate()` directly instead. Delete the
function and its section header comment. Expected recovery: ~2.3 pts in
`utils.R`.

### 0b. Fix broken `# nocov` in `.get_history()` — `R/utils.R` line 678

```r
if (is.null(wh)) list() else wh # nocov   # <-- inline form not recognized by covr
```

covr requires block-form markers. Either:
- Wrap in `# nocov start` / `# nocov end` if the branch is genuinely unreachable
  (true if `surveycore::survey_metadata()` always initializes `weighting_history`
  as `list()` not `NULL`), OR
- Remove the `else wh` branch if `NULL` is impossible

Verify by checking `surveycore::survey_metadata()` source before deciding.

### 0c. Mark `.svrep_calibrate_to_sample()` — `R/calibrate_to_survey.R` line 1216

No production callers — it is a test hook / mockable binding only. Add:

```r
# nocov start
.svrep_calibrate_to_sample <- function(design, ...) {
  survey::calibrate(design, ...)
}
# nocov end
```

---

## Phase 1 — Largest Single Gap: Calibration-Only DAGJK

**File:** `tests/testthat/test-nps-jackknife.R`
**Impact:** `.dagjk_single_replicate_calib()` is at 0% (lines 373–456) plus
the branch in `create_jackknife_weights.R` lines 482–511 and 626.

All existing DAGJK tests build a pipeline with `ipw()` first. The calibration-
only path triggers when `create_jackknife_weights(type = "grouped")` is called
on a `survey_nonprob` whose weighting history contains only a calibration step
(no `ipw()` entry).

### Test 1.1 — Calibration-only DAGJK, Level A (no reference design)

Setup: calibrate a `survey_nonprob` with `calibrate_rake()`, no
`reference_design`. Then call `create_jackknife_weights(type = "grouped")`.
Covers lines 509–511 in `create_jackknife_weights.R` and the main body of
`.dagjk_single_replicate_calib()`.

```r
test_that("create_jackknife_weights() runs calibration-only DAGJK (Level A)", {
  df <- make_surveywts_data(n = 300, seed = 101)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  pop <- list(
    age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  cal <- calibrate_rake(nps, targets = pop, type = "prop")
  result <- create_jackknife_weights(cal, type = "grouped")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  rep_mat <- result@repweights
  expect_equal(nrow(rep_mat), nrow(df))
  expect_true(ncol(rep_mat) > 0)
})
```

### Test 1.2 — Calibration-only DAGJK, Level B (with reference design)

Covers lines 482–506 in `create_jackknife_weights.R` (Level B reference path).
Pass a `reference_design` to `calibrate_rake()` so the history entry carries a
reference, then call `create_jackknife_weights()`.

```r
test_that("create_jackknife_weights() runs calibration-only DAGJK (Level B)", {
  df  <- make_surveywts_data(n = 300, seed = 102)
  ref <- make_surveywts_data(n = 500, seed = 999)
  ref_svy <- surveycore::survey_taylor(
    data = ref,
    variables = list(weights = "base_weight")
  )
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  pop <- list(
    age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  cal <- calibrate_rake(nps, targets = pop, type = "prop",
                        reference_design = ref_svy)
  result <- create_jackknife_weights(cal, type = "grouped")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
```

---

## Phase 2 — DAGJK Variant Paths

**File:** `tests/testthat/test-nps-jackknife.R`
All tests in this phase require an `ipw()` step before DAGJK (existing pattern).

### Test 2.1 — DAGJK with `missing_method = "separate"`

Covers lines 157–163 in `.dagjk_single_replicate()`. Build the NPS with
`missing_method = "separate"` so the `(Missing)` factor level is present.

```r
test_that("create_jackknife_weights() handles missing_method = 'separate'", {
  skip_if_not_installed("survey")
  df  <- make_surveywts_data(n = 300, seed = 201, include_nonrespondents = TRUE)
  ref <- make_surveywts_data(n = 500, seed = 998)
  ref_svy <- surveycore::survey_taylor(
    data = ref[ref$responded == 1, ],
    variables = list(weights = "base_weight")
  )
  nps_df <- df[df$responded == 1, ]
  nps <- surveycore::survey_nonprob(
    data = nps_df,
    variables = list(weights = "base_weight")
  )
  ipw_result <- ipw(nps, reference = ref_svy,
                    selection = ~age_group + sex,
                    missing_method = "separate")
  result <- create_jackknife_weights(ipw_result, type = "grouped")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
```

### Test 2.2 — DAGJK with strata variable

Covers lines 226–256 in `.dagjk_single_replicate()` (per-stratum scaling
block). Construct a `survey_nonprob` with `@variables$strata` set.

```r
test_that("create_jackknife_weights() applies per-stratum scaling when strata present", {
  skip_if_not_installed("survey")
  df  <- make_surveywts_data(n = 400, seed = 202)
  ref <- make_surveywts_data(n = 600, seed = 997)
  ref_svy <- surveycore::survey_taylor(
    data = ref,
    variables = list(weights = "base_weight", strata = "region")
  )
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight", strata = "region")
  )
  ipw_result <- ipw(nps, reference = ref_svy,
                    selection = ~age_group + sex)
  result <- create_jackknife_weights(ipw_result, type = "grouped")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
```

### Test 2.3 — DAGJK with `trim = TRUE` in `ipw()`

Covers line 265 in `.dagjk_single_replicate()` (`trim_threshold` path).

```r
test_that("create_jackknife_weights() handles ipw() with trim = TRUE", {
  skip_if_not_installed("survey")
  df  <- make_surveywts_data(n = 300, seed = 203)
  ref <- make_surveywts_data(n = 500, seed = 996)
  ref_svy <- surveycore::survey_taylor(
    data = ref,
    variables = list(weights = "base_weight")
  )
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  ipw_result <- ipw(nps, reference = ref_svy,
                    selection = ~age_group + sex,
                    trim = TRUE)
  result <- create_jackknife_weights(ipw_result, type = "grouped")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
```

### Test 2.4 — DAGJK with linear calibration-after-IPW

Covers lines 297–329 in `.dagjk_single_replicate()` (linear/logit
calibration replay). All current DAGJK tests use rake; this one uses
`calibrate_linear()` as the post-IPW calibration step.

```r
test_that("create_jackknife_weights() replays calibrate_linear() in DAGJK", {
  skip_if_not_installed("survey")
  df  <- make_surveywts_data(n = 300, seed = 204)
  ref <- make_surveywts_data(n = 500, seed = 995)
  ref_svy <- surveycore::survey_taylor(
    data = ref,
    variables = list(weights = "base_weight")
  )
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  ipw_result <- ipw(nps, reference = ref_svy,
                    selection = ~age_group + sex)
  pop <- list(
    age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  cal <- calibrate_linear(ipw_result, targets = pop, type = "prop")
  result <- create_jackknife_weights(cal, type = "grouped")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
```

---

## Phase 3 — Replicate Utils: Linear/Logit Replay

**File:** `tests/testthat/test-replicate-weights.R` (or wherever QR bootstrap
tests live)
**Impact:** `.dispatch_calibration_replay()` lines 666–712 (linear and logit
replay branches).

### Test 3.1 — QR bootstrap replays `calibrate_linear()`

```r
test_that("create_bootstrap_weights() replays calibrate_linear() correctly", {
  df  <- make_surveywts_data(n = 300, seed = 301)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  pop <- list(
    age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  cal <- calibrate_linear(nps, targets = pop, type = "prop")
  result <- create_bootstrap_weights(cal, replicates = 50, seed = 1)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
```

### Test 3.2 — QR bootstrap replays `calibrate_logit()`

```r
test_that("create_bootstrap_weights() replays calibrate_logit() correctly", {
  df  <- make_surveywts_data(n = 300, seed = 302)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  pop <- list(
    age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  cal <- calibrate_logit(nps, targets = pop, type = "prop")
  result <- create_bootstrap_weights(cal, replicates = 50, seed = 1)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
```

### Test 3.3 — Unsupported calibration operation error in `.dispatch_calibration_replay()`

This error (line 721) requires calling the internal function directly with a
fake history entry because the public API filters unknown operations before
reaching it.

```r
test_that(".dispatch_calibration_replay() aborts on unknown calibration operation", {
  fake_entry <- list(
    operation = "unknown_op",
    targets   = list(),
    type      = "prop"
  )
  expect_error(
    .dispatch_calibration_replay(
      data        = make_surveywts_data(n = 50, seed = 9),
      calib_entry = fake_entry,
      wt_col      = "base_weight"
    ),
    class = "surveywts_error_unsupported_calibration_op"
  )
})
```

### Test 3.4 — `.extract_weight_vec()` weighted_df and plain df branches (dead-ish)

Lines 752–755 are never reached via public API — the calibration result is
always `survey_nonprob` in all current call sites. Add `# nocov start` /
`# nocov end` around these two branches rather than writing a contrived direct
test. Document the reason in the comment:

```r
# nocov start
# These branches are never reached via the public API: calibration
# functions always return survey_nonprob when given survey_nonprob input,
# so result is always survey_nonprob here.
} else if (inherits(result, "weighted_df")) {
  result[[attr(result, "weight_col")]]
} else {
  result[[wt_col]]
}
# nocov end
```

---

## Phase 4 — utils.R: Validators and History Formatting

**File:** `tests/testthat/test-weight-utils.R` (or inline in each relevant
test file)

### Test 4.1 — `.validate_weights()`: column not found

Trigger via `rescale_weights()` with an explicit column name that doesn't exist.

```r
test_that("rescale_weights() aborts when named weight column is absent", {
  df <- make_surveywts_data(n = 100, seed = 401)
  expect_error(
    rescale_weights(df, weights = nonexistent_col),
    class = "surveywts_error_weight_col_not_found"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(df, weights = nonexistent_col)
  )
})
```

### Test 4.2 — `.validate_weights()`: column not numeric

```r
test_that("rescale_weights() aborts when weight column is not numeric", {
  df <- make_surveywts_data(n = 100, seed = 402)
  df$base_weight <- as.character(df$base_weight)
  expect_error(
    rescale_weights(df, weights = base_weight),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(df, weights = base_weight)
  )
})
```

### Test 4.3 — `.validate_weights()`: column has NAs

```r
test_that("rescale_weights() aborts when weight column contains NAs", {
  df <- make_surveywts_data(n = 100, seed = 403)
  df$base_weight[1] <- NA_real_
  expect_error(
    rescale_weights(df, weights = base_weight),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(df, weights = base_weight)
  )
})
```

### Test 4.4 — `.get_weight_vec()`: explicit `weights =` in diagnostics

Covers lines 193–194.

```r
test_that("effective_sample_size() accepts explicit weights = argument", {
  df <- make_surveywts_data(n = 200, seed = 404)
  result <- effective_sample_size(df, weights = base_weight)
  expect_true(is.numeric(result))
  expect_true(result > 0)
})
```

Repeat for `weight_variability()` and `summarize_weights()`.

### Test 4.5 — `.format_history_step()`: print paths for non-rake operations

Add to `tests/testthat/test-06-diagnostics.R` or `test-replicate-print.R`.
Create a `survey_nonprob` object, apply each of `calibrate_linear()`,
`calibrate_logit()`, `poststratify()`, then snapshot the print output.

```r
test_that("survey_nonprob print shows calibrate_linear history correctly", {
  df  <- make_surveywts_data(n = 200, seed = 405)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  pop <- list(
    age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3)
  )
  cal <- calibrate_linear(nps, targets = pop, type = "prop")
  expect_snapshot(print(cal))
})
```

Repeat for `calibrate_logit()` and `poststratify()`.

---

## Phase 5 — Utility Functions: Empty Data Frame Errors

**File:** `tests/testthat/test-weight-utils.R`

### Test 5.1 — `trim_weights()` with zero-row data

```r
test_that("trim_weights() aborts on zero-row data frame", {
  empty_df <- make_surveywts_data(n = 100, seed = 501)[0, ]
  expect_error(
    trim_weights(empty_df, weights = base_weight, upper = 3),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(empty_df, weights = base_weight, upper = 3)
  )
})
```

### Test 5.2 — `rescale_weights()` with zero-row data

```r
test_that("rescale_weights() aborts on zero-row data frame", {
  empty_df <- make_surveywts_data(n = 100, seed = 502)[0, ]
  expect_error(
    rescale_weights(empty_df, weights = base_weight),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(empty_df, weights = base_weight)
  )
})
```

---

## Phase 6 — Print Methods: Zero-History and Strata/IDs Paths

**File:** `tests/testthat/test-replicate-print.R` (or `test-06-diagnostics.R`)

### Test 6.1 — Print `survey_nonprob` with no weighting history

Covers line 59 in `methods-print.R`.

```r
test_that("survey_nonprob print shows 'none' for empty weighting history", {
  df <- make_surveywts_data(n = 100, seed = 601)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  expect_snapshot(print(nps))
})
```

### Test 6.2 — Print `survey_nonprob` with strata variable

Covers line 46 (non-null strata in `.format_design_vars()`).

```r
test_that("survey_nonprob print shows strata variable", {
  df <- make_surveywts_data(n = 200, seed = 602)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight", strata = "region")
  )
  expect_snapshot(print(nps))
})
```

### Test 6.3 — Print `survey_nonprob` with non-null IDs

Covers line 16 in `.format_design_vars()`.

```r
test_that("survey_nonprob print shows ids variable", {
  df <- make_surveywts_data(n = 200, seed = 603)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight", ids = "id")
  )
  expect_snapshot(print(nps))
})
```

### Test 6.4 — Print `survey_replicate` with no history (line 137)

```r
test_that("survey_replicate print shows 'none' for empty weighting history", {
  df <- make_surveywts_data(n = 200, seed = 604)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  rep <- create_bootstrap_weights(nps, replicates = 20, seed = 1)
  expect_snapshot(print(rep))
})
```

---

## Phase 7 — `calibrate_to_survey.R` and `calibrate_to_estimate.R`

Lower priority — these are existing tests with edge case gaps, not zero-coverage
functions.

### Test 7.1 — `calibrate_to_survey()`: control survey missing a level

Covers lines 781–797 in `.compute_control_totals()`.

```r
test_that("calibrate_to_survey() aborts when control survey is missing a level", {
  # primary has all four regions; control only has three
  # ... construct accordingly ...
  expect_error(
    calibrate_to_survey(primary, control_missing_level, variables = "region"),
    class = "surveywts_error_missing_level"  # verify actual class name
  )
})
```

### Test 7.2 — `calibrate_to_survey()` and `calibrate_to_estimate()` with `method = "logit"`

Covers line 870–871 in `.method_to_calfun()`.

```r
test_that("calibrate_to_survey() accepts method = 'logit'", {
  # use existing test data pattern from test-sample-calibration.R
  result <- calibrate_to_survey(primary, control, variables = "age_group",
                                 method = "logit")
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})
```

### Test 7.3 — `calibrate_to_estimate()`: vcov not a matrix

Covers line 368.

```r
test_that("calibrate_to_estimate() aborts when vcov_estimate is not a matrix", {
  expect_error(
    calibrate_to_estimate(design, targets, vcov_estimate = c(1, 2, 3)),
    class = "surveywts_error_vcov_not_matrix"  # verify actual class name
  )
})
```

---

## Implementation Order

1. Phase 0 — dead code removal (no tests needed; immediate coverage gain)
2. Phase 1 — calibration-only DAGJK (largest single gap, ~5 pts)
3. Phase 2 — DAGJK variant paths (~2–3 pts)
4. Phase 3 — replicate utils linear/logit replay (~1 pt); add nocov for
   `.extract_weight_vec()` branches
5. Phase 4 — utils.R validators and history formatting (~1 pt)
6. Phase 5 — empty data frame errors (trivial, ~0.3 pts each)
7. Phase 6 — print paths (~0.5 pts)
8. Phase 7 — `calibrate_to_survey` / `calibrate_to_estimate` gaps (~0.5 pts)

Phases 0–4 alone should clear the 98% target.

---

## Notes

- All tests use `make_surveywts_data()` with explicit seeds.
- All constructor tests call `test_invariants(result)` as the first assertion.
- Snapshot tests: run `testthat::snapshot_review()` to approve new snapshots
  before committing — never run `testthat::snapshot_accept()` blindly.
- Error class names in Phase 7 marked "verify actual class name" — confirm
  against `plans/error-messages.md` before writing the test.
- Before implementing Phase 2 tests, verify that `surveycore::survey_nonprob()`
  accepts `strata` in `@variables` — the coverage agent assumed it does based on
  the print method having that branch, but confirm against surveycore source.
