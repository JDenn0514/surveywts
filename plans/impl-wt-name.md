# Implementation Plan: `wt_name` Argument

**Spec:** `plans/spec-wt-name.md` (v0.2, Stage 4 complete)
**Decisions:** `plans/decisions-wt-name.md`
**Date:** 2026-03-19

---

## Overview

This plan implements the `wt_name` argument for all four weighting functions
(`calibrate()`, `rake()`, `poststratify()`, `adjust_nonresponse()`). The
argument controls the name of the output weight column for `data.frame` and
`weighted_df` inputs. The default changes from `".weight"` to `"wts"`.

The work is split into 5 PRs: shared infrastructure first, then one PR per
function (calibrate establishes the pattern, the rest replicate it).

---

## PR Map

- [x] PR 1: `feature/wt-name-infrastructure` — Shared helpers and error class registry
- [ ] PR 2: `feature/wt-name-calibrate` — Add `wt_name` to `calibrate()`
- [ ] PR 3: `feature/wt-name-rake` — Add `wt_name` to `rake()`
- [ ] PR 4: `feature/wt-name-poststratify` — Add `wt_name` to `poststratify()`
- [ ] PR 5: `feature/wt-name-nonresponse` — Add `wt_name` to `adjust_nonresponse()`

---

## PR 1: Shared Infrastructure

**Branch:** `feature/wt-name-infrastructure`
**Depends on:** none

**Files:**
- `R/utils.R` — Add `.validate_wt_name()` helper; add `weight_col` parameter to `.make_history_entry()`
- `plans/error-messages.md` — Add two new error classes

**Tasks:**

1. **Add `.validate_wt_name()` to `R/utils.R`.**
   Insert after the `.get_weight_col_name()` block (after line ~101). Exact
   implementation from spec §IV:
   ```r
   .validate_wt_name <- function(wt_name) {
     if (!is.character(wt_name) || length(wt_name) != 1) {
       cli::cli_abort(
         c("x" = "{.arg wt_name} must be a single character string.",
           "i" = "Got {.cls {class(wt_name)}} of length {length(wt_name)}."),
         class = "surveywts_error_wt_name_not_scalar"
       )
     }
     if (is.na(wt_name) || wt_name == "") {
       cli::cli_abort(
         c("x" = "{.arg wt_name} must be a non-empty, non-NA string."),
         class = "surveywts_error_wt_name_empty"
       )
     }
     invisible(TRUE)
   }
   ```

2. **Add `weight_col` parameter to `.make_history_entry()` in `R/utils.R`.**
   Current signature (line 476):
   ```r
   .make_history_entry <- function(step, operation, call_str, parameters,
                                    before_stats, after_stats, convergence = NULL)
   ```
   New signature — add `weight_col = NULL` after `operation`:
   ```r
   .make_history_entry <- function(step, operation, weight_col = NULL, call_str,
                                    parameters, before_stats, after_stats,
                                    convergence = NULL)
   ```
   Add `weight_col = weight_col` to the returned list, after `operation` and
   before `timestamp`. The `NULL` default ensures existing callers (all four
   functions) continue to work until their PRs land.

3. **Update `plans/error-messages.md`.**
   Add to the "Common" section table:
   | `surveywts_error_wt_name_not_scalar` | `.validate_wt_name()` | `wt_name` is not `character(1)` |
   | `surveywts_error_wt_name_empty` | `.validate_wt_name()` | `wt_name` is `NA` or `""` |

4. **Run `devtools::check()`.** Confirm 0 errors, 0 warnings.

**Acceptance criteria:**
- [ ] `.validate_wt_name()` exists in `R/utils.R`
- [ ] `.make_history_entry()` accepts `weight_col` parameter and includes it in output
- [ ] Existing callers of `.make_history_entry()` still work (default `NULL`)
- [ ] `plans/error-messages.md` has both new error classes
- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes

**Notes:**
- No changelog entry for PR 1 — internal-only infrastructure. User-facing
  changelog entries are in PRs 2–5.
