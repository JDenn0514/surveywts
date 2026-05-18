# Implementation Plan — Utilities Phase

**Spec:** `plans/spec-utilities.md` v1.0
**Decisions log:** `plans/decisions-utilities.md`
**Date:** 2026-05-18
**Status:** Draft — pending Stage 2 review

---

## Overview

This plan delivers `trim_weights()` and `stabilize_weights()` in a new
`R/weight-utils.R` file, plus the shared internal helper
`.trim_weights_internal()` in `R/utils.R`. Infrastructure ships first (PR 1)
to extend `.get_weight_vec()` for `survey_replicate` input and add the
trim primitive; both user-facing functions and their full test suite ship in
PR 2. Following the precedent set by PR #37 → PR #38 for the Nonresponse
phase.

---

## PR Map

- [x] PR 1: `feature/weight-utils-infra` — Doc updates + utils.R extensions (`.trim_weights_internal`, `.get_weight_vec` survey_replicate branch)
- [ ] PR 2: `feature/weight-utils` — `trim_weights()`, `stabilize_weights()`, and full test suite

---

## PR 1: Weight Utilities Infrastructure

**Branch:** `feature/weight-utils-infra`
**Depends on:** none (cut from `develop`)

**Files (in authoring order — no TDD for infra-only changes):**
- `plans/error-messages.md` — add 11 new error/warning classes for both functions
- `.claude/rules/surveywts-conventions.md` — add `utilities` family to the `@family groups` table
- `R/utils.R` — extend `.get_weight_vec()` with `survey_replicate` branch; add `.trim_weights_internal()` with attribution comment
- `changelog/utilities/feature-weight-utils-infra.md` — new; infrastructure changelog entry (create `changelog/utilities/` directory)

**Tasks:**

1. **Add new error/warning classes to `plans/error-messages.md`**
   Add a new `### trim_weights() / stabilize_weights()` subsection under
   `## Errors` with these 10 classes (plus 1 warning):

   *Errors — `trim_weights()`*:
   - `surveywts_error_null_bound_percentile` — `upper = NULL` with `type = "percentile"`
   - `surveywts_error_k_not_scalar` — `k` is not `numeric(1)` or is `NA`
   - `surveywts_error_k_nonpositive` — `k <= 0`
   - `surveywts_error_lower_not_scalar` — `lower` is not `numeric(1)` or is `NA`
   - `surveywts_error_upper_not_scalar` — `upper` is not `numeric(1)` or is `NA`
   - `surveywts_error_bounds_invalid` — resolved `lower_abs >= upper_abs`
   - `surveywts_error_upper_nonpositive` — `upper <= 0` when `type = "absolute"`
   - `surveywts_error_percentile_out_of_range` — bound not in [0, 1] with `type = "percentile"`

   *Errors — `stabilize_weights()`*:
   - `surveywts_error_by_variable_not_found` — a `by` variable not in `data`

   *Warnings — `trim_weights()`*:
   - `surveywts_warning_no_weights_trimmed` — no main weights fell outside the resolved bounds
   - `surveywts_warning_trimming_failed` — all remaining units already trimmed; no untrimmed units to absorb excess

2. **Add `utilities` family to `surveywts-conventions.md`**
   In the `@family groups` table (Section 2), add a new row:
   ```
   | `utilities` | `trim_weights()`, `stabilize_weights()` |
   ```

3. **Extend `.get_weight_vec()` in `R/utils.R` with `survey_replicate` branch**
   After the `survey_taylor` / `survey_nonprob` branch and before the plain
   `data.frame` fallback, add:
   ```r
   if (S7::S7_inherits(x, surveycore::survey_replicate)) {
     return(data_df[[x@variables$weights]])
   }
   ```
   This resolves Issue 1 from the spec review. The plain `data.frame` fallback
   (`rep(1/nrow(data_df), nrow(data_df))`) is NOT used by `trim_weights()` or
   `stabilize_weights()` — both inline `rep(1, nrow(data))` directly for the
   `data.frame` + `weights = NULL` case. This branch is for survey_replicate
   objects with named weights.
   Also update the embedded comment inside `.get_weight_vec()` that lists accepted
   input types to include `survey_replicate` alongside the existing classes.

