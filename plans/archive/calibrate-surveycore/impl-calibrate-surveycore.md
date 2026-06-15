# Implementation plan — calibrate-surveycore

**Status**: PLAN_READY
**Spec version**: 1.1
**PR range**: PR 1–2

---

## Overview

This plan delivers `@calibration` slot population and `survey_replicate`
support for `calibrate_greg()`, `calibrate_rake()`, and
`calibrate_poststrat()`. PR 1 ships the three shared helpers that all three
calibrate functions depend on. PR 2 wires those helpers into each calibrate
function and adds the replicate loop. No new exported functions; no class
changes (`@calibration` already exists on `survey_taylor`, `survey_replicate`,
and `survey_nonprob` — this spec populates it).

---

## PR map

- [x] PR 1: `feature/calibrate-surveycore-infra` — Shared infrastructure: remove `survey_replicate` error from `.check_input_class()`, add `caldata` arg to `.update_survey_weights()`, add `.build_calibration_provenance()` helper
- [x] PR 2: `feature/calibrate-surveycore-functions` — Wire `@calibration` and `survey_replicate` loop into `calibrate_greg()`, `calibrate_rake()`, `calibrate_poststrat()`

---

## PR 1: Infrastructure — shared calibration helpers

**Branch:** `feature/calibrate-surveycore-infra`
**Depends on:** none

### Tasks (TDD order)

1. Verify `plans/error-messages.md` contains `surveywts_warning_replicate_calibration_failed` — confirmed present; **no file change needed**

2. **Write failing test [RED]** in `tests/testthat/test-02-calibrate.R` — new section "Infrastructure helpers":

   a. `.check_input_class()` accepts `survey_replicate` without throwing
      `surveywts_error_replicate_not_supported`. Use `surveycore::survey_replicate`
      constructed via `create_bootstrap_weights()` or inline. Currently FAILS.

   b. `.update_survey_weights(taylor_design, wts, entry, caldata = fake_caldata)`
      sets `output@calibration` equal to `fake_caldata`. Where `fake_caldata`
      is any named list (e.g., `list(method = "linear")`). Currently FAILS
      (caldata arg does not exist).

   c. `.update_survey_weights(taylor_design, wts, entry, caldata = NULL)` leaves
      `@calibration` unchanged (it stays `NULL`). Currently passes incidentally —
      but add explicit test to pin this behavior.

3. **Write failing tests [RED]** for `.build_calibration_provenance()` (direct tests,
   acceptable per `testing-standards.md` since the function is internal and
   cannot be covered via public API before PR 2):

   a. Return value is a named list with all 12 required fields: `x_matrix`,
      `base_weights`, `g_weights`, `crossproduct_inv`, `population_totals`,
      `discrepancy`, `lambda`, `method`, `cell_factors`, `q_weights`,
      `converged`, `n_iterations`. Does NOT include `replicate_converged`
      (caller adds it). Currently FAILS (function does not exist).

   b. `g_weights == engine_result$weights / base_weights` within 1e-10.

   c. `discrepancy == population_totals - drop(t(x_matrix) %*% base_weights)`
      within 1e-10.

   d. `crossproduct_inv %*% (t(x_matrix) %*% (base_weights * q_weights * x_matrix))`
      is approximately `diag(J)` within 1e-8.

   e. For `method = "linear"`: `lambda == crossproduct_inv %*% discrepancy`
      within 1e-10. For `method = "logit"`: same formula.
      For `method = "raking"` and `"poststrat"`: `is.null(lambda)`.

   f. `converged == engine_result$convergence$converged`.

   g. `n_iterations == as.integer(engine_result$convergence$iterations)`.

   h. For `cell_factors = NULL` input: `is.null(output$cell_factors)`.

   i. Return value is visible (not `invisible()`): direct assignment
      `caldata <- .build_calibration_provenance(...)` works without explicit
      `return()`.

4. Confirm all tests fail for the right reason (not due to unrelated errors).

5. **Implement** in `R/utils.R`:

   a. `.check_input_class()` — delete the `survey_replicate` branch entirely
      (lines that throw `surveywts_error_replicate_not_supported`). The
      remaining `is_supported` check uses `S7::S7_inherits(data, survey_base)`,
      which covers `survey_replicate` since it inherits from `survey_base`.
      No other change.

   b. `.update_survey_weights()` — add `caldata = NULL` to signature; add step
      after the history append: `if (!is.null(caldata)) design@calibration <- caldata`.
      Update the internal header comment to mention the `caldata` parameter and
      `survey_replicate` as a supported input class.