- `.validate_wt_name()` is tested indirectly via PRs 2–5 (per
  testing-standards.md — default indirect testing for private functions).
- `.get_weight_col_name()` is NOT changed (see decisions-wt-name.md).

---

## PR 2: `calibrate()` — Add `wt_name`

**Branch:** `feature/wt-name-calibrate`
**Depends on:** PR 1

**Files (TDD order):**
- `tests/testthat/test-02-calibrate.R` — New `wt_name` tests + update existing `.weight` references
- `tests/testthat/_snaps/02-calibrate.md` — Updated snapshots
- `tests/testthat/test-06-diagnostics.R` — Update `.weight` → `wts` references broken by new default
- `R/calibrate.R` — Add `wt_name` argument and rewire output path
- `changelog/wt-name/calibrate-wt-name.md` — Changelog entry

### Phase A: Write failing tests (RED)

**Task 1. Write `wt_name` validation error tests.**
Add to `test-02-calibrate.R`:
```r
test_that("calibrate() rejects non-character wt_name", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  expect_error(
    calibrate(df, variables = c(age_group), population = pop, wt_name = 42),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group), population = pop, wt_name = 42)
  )
})

test_that("calibrate() rejects empty wt_name", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  expect_error(
    calibrate(df, variables = c(age_group), population = pop, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group), population = pop, wt_name = "")
  )
})

test_that("calibrate() rejects NA wt_name", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  expect_error(
    calibrate(df, variables = c(age_group), population = pop,
              wt_name = NA_character_),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group), population = pop,
              wt_name = NA_character_)
  )
})
```

**Task 2. Write `wt_name` happy path tests.**
Add to `test-02-calibrate.R`:
```r
test_that("calibrate() names output weight column 'wts' by default", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  result <- calibrate(df, variables = c(age_group), population = pop)
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true("wts" %in% names(result))
})

test_that("calibrate() uses custom wt_name for output column", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  result <- calibrate(df, variables = c(age_group), population = pop,
                      wt_name = "cal_wt")
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "cal_wt")
  expect_true("cal_wt" %in% names(result))
})
```

**Task 3. Write input preservation and overwrite tests.**
```r
test_that("calibrate() preserves input weight column when wt_name differs", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  result <- calibrate(df, variables = c(age_group), population = pop,
                      weights = base_weight, wt_name = "cal_wt")
  test_invariants(result)
  expect_true("base_weight" %in% names(result))
  expect_true("cal_wt" %in% names(result))
  expect_identical(attr(result, "weight_col"), "cal_wt")
})

test_that("calibrate() overwrites input column when wt_name matches", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  result <- calibrate(df, variables = c(age_group), population = pop,
                      weights = base_weight, wt_name = "base_weight")
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "base_weight")
  # Values are calibrated, not original
  expect_false(identical(result[["base_weight"]], df[["base_weight"]]))
})
```

**Task 4. Write no-phantom-column test (Rule 1b).**
```r
test_that("calibrate() has no phantom column when weights = NULL + custom wt_name", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  result <- calibrate(df, variables = c(age_group), population = pop,
                      wt_name = "cal_wt")
  test_invariants(result)
  expect_true("cal_wt" %in% names(result))
  # No ".weight" or "wts" phantom column
  expect_false(".weight" %in% names(result))
  # Only the columns from input + cal_wt
  expected_cols <- c(names(df), "cal_wt")
  expect_true(all(names(result) %in% expected_cols))
})
```

**Task 5. Write survey object ignore test.**
```r
test_that("calibrate() ignores wt_name for survey_nonprob input", {
  df <- make_surveywts_data(seed = 1)
  snp <- survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  result <- calibrate(snp, variables = c(age_group), population = pop,
                      wt_name = "ignored_name")
  # Survey object path: wt_name has no effect
  expect_identical(result@variables$weights, snp@variables$weights)
})
```

