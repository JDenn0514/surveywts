# Implementation Plan: Phase 0 Fixes

**Spec:** `plans/spec-phase-0-fixes.md` (v0.4, approved 2026-03-18)
**Decisions:** `plans/decisions-phase-0-fixes.md`

---

## Overview

This plan delivers 10 surveywts changes (spec Changes 1–10) across 6 PRs.
Change 11 (remove `survey_srs` + relax `survey_nonprob` validator) is a
surveycore change that has already landed in surveycore >= 0.6.1.

The changes range from deleting ~586 lines of vendored algorithm code
(Change 1) to single-line cosmetic fixes (Change 9). PRs are ordered to
minimize merge conflicts: shared infrastructure first, then independent
fixes, then the two high-severity changes.

---

## PR Map

- [x] PR 1: `fix/utils-housekeeping` — Move helpers to utils.R, inline `%||%`, document `@importFrom` exception (Changes 4, 5, 10)
- [ ] PR 2: `fix/input-validation` — Modernize `.check_input_class()` and `response_status` resolution (Changes 3, 7)
- [x] PR 3: `fix/diagnostics-cosmetic` — Rewrite grouped path in `summarize_weights()` and fix print label (Changes 6, 9)
- [ ] PR 4: `fix/poststratify-default-type` — Change `poststratify()` default `type` to `"prop"` (Change 8)
- [ ] PR 5: `fix/vendor-delegation` — Replace vendored algorithms with `survey`/`anesrake` calls (Change 1)
- [ ] PR 6: `fix/nonresponse-zero-weights` — Zero weights instead of dropping rows in `adjust_nonresponse()` (Change 2)

---

## PR 1: Utils Housekeeping

**Branch:** `fix/utils-housekeeping`
**Depends on:** none
**Spec changes:** 4 (move helpers), 5 (remove `%||%`), 10 (`@importFrom` docs)

This PR is a pure refactor with no behavioral change. All existing tests
must pass without modification.

**Files:**
- `R/utils.R` — receive `.check_input_class()` and `.get_history()`; inline `%||%`
- `R/calibrate.R` — remove `.check_input_class()` and `.get_history()` definitions; inline `%||%`
- `.claude/rules/code-style.md` — add `@importFrom` exception clause

### Steps

**Change 4 — Move helpers to utils.R**

1. Read `R/calibrate.R` lines 242–286 and copy `.check_input_class()` (lines 242–271) and `.get_history()` (lines 277–286) to `R/utils.R`. Place them after `.update_survey_weights()` (after line 562) and before `.calibrate_engine()` (before line 614). Add both to the `R/utils.R` header comment (lines 1–24).

2. Delete `.check_input_class()` (lines 242–271) and `.get_history()` (lines 277–286) from `R/calibrate.R`.

3. Run `devtools::load_all()` and `devtools::test()` — all tests must pass unchanged. These are package-internal functions; moving them within `R/` has no effect on NAMESPACE or behavior.

**Change 5 — Remove `%||%` redefinition**

4. Inline the 4 `%||%` usage sites. Replace each `x %||% y` with `if (is.null(x)) y else x`:
   - `R/calibrate.R` line 279: `attr(x, "weighting_history") %||% list()`
     → `if (is.null(attr(x, "weighting_history"))) list() else attr(x, "weighting_history")`
     (Note: this is inside `.get_history()`, which was just moved to utils.R in step 1. Apply in utils.R.)
   - `R/calibrate.R` line 282: `x@metadata@weighting_history %||% list()`
     → `if (is.null(x@metadata@weighting_history)) list() else x@metadata@weighting_history`
     (Same — now in utils.R.)
   - `R/utils.R` line 663: `attr(g, "iterations") %||% NA_integer_`
     → `if (is.null(attr(g, "iterations"))) NA_integer_ else attr(g, "iterations")`
   - `R/utils.R` line 664: `attr(g, "max_error") %||% 0`
     → `if (is.null(attr(g, "max_error"))) 0 else attr(g, "max_error")`

5. Delete the `%||%` definition at `R/utils.R` line 899.

6. Grep the entire repo for `%||%` to confirm no remaining usage (tests/, man/, R/).

7. Run `devtools::test()` — all tests must pass unchanged.

**Change 10 — Document `@importFrom` exception**

8. Add the exception clause to `.claude/rules/code-style.md` §4 (Import style), after the "no `@importFrom`" rule. Text from spec §XI:
   > **Exception: S3 method registration.** `@importFrom` is required when
   > registering an S3 method for a generic from another package (e.g.,
   > `dplyr::dplyr_reconstruct`, `dplyr::select`). Without it, `roxygen2`
   > cannot generate the `S3method()` directive in `NAMESPACE`. This is the
   > only approved use of `@importFrom`.