6. **Implement** `.build_calibration_provenance()` in `R/calibrate-utils.R`
   (below existing helpers):

   ```
   .build_calibration_provenance(
     engine_result,
     x_matrix,
     base_weights,
     q_weights,
     population_totals,
     method,
     cell_factors = NULL
   )
   ```

   Computed fields (in order):
   - `g_weights <- engine_result$weights / base_weights`
     (NaN when `base_weights[k] == 0`; do not error on this)
   - `discrepancy <- population_totals - drop(t(x_matrix) %*% base_weights)`
   - `crossproduct_inv <- solve(t(x_matrix) %*% (base_weights * q_weights * x_matrix))`
   - `lambda`: if `method %in% c("linear", "logit")`: `crossproduct_inv %*% discrepancy`
     (valid GREG Lagrange multiplier for both; logit GREG satisfies the same
     linearization at convergence). Else: `NULL`.
   - `converged <- engine_result$convergence$converged`
   - `n_iterations <- as.integer(engine_result$convergence$iterations)`
     (`NA_integer_` for logit — engine returns `NA_integer_` from
     `survey::calibrate()`; `as.integer()` preserves it)

   Return the list with all 12 fields. Do NOT include `replicate_converged`
   (callers add it for `survey_replicate` inputs before calling
   `.update_survey_weights()`). No `invisible()`.

   **Singularity**: if `solve()` fails (singular matrix), the error propagates
   naturally — do not catch it. The engine would have already failed before
   this point for any well-posed calibration.

7. Verify all PR 1 tests pass (GREEN).

8. Run `devtools::document()`. Verify NAMESPACE and man/ are unchanged (no new
   exports; `.build_calibration_provenance` has `@noRd` and `@keywords internal`).

9. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.

10. Run `devtools::test()` — full suite passes (no regressions in
    `test-02-calibrate.R`, `test-03-rake.R`, `test-04-poststratify.R`).

11. Run `testthat::snapshot_review()` for any new `expect_snapshot()` tests;
    review and accept each new snapshot; commit `_snaps/` changes on this branch.

12. Run `covr::package_coverage()` — ≥ 98% overall.

13. Write `changelog/calibration/feature-calibrate-surveycore-pr1.md`.

### Acceptance criteria

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ unchanged (no new exports)
- [ ] `.check_input_class(survey_replicate_obj)` does not throw — GREEN
- [ ] `.update_survey_weights(…, caldata = list(…))` sets `output@calibration` — GREEN
- [ ] `.update_survey_weights(…, caldata = NULL)` leaves `@calibration` unchanged — GREEN
- [ ] `.build_calibration_provenance()` returns 12-field list with correct shapes and values — GREEN
- [ ] g_weights identity: `caldata$g_weights * caldata$base_weights ≈ engine_result$weights` (1e-10)
- [ ] crossproduct_inv identity: `C^{-1} %*% C ≈ I_J` (1e-8)
- [ ] lambda: `crossproduct_inv %*% discrepancy` for "linear"/"logit"; `NULL` for "raking"/"poststrat"
- [ ] No regressions in existing calibration test suite
- [ ] Coverage ≥ 98% overall

### Files touched — exact write surface

- `R/utils.R` — modified (`.check_input_class`, `.update_survey_weights`)
- `R/calibrate-utils.R` — modified (add `.build_calibration_provenance`)
- `tests/testthat/test-02-calibrate.R` — modified (new infra helper test section)
- `man/` — generated by `devtools::document()` (no new .Rd files expected)
- `NAMESPACE` — generated by `devtools::document()` (no change expected)
- `changelog/calibration/feature-calibrate-surveycore-pr1.md` — created

---

## PR 2: Wire `@calibration` and `survey_replicate` into all three calibrate functions

**Branch:** `feature/calibrate-surveycore-functions`
**Depends on:** PR 1

### Tasks (TDD order)

All tests are written RED before any implementation begins. Tests are grouped
by file, but all written in the same session before touching any `R/` source.

#### Write all failing tests first

**`tests/testthat/helper-test-data.R` — add survey_replicate fixture helpers:**