4. **Add `.trim_weights_internal()` to `R/utils.R`**
   Append after `.validate_formula_variables()` and before `.to_svyrep_design()`.
   Include the attribution block and the exact implementation from spec §V:
   ```r
   # ============================================================================
   # .trim_weights_internal()
   # ============================================================================

   # Clip-and-redistribute logic adapted from survey::do_trimWeights (Thomas Lumley, GPL-2/3).
   # Source: https://github.com/cran/survey/blob/4834b8bc91f6414ad4514552daaed8990a86d9c1/R/grake.R#L449
   .trim_weights_internal <- function(weights, lower, upper, has_trimmed) {
     outside <- weights < lower | weights > upper
     if (!any(outside)) return(list(weights = weights, has_trimmed = has_trimmed))
     weights_new <- pmax(lower, pmin(weights, upper))
     trimmings <- weights - weights_new
     can_adjust <- !outside & !has_trimmed
     if (!any(can_adjust)) {
       cli::cli_warn(
         c("!" = "Weight redistribution failed: no untrimmed units remain to absorb the trimmed excess."),
         class = "surveywts_warning_trimming_failed"
       )
     } else {
       weights_new[can_adjust] <- weights_new[can_adjust] + sum(trimmings) / sum(can_adjust)
     }
     list(weights = weights_new, has_trimmed = outside | has_trimmed)
   }
   ```
   Also update the file-level comment block at the top of `R/utils.R` to list
   `.trim_weights_internal()` in the contents table.

5. **Run `devtools::document()` and `devtools::check()`**
   `.trim_weights_internal()` is unexported and has no roxygen2 block, so
   `devtools::document()` will be a no-op for this function but must still be
   run to confirm nothing broke. `devtools::check()` must pass: 0E 0W ≤2N.

**Acceptance criteria:**
- [ ] All new error/warning classes appear in `plans/error-messages.md`
- [ ] `utilities` family row added to `surveywts-conventions.md` Section 2
- [ ] `.get_weight_vec()` has a `survey_replicate` branch before the plain-df fallback
- [ ] `.trim_weights_internal()` present in `R/utils.R` with attribution comment
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE unchanged (no new exports)
- [ ] Changelog entry written at `changelog/utilities/feature-weight-utils-infra.md`

**Notes:**
- PR 1 has no new test file. `.trim_weights_internal()` is tested indirectly
  through `test-weight-utils.R` which ships in PR 2.
- The `.get_weight_vec()` survey_replicate branch addition is a pure additive
  change — no existing branch is touched.
- Do NOT change `.check_input_class()` — it is not used by either utilities
  function (they use the file-local `.check_weight_utils_class()`).

---

## PR 2: `trim_weights()` and `stabilize_weights()`

**Branch:** `feature/weight-utils`
**Depends on:** PR 1 merged to `develop`

**Files (TDD order — tests first):**
- `tests/testthat/test-weight-utils.R` — new; full test suite for both functions
- `R/weight-utils.R` — new; `.check_weight_utils_class()`, `trim_weights()`, `stabilize_weights()`
- `changelog/utilities/feature-weight-utils.md` — new; PR 2 changelog entry

**Tasks:**

### Group A — Write `trim_weights()` tests (all categories)

6. **Create `tests/testthat/test-weight-utils.R` with section structure**
   Add section headers matching spec §VI test categories:
   - `# trim_weights() -------------------------------------------------------`
   - `# 1. Happy path — trim_weights()`
   - `# 2. Numerical correctness — trim_weights()`
   - `# 3. Error paths — trim_weights()`
   - `# 4. Warning paths — trim_weights()`
   - `# 5. History correctness — trim_weights()`
   - `# 6. Edge cases — trim_weights()`
   - `# stabilize_weights() --------------------------------------------------`
   - (etc.)