**Task 6. Write `weighted_df` input tests.**
```r
test_that("calibrate() preserves old weight col and creates 'wts' for weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  wdf <- calibrate(df, variables = c(age_group), population = pop,
                    wt_name = "original_wt")
  result <- calibrate(wdf, variables = c(age_group), population = pop)
  test_invariants(result)
  expect_true("original_wt" %in% names(result))
  expect_true("wts" %in% names(result))
  expect_identical(attr(result, "weight_col"), "wts")
})

test_that("calibrate() overwrites weight col when wt_name matches weighted_df attr", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  wdf <- calibrate(df, variables = c(age_group), population = pop)
  result <- calibrate(wdf, variables = c(age_group), population = pop,
                      wt_name = "wts")
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "wts")
})
```

**Task 7. Write history test.**
```r
test_that("calibrate() records wt_name in weighting history", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  result <- calibrate(df, variables = c(age_group), population = pop,
                      wt_name = "cal_wt")
  history <- attr(result, "weighting_history")
  expect_identical(history[[length(history)]]$weight_col, "cal_wt")
})
```

**Task 8. Run tests to confirm all new tests FAIL (RED).**
Run `devtools::test(filter = "02-calibrate")`. All new `wt_name` tests should
fail (unknown argument or wrong default). Existing tests should still pass.

### Phase B: Implement (GREEN)

**Task 9. Update `calibrate()` signature in `R/calibrate.R`.**
Add `wt_name = "wts"` after `weights`:
```r
calibrate <- function(
  data,
  variables,
  population,
  weights = NULL,
  wt_name = "wts",
  method = c("linear", "logit"),
  type = c("prop", "count"),
  control = list(maxit = 50, epsilon = 1e-7)
) {
```

**Task 10. Add `wt_name` validation call.**
Insert after `weights_quo <- rlang::enquo(weights)` (line 80):
```r
.validate_wt_name(wt_name)
```

**Task 11. Implement Rule 1b — uniform weights in `wt_name` column.**
Change the uniform weight creation block (lines 105–108). Current:
```r
if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
    !inherits(data, "weighted_df")) {
  data_df[[weight_col]] <- rep(1 / nrow(data_df), nrow(data_df))
}
```
New — create in `wt_name` column and update `weight_col`:
```r
if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
    !inherits(data, "weighted_df")) {
  data_df[[wt_name]] <- rep(1 / nrow(data_df), nrow(data_df))
  weight_col <- wt_name
}
```

**Task 12. Update output construction.**
Change the data.frame output branch (lines 226–231). Current:
```r
if (inherits(data, "data.frame")) {
  out_df <- plain_df
  out_df[[weight_col]] <- new_weights
  new_history <- c(current_history, list(history_entry))
  .make_weighted_df(out_df, weight_col, new_history)
```
New — use `wt_name` for output:
```r
if (inherits(data, "data.frame")) {
  out_df <- plain_df
  out_df[[wt_name]] <- new_weights
  new_history <- c(current_history, list(history_entry))
  .make_weighted_df(out_df, wt_name, new_history)
```

**Task 13. Pass `weight_col` to `.make_history_entry()`.**
Update the `.make_history_entry()` call (lines 209–223). Add:
```r
weight_col = if (inherits(data, "data.frame")) wt_name else data@variables$weights,
```
after `operation = "calibration",`.

**Task 14. Update `@param` roxygen documentation.**
Add after the `@param weights` line:
```r
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored when `data` is a survey
#'   object (`survey_taylor` or `survey_nonprob`).
```

### Phase C: Update existing tests and snapshots

**Task 15. Update existing tests from `".weight"` to `"wts"`.**
In `test-02-calibrate.R`, find all `".weight"` references and replace with
`"wts"`. Key locations:
- Line 59: `expect_identical(attr(result, "weight_col"), ".weight")` → `"wts"`
- Line 60: `result[[".weight"]]` → `result[["wts"]]`
- Line 125: `result[[".weight"]]` → `result[["wts"]]`
- Line 206: `result[[".weight"]]` → `result[["wts"]]`
- Line 223: `result[[".weight"]]` → `result[["wts"]]`