**Finalize**

9. Run `devtools::document()`.
10. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.
11. Commit and open PR.

**Acceptance criteria:**
- [ ] `.check_input_class()` and `.get_history()` live in `R/utils.R`
- [ ] No definitions of either remain in `R/calibrate.R`
- [ ] `R/utils.R` header comment updated with both function names
- [ ] Zero `%||%` occurrences in the codebase
- [ ] `code-style.md` documents `@importFrom` exception for S3 method registration
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained
- [ ] All existing tests pass without modification

**Notes:**
- Step 4 requires care: the line numbers for `.get_history()` usage sites
  (originally calibrate.R 279, 282) will now be in utils.R at different line
  numbers after the move in step 1. Work from the function body, not absolute
  line numbers.
- No new tests needed — this is a pure refactor.

---

## PR 2: Input Validation Modernization

**Branch:** `fix/input-validation`
**Depends on:** PR 1 (`.check_input_class()` moved to utils.R)
**Spec changes:** 3 (survey_base check), 7 (response_status eval_select)

**Files (TDD order):**
- `plans/error-messages.md` — add `surveywts_error_response_status_multiple_columns`
- `tests/testthat/test-05-nonresponse.R` — add eval_select tests
- `tests/testthat/test-02-calibrate.R` — update snapshot if error message text changes
- `tests/testthat/test-06-diagnostics.R` — update snapshot if error message text changes
- `R/utils.R` — update `.check_input_class()`
- `R/diagnostics.R` — update `.diag_validate_input()`
- `R/nonresponse.R` — replace `rlang::as_name()` with `tidyselect::eval_select()`

### Steps

**Prep — error-messages.md**

1. Add `surveywts_error_response_status_multiple_columns` to `plans/error-messages.md` under `adjust_nonresponse()`:
   | `surveywts_error_response_status_multiple_columns` | `adjust_nonresponse()` | `response_status` selects > 1 column |

**Change 3 — `.check_input_class()` → `survey_base`**

2. Write test in `test-02-calibrate.R`: verify that `calibrate()` rejects `survey_replicate` input with class `surveywts_error_replicate_not_supported`. (This test likely already exists — confirm and add if missing.)

3. Update `.check_input_class()` in `R/utils.R`:
   - Keep the `survey_replicate` guard first (specific before general)
   - Replace `S7::S7_inherits(data, surveycore::survey_taylor) || S7::S7_inherits(data, surveycore::survey_nonprob)` with `S7::S7_inherits(data, surveycore::survey_base)`
   - Update error message per decisions log: "Use a data.frame or a supported survey design object. See package documentation for details."

4. Update `.diag_validate_input()` in `R/diagnostics.R` identically:
   - Add `survey_replicate` guard (mirrors `.check_input_class()`)
   - Replace specific class checks with `S7::S7_inherits(x, surveycore::survey_base)`
   - Update error message to match

5. Update `.get_history()` in `R/utils.R`: replace
   `S7::S7_inherits(x, surveycore::survey_taylor) || S7::S7_inherits(x, surveycore::survey_nonprob)`
   with `S7::S7_inherits(x, surveycore::survey_base)`. This aligns with the
   same pattern applied to `.check_input_class()` and `.diag_validate_input()`.

6. Run tests — confirm existing unsupported-class error tests still pass. Update snapshot files if error message text changed.

**Change 7 — `response_status` → `tidyselect::eval_select()`**

7. Write failing test in `test-05-nonresponse.R`: call `adjust_nonresponse()` with a tidyselect expression that selects 2+ columns for `response_status`. Expect error with class `surveywts_error_response_status_multiple_columns`.

8. Run the new test — confirm it fails (currently `rlang::as_name()` would error differently).

9. Replace the response_status resolution in `R/nonresponse.R` step 7 (lines 138–156). Replace:
   ```r
   status_var <- rlang::as_name(rs_quo)
   if (!status_var %in% names(plain_df)) { ... }
   ```
   With the `tidyselect::eval_select()` pattern from spec §VIII:
   ```r
   status_pos <- tidyselect::eval_select(rs_quo, plain_df)
   if (length(status_pos) == 0L) { ... class = "surveywts_error_response_status_not_found" }
   if (length(status_pos) > 1L) { ... class = "surveywts_error_response_status_multiple_columns" }
   status_var <- names(status_pos)
   ```

10. Run the new test — confirm it passes.

11. Run full test suite — confirm all existing `adjust_nonresponse()` tests still pass with the new resolution method. Update snapshots if the "not found" error message text changed.