7. **Write happy-path tests for `trim_weights()` — input class coverage**
   One `test_that()` block per input class per spec §VI §1:
   - `data.frame` + named `weights` → `weighted_df`; call `test_invariants(result)`
   - `weighted_df` → `weighted_df`; weight column name preserved
   - `survey_taylor` → `survey_taylor`; call `test_invariants(result)`
   - `survey_nonprob` → `survey_nonprob`; call `test_invariants(result)`
   - `survey_replicate` → `survey_replicate`; verify main weights trimmed AND
     replicate weight columns trimmed (compare `colSums` before/after)
   - `data.frame` + `weights = NULL` → `weighted_df`; output column named `wt_name`

8. **Write happy-path tests for `trim_weights()` — bound/type variations**
   One `test_that()` block per variation per spec §VI §1:
   - Default call (`upper = NULL`, `lower = NULL`, `type = "absolute"`):
     `history$upper_abs == median(w) + 5 * IQR(w)`; `history$lower_abs == -Inf`
   - `k = 6`: `history$upper_abs == median(w) + 6 * IQR(w)`
   - `type = "absolute"` both tails explicit
   - `type = "absolute"` upper only
   - `type = "absolute"` lower only
   - `type = "percentile"`: `upper = 0.99` → `history$upper_abs == quantile(w, 0.99)`
   - `type = "percentile"` upper only (no lower)
   - Explicit no-op (`upper = Inf`): history appended; expect
     `surveywts_warning_no_weights_trimmed`
   - `strict = FALSE` (default): weight sum preserved; single pass only
   - `strict = TRUE`: all main weights in `[lower_abs, upper_abs]`;
     weight sum preserved

9. **Write numerical correctness tests for `trim_weights()`** (spec §VI §2):
   - `abs(sum(result_weights) - sum(original_weights)) < 1e-10` when trimming succeeds
   - With `strict = TRUE` (success): `all(result_weights <= upper_abs + .Machine$double.eps)`
     AND `all(result_weights >= lower_abs - .Machine$double.eps)`
   - With `strict = FALSE`: sum ≈ original sum; NOT all weights guaranteed in bounds
   - `n_trimmed_upper == sum(original_weights > upper_abs)` (before redistribution)
   - `n_trimmed_lower == sum(original_weights < lower_abs)` (before redistribution)
   - `type = "percentile"`, `upper = 0.99`:
     `history$upper_abs == quantile(original_weights, 0.99)`
   - `survey_replicate`: for each replicate column where redistribution succeeds,
     `abs(colSums(result_rep) - colSums(original_rep)) < 1e-10`

10. **Write error-path tests for `trim_weights()`** (spec §VI §3):
    Dual pattern for each: `expect_error(class=)` + `expect_snapshot(error=TRUE)`.
    Tests:
    - `list` input → `surveywts_error_unsupported_class`
    - 0-row data frame → `surveywts_error_empty_data`
    - Named weight column missing → `surveywts_error_weights_not_found`
    - Weight column not numeric → `surveywts_error_weights_not_numeric`
    - Negative weight → `surveywts_error_weights_nonpositive`
    - `NA` weight → `surveywts_error_weights_na`
    - `upper = NULL, type = "percentile"` → `surveywts_error_null_bound_percentile`
    - `k = "5"` → `surveywts_error_k_not_scalar`
    - `k = NA_real_` → `surveywts_error_k_not_scalar`
    - `k = c(1, 2)` → `surveywts_error_k_not_scalar`
    - `k = -1` → `surveywts_error_k_nonpositive`
    - `k = 0` → `surveywts_error_k_nonpositive`
    - `lower = "0.5"` → `surveywts_error_lower_not_scalar`
    - `lower = NA_real_` → `surveywts_error_lower_not_scalar`
    - `upper = c(1, 2)` → `surveywts_error_upper_not_scalar`
    - `upper = NA_real_` → `surveywts_error_upper_not_scalar`
    - `lower = 3, upper = 3` → `surveywts_error_bounds_invalid`
    - `lower = 5, upper = 3` → `surveywts_error_bounds_invalid`
    - `lower = 0.99, upper = 0.01, type = "percentile"` → `surveywts_error_bounds_invalid`
    - `upper = 0` → `surveywts_error_upper_nonpositive`
    - `upper = -1` → `surveywts_error_upper_nonpositive`
    - `lower = -0.1, type = "percentile"` → `surveywts_error_percentile_out_of_range`
    - `upper = 1.1, type = "percentile"` → `surveywts_error_percentile_out_of_range`
    - `wt_name = 1L` (plain df + weights=NULL) → `surveywts_error_wt_name_not_scalar`
    - `wt_name = ""` → `surveywts_error_wt_name_empty`