**Task 15b. Update `test-06-diagnostics.R` references from `.weight` to `wts`.**
Diagnostic tests create `weighted_df` objects via `calibrate()`. After PR 2,
those objects have `"wts"` as their weight column. Update:
- Line 85: `weights = .weight` → `weights = wts`
- Line 97: `weights = .weight` → `weights = wts`

**Task 16. Run tests and accept updated snapshots.**
Run `devtools::test(filter = "02-calibrate")` and
`devtools::test(filter = "06-diagnostics")`. All tests should pass.
For changed snapshots: `testthat::snapshot_review("02-calibrate")` — review
each diff individually, confirm only `".weight"` → `"wts"` changes.

**Task 17. Run `devtools::document()` and `devtools::check()`.**
Confirm 0 errors, 0 warnings. NAMESPACE updated.

**Task 18. Write changelog entry.**

**Acceptance criteria:**
- [ ] `calibrate()` accepts `wt_name` with default `"wts"`
- [ ] `.validate_wt_name()` fires for bad input (`NA_character_`, `""`, non-character)
- [ ] Default output column is `"wts"` for data.frame input
- [ ] Custom `wt_name` produces correctly named output column
- [ ] No phantom column when `weights = NULL` + custom `wt_name`
- [ ] Input weight column preserved when `wt_name` differs
- [ ] `wt_name` silently ignored for survey object inputs
- [ ] `weighted_df` input tested with default and matching `wt_name`
- [ ] Weighting history records `weight_col` field
- [ ] All existing `".weight"` tests updated to `"wts"` in `test-02-calibrate.R`
- [ ] `test-06-diagnostics.R` lines 85 and 97 updated from `weights = .weight` to `weights = wts`
- [ ] Snapshots reviewed and accepted
- [ ] `devtools::document()` run; NAMESPACE in sync
- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] 98%+ line coverage maintained
- [ ] Changelog entry written and committed

**Notes:**
- This is the "template" PR. PRs 3–5 replicate this pattern mechanically.
- The chain test (`calibrate() |> rake()`) belongs in PR 3, once both
  functions have `wt_name`. PR 2 tests only calibrate-specific behavior.
- No change is needed to the `plain_df` sync block (lines 111–117 in
  calibrate.R). After Task 11, `weight_col <- wt_name` in the
  `weights = NULL` branch. `.validate_weights(plain_df, weight_col)`
  validates `plain_df[[wt_name]]` — the uniform weights (all positive,
  non-NA) — which passes validation. For the `weighted_df` input branch,
  `weight_col` is not reassigned, so `.validate_weights()` validates the
  input weights correctly.

---

## PR 3: `rake()` — Add `wt_name`

**Branch:** `feature/wt-name-rake`
**Depends on:** PR 2

**Files (TDD order):**
- `tests/testthat/test-03-rake.R` — New `wt_name` tests + update existing `.weight` references
- `tests/testthat/_snaps/03-rake.md` — Updated snapshots
- `R/rake.R` — Add `wt_name` argument and rewire output path
- `changelog/wt-name/rake-wt-name.md` — Changelog entry

### Phase A: Write failing tests (RED)

**Task 1. Write `wt_name` validation error tests for `rake()`.**
Same pattern as PR 2 Task 1 but using `rake()` with margins.

**Task 2. Write `wt_name` happy path tests for `rake()`.**
Same pattern as PR 2 Task 2: default `"wts"`, custom name.

**Task 3. Write input preservation and overwrite tests for `rake()`.**
Same pattern as PR 2 Task 3.

**Task 4. Write no-phantom-column test for `rake()`.**
Same pattern as PR 2 Task 4.

**Task 5. Write survey object ignore test for `rake()`.**
Same pattern as PR 2 Task 5.

**Task 6. Write `weighted_df` input tests for `rake()`.**
Same pattern as PR 2 Task 6.