0. Before writing any test expansions, add three helper functions to
   `helper-test-data.R`:

   - `.make_replicate_design(df, weight_col = "base_weight", seed = 42)` —
     wraps `df` in a `survey_taylor` via `surveycore::as_survey()`, then calls
     `create_bootstrap_weights()` to produce a `survey_replicate`. Used across
     all three calibrate function test files.

   - `.make_brr_design(df, weight_col = "base_weight")` — constructs a
     `survey_replicate` via `surveycore::as_survey_replicate()` and manually
     sets some replicate weight columns to negative values (e.g., `wt * -0.1`)
     to simulate BRR replicate weights. Used in HB tests.

   - `.make_empty_cell_replicate_design(df, calibration_var, weight_col = "base_weight")` —
     constructs a `survey_replicate` where at least one replicate column
     assigns zero weight to all units in one level of `calibration_var`.
     Used in SX-1, warning path tests.

   Confirm all three helpers work before writing the test expansions.

**`test-02-calibrate.R` expansion — `calibrate_greg()` and dispatcher:**

1. Happy path — `survey_taylor` input (HT-1 through HT-16):
   - Output class is `survey_taylor`; `@calibration` is non-`NULL`; all 12
     fields present (CS-1, CS-2)
   - Each field has the correct type and shape (CS-3 through CS-12)
   - `base_weights` equals pre-calibration weight vector (HT-4, 1e-10)
   - `g_weights * base_weights == output_weights` (HT-5, GW-1, 1e-10)
   - `crossproduct_inv %*% C ≈ I_J` (CI-1, 1e-8)
   - Calibration constraint: `t(x_matrix) %*% output_weights ≈ population_totals`
     (HT-8, 1e-6)
   - `method == "linear"` (HT-9); `cell_factors` is `NULL` (HT-10);
     `q_weights` all 1 (HT-11); `converged == TRUE` (HT-12);
     `n_iterations == 1L` (HT-13); `replicate_converged` is `NULL` (HT-14)
   - History entry appended (HT-15)

2. Happy path — `model = "logit"` (HL-1 through HL-5):
   - `@calibration` populated; `method == "logit"` (HL-2);
     `n_iterations == NA_integer_` (HL-3); calibration constraint (HL-4);
     `converged == TRUE` (HL-5)

3. Happy path — `survey_nonprob` input (HN-1 through HN-4):
   - Output class `survey_nonprob`; `@calibration` populated; all 12 fields;
     `replicate_converged == NULL`
   - **`test_invariants(output)` is the first assertion in every HN block**
     (required by `testing-surveywts.md` for all blocks constructing
     `survey_nonprob` objects)

4. Happy path — `survey_replicate` input (HR-1 through HR-9):
   - Output class `survey_replicate`; `@calibration` populated
   - `replicate_converged` is a named logical of length R (HR-3, RC-1, RC-3)
   - All entries `TRUE` when all replicates converge (HR-4, RC-1)
   - Full-sample weight column calibrated (HR-5)
   - Each replicate column calibrated; constraint satisfied per replicate
     (HR-6, HR-8, 1e-6)
   - g_weights correct for full sample (HR-9, 1e-10)
   - `replicate_converged` names match `output@variables$repweights` (RC-3)

5. Happy path — negative BRR replicate weights (HB-1 through HB-3):
   - No `surveywts_error_weights_nonpositive` for `brr_design` with negative
     replicate columns (HB-1)
   - Full-sample weights calibrated normally (HB-2)

6. Numerical oracle — `skip_if_not_installed("survey")` inside each block
   (NC-1 through NC-3):
   - Full-sample weights match `survey::calibrate()` within 1e-8 (NC-1/2)
   - Each replicate column matches oracle on that replicate's starting weights
     (NC-3)

7. Warning path — `surveywts_warning_replicate_calibration_failed`:
   - One replicate fails: warning emitted once; `replicate_converged` has
     exactly one `FALSE` entry (named correctly); other entries `TRUE`
   - All replicates fail: R warnings emitted; all `FALSE`; function returns

8. Warning path — `surveywts_warning_negative_calibrated_weights` (already
   tested in existing file; verify test still passes)

9. Warning path — `surveywts_warning_control_param_ignored` (already tested;
   verify still passes)

10. Edge cases:
    - All replicates fail: full-sample weights calibrated; output returned
    - 0 replicate columns: `replicate_converged` is named logical length 0
    - Single-row `survey_taylor`: calibration proceeds normally; `@calibration`
      populated
    - `survey_nonprob`: `@calibration` populated; `replicate_converged == NULL`