11. **Write warning-path tests for `trim_weights()`** (spec §VI §4):
    - All main weights already within bounds → `surveywts_warning_no_weights_trimmed`
      (e.g., all weights = 1, bounds = [0.5, 5])
    - All units outside bounds → `surveywts_warning_trimming_failed`:
      weights `c(1, 10)`, bounds `lower = 3, upper = 7`; verify
      `sum(result_weights) != sum(original_weights)` (unredistributed excess)

12. **Write history correctness and edge case tests for `trim_weights()`**
    (spec §VI §5, §6):
    - History entry has `operation = "trim_weights"`, `type`, `lower_input`,
      `upper_input`, `lower_abs`, `upper_abs`, `n_trimmed_lower`, `n_trimmed_upper`
    - `type = "percentile"`: `lower_input != lower_abs`
    - Step number correct when chained after `calibrate()`
    - Single-row data: trimming applied, result valid
    - All weights equal: trimming is no-op; warning fires
    - Exactly one weight at each bound: both counts are 1
    - `survey_replicate` + `type = "percentile"`: cutoffs from main weights,
      applied to replicates

13. **Run `devtools::test(filter = "weight-utils")` → confirm ALL `trim_weights()` tests fail**
    Expected: all `test_that()` blocks that test `trim_weights()` fail with
    "could not find function" or similar. Stop here if any pass unexpectedly.

### Group B — Implement `trim_weights()`

14. **Create `R/weight-utils.R` with file header and `.check_weight_utils_class()`**
    Add file header comment listing contents. Define the file-local class
    validation helper:
    ```r
    # File-local class check for trim_weights() and stabilize_weights().
    # Accepts all 5 input types; errors with surveywts_error_unsupported_class
    # for anything else. Does NOT call .check_input_class() (which errors on
    # survey_replicate).
    .check_weight_utils_class <- function(data) {
      is_supported <- inherits(data, "data.frame") ||
        S7::S7_inherits(data, surveycore::survey_base)
      if (!is_supported) {
        cls <- class(data)[[1L]]
        cli::cli_abort(
          c(
            "x" = "{.arg data} must be a data frame or a supported survey design object.",
            "i" = "Got {.cls {cls}}.",
            "v" = "See package documentation for supported input types."
          ),
          class = "surveywts_error_unsupported_class"
        )
      }
    }
    ```
    Note: `S7::S7_inherits(data, surveycore::survey_base)` returns `TRUE` for
    `survey_taylor`, `survey_nonprob`, AND `survey_replicate` (all inherit from
    `survey_base`), so no special replicate branch is needed here.

15. **Implement `trim_weights()` — signature + steps 0–2 (validation)**
    - Signature per spec §III (argument order per decisions log: `data, weights,
      lower, upper, k, type, strict, wt_name`)
    - Step 0: If plain `data.frame` and `weights = NULL`, call
      `.validate_wt_name(wt_name)` before anything else
    - Step 1: `.check_weight_utils_class(data)`; then extract
      `data_df <- if (S7::S7_inherits(data, surveycore::survey_base)) data@data else data`
      and check `nrow(data_df) == 0L` → `surveywts_error_empty_data`
    - Step 2: `type <- match.arg(type)` then validate bounds in order:
      upper=NULL+percentile error; k validation when upper=NULL; upper scalar
      check; upper>0 check for absolute; lower scalar check; percentile range
      checks for lower/upper