**Finalize**

12. Run `devtools::document()`.
13. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.
14. Commit and open PR.

**Acceptance criteria:**
- [ ] `.check_input_class()` uses `surveycore::survey_base` inheritance check
- [ ] `.diag_validate_input()` uses `surveycore::survey_base` inheritance check
- [ ] Both include `survey_replicate` rejection guard before the general check
- [ ] `.get_history()` uses `surveycore::survey_base` inheritance check
- [ ] Error messages reference documentation, not specific class names
- [ ] `response_status` resolved via `tidyselect::eval_select()`
- [ ] Multi-column `response_status` throws `surveywts_error_response_status_multiple_columns`
- [ ] `plans/error-messages.md` updated
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained
- [ ] All new tests confirmed failing before implementation

**Notes:**
- The `tidyselect::eval_select()` call must happen AFTER step 3 (empty data
  check) and AFTER `plain_df` is assembled, but BEFORE the response status
  validation (step 7). The spec is explicit about placement.
- Existing `response_status` tests using bare column names will continue to
  work — `eval_select()` supports the same bare-name syntax as `as_name()`.

---

## PR 3: Diagnostics & Cosmetic Fixes

**Branch:** `fix/diagnostics-cosmetic`
**Depends on:** none
**Spec changes:** 6 (rewrite grouped path), 9 (print label)

**Files (TDD order):**
- `tests/testthat/test-06-diagnostics.R` — add dot-in-level test
- `tests/testthat/test-00-classes.R` — update print snapshot
- `R/diagnostics.R` — rewrite grouped path in `summarize_weights()`
- `R/methods-print.R` — fix variance method label

### Steps

**Change 6 — Rewrite grouped path in `summarize_weights()`**

1. Write failing test in `test-06-diagnostics.R`: create a dataset with a grouping variable containing `.` in its levels (e.g., `"Dr."`, `"Mr."`). Call `summarize_weights(data, weights = w, by = title)`. Assert the output has the correct number of rows and the group column values are correct (not mangled by `interaction()` separator collision).

2. Run the new test — confirm it fails (current `interaction()` uses `.` separator, which collides with `.` in factor levels).

3. Replace the grouped path in `summarize_weights()` (diagnostics.R lines ~124–142). Replace `interaction()` with the `paste(sep = "//")` + `split()` + `lapply()` pattern from spec §VII:
   ```r
   cell_keys <- do.call(
     paste,
     c(lapply(by_names, function(v) as.character(data_df[[v]])), sep = "//")
   )
   groups <- split(seq_len(nrow(data_df)), cell_keys)
   # Preserve factor-level order: reorder group names by first occurrence
   key_order <- unique(cell_keys)
   groups <- groups[key_order]
   result_dfs <- lapply(names(groups), function(gkey) {
     idx <- groups[[gkey]]
     w <- data_df[[weight_col]][idx]
     stats_tbl <- tibble::as_tibble(.compute_weight_stats(w))
     group_row <- data_df[idx[[1L]], by_names, drop = FALSE]
     dplyr::bind_cols(tibble::as_tibble(group_row), stats_tbl)
   })
   dplyr::bind_rows(result_dfs)
   ```

4. Run the new test — confirm it passes.

5. Run existing `summarize_weights()` tests — confirm all pass.

**Change 9 — Print label fix**

6. Update `R/methods-print.R` line 38: replace
   `cat("# Variance method: Taylor linearization\n")` with
   `cat("# Variance: model-assisted (SRS assumption)\n")`

7. Update the `survey_nonprob` print snapshot in `tests/testthat/_snaps/` to reflect the new label. (Run `testthat::snapshot_review()` to review and accept.)

8. Run `test-00-classes.R` — confirm the print snapshot test passes.

**Finalize**

9. Run `devtools::document()`.
10. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.
11. Commit and open PR.

**Acceptance criteria:**
- [ ] `summarize_weights()` uses `paste(sep = "//")` instead of `interaction()`
- [ ] Grouping variables with `.` in levels produce correct output
- [ ] `survey_nonprob` print says `"model-assisted (SRS assumption)"`
- [ ] Updated print snapshot committed
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained
- [ ] Row ordering preserves first-occurrence order (not alphabetical)
- [ ] Dot-in-level test confirmed failing before implementation

**Notes:**
- The grouped-path rewrite replaces both the grouping mechanism AND the
  per-group computation loop. This is intentional per spec §VII — the
  `interaction()` fix naturally leads to a cleaner iteration pattern.
- The `by_names == 0L` check (ungrouped path) is unchanged.
- `split()` returns groups in alphabetical key order. The `groups <- groups[key_order]`
  line reorders to first-occurrence order, preserving factor-level ordering when
  the input column is a factor.