11. Error paths — all 17 error classes from spec §`calibrate_greg()` errors
    table. For each: dual pattern `expect_error(class = …)` +
    `expect_snapshot(error = TRUE, …)`. Key additions over existing tests:
    - `surveywts_error_weights_not_found` with `survey_taylor` input
    - `surveywts_error_weights_not_numeric` with `survey_taylor` input
    - `surveywts_error_wt_name_not_scalar` with `survey_taylor` input
    - `surveywts_error_wt_name_empty` with `survey_taylor` input
    - `surveywts_error_variable_has_na` with `survey_taylor` input
    - `surveywts_error_margins_format_invalid` (unnamed list)
    - Regression: `calibrate_greg(survey_replicate_obj, targets)` does NOT
      throw `surveywts_error_replicate_not_supported` (REG-2)

12. g_weights numerical checks (GW-1, GW-2, GW-3):
    - `g_weights == calibrated / base` within 1e-10 (GW-1)
    - All positive when no negative calibrated weights (GW-2)
    - Can be negative when `surveywts_warning_negative_calibrated_weights`
      emitted (GW-3)

13. No `@calibration` for `data.frame` / `weighted_df` (DF-1, DF-2).

14. Dispatcher pass-through — `calibrate()` (D-1, D-2, D-3):
    - `calibrate(replicate_design, targets, method = "greg")` → `survey_replicate`
    - `calibrate(replicate_design, targets, method = "rake")` → `survey_replicate`
    - `calibrate(replicate_design, targets_df, method = "poststrat")` →
      `survey_replicate`

**`test-03-rake.R` expansion — `calibrate_rake()`:**

15. Happy path — `survey_taylor` input (RT-1 through RT-9):
    - `@calibration` populated; `method == "raking"` (RT-2); `lambda == NULL`
      (RT-3); `cell_factors == NULL` (RT-4); CF-3
    - `x_matrix` uses treatment contrasts: for two-variable raking with levels
      (2, 3), J = 4; `colnames` includes `"(Intercept)"` (RT-5)
    - Calibration constraint (RT-6, 1e-6); g_weights (RT-7, 1e-10)
    - `crossproduct_inv` is J × J (RT-8); `base_weights` correct (RT-9, 1e-10)

16. Happy path — `survey_replicate` input (RR-1, RR-2):
    - Replicate loop runs for both `algorithm = "anesrake"` and `"survey"`
    - Calibration constraint per replicate (1e-6)

17. Numerical oracle (RNC-1 through RNC-3, `skip_if_not_installed("survey")`):
    - Full-sample against `survey::rake()` (1e-8); replicate full-sample (1e-8);
      per-replicate (1e-8)

18. Warning path — `surveywts_warning_replicate_calibration_failed` for raking
    non-convergence within a replicate.

19. Error paths — six shared new paths (dual pattern, in `test-03-rake.R`):
    - `surveywts_error_weights_not_found` with `survey_taylor` input
    - `surveywts_error_weights_not_numeric` with `survey_taylor` input
    - `surveywts_error_wt_name_not_scalar` with `survey_taylor` input
    - `surveywts_error_wt_name_empty` with `survey_taylor` input
    - `surveywts_error_variable_has_na` with `survey_taylor` input
    - `surveywts_error_margins_format_invalid` (unnamed list)
    - `surveywts_error_cap_not_supported_survey` (already tested; verify still passes)

**`test-04-poststratify.R` expansion — `calibrate_poststrat()`:**

20. Happy path — `survey_taylor` input (PT-1 through PT-8):
    - `@calibration` populated; `method == "poststrat"` (PT-2);
      `lambda == NULL` (PT-3)
    - `cell_factors` is a named numeric (PT-4); values correct (PT-5, CF-1,
      CF-2, 1e-10)
    - `x_matrix` is cell-indicator matrix: n × C, each row sums to 1 (PT-6)
    - Calibration constraint (PT-7, 1e-6); g_weights (PT-8, 1e-10)

21. Happy path — `survey_replicate` input (PR-1 through PR-3):
    - Replicate loop applies post-stratification per replicate
    - `cell_factors` from full-sample calibration (PR-3)

22. Numerical oracle (PNC-1 through PNC-3, `skip_if_not_installed("survey")`):
    - Full-sample against `survey::postStratify()` (1e-8); replicate (1e-8);
      per-replicate (1e-8)