**Task 7. Write chaining and history tests.**
Now that both `calibrate()` and `rake()` have `wt_name`, write the chain test:
```r
test_that("chaining calibrate() |> rake() uses 'wts' throughout", {
  df <- make_surveywts_data(seed = 1)
  pop <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  margins <- list(sex = c("M" = 0.48, "F" = 0.52))
  result <- calibrate(df, variables = c(age_group), population = pop) |>
    rake(margins = margins)
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "wts")
})
```
Plus the history test for `rake()`.

**Task 8. Run tests to confirm new tests FAIL (RED).**

### Phase B: Implement (GREEN)

**Task 9. Update `rake()` signature.**
Add `wt_name = "wts"` after `weights` (before `type`).

**Task 10. Add `.validate_wt_name(wt_name)` call after `weights_quo` capture.**

**Task 11. Implement Rule 1b — uniform weights in `wt_name` column.**
Same pattern as calibrate: change uniform weight creation to use `wt_name`.

**Task 12. Update output construction to use `wt_name`.**

**Task 13. Pass `weight_col` to `.make_history_entry()`.**

**Task 14. Update `@param` roxygen.**

### Phase C: Update existing tests and snapshots

**Task 15. Update existing tests from `".weight"` to `"wts"` in `test-03-rake.R`.**
Search for all `".weight"` references in the file and replace with `"wts"`.

**Task 16. Run tests and accept updated snapshots.**

**Task 17. Run `devtools::document()` and `devtools::check()`.**

**Task 18. Write changelog entry.**

**Acceptance criteria:**
Same as PR 2 but for `rake()`. Plus:
- [ ] Chaining `calibrate() |> rake()` both use `"wts"` by default
- [ ] `wt_name` position: after `weights`, before `type`
- [ ] 98%+ line coverage maintained

---

## PR 4: `poststratify()` — Add `wt_name`

**Branch:** `feature/wt-name-poststratify`
**Depends on:** PR 1

**Files (TDD order):**
- `tests/testthat/test-04-poststratify.R` — New `wt_name` tests + update existing `.weight` references
- `tests/testthat/_snaps/04-poststratify.md` — Updated snapshots (if any)
- `R/poststratify.R` — Add `wt_name` argument and rewire output path
- `changelog/wt-name/poststratify-wt-name.md` — Changelog entry

### Phase A: Write failing tests (RED)

**Tasks 1–6.** Same test categories as PR 2 (validation errors, happy paths,
preservation, phantom column, survey object, weighted_df input). Adapted
for `poststratify()` which uses `strata` + `population` (data frame format)
instead of `variables` + `population` (list format).

**Task 7. Write history test for `poststratify()`.**

**Task 8. Run tests to confirm new tests FAIL (RED).**

### Phase B: Implement (GREEN)

**Task 9. Update `poststratify()` signature.**
Add `wt_name = "wts"` after `weights` (before `type`):
```r
poststratify <- function(
  data,
  strata,
  population,
  weights = NULL,
  wt_name = "wts",
  type = c("prop", "count")
) {
```

**Tasks 10–14.** Same implementation pattern as PR 2: validate, Rule 1b,
output construction, history, roxygen.

### Phase C: Update existing tests and snapshots

**Task 15. Update existing tests from `".weight"` to `"wts"` in `test-04-poststratify.R`.**
Search for all `".weight"` references in the file and replace with `"wts"`.

**Task 16–18.** Run tests, snapshot review, check, changelog.

**Acceptance criteria:**
Same as PR 2 but for `poststratify()`.
- [ ] `wt_name` position: after `weights`, before `type`
- [ ] 98%+ line coverage maintained

---

## PR 5: `adjust_nonresponse()` — Add `wt_name`

**Branch:** `feature/wt-name-nonresponse`
**Depends on:** PR 1

**Files (TDD order):**
- `tests/testthat/test-05-nonresponse.R` — New `wt_name` tests + update existing `.weight` references
- `tests/testthat/_snaps/05-nonresponse.md` — Updated snapshots
- `R/nonresponse.R` — Add `wt_name` argument and rewire output path
- `changelog/wt-name/nonresponse-wt-name.md` — Changelog entry

### Phase A: Write failing tests (RED)