16. **Implement `trim_weights()` — steps 3–5 (weight extraction + resolve cutoffs)**
    - Step 3: For plain `data.frame` + `weights = NULL`, inline
      `weights_vec <- rep(1, nrow(data))` and set `wt_col_name <- wt_name`.
      For all other cases, use `.get_weight_col_name()` to get `wt_col_name`,
      then `.get_weight_vec()` to get `weights_vec`.
    - Step 4: Call `.validate_weights(data_df, wt_col_name)` using the `data_df`
      extracted in task 15. Skip for the `data.frame` + `weights = NULL` case
      (uniform weights need no validation). Do not re-extract `data_df` here.
    - Step 5: Resolve `lower_abs` and `upper_abs` per spec formulas.
      Verify `lower_abs < upper_abs`; error if not.

17. **Implement `trim_weights()` — step 6 (main trimming loop)**
    Mirror spec Behavior Rule 6 exactly:
    ```r
    weights_vec_orig <- weights_vec
    outside_initial <- weights_vec < lower_abs | weights_vec > upper_abs
    if (!any(outside_initial)) {
      cli::cli_warn(
        c("!" = "No weights were trimmed: all main weights already fall within [{lower_abs}, {upper_abs}]."),
        class = "surveywts_warning_no_weights_trimmed"
      )
    } else {
      has_trimmed <- rep(FALSE, length(weights_vec))
      repeat {
        result <- .trim_weights_internal(weights_vec, lower_abs, upper_abs, has_trimmed)
        weights_vec <- result$weights
        has_trimmed <- result$has_trimmed
        if (!strict || !any(weights_vec < lower_abs | weights_vec > upper_abs)) break
      }
    }
    ```
    Count `n_trimmed_lower` and `n_trimmed_upper` from `outside_initial` (always,
    even when no weights were trimmed — counts are 0 in that case).

18. **Implement `trim_weights()` — step 7 (replicate column trimming)**
    Applies only when `S7::S7_inherits(data, surveycore::survey_replicate)`.
    Follow spec Behavior Rules 7a–7d exactly:
    ```r
    rep_weights <- as.matrix(data@data[data@variables$repweights])
    rwnew <- pmax(lower_abs, pmin(rep_weights, upper_abs))
    trimmings <- rep_weights - rwnew
    for (j in seq_len(ncol(rep_weights))) {
      outside_j <- rep_weights[, j] < lower_abs | rep_weights[, j] > upper_abs
      if (any(!outside_j)) {
        rwnew[!outside_j, j] <- rwnew[!outside_j, j] +
          sum(trimmings[, j]) / sum(!outside_j)
      }
      # If all outside_j: no redistribution (sum changes, no warning)
    }
    ```

19. **Implement `trim_weights()` — step 9 (output construction)**
    Build the history parameters list:
    ```r
    hist_params <- list(
      type = type, strict = strict,
      lower_input = lower, upper_input = upper,
      lower_abs = lower_abs, upper_abs = upper_abs,
      n_trimmed_lower = sum(weights_vec_orig < lower_abs),
      n_trimmed_upper = sum(weights_vec_orig > upper_abs)
    )
    ```
    where `weights_vec_orig` is the weight vector captured before trimming (assigned
    as the first line of task 17).
    Output construction per class:
    - `data.frame` / `weighted_df`: use `.make_weighted_df()`; history via
      `c(.get_history(data), list(history_entry))`
    - `survey_taylor` / `survey_nonprob`: use `.update_survey_weights()`
    - `survey_replicate`: call `.update_survey_weights()` for main weights +
      history, then write back: `data@data[data@variables$repweights] <- as.data.frame(rwnew)`

    History entry uses `.make_history_entry()` with `operation = "trim_weights"`,
    `parameters = hist_params`, `before_stats` / `after_stats` from
    `.compute_weight_stats()`.