23. Cell-factor cross-cutting (CF-1, CF-2):
    - `cell_factors` names match cell labels using `"//"` separator
    - Values: `N_c / N_hat_c` within 1e-10

24. Singular x_matrix / empty-cell scenarios (SX-1, SX-2):
    - `empty_cell_replicate_design` → `surveywts_warning_replicate_calibration_failed`
    - Full-sample empty stratum still errors with `surveywts_error_empty_stratum` (SX-2)

25. Warning path — `surveywts_warning_replicate_calibration_failed` for empty
    post-stratification cell in a replicate.

26. Error paths (dual pattern, in `test-04-poststratify.R`) — post-strat-specific
    plus the six shared new paths:
    - `surveywts_error_no_strata_variables`
    - `surveywts_error_population_cell_duplicate`
    - `surveywts_error_population_cell_missing`
    - `surveywts_error_population_cell_not_in_data`
    - `surveywts_error_empty_stratum`
    - `surveywts_error_weights_not_found` with `survey_taylor` input
    - `surveywts_error_weights_not_numeric` with `survey_taylor` input
    - `surveywts_error_wt_name_not_scalar` with `survey_taylor` input
    - `surveywts_error_wt_name_empty` with `survey_taylor` input
    - `surveywts_error_variable_has_na` with `survey_taylor` input
    - `surveywts_error_margins_format_invalid` (non-data.frame)

27. No `@calibration` for `data.frame` input (DF-3).

28. Confirm ALL new tests fail for the right reason (not syntax errors).

---

#### Implement changes (after all tests are RED)

**29. Implement `calibrate_greg.R`** — establishes the replicate loop pattern:

   a. **Update `@param data` roxygen** — replace "survey_replicate -> error"
      with "survey_replicate: Supported. Full-sample and each replicate column
      are calibrated independently. See `@calibration$replicate_converged`."

      **Update `@return` roxygen** — add a note for the `survey_replicate`
      output: "For `survey_replicate` input: `@calibration$replicate_converged`
      is a named logical vector (one entry per replicate). When some replicates
      fail calibration, the returned object has uncalibrated weights for those
      replicates; variance estimates will mix calibrated and uncalibrated draws.
      Inspect `output@calibration$replicate_converged` before computing variance."

   b. **Build `x_matrix` after engine call** — immediately after
      `engine_result <- .calibrate_engine(…)` in the survey-object path:

      ```r
      # Build x_matrix mirroring the engine's internal model.matrix call.
      # Filter to variables with 2+ levels (same logic as the engine at R/utils.R ~L815).
      fml_vars <- variable_names[vapply(
        vars_spec, function(v) length(v$targets) >= 2L, logical(1)
      )]
      fml_for_mm <- stats::as.formula(paste("~", paste(fml_vars, collapse = " + ")))
      x_matrix <- stats::model.matrix(fml_for_mm, data = plain_df)
      ```

      Build `population_totals_vec` (named numeric, same column order as `x_matrix`):
      - `"(Intercept)"` column: `sum(population_counts[[variable_names[[1L]]]])` (= N)
      - Each contrast column `paste0(v, lev)` (2nd through last level):
        `population_counts[[v]][[lev]]`
      This mirrors the engine's `pop_totals` construction at `R/utils.R ~L831–845`.

   c. **Call `.build_calibration_provenance()`** (survey-object path only):
      ```r
      n <- nrow(plain_df)
      caldata <- .build_calibration_provenance(
        engine_result      = engine_result,
        x_matrix           = x_matrix,
        base_weights       = weights_vec,
        q_weights          = rep(1, n),
        population_totals  = population_totals_vec,
        method             = model,    # "linear" or "logit"
        cell_factors       = NULL
      )
      ```

   d. **For `survey_taylor` / `survey_nonprob` path**: call
      `.update_survey_weights(data, new_weights, history_entry, caldata = caldata)`.
      Replace the existing call that has no `caldata` argument.

   e. **For `survey_replicate` path** (new branch — add after checking class):

      ```r
      # Initialize replicate_converged (all TRUE)
      repweight_cols <- design@variables$repweights
      caldata$replicate_converged <- stats::setNames(
        rep(TRUE, length(repweight_cols)), repweight_cols
      )

      # Replicate loop
      for (repweights_col in repweight_cols) {
        rep_wt <- design@data[[repweights_col]]
        # Do NOT validate positivity of rep_wt (negative BRR weights are valid)
        tryCatch(
          {
            rep_result <- .calibrate_engine(
              data_df           = plain_df,
              weights_vec       = rep_wt,
              calibration_spec  = calibration_spec,   # same spec as full-sample
              method            = model,
              control           = control
            )
            design@data[[repweights_col]] <- rep_result$weights
          },
          error = function(e) {
            caldata$replicate_converged[[repweights_col]] <<- FALSE
            cli::cli_warn(
              c(
                "!" = "Calibration failed for replicate column {.field {repweights_col}}.",
                "i" = "Reason: {conditionMessage(e)}",
                "i" = paste0(
                  "This replicate's calibrated weights are not updated; ",
                  "base weights are retained for this column."
                )
              ),
              class = "surveywts_warning_replicate_calibration_failed"
            )
          }
        )
      }

      # Single .update_survey_weights() call writes full-sample weight,
      # appends history, and sets @calibration (including replicate_converged).
      .update_survey_weights(design, new_weights, history_entry, caldata = caldata)
      ```

      **Note**: The replicate loop uses `<<-` to modify `caldata` in the enclosing
      scope. Alternatively, collect failed columns in a vector outside the loop and
      assign after — either pattern is acceptable; avoid `<<-` if it adds confusion.
      Preferred: pre-initialize `caldata$replicate_converged`, then directly index
      inside the error handler using `<<-`.

   f. Verify `calibrate_greg` tests are GREEN.