---

## PR 4: Poststratify Default Type

**Branch:** `fix/poststratify-default-type`
**Depends on:** none
**Spec change:** 8

**Files (TDD order):**
- `tests/testthat/test-04-poststratify.R` — update tests relying on count default
- `R/poststratify.R` — change function signature

### Steps

1. Write a new test in `test-04-poststratify.R`: call `poststratify()` without explicit `type =`, passing proportion-based population data (targets sum to 1.0). Assert it succeeds and produces correct weights. This test should fail currently (default is `"count"`, proportions summing to 1 would fail the count validator).

2. Run the new test — confirm it fails.

3. Identify all test blocks that call `poststratify()` without explicit `type =` and rely on count-based population data. From spec §IX, these are at approximately:
   - Line 66: `"poststratify() returns weighted_df for data.frame input"`
   - Line 82: `"poststratify() default type is 'count', not 'prop'"` — rewrite entirely
   - Line 136: `"poststratify() preserves survey_taylor class..."`
   - Line 161: `"poststratify() accepts and returns survey_nonprob"`
   - Line 551: `"poststratify() history entry has correct structure"`
   - Line 580: `"poststratify() step increments correctly in chained calls"`
   - Error path tests (lines 238–497) using `.make_pop_ps()` without `type =`

4. Add explicit `type = "count"` to all test blocks identified in step 3 that use count-based population data. Rewrite the "default type" test (line 82) to verify the new default is `"prop"`.

5. Change the `poststratify()` function signature in `R/poststratify.R` (line 72):
   From: `type = c("count", "prop")`
   To: `type = c("prop", "count")`

6. Update the `@param type` roxygen documentation per spec §IX:
   ```
   @param type Character scalar. `"prop"` (default): `target` values are
     proportions summing to 1.0. `"count"`: `target` values are population
     counts.
   ```
   Remove any note about the default differing from `calibrate()` / `rake()`.

7. Run the new default-prop test from step 1 — confirm it passes.

8. Run the full `test-04-poststratify.R` suite — confirm all tests pass.

9. Add NEWS.md entry under `## Breaking changes`:
   ```
   * `poststratify()` now defaults to `type = "prop"`, consistent with
     `calibrate()` and `rake()`. Existing code that relies on the count default
     should add explicit `type = "count"`.
   ```

**Finalize**

10. Run `devtools::document()`.
11. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.
12. Commit and open PR.

**Acceptance criteria:**
- [ ] `poststratify()` defaults to `type = "prop"`
- [ ] All tests that relied on `type = "count"` default now specify it explicitly
- [ ] New test verifies default behavior with proportion-based targets
- [ ] `@param type` roxygen updated
- [ ] NEWS.md documents the breaking default change
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained
- [ ] Default-prop test confirmed failing before implementation

**Notes:**
- This is an API change. Pre-CRAN semver allows it without deprecation.
- The `.make_pop_ps()` test helper may default to count-based data — check
  its implementation and add `type = "count"` to callers as needed.

---

## PR 5: Vendor Delegation

**Branch:** `fix/vendor-delegation`
**Depends on:** PR 1 (utils.R stable after housekeeping)
**Spec change:** 1

This is the largest PR: ~586 lines of vendor code deleted, `.calibrate_engine()`
rewritten to delegate to `survey::calibrate()`, `survey::rake()`,
`anesrake::anesrake()`, and `survey::postStratify()`.

**Files (TDD order):**
- `plans/error-messages.md` — add `surveywts_error_cap_not_supported_survey`
- `tests/testthat/test-02-calibrate.R` — add delegation + convergence tests
- `tests/testthat/test-03-rake.R` — add delegation + convergence + cap error tests
- `tests/testthat/test-04-poststratify.R` — add delegation test
- `DESCRIPTION` — move `survey` to Imports, add `anesrake` to Imports
- `R/utils.R` — rewrite `.calibrate_engine()`
- `R/rake.R` — add cap + survey method error
- Delete: `R/vendor-calibrate-greg.R`, `R/vendor-calibrate-ipf.R`, `R/vendor-rake-anesrake.R`

### Steps

**Prep — error-messages.md + DESCRIPTION**

1. Add `surveywts_error_cap_not_supported_survey` to `plans/error-messages.md` under `rake()`:
   | `surveywts_error_cap_not_supported_survey` | `rake()` | `cap` specified with `method = "survey"` |

2. Update `DESCRIPTION`:
   - Move `survey (>= 4.2-1)` from `Suggests` to `Imports`
   - Add `anesrake (>= 0.80)` to `Imports`
   - Remove `survey` from `Suggests` (now in `Imports`)