20. **Add roxygen2 documentation to `trim_weights()`**
    Required tags:
    - `@title`, `@description` (use "trim", not "Winsorize" per spec §III terminology)
    - `@param` for all 8 arguments; terse for simple, fuller for `lower`, `upper`, `k`, `type`
    - `@return` — same class as input with trimmed weights and updated history
    - `@family utilities`
    - `@export`
    - `@examples` — use `make_surveywts_data(seed = 1)`, run at least 3 example forms
      (default, explicit upper, percentile). Add `library(survey)` if needed.

21. **Run `devtools::test(filter = "weight-utils")` → confirm all `trim_weights()` tests pass**
    All blocks in sections 1–6 for `trim_weights()` must pass. Fix failures before
    moving to `stabilize_weights()` tests.

### Group C — Write `stabilize_weights()` tests (all categories)

22. **Write happy-path tests for `stabilize_weights()`** (spec §VI §1):
    One `test_that()` block per variation:
    - `data.frame` + named `weights` → `weighted_df`; `test_invariants(result)`
    - `weighted_df` → `weighted_df`; weight column name preserved
    - `survey_taylor` → `survey_taylor`; `test_invariants(result)`
    - `survey_nonprob` → `survey_nonprob`; `test_invariants(result)`
    - `survey_replicate` → `survey_replicate`; main + replicate columns scaled
    - `data.frame` + `weights = NULL` → `weighted_df`; column named `wt_name`
    - `by = NULL` (global): `abs(sum(result_weights) - nrow(data)) < 1e-10`
    - `by = col`: for each level, sum of group weights = group `n`
    - `by = c(col1, col2)`: multi-variable grouping works

23. **Write numerical correctness tests for `stabilize_weights()`** (spec §VI §2):
    - Global: `abs(sum(new_weights) - n) < 1e-10`
    - Within-group: for each level `h`, `abs(sum(new_weights[h]) - n_h) < 1e-10`
    - Scale factor = `n / sum(w)` matches `history$parameters$scale_factor`
    - `survey_replicate` global: `abs(colSums(result_rep) - colSums(original_rep) *
      (n / sum(w_main))) < 1e-10` for all replicate columns
    - `survey_replicate` + `by`: for each group `h` and replicate column `j`:
      `abs(sum(result_rep[h, j]) - sum(original_rep[h, j]) * (n_h / W_h)) < 1e-10`
      where `W_h = sum(w_main[h])`

24. **Write error-path tests for `stabilize_weights()`** (spec §VI §3):
    Dual pattern for each: `expect_error(class=)` + `expect_snapshot(error=TRUE)`.
    - `list` input → `surveywts_error_unsupported_class`
    - 0-row data frame → `surveywts_error_empty_data`
    - Named weight column missing → `surveywts_error_weights_not_found`
    - Weight column not numeric → `surveywts_error_weights_not_numeric`
    - Negative weight → `surveywts_error_weights_nonpositive`
    - `NA` weight → `surveywts_error_weights_na`
    - `by` variable not in data → `surveywts_error_by_variable_not_found`
    - `by` variable has `NA` values → `surveywts_error_variable_has_na`
    - `wt_name = 1L` → `surveywts_error_wt_name_not_scalar`
    - `wt_name = ""` → `surveywts_error_wt_name_empty`

25. **Write history correctness and edge case tests for `stabilize_weights()`**
    (spec §VI §4, §5):
    - History entry has `operation = "stabilize_weights"`, `by`, `scale_factor`
    - Multi-variable `by`: names in `scale_factor` use ` | ` separator
    - Step number correct when chained after `trim_weights()`
    - Weights already sum to n: scale factor = 1; history appended; no warning
    - Single-row data: weight set to 1
    - `by` with one group: equivalent to global stabilization
    - `by` with a group of size 1: weight for that observation set to 1

26. **Run `devtools::test(filter = "weight-utils")` → confirm all `stabilize_weights()` tests fail**
    All `stabilize_weights()` blocks must fail ("could not find function" or similar).