**Tasks 1–6.** Same test categories as PR 2. Note: `adjust_nonresponse()`
returns ALL rows with nonrespondent weights set to 0. Tests must verify
`wt_name` column has 0s for nonrespondents and positive values for
respondents.

**Task 7. Write history test for `adjust_nonresponse()`.**

**Task 8. Run tests to confirm new tests FAIL (RED).**

### Phase B: Implement (GREEN)

**Task 9. Update `adjust_nonresponse()` signature.**
Per decisions-wt-name.md, `wt_name` goes **after `by`** (not after `weights`):
```r
adjust_nonresponse <- function(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  wt_name = "wts",
  method = c("weighting-class", "propensity-cell", "propensity"),
  control = list(min_cell = 20, max_adjust = 2.0)
) {
```
This follows code-style.md §4 (optional NSE `by` before optional scalar `wt_name`).

**Task 10. Add `.validate_wt_name(wt_name)` call after `weights_quo` capture.**

**Task 11. Implement Rule 1b — uniform weights in `wt_name` column.**
Same pattern as calibrate: change uniform weight creation to use `wt_name`.

**Task 11b. Update pre-output weight assignment.**
`adjust_nonresponse()` assigns weights BEFORE the output branch (unlike
the other three functions which assign inside the output branch). Change
`out_df[[weight_col]] <- new_weights` to `out_df[[wt_name]] <- new_weights`.
Also update the `.make_weighted_df()` call from `weight_col` to `wt_name`.

**Task 12. Update output construction to use `wt_name`.**
The `.make_weighted_df()` call changes from `weight_col` to `wt_name`.

**Task 13. Pass `weight_col` to `.make_history_entry()`.**

**Task 14. Update `@param` roxygen.**

### Phase C: Update existing tests and snapshots

**Task 15. Update existing tests from `".weight"` to `"wts"` in `test-05-nonresponse.R`.**
Key locations: lines 54, 59, 60, 76, 657, 674, 675.

**Task 16–18.** Run tests, snapshot review, check, changelog.

**Acceptance criteria:**
Same as PR 2 but for `adjust_nonresponse()`. Plus:
- [ ] `wt_name` after `by` in signature (not after `weights`)
- [ ] Nonrespondent rows have weight 0 in `wt_name` column
- [ ] Input weight column preserved when `wt_name` differs
- [ ] 98%+ line coverage maintained

**Notes:**
- `adjust_nonresponse()` is the only function where `wt_name` is NOT
  immediately after `weights` — it follows `by` per the argument order
  convention.
- The `survey_taylor` output path filters to respondents only. The `wt_name`
  argument is ignored for survey objects (same as other functions).

---

## Cross-cutting Concerns

### Snapshot updates
Each PR updates its own snapshot file. Snapshots that mention `".weight"` in
column listings will change to `"wts"`. The review in each PR's Task 16 must
confirm only the expected column name change.

### Existing test references to `.weight`
All occurrences of `".weight"` in test assertions refer to the old default
output column name. These change to `"wts"` in each function's PR. The
diagnostics test file (`test-06-diagnostics.R`) references `.weight` only
in tidy-eval contexts (`weights = .weight`) which is a column name selector
for `weighted_df` objects — these may need updating if the `weighted_df`
objects used in those tests now have `"wts"` as their weight column.

### Diagnostic function tests (`test-06-diagnostics.R`)
The diagnostic tests create `weighted_df` objects by calling `calibrate()` or
`rake()`. After PR 2, those objects have `"wts"` as their weight column.
Lines 85 and 97 use `weights = .weight` which is tidy-eval for a column
named `.weight`. **Handled in PR 2** (Task 15b): update to `weights = wts`.

### PR dependency graph
```
PR 1 (infrastructure)
  ├── PR 2 (calibrate)
  │     └── PR 3 (rake) [depends on PR 2 for chain test]
  ├── PR 4 (poststratify) [depends on PR 1 only]
  └── PR 5 (nonresponse) [depends on PR 1 only]
```
PRs 4 and 5 can be developed in parallel with PRs 2–3.