**Tests — write failing tests first**

3. Write delegation round-trip test for **linear calibration** in `test-02-calibrate.R`:
   construct data + population via `make_surveywts_data()`, run `calibrate(method = "linear")`,
   then run `survey::calibrate()` directly with identical inputs. Compare output
   weights within tolerance `1e-8`.

4. Write delegation round-trip test for **logit calibration**: same pattern,
   `method = "logit"`, compare against `survey::calibrate(calfun = survey::cal.logit)`.

5. Write **logit non-convergence test**: construct a scenario where logit
   calibration cannot converge (e.g., `maxit = 1` with extreme targets).
   Expect error with class `surveywts_error_calibration_not_converged`.

6. Write delegation round-trip test for **IPF raking** in `test-03-rake.R`:
   run `rake(method = "survey")`, then run `survey::rake()` directly.
   Compare output weights within tolerance `1e-8`.

7. Write **IPF non-convergence test**: construct a scenario where
   `survey::rake()` cannot converge (e.g., `maxit = 1`). Expect error with
   class `surveywts_error_calibration_not_converged`.

8. Write **cap + survey method error test** in `test-03-rake.R`:
   call `rake(method = "survey", cap = 5)`. Expect error with class
   `surveywts_error_cap_not_supported_survey`.

9. Write delegation round-trip test for **anesrake** in `test-03-rake.R`:
   run `rake(method = "anesrake")` and compare against
   `anesrake::anesrake()` directly. Compare within tolerance `1e-8`.

10. Write **anesrake non-convergence test**: construct data where anesrake
    cannot converge (extreme targets + `maxiter = 1`). Expect error with
    class `surveywts_error_calibration_not_converged`.

11. Write **anesrake already-calibrated test**: construct data where targets
    already match sample marginals. Expect message with class
    `surveywts_message_already_calibrated`.

12. Write delegation round-trip test for **poststratification** in
    `test-04-poststratify.R`: run `poststratify()`, then run
    `survey::postStratify()` directly. Compare within `1e-8`.