### Group D — Implement `stabilize_weights()`

27. **Implement `stabilize_weights()` — signature + steps 0–2 (validation)**
    - Signature: `(data, weights = NULL, by = NULL, wt_name = "wts")`
    - Step 0: If plain `data.frame` + `weights = NULL`, call `.validate_wt_name(wt_name)`
    - Step 1: `.check_weight_utils_class(data)`; check `nrow(data) == 0`
    - Step 2a: For plain `data.frame` + `weights = NULL`: `weights_vec <- rep(1, nrow(data))`
      and `wt_col_name <- wt_name`. For all other cases: extract via
      `.get_weight_col_name()` + `.get_weight_vec()`.
    - Step 2b: Validate weights via `.validate_weights(data_df, wt_col_name)`
      (skip for plain df + weights=NULL uniform case).

28. **Implement `stabilize_weights()` — step 3 (by resolution and validation)**
    For `by` resolution, follow the `summarize_weights()` pattern:
    - Extract `data_df` from S7 objects via `@data`; for data frames use directly.
    - Use `tidyselect::eval_select(rlang::enquo(by), data_df)` to resolve `by`
      variable names.
    - Validate each `by` variable exists (error `surveywts_error_by_variable_not_found`)
      and has no `NA` values (error `surveywts_error_variable_has_na`).
    - Build `by_names` (character vector of resolved variable names).

29. **Implement `stabilize_weights()` — steps 4–5 (scale factors + rescaling)**
    - If `by = NULL`: `scale_factor <- nrow(data) / sum(weights_vec)`;
      `weights_new <- weights_vec * scale_factor`.
    - If `by` specified: compute per-group scale factors; apply to each group's
      rows. Build named `scale_factor` vector:
      - Single `by` variable: names from `as.character(group_values)`
      - Multi-variable `by`: paste values with ` | ` separator
    - For `survey_replicate`: extract replicate matrix, apply same per-group (or
      global) scale factors to all replicate columns, write back.
    - For replicate application: multiply each row by the scale factor for its
      group (or the global factor). This can be done as a vectorized operation:
      `rep_weights_new <- rep_weights * scale_factors_vec` where
      `scale_factors_vec` is a length-n vector of the appropriate group factor
      for each row.

30. **Implement `stabilize_weights()` — step 6 (output construction + history)**
    Build `hist_params`:
    ```r
    hist_params <- list(
      by = by_names,  # NULL if no grouping
      scale_factor = scale_factor  # scalar (global) or named numeric vector (by)
    )
    ```
    Output construction follows same class-dispatch pattern as `trim_weights()`.
    History entry: `operation = "stabilize_weights"`.

31. **Add roxygen2 documentation to `stabilize_weights()`**
    Required tags: `@title`, `@description`, `@param` (all 4 args), `@return`,
    `@family utilities`, `@export`, `@examples`.
    Use `make_surveywts_data(seed = 1)`, run at least 2 example forms (global
    stabilization, by-group stabilization). Add `library(survey)` if the example
    creates survey objects.

### Group E — Quality gates

32. **Run `devtools::test(filter = "weight-utils")` → all tests pass**
    Every test block in all 5 categories for both functions must be green.
    Fix any failures before proceeding.

33. **Run `error-class-auditor` agent**
    Invoke the `error-class-auditor` subagent to verify every `cli_abort()` and
    `cli_warn()` call in `R/weight-utils.R` has a `class=` argument and that each
    class name exists in `plans/error-messages.md`. Fix any violations before proceeding.

34. **Run `devtools::document()`**
    Verify NAMESPACE gains `export(trim_weights)` and `export(stabilize_weights)`.
    Verify `man/trim_weights.Rd` and `man/stabilize_weights.Rd` are created.

35. **Run `devtools::check()`**
    Must pass: 0 errors, 0 warnings, ≤2 pre-approved notes. Fix any failures.