**30. Implement `calibrate_rake.R`** — same pattern, raking-specific provenance:

   a. **Update `@param data` roxygen** (same as greg).
      **Update `@return` roxygen** — same partial-calibration caveat as greg.

   b. **Build x_matrix** after the engine call (survey-object path only):
      ```r
      fml_for_mm <- stats::as.formula(paste("~", paste(variable_names, collapse = " + ")))
      x_matrix <- stats::model.matrix(fml_for_mm, data = plain_df)
      ```
      Treatment contrasts (default in R). J = 1 + Σ(m_j − 1).

   c. **Build `population_totals_vec`** (count scale, same column order as x_matrix):
      - `"(Intercept)"` column: `sum(weights_vec)` (≈ N — the sum of design weights
        equals the population total when type = "prop"; for type = "count", use
        `sum(population_counts[[variable_names[[1L]]]])`)
      - Each contrast column `paste0(v, lev)` (2nd through last level):
        `population_counts[[v]][[lev]]`

      **Critical**: the intercept total must match what the engine uses. For raking,
      the engine uses IPF (`survey::rake`) which does NOT use model.matrix internally.
      The population_totals_vec for provenance purposes uses treatment contrasts.
      The intercept column total = N = sum of design weights = sum(weights_vec) when
      type = "prop". Verify this matches the constraint: `t(x_matrix) %*% calibrated_weights ≈ population_totals_vec`.

   d. **Call `.build_calibration_provenance()`**:
      ```r
      n <- nrow(plain_df)
      caldata <- .build_calibration_provenance(
        engine_result     = engine_result,
        x_matrix          = x_matrix,
        base_weights      = weights_vec,
        q_weights         = rep(1, n),
        population_totals = population_totals_vec,
        method            = "raking",
        cell_factors      = NULL
      )
      ```
      `lambda` will be `NULL` (method = "raking" → `.build_calibration_provenance()`
      stores NULL).

   e. **Replicate loop** — identical structure to `calibrate_greg.R` step 29e,
      substituting the raking engine call (same `calibration_spec`).

   f. Verify `calibrate_rake` tests are GREEN.

**31. Implement `calibrate_poststrat.R`** — same pattern, poststrat-specific provenance:

   a. **Update `@param data` roxygen** (same as greg).
      **Update `@return` roxygen** — same partial-calibration caveat as greg.

   b. **Build `x_matrix`** (cell-indicator matrix, n × C):
      After identifying unique cells and matching units to cells (existing logic),
      build a matrix where row k has a 1 in column c if unit k belongs to cell c,
      0 elsewhere. Column names should match the cell label strings used in
      `cell_factors`.

   c. **Build `cell_factors`** (named numeric, length C):
      For each cell c: `N_c / N_hat_c` where `N_hat_c = sum(base_weights[cell_c_indices])`.
      Names use the existing `"//"` key format already in the function.

   d. **Build `population_totals_vec`** (count-scale targets per cell, in the same
      column order as x_matrix): `N_c` for each cell c (the target count, same
      ordering as x_matrix columns).

   e. **Call `.build_calibration_provenance()`**:
      ```r
      n <- nrow(plain_df)
      caldata <- .build_calibration_provenance(
        engine_result     = engine_result,
        x_matrix          = x_matrix,
        base_weights      = weights_vec,
        q_weights         = rep(1, n),
        population_totals = population_totals_vec,
        method            = "poststrat",
        cell_factors      = cell_factors
      )
      ```
      `lambda` will be `NULL` (method = "poststrat").

   f. **Replicate loop** — same structure. For a replicate whose effective
      sample creates a zero-weighted cell, the engine will throw. Catch this
      with `tryCatch`, set `replicate_converged[[col]] <- FALSE`, emit
      `surveywts_warning_replicate_calibration_failed`, continue.

   g. Verify `calibrate_poststrat` tests are GREEN.