13. Run all new tests — confirm they fail (still using vendored algorithms;
    convergence detection and cap error don't exist yet).

**Implementation — rewrite `.calibrate_engine()`**

14. Add the **cap error** in `R/rake.R`: immediately after `rlang::arg_match(method)`,
    before margin parsing:
    ```r
    if (!is.null(cap) && method == "survey") {
      cli::cli_abort(
        c(
          "x" = "{.arg cap} is not supported when {.code method = \"survey\"}.",
          "i" = "{.fn survey::rake} does not support per-step weight capping.",
          "v" = "Use {.code method = \"anesrake\"} for raking with a weight cap."
        ),
        class = "surveywts_error_cap_not_supported_survey"
      )
    }
    ```

15. Rewrite `.calibrate_engine()` **linear/logit path** (utils.R lines ~623–669):
    - Set `contrasts()` on each factor column in `data_df` to
      `contr.treatment(nlevels, contrasts = FALSE)` **before** constructing
      the svydesign. This ensures the formula `~var1 + var2 - 1` produces
      full indicator encoding (k columns per k-level factor, no reference
      level dropped).
    - Build the formula: `~var1 + var2 - 1`
    - Build named population totals vector (one entry per factor level,
      names matching `model.matrix()` column names)
    - Construct `survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)`
    - Call `survey::calibrate(svy_tmp, formula, population, calfun, maxit, epsilon)`
    - Extract weights via `weights(cal_result)`
    - **Logit convergence:** wrap in `withCallingHandlers()`, intercept
      warnings matching non-convergence, suppress, re-throw as
      `surveywts_error_calibration_not_converged`
    - **Linear:** no convergence check (closed-form)

16. Rewrite `.calibrate_engine()` **IPF path** (utils.R lines ~671–706):
    - Build margin formulas: `list(~var1, ~var2, ...)`
    - Build population data frames with `Freq` column
    - Construct `survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)`
    - Call `survey::rake(svy_tmp, sample.margins, population.margins, control)`
    - Extract weights via `weights(raked)`
    - **Convergence:** wrap in `withCallingHandlers()`, intercept warnings,
      suppress, re-throw as `surveywts_error_calibration_not_converged`

17. Rewrite `.calibrate_engine()` **anesrake path** (utils.R lines ~708–755):
    - Build named list of target vectors
    - Create synthetic caseid: `data_df$.anesrake_id <- seq_len(nrow(data_df))`
    - Call `anesrake::anesrake(inputter, dataframe, caseid, weightvec, ...)`
      with params mapped from `control`: `pctlim = control$improvement`,
      `nlim = control$min_cell_n`, `cap = cap`, `maxiter = control$maxit`,
      `choosemethod = control$variable_select`, `type = "pctlim"`,
      `force1 = FALSE`, `iterate = TRUE`
    - Check `result$converge`: if `FALSE`, throw
      `surveywts_error_calibration_not_converged`
    - Check `result$iterations == 0`: if so, emit
      `surveywts_message_already_calibrated`
    - Extract weights via `result$weightvec`

18. Enrich `calibration_spec` in `R/poststratify.R`: add `strata_names` and
    `population` to the spec passed to `.calibrate_engine()`:
    ```r
    calibration_spec <- list(
      type = "poststratify",
      cells = cells,
      strata_names = strata_names,
      population = population   # data frame with strata cols + "target"
    )
    ```

19. Rewrite `.calibrate_engine()` **poststratify path** (utils.R lines ~757–775):
    - Build formula from `calibration_spec$strata_names`: `~var1 + var2`
    - Build population data frame: rename `target` → `Freq` in
      `calibration_spec$population`
    - Construct `survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)`
    - Call `survey::postStratify(svy_tmp, strata, population)`
    - Extract weights via `weights(ps_result)`

20. Run all new delegation tests — confirm they pass.

21. Run the **full test suite** — identify any existing tests that fail due
    to the engine rewrite. Fix numerical tolerance issues if any (tolerance
    `1e-8` for delegation tests).

**Cleanup — delete vendor files**

22. Delete `R/vendor-calibrate-greg.R` (185 lines).

23. Delete `R/vendor-calibrate-ipf.R` (127 lines).

24. Delete `R/vendor-rake-anesrake.R` (274 lines).

25. Remove any unit tests for vendored internals (`.greg_linear()`,
    `.greg_logit()`, `.ipf_calibrate()`, `.anesrake_calibrate()`).
    Update comments in test files that reference deleted vendor files
    (e.g., `test-02-calibrate.R:802` referencing `vendor-calibrate-greg.R`).

26. Delete `.build_model_matrix()` from utils.R (lines ~792–799) if it was
    only used by vendored code. Grep for usage first.

27. Delete `.throw_not_converged()` from utils.R after verifying no remaining
    callers (`grep -r ".throw_not_converged(" R/`). Keep
    `.throw_not_converged_zero_maxit()` (still used by `maxit = 0` guard).

28. Remove `skip_if_not_installed("survey")` guards from tests where they
    protect delegation tests (survey is now `Imports`, always available).
    Keep guards for `svrep` if used as additional oracle.

29. Run `devtools::test()` — all tests must pass.

**Finalize**

30. Run `devtools::document()`.
31. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.
32. Commit and open PR.

**Acceptance criteria:**
- [ ] All 3 vendor files deleted
- [ ] `survey` in `Imports` (not `Suggests`); `anesrake` in `Imports`
- [ ] `.calibrate_engine()` delegates to package functions for all 5 methods
- [ ] Delegation round-trip tests pass within `1e-8` for all methods
- [ ] Logit non-convergence intercepted + re-thrown as typed error
- [ ] IPF non-convergence intercepted + re-thrown as typed error
- [ ] Anesrake non-convergence detected via `$converge` flag
- [ ] Anesrake already-calibrated detected via `$iterations == 0`
- [ ] `cap` + `method = "survey"` errors with `surveywts_error_cap_not_supported_survey`
- [ ] `plans/error-messages.md` updated
- [ ] All new tests confirmed failing before implementation
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained

**Notes:**
- The formula encoding for `survey::calibrate()` must use full indicator
  encoding without intercept (decision: Option B in decisions log). Use
  `contr.treatment(..., contrasts = FALSE)` and `- 1` in the formula.
- The `%||%` sites in `.calibrate_engine()` engine result handling (lines
  663–664) will already be inlined by PR 1. Account for that.
- `force1 = FALSE` is correct — no post-raking normalization (decisions log).
- `.throw_not_converged_zero_maxit()` is still needed for the `maxit = 0`
  fast-fail guard. Keep it.
- `.throw_not_converged()` becomes dead code after the engine rewrite —
  delegation paths throw typed errors inline. Delete it after verifying no
  remaining callers (grep for `.throw_not_converged(`). Add this to the
  cleanup section (step 26).

---

## PR 6: Nonresponse Zero Weights

**Branch:** `fix/nonresponse-zero-weights`
**Depends on:** surveycore >= 0.6.1 (already installed); ideally after PR 3
**Spec change:** 2

This is a **breaking change** to the `adjust_nonresponse()` output contract.

**Prerequisite:** surveycore >= 0.6.1 with the relaxed `survey_nonprob`
validator (condition 4: `>= 0 && any > 0`) is already installed and pinned
in DESCRIPTION.

**Files (TDD order):**
- `tests/testthat/helper-test-data.R` — update `test_invariants()`
- `tests/testthat/test-05-nonresponse.R` — update existing + add new tests
- `tests/testthat/test-06-diagnostics.R` — add post-nonresponse diagnostic tests
- `R/nonresponse.R` — modify steps 14, 15, 16
- `R/diagnostics.R` — add zero-weight filter to diagnostic functions
- `DESCRIPTION` — already pinned to `surveycore (>= 0.6.1)`
- `NEWS.md` — breaking change entry

### Steps

**Infrastructure — test_invariants() update**

1. Update `test_invariants()` in `helper-test-data.R`: change the
   `survey_nonprob` branch from `all(w > 0)` to `all(w >= 0) && any(w > 0)`.
   (The surveycore validator already allows this as of 0.6.1; this aligns
   the test helper.) Also update the `survey_taylor` branch identically
   for consistency.

**Tests — write failing tests first**

2. Write test in `test-05-nonresponse.R`: **data.frame happy path** —
   call `adjust_nonresponse()` on a data.frame. Assert:
   - `nrow(result) == nrow(input)` (all rows retained)
   - Nonrespondent weights are exactly 0
   - Respondent weights match the expected adjustment formula
   - `test_invariants()` passes on the result

3. Write test: **survey_nonprob happy path** — call `adjust_nonresponse()`
   on a `survey_nonprob` object. Assert:
   - `nrow(result@data) == nrow(input@data)` (all rows retained)
   - Nonrespondent weights in `@data` are exactly 0
   - Respondent weights adjusted correctly
   - `@variables` and `@metadata` preserved (except weighting_history)
   - `test_invariants()` passes

4. Write test: **diagnostics on post-nonresponse data** — create a
   post-nonresponse `weighted_df` (with zero weights). Call
   `effective_sample_size()`, `weight_variability()`, and
   `summarize_weights()` on it. Assert they return correct results
   computed on positive weights only.

5. Write test: **re-calibration fails** — create a post-nonresponse
   `weighted_df` with zero weights. Call `calibrate()` on it. Expect error
   with class `surveywts_error_weights_nonpositive` (`.validate_weights()`
   rejects zeros).

6. Run new tests — confirm they fail (current behavior drops rows /
   diagnostics reject zeros).

7. Update existing tests that assert `nrow(result) < nrow(input)` to
   assert `nrow(result) == nrow(input)`. Update weight assertions to
   account for zero weights in the output.

**Implementation — modify `adjust_nonresponse()`**

8. Modify **step 14** in `R/nonresponse.R` (lines 307–311). Replace
   respondent-only subsetting:
   ```r
   # Before:
   resp_rows <- which(is_respondent)
   out_df <- plain_df[resp_rows, , drop = FALSE]
   out_weights <- new_weights[resp_rows]
   out_df[[weight_col]] <- out_weights

   # After:
   new_weights[!is_respondent] <- 0
   out_df <- plain_df
   out_df[[weight_col]] <- new_weights
   ```

9. Modify **step 15** (line 314): compute `after_stats` on respondent
   weights only:
   ```r
   # Before:
   after_stats <- .compute_weight_stats(out_weights)

   # After:
   after_stats <- .compute_weight_stats(new_weights[is_respondent])
   ```

10. Modify **step 16** (lines 330–341): for survey objects, no longer
    filter `@data`:
    ```r
    # Before:
    filtered_design <- data
    filtered_design@data <- out_df
    .update_survey_weights(filtered_design, out_weights, history_entry)

    # After:
    .update_survey_weights(data, new_weights, history_entry)
    ```

11. Run the new happy-path tests — confirm they pass.

**Implementation — diagnostic zero-weight filter**

12. Add zero-weight filtering to `effective_sample_size()`,
    `weight_variability()`, and `summarize_weights()` in `R/diagnostics.R`.
    After extracting `data_df` and `weight_col` via `.diag_validate_input()`,
    filter to positive weights before calling `.validate_weights()`:
    ```r
    w_all <- data_df[[weight_col]]
    data_df <- data_df[w_all > 0, , drop = FALSE]
    .validate_weights(data_df, weight_col)
    w <- data_df[[weight_col]]
    ```

13. Run the post-nonresponse diagnostics test — confirm it passes.

14. Run the re-calibration-fails test — confirm it passes (`.validate_weights()`
    still rejects zeros at calibration entry points).

**Documentation + metadata**

15. Update `@return` in `R/nonresponse.R` roxygen per spec §III:
    "All rows (respondents and nonrespondents) are returned. Nonrespondent
    weights are set to 0; respondent weights are adjusted upward..."

16. Update `@description` and `@details` per spec §III to document
    zero-weight behavior for downstream consumers.

17. Verify `surveycore (>= 0.6.1)` is already pinned in `DESCRIPTION`.

18. Add NEWS.md entry under `## Breaking changes`:
    ```
    * `adjust_nonresponse()` now returns all rows with nonrespondent weights
      set to 0, instead of dropping nonrespondent rows. This preserves design
      structure for variance estimation. Code that uses `nrow(result)` to count
      respondents should use `sum(result$weight_col > 0)` instead.
    ```

**Finalize**

19. Run `devtools::document()`.
20. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.
21. Commit and open PR.

**Acceptance criteria:**
- [ ] `adjust_nonresponse()` returns all rows; nonrespondent weights = 0
- [ ] Respondent weights unchanged from previous formula
- [ ] `after_stats` computed on respondent weights only
- [ ] Survey object path preserves all rows in `@data`
- [ ] `test_invariants()` updated for zero-weight `survey_nonprob`
- [ ] Diagnostics filter to `w > 0` before `.validate_weights()`
- [ ] `.validate_weights()` unchanged (still strict for calibration)
- [ ] Re-calibrating post-nonresponse data errors correctly
- [x] `surveycore (>= 0.6.1)` pinned in DESCRIPTION
- [ ] NEWS.md documents breaking change
- [ ] Roxygen updated
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained
- [ ] All new tests confirmed failing before implementation

**Notes:**
- The `for (cell in unique_cells)` loop in step 13 (line 275) still only
  adjusts respondent weights upward. The new step 14 zeroes nonrespondent
  weights AFTER the loop, so the adjustment formula is unchanged.
- `surveycore >= 0.6.1` is already installed and pinned in DESCRIPTION.
- The `summarize_weights()` zero-weight filter must apply BEFORE the grouped
  path — filter the full `data_df`, then split into groups. This ensures
  zero-weight rows don't appear as group members.

---

## Dependency Graph

```
PR 1 (utils housekeeping)
 ├─→ PR 2 (input validation)
 └─→ PR 5 (vendor delegation)

PR 3 (diagnostics cosmetic)  ← independent
PR 4 (poststratify default)  ← independent

surveycore >= 0.6.1 (done) ─→ PR 6 (nonresponse zero weights)
```

PRs 2, 3, 4, 5 are independent of each other (all depend on PR 1 or nothing).
PR 6 should be last — it depends on surveycore and benefits from PRs 3 and 5
having stabilized `diagnostics.R` and `utils.R`.

Recommended merge order: **1 → 3 → 4 → 2 → 5 → 6**

---

## Quality Gates (from spec §XIII)

All of the following must be true after all 6 PRs merge:

- [ ] All 3 vendor files deleted (PR 5)
- [ ] `survey` and `anesrake` moved to `Imports` (PR 5)
- [ ] `.calibrate_engine()` delegates to package functions for all 5 methods (PR 5)
- [ ] `adjust_nonresponse()` returns all rows with nonrespondent weights = 0 (PR 6)
- [ ] `.check_input_class()` uses `survey_base` inheritance (PR 2)
- [ ] `.check_input_class()` and `.get_history()` live in `utils.R` (PR 1)
- [ ] `%||%` redefinition removed; null checks inlined (PR 1)
- [ ] `interaction()` replaced with `paste(sep = "//")` in `summarize_weights()` (PR 3)
- [ ] `response_status` resolved via `tidyselect::eval_select()` (PR 2)
- [ ] `poststratify()` defaults to `type = "prop"` (PR 4)
- [x] `survey_nonprob` S7 validator relaxed to allow zero weights (surveycore >= 0.6.1)
- [ ] `test_invariants()` updated for zero-weight `survey_nonprob` (PR 6)
- [ ] `survey_nonprob` print says "model-assisted (SRS assumption)" (PR 3)
- [ ] `code-style.md` documents `@importFrom` exception (PR 1)
- [ ] `plans/error-messages.md` updated with new error classes (PRs 2, 5)
- [ ] Diagnostics return correct results on post-nonresponse objects (PR 6)
- [ ] NEWS.md entry documents the breaking change (PR 6)
- [x] surveywts DESCRIPTION pins `surveycore (>= 0.6.1)`
- [ ] `R CMD check`: 0 errors, 0 warnings, ≤2 notes (every PR)
- [ ] All existing tests updated; no snapshot regressions (every PR)
- [ ] 98%+ line coverage maintained (every PR)