36. **Run coverage check**
    Use `covr::package_coverage()` to verify ≥98% overall line coverage.
    If below target, identify uncovered lines and add tests. Focus areas:
    - `.check_weight_utils_class()` error branch
    - All bound-validation branches in `trim_weights()`
    - `strict = TRUE` loop termination
    - `survey_replicate` all-outside-bounds replicate column (no-redistribution path — documented exception, acceptable `# nocov` if unreachable)

37. **Run snapshot review**
    Run `testthat::snapshot_review()` to review all new snapshots added during
    implementation. Approve each snapshot diff individually before committing.

**Acceptance criteria:**
- [ ] All tests confirmed failing (red) before any implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE has `export(trim_weights)` and `export(stabilize_weights)`; man/ files in sync
- [ ] Happy path: one test block per input class for each function
- [ ] `test_invariants()` called in every constructor test block that produces `weighted_df` or `survey_nonprob` output; skipped for `survey_replicate` output (no-op)
- [ ] All error classes have dual `expect_error(class=)` + `expect_snapshot(error=TRUE)` tests
- [ ] Both warning classes tested: `surveywts_warning_no_weights_trimmed`, `surveywts_warning_trimming_failed`
- [ ] Weight sum preserved: `abs(sum(result) - sum(original)) < 1e-10`
- [ ] `trim_weights(strict = TRUE)` guarantees all main weights within `[lower_abs, upper_abs]`
- [ ] `stabilize_weights()` global: `abs(sum(result) - nrow(data)) < 1e-10`
- [ ] `survey_replicate` replicate columns updated in both functions
- [ ] History entries use correct `operation` strings: `"trim_weights"`, `"stabilize_weights"`
- [ ] All `@examples` are runnable (`R CMD check`)
- [ ] Snapshot tests updated and approved
- [ ] Coverage ≥ 98% overall
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `.check_weight_utils_class()` uses `S7::S7_inherits(data, surveycore::survey_base)` which
  returns `TRUE` for all S7 survey classes (taylor, nonprob, replicate). No need to
  enumerate each class individually or check for replicate specially.
- For the plain `data.frame` + `weights = NULL` case: skip `.validate_weights()` (the
  uniform `rep(1, n)` vector is always valid). The `wt_name` argument controls the
  output column name.
- The `n_trimmed_lower` and `n_trimmed_upper` history fields count **main** weights
  before redistribution — capture `outside_initial` before the trimming loop.
- For multi-variable `by` in `stabilize_weights()`: follow `summarize_weights()` pattern
  for the `tidyselect::eval_select()` call — pass the enquoted `by` against `data_df`
  (not the S7 object).
- `@importFrom tidyselect eval_select` is NOT needed — use `tidyselect::eval_select()` via `::`.
- The `by` argument needs `{{ by }}` or `rlang::enquo(by)` NSE handling; follow the
  `summarize_weights()` implementation as the reference.

---

## Pre-PR Checklist (both PRs)

Before opening each PR:
- [ ] Branch cut from `develop` (not `main`)
- [ ] PR title is a valid Conventional Commit: `feat(utils): ...` (PR 1), `feat(weights): ...` (PR 2)
- [ ] PR description uses `.github/PULL_REQUEST_TEMPLATE.md` format
- [ ] `devtools::check()` passed locally on the branch
- [ ] `devtools::document()` committed
- [ ] No files outside the stated scope modified

---

## Phase Completion Checklist

When both PRs are merged to `develop`:
- [ ] `plans/error-messages.md` has all 11 new classes
- [ ] `surveywts-conventions.md` has the `utilities` family
- [ ] `R/utils.R` has `.trim_weights_internal()` and `survey_replicate` branch in `.get_weight_vec()`
- [ ] `R/weight-utils.R` exists with both functions exported
- [ ] `tests/testthat/test-weight-utils.R` exists with all test categories
- [ ] `DESCRIPTION` Version still ends in `.9000` (full release bump comes at `/merge-main`)
- [ ] CLAUDE.md release table updated: Utilities row changed from `🔜 Next` to `✅ Complete`