**32.** Run `devtools::document()` — update roxygen for all three functions.
Verify `@param data` and `@return` changes are reflected in `man/`.

**33.** Run `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.

**34.** Run full `devtools::test()` — entire suite passes.

**35.** Run `testthat::snapshot_review()` for all new `expect_snapshot()` tests;
review and accept each new snapshot; commit `tests/testthat/_snaps/` changes on
this branch.

**36.** Run `covr::package_coverage()` — ≥ 98% overall.

**37.** Write `changelog/calibration/feature-calibrate-surveycore-pr2.md`.

### Acceptance criteria

- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; `man/calibrate_greg.Rd`, `man/calibrate_rake.Rd`,
      `man/calibrate_poststrat.Rd` updated: `@param data` includes `survey_replicate`
      support; `@return` includes partial-calibration caveat for replicate outputs
- [ ] Changelog entry written and committed on this branch
- [ ] HT-1 through HT-16: `survey_taylor` → `calibrate_greg()` GREEN
- [ ] HL-1 through HL-5: `model = "logit"` GREEN; `n_iterations == NA_integer_`
- [ ] HN-1 through HN-4: `survey_nonprob` GREEN; `test_invariants(output)` is first assertion in each HN block
- [ ] HR-1 through HR-9: `survey_replicate` → `calibrate_greg()` GREEN
- [ ] HB-1 through HB-3: Negative BRR weights accepted GREEN
- [ ] RT-1 through RT-9: `survey_taylor` → `calibrate_rake()` GREEN
- [ ] RR-1, RR-2: `survey_replicate` → `calibrate_rake()` GREEN
- [ ] PT-1 through PT-8: `survey_taylor` → `calibrate_poststrat()` GREEN
- [ ] PR-1 through PR-3: `survey_replicate` → `calibrate_poststrat()` GREEN
- [ ] CS-1 through CS-12: `@calibration` structure tests GREEN
- [ ] GW-1/2/3: g_weights numerical GREEN
- [ ] CI-1: crossproduct_inv identity GREEN (1e-8)
- [ ] CF-1, CF-2: `cell_factors` values and names GREEN (1e-10)
- [ ] CF-3: `cell_factors == NULL` for GREG and raking GREEN
- [ ] NC-1/2/3, RNC-1/2/3, PNC-1/2/3: oracle correctness GREEN (1e-8)
- [ ] RC-1/2/3/4: `replicate_converged` field tests GREEN
- [ ] DF-1/2/3: no `@calibration` on `data.frame`/`weighted_df` outputs GREEN
- [ ] D-1/2/3: dispatcher pass-through GREEN
- [ ] REG-2: `calibrate_greg(survey_replicate_obj, …)` does NOT throw
      `surveywts_error_replicate_not_supported` GREEN
- [ ] All 17 error-path tests GREEN (dual pattern)
- [ ] `surveywts_warning_replicate_calibration_failed` warning tests GREEN
- [ ] Edge cases (all replicates fail; 0 replicates) GREEN
- [ ] SX-1, SX-2: singular / empty-cell scenarios GREEN
- [ ] Coverage ≥ 98% overall

### Files touched — exact write surface

- `R/calibrate_greg.R` — modified (`@param data`, `@return`, x_matrix build, `.build_calibration_provenance()` call, replicate loop)
- `R/calibrate_rake.R` — modified (same pattern)
- `R/calibrate_poststrat.R` — modified (same pattern)
- `tests/testthat/helper-test-data.R` — modified (add `.make_replicate_design()`, `.make_brr_design()`, `.make_empty_cell_replicate_design()`)
- `tests/testthat/test-02-calibrate.R` — modified (large expansion: HT/HL/HN/HR/HB/NC/CS/GW/CI/DF/D/REG tests + all new error/warning paths)
- `tests/testthat/test-03-rake.R` — modified (RT/RR/RNC tests + 6 shared new error paths)
- `tests/testthat/test-04-poststratify.R` — modified (PT/PR/PNC/CF/SX tests + 6 shared new error paths)
- `tests/testthat/_snaps/` — new snapshot files created by `expect_snapshot()` calls
- `man/calibrate_greg.Rd` — generated by `devtools::document()`
- `man/calibrate_rake.Rd` — generated by `devtools::document()`
- `man/calibrate_poststrat.Rd` — generated by `devtools::document()`
- `NAMESPACE` — generated (no change expected)
- `changelog/calibration/feature-calibrate-surveycore-pr2.md` — created

---

## Implementation notes (cross-PR)

### x_matrix construction — mirror engine logic exactly

The engine at `R/utils.R ~L812–845` builds:
```r
fml_vars <- var_names[vapply(vars_spec, function(v) length(v$targets) >= 2L, logical(1))]
fml <- stats::as.formula(paste("~", paste(fml_vars, collapse = " + ")))
mm <- stats::model.matrix(fml, data = data_df)
```
The caller must use the same `fml_vars` filter (exclude single-level variables)
so that the x_matrix passed to `.build_calibration_provenance()` matches what
`survey::calibrate()` actually used. Mismatch would make the crossproduct_inv
identity check fail.

### population_totals_vec alignment

`population_totals_vec` must be aligned with `colnames(x_matrix)`. Use
`stats::setNames(numeric(ncol(x_matrix)), colnames(x_matrix))` and fill in:
- `"(Intercept)"` → N (same value the engine uses for the intercept constraint)
- `paste0(v, lev)` for each non-reference level → `population_counts[[v]][[lev]]`

### survey_replicate branch placement

The `survey_replicate` input follows the existing `survey_taylor`/`survey_nonprob`
path up through the engine call and caldata construction. The replicate loop is
a new else-if branch: check `S7::S7_inherits(data, surveycore::survey_replicate)`
AFTER the existing survey-object path. Alternatively, add the replicate loop as
a post-processing step within the survey-object branch (after full-sample
calibration) by testing for `survey_replicate` class.

### n_iterations for logit

`as.integer(NA_integer_)` is `NA_integer_` — this is correct. When storing
`n_iterations`, do `n_iterations = as.integer(engine_result$convergence$iterations)`
regardless of the model; for logit, the engine returns `NA_integer_` from the
convergence list (confirmed at `R/utils.L929`).

### replicate_converged warning scope

The warning must be emitted ONCE per failed replicate column, not once per
error type. The `tryCatch` error handler emits the warning and continues;
`.calibrate_engine()` may throw any error class (convergence failure, singular
matrix, empty cell, etc.) — all are caught and converted to this warning.

### caldata$replicate_converged mutation

Use `<<-` assignment from within the `tryCatch` error handler to mutate
`caldata$replicate_converged` in the enclosing scope. Alternatively, use a
separate `failed_cols` vector outside the loop, assign `FALSE` entries after
the loop completes. The latter avoids `<<-` and may be cleaner:
```r
failed_cols <- character(0)
for (repweights_col in repweight_cols) {
  tryCatch(
    { ... },
    error = function(e) {
      failed_cols <<- c(failed_cols, repweights_col)
      cli::cli_warn(...)
    }
  )
}
caldata$replicate_converged[failed_cols] <- FALSE
```

### Quality gate verification

After PR 2, verify the spec's quality gates (§Quality gates):
1. Every `survey_taylor` output: `!is.null(output@calibration)` ✓ (test CS-1)
2. Every `survey_nonprob` output: same ✓ (test HN-1, HN-2)
3. Every `survey_replicate` output: `replicate_converged` present, length matches ✓ (test RC-3)
4. Every replicate column in `@variables$repweights` overwritten ✓ (test HR-6)
5. Full-sample weight column calibrated regardless of replicate failures ✓ (test HR-5)
6. g_weights identity ✓ (test GW-1, 1e-10)
7. Calibration constraint ✓ (tests HT-8, HR-7, HR-8, 1e-6)
8. `data.frame`/`weighted_df`: `@calibration` not set ✓ (tests DF-1/2/3)
