# Implementation Plan — Nonresponse Phase

**Spec:** `plans/spec-nonresponse.md` (v0.4, approved 2026-05-12)
**ID:** `nonresponse`
**Status:** Ready for implementation

---

## Overview

This plan delivers four new capabilities in the Nonresponse phase: sample-based
calibration via `calibrate_to_survey()` and `calibrate_to_estimate()` (delegating
to `svrep`); a general weight redistribution primitive `redistribute_weights()`; and
the `propensity-cell` method for `adjust_nonresponse()`. All deliverables are in
the spec (§I). Implementation proceeds in four PRs: shared infrastructure first,
then sample-calibration functions, then the two nonresponse extensions.

---

## PR Map

- [x] PR 1: `feature/nonresponse-infrastructure` — Shared helpers, svrep dependency, and error class registry
- [x] PR 2: `feature/sample-calibration` — `calibrate_to_survey()` and `calibrate_to_estimate()`
- [ ] PR 3: `feature/redistribute-weights` — `redistribute_weights()` primitive
- [ ] PR 4: `feature/propensity-cell` — `adjust_nonresponse(method = "propensity-cell")`

---

## PR 1: Infrastructure

**Branch:** `feature/nonresponse-infrastructure`
**Depends on:** none

**Files:**
- `DESCRIPTION` — add `svrep` to `Imports` with minimum version pin
- `plans/error-messages.md` — add all new error/warning classes from §X of the spec
- `R/utils.R` — add `.to_svyrep_design()`, `.validate_formula_variables()`, `.validate_formula()`
- `tests/testthat/helper-test-data.R` — add `make_replicate_design(n_replicates = 50, seed = 42)`
- `changelog/nonresponse/feature-infrastructure.md` — new changelog entry

**Task sequence:**

1. Add `svrep` to `Imports` in `DESCRIPTION`. Use `pak::pkg_deps("svrep")` to determine
   the minimum version to pin (use the current CRAN release version). Format:
   `svrep (>= X.Y.Z)`.

2. Add all new error and warning classes to `plans/error-messages.md`:

   - New section `### calibrate_to_survey() / calibrate_to_estimate()` with:
     `surveywts_error_primary_not_replicate`, `surveywts_error_control_not_replicate`,
     `surveywts_error_replicate_count_mismatch`, `surveywts_error_formula_variable_not_found`,
     `surveywts_error_formula_invalid`, `surveywts_error_estimate_not_named`,
     `surveywts_error_estimate_has_na`, `surveywts_error_estimate_length_mismatch`,
     `surveywts_error_estimate_names_mismatch`, `surveywts_error_vcov_dimension_mismatch`,
     `surveywts_error_vcov_has_na`, `surveywts_error_vcov_not_symmetric`,
     `surveywts_error_vcov_cholesky_failed`
     (note: `surveywts_error_calibration_not_converged` already exists — mark as "reuse")

   - New section `### redistribute_weights()` with:
     `surveywts_error_reduce_if_not_found`, `surveywts_error_increase_if_not_found`,
     `surveywts_error_reduce_if_not_binary`, `surveywts_error_increase_if_not_binary`,
     `surveywts_error_reduce_if_has_na`, `surveywts_error_increase_if_has_na`,
     `surveywts_error_indicators_overlap`, `surveywts_error_no_recipients_in_group`,
     `surveywts_error_wt_name_conflict`

   - New section `### adjust_nonresponse() — propensity-cell` with:
     `surveywts_error_formula_required_for_propensity_cell`,
     `surveywts_error_formula_variable_has_na`, `surveywts_error_n_cells_invalid`,
     `surveywts_error_no_respondents_in_propensity_cell`
     (note: `surveywts_error_formula_invalid` and `surveywts_error_formula_variable_not_found`
     are shared — cross-reference from the calibration section)

   - New warnings:
     `surveywts_warning_replicate_scheme_mismatch` (calibration),
     `surveywts_warning_by_ignored_for_propensity_cell` (nonresponse)
     (note: `surveywts_warning_negative_calibrated_weights` and
     `surveywts_warning_class_near_empty` already exist — mark as "reuse" in notes)

3. Add `.validate_formula()` to `R/utils.R`:
   - Signature: `(formula)`
   - Check: `inherits(formula, "formula") && length(formula) == 2L`
     (two-element formula = one-sided: `~ RHS`; three-element = two-sided: `LHS ~ RHS`)
   - On failure: `cli_abort(class = "surveywts_error_formula_invalid")`
   - Returns `invisible(TRUE)` on success
   - No roxygen (internal helper)

4. Add `.validate_formula_variables()` to `R/utils.R`:
   - Signature: `(formula, data, design_label)`
   - Extract vars: `all.vars(formula)`
   - For the first missing variable: `cli_abort(class = "surveywts_error_formula_variable_not_found")`
     Include `design_label` in the message (e.g., `"Variable {.field {var}} not found in {design_label}."`)
   - Returns `invisible(TRUE)` on success
   - No roxygen (internal helper)

5. Add `.to_svyrep_design()` to `R/utils.R`:
   - Signature: `(design)` where `design` is a `survey_replicate`
   - Extract from `design@variables`: `weights`, `repweights`, `type`, `scale`, `rscales`
   - Call `survey::svrepdesign()` with:
     - `data = design@data`
     - `weights = design@data[[design@variables$weights]]` (as formula or vector, per svrepdesign API)
     - `repweights = design@data[design@variables$repweights]` (data frame of replicate columns)
     - `type = design@variables$type`
     - `scale = design@variables$scale`
     - `rscales = design@variables$rscales`
     - `combined.weights = FALSE` — surveywts stores replicate weights as scale factors
       (not combined sampling weights), matching the behaviour of `svrep::as_bootstrap_design()`
       and `survey::as.svrepdesign()` which both set `combined.weights = FALSE`. The
       `survey::svrepdesign()` default is `TRUE`; omitting this argument causes it to
       misinterpret scale factors as full sampling weights and produces silently wrong
       calibration results.
     - `mse = design@variables$mse` if present, else `TRUE`
   - Returns the `svyrep.design` object
   - No roxygen (internal helper)
   - **Note on `weights` argument:** `survey::svrepdesign()` accepts `weights` as a
     formula (e.g., `~wt_col`) or a numeric vector. Use the vector form for simplicity:
     `weights = ~1` is not correct — pass the actual weight column as a numeric vector.
     Check the `survey::svrepdesign()` signature before implementing.

6. Add `make_replicate_design()` to `tests/testthat/helper-test-data.R`:
   - Signature: `make_replicate_design(n_replicates = 50, seed = 42)`
   - Call `make_surveywts_data(n = 200, seed = seed)` to get a plain `data.frame`
   - Build a `survey_taylor` via `survey_taylor(data = df, variables = list(weights = "base_weight"))`
   - Call `create_bootstrap_weights(design, n_replicates = n_replicates)` to get a `survey_replicate`
   - Return the `survey_replicate` object
   - No roxygen (test helper)
   - This generator is used by PR 2 (and later PRs) whenever a `survey_replicate` is needed in tests

7. Update `R/utils.R` header comment to list the three new helpers.

7. Run `devtools::check()` — confirm 0 errors, 0 warnings, ≤2 notes.

8. Run `devtools::document()` — NAMESPACE must not change (no roxygen changes).

9. Commit: `feat(utils): add formula and svyrep helpers for nonresponse phase`
   Open PR to `develop`.

**Acceptance criteria:**
- [ ] All new error/warning classes listed in `plans/error-messages.md`
- [ ] `svrep` present in `DESCRIPTION` Imports with version pin
- [ ] `.validate_formula()`, `.validate_formula_variables()`, `.to_svyrep_design()` present in `R/utils.R`
- [ ] `make_replicate_design()` added to `tests/testthat/helper-test-data.R`
- [ ] Changelog entry committed at `changelog/nonresponse/feature-infrastructure.md`
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::document()` run; NAMESPACE unchanged
- [ ] Test coverage ≥ 95% (checked via `covr::package_coverage()` before opening PR)

**Notes:**
- No test file changes in this PR — all three helpers are tested indirectly by
  the functions that use them (PRs 2–4). Per `testing-surveywts.md`, `utils.R`
  has no direct test file.
- The `survey::svrepdesign()` API may differ between survey package versions;
  verify against the installed version in this repo before writing the implementation.

---

## PR 2: `calibrate_to_survey()` and `calibrate_to_estimate()`

**Branch:** `feature/sample-calibration`
**Depends on:** PR 1 (merged to `develop`)

**Files (TDD order — tests first):**
- `tests/testthat/test-sample-calibration.R` — new; all test categories for both functions
- `R/sample-calibration.R` — new; both exported functions
- `.claude/rules/surveywts-conventions.md` — add `sample-calibration` to `@family` table
- `changelog/nonresponse/feature-sample-calibration.md` — new changelog entry

**Task sequence:**

1. Write `tests/testthat/test-sample-calibration.R` with all test blocks below.
   Run `devtools::test(filter = "sample-calibration")` after each section to confirm
   tests are **red** (failing) before writing implementation.

2. **Test: `calibrate_to_survey()` happy path**
   ```
   test_that("calibrate_to_survey() returns survey_replicate with updated weights")
   test_that("calibrate_to_survey() appends history entry operation = 'sample_calibration_replicate'")
   test_that("test_invariants() passes on calibrate_to_survey() result")
   ```
   Use two `make_surveywts_data()` datasets to build two matching `survey_replicate` objects.

3. **Test: `calibrate_to_survey()` numerical correctness**
   ```
   test_that("calibrate_to_survey() full-sample weights satisfy calibration constraints within 1e-8")
   test_that("calibrate_to_survey() weight total aligns with control survey total, not primary total")
   ```
   Verify `abs(sum(w_new * X) - sum(w_control * X)) < 1e-8` for each formula variable.
   Verify `abs(sum(w_new) - sum(w_control)) < 1e-8`.

4. **Test: `calibrate_to_survey()` error paths** (dual pattern for each)
   ```
   test_that("calibrate_to_survey() errors when primary_design is not survey_replicate")
   test_that("calibrate_to_survey() errors when control_design is not survey_replicate")
   test_that("calibrate_to_survey() errors on replicate count mismatch")
   test_that("calibrate_to_survey() errors when formula variable missing from primary_design")
   test_that("calibrate_to_survey() errors when formula variable missing from control_design")
   test_that("calibrate_to_survey() errors when formula is not a formula object")
   test_that("calibrate_to_survey() errors when calibration does not converge")
   ```

5. **Test: `calibrate_to_survey()` warning paths**
   ```
   test_that("calibrate_to_survey() warns on replicate scheme mismatch and still calibrates")
   test_that("calibrate_to_survey() warns on negative full-sample weights from linear calibration")
   ```
   For scheme mismatch: create two `survey_replicate` objects with different `type` values
   (e.g., `"bootstrap"` vs `"JK1"`). Confirm warning fires AND result passes
   `test_invariants()`.
   For negative weights: construct control totals that force negative weights under
   `method = "linear"`. Use `expect_warning(..., class = "surveywts_warning_negative_calibrated_weights")`.

6. **Test: `calibrate_to_survey()` edge cases**
   ```
   test_that("calibrate_to_survey() works with a single formula variable")
   test_that("calibrate_to_survey() works with formula interaction terms (age * sex)")
   test_that("calibrate_to_survey() works with method = 'linear'")
   test_that("calibrate_to_survey() works with method = 'logit' and finite bounds")
   test_that("calibrate_to_survey() works with n_rep = 1")
   ```

7. **Test: `calibrate_to_estimate()` happy path**
   ```
   test_that("calibrate_to_estimate() returns survey_replicate with updated weights")
   test_that("calibrate_to_estimate() appends history entry operation = 'sample_calibration_estimate'")
   test_that("test_invariants() passes on calibrate_to_estimate() result")
   ```

8. **Test: `calibrate_to_estimate()` numerical correctness**
   ```
   test_that("calibrate_to_estimate() full-sample weights satisfy calibration constraints within 1e-8")
   ```
   Verify `abs(sum(w_new * X) - estimate[[col]]) < 1e-8` for each calibration variable.

9. **Test: `calibrate_to_estimate()` error paths** (dual pattern for each)
   ```
   test_that("calibrate_to_estimate() errors when design is not survey_replicate")
   test_that("calibrate_to_estimate() errors when formula variable missing from design")
   test_that("calibrate_to_estimate() errors when formula is not a formula object")
   test_that("calibrate_to_estimate() errors when estimate is not named")
   test_that("calibrate_to_estimate() errors when estimate has NA values")
   test_that("calibrate_to_estimate() errors when estimate length does not match model matrix")
   test_that("calibrate_to_estimate() errors when estimate names do not match model matrix")
   test_that("calibrate_to_estimate() errors when vcov_estimate has wrong dimensions")
   test_that("calibrate_to_estimate() errors when vcov_estimate has NA values")
   test_that("calibrate_to_estimate() errors when vcov_estimate is not symmetric")
   test_that("calibrate_to_estimate() errors when vcov_estimate is not positive definite")
   test_that("calibrate_to_estimate() errors when calibration does not converge")
   ```

10. **Test: `calibrate_to_estimate()` warning paths**
    ```
    test_that("calibrate_to_estimate() warns on negative full-sample weights from linear calibration")
    ```

11. **Test: `calibrate_to_estimate()` edge cases**
    ```
    test_that("calibrate_to_estimate() works with identity covariance (zero uncertainty)")
    test_that("calibrate_to_estimate() works with a single calibration variable")
    test_that("calibrate_to_estimate() works with method = 'linear'")
    test_that("calibrate_to_estimate() works with method = 'logit' and finite bounds")
    ```

12. Run `devtools::test(filter = "sample-calibration")` — confirm all tests **red**.

13. Create `R/sample-calibration.R`:
    - File header comment (same style as other source files)
    - `calibrate_to_survey()`:
      - Validate `primary_design` (S7_inherits survey_replicate → `surveywts_error_primary_not_replicate`)
      - Validate `control_design` (S7_inherits survey_replicate → `surveywts_error_control_not_replicate`)
      - Validate replicate count match (`length(@variables$repweights)` both sides)
      - Warn if `@variables$type` mismatch (`surveywts_warning_replicate_scheme_mismatch`)
      - Call `.validate_formula(formula)` → `surveywts_error_formula_invalid`
      - Call `.validate_formula_variables(formula, primary_design@data, "primary_design")`
      - Call `.validate_formula_variables(formula, control_design@data, "control_design")`
      - Merge `control` with defaults: `list(maxit = 50, epsilon = 1e-7)`
      - Derive `calfun`: `survey::cal.raking` / `survey::cal.linear` / `survey::cal.logit`
        from `method` (use `match.arg(method)` at top)
      - Convert both designs to `svyrep.design` via `.to_svyrep_design()`
      - Call `svrep::calibrate_to_sample()` with all required arguments (per §III Rule 5,
        including `bounds`)
      - Catch calibration errors and re-throw as `surveywts_error_calibration_not_converged`
      - Extract updated full-sample weights via `weights(calibrated, type = "sampling")`;
        check for negatives → `surveywts_warning_negative_calibrated_weights`
      - Extract updated replicate weights via `weights(calibrated, type = "analysis")`
        (returns a matrix; columns correspond to replicates)
      - Write full-sample weights back into `primary_design@data` by the column named
        in `primary_design@variables$weights`; write replicate weight columns back by
        the names in `primary_design@variables$repweights`
      - Verify these field accessors against the installed `survey`/`svrep` versions
        before finalizing (run `str(weights(calibrated, type = "sampling"))` on a toy
        example to confirm shape)
      - Append history entry via `.make_history_entry()`:
        `operation = "sample_calibration_replicate"`, params include formula, method,
        n_replicates, control_design class, n_replicates_control
      - Return `primary_design`
    - `calibrate_to_estimate()`:
      - Validate `design` (S7_inherits survey_replicate → `surveywts_error_primary_not_replicate`)
      - Call `.validate_formula(formula)`
      - Call `.validate_formula_variables(formula, design@data, "design")`
      - Compute `model_matrix_cols <- colnames(model.matrix(formula, design@data))[-1]`
        (drop intercept)
      - Validate `estimate`: named check, NA check, length check, names check
      - Validate `vcov_estimate`: NA check first (`anyNA()`), dimension check, symmetry check
        (tolerance `1e-8`), Cholesky check (catch error → `surveywts_error_vcov_cholesky_failed`)
      - Merge `control` with defaults
      - Derive `calfun` from `method`
      - Convert design to `svyrep.design` via `.to_svyrep_design()`
      - Call `svrep::calibrate_to_estimate()` with all required arguments (including `bounds`)
      - Catch calibration errors; check for negative weights
      - Write updated weights back; append history entry:
        `operation = "sample_calibration_estimate"`
      - Return `design`
    - Roxygen for both functions:
      - `@family sample-calibration`
      - `@export`
      - `@return`, `@param` for all arguments
      - `@note` for `calibrate_to_estimate()` re multivariate normality assumption (§IV)
      - `@details` for logit bounds limitation (§III argument table note)

14. Run `devtools::test(filter = "sample-calibration")` — confirm all tests **green**.

15. Run `devtools::document()` — confirm NAMESPACE picks up both exports.

16. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.

17. Update `.claude/rules/surveywts-conventions.md`: add a `sample-calibration` row to the
    `@family` table with `calibrate_to_survey()` and `calibrate_to_estimate()`.

18. Commit: `feat(calibration): implement calibrate_to_survey() and calibrate_to_estimate()`
    Open PR to `develop`.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Happy path, numerical correctness, error paths, warning paths, edge cases all present
- [ ] `test_invariants()` called in every happy-path test block
- [ ] Dual pattern (`expect_error(class=)` + `expect_snapshot(error=TRUE)`) for all error paths
- [ ] Calibration constraints verified within 1e-8 for both functions
- [ ] Weight total aligns with control survey total (not primary) for `calibrate_to_survey()`
- [ ] History entries use `operation = "sample_calibration_replicate"` and `"sample_calibration_estimate"`
- [ ] `@family sample-calibration` in roxygen for both functions
- [ ] Changelog entry committed at `changelog/nonresponse/feature-sample-calibration.md`
- [ ] Test coverage ≥ 95% (checked via `covr::package_coverage()` before opening PR)

**Notes:**
- `survey::svrepdesign()` API: check what it expects for `weights` (formula vs. vector),
  `repweights` (data frame vs. matrix), and `combined.weights` flag. The `svrep` package
  may impose its own requirements on top — read both package docs before implementing
  `.to_svyrep_design()`.
- The Cholesky check in `calibrate_to_estimate()`: use `tryCatch(chol(vcov_estimate), error = ...)`.
  The actual factorization is done internally by `svrep`; this check is pre-flight validation only.
- Negative-weight warning fires only for full-sample calibration, not per-replicate (per §III Rule 8).
- `method = "logit"` with default infinite bounds will cause `survey::cal.logit` to fail with a
  raw survey package error (per §III argument table note). Document in `@details` but do not
  wrap the error — let it propagate.
- When `svrep::calibrate_to_sample()` errors with a calibration/convergence message, the
  catch-and-rethrow must preserve useful information in the `"i"` bullet.

---

## PR 3: `redistribute_weights()`

**Branch:** `feature/redistribute-weights`
**Depends on:** PR 1 (merged to `develop`)

**Files (TDD order — tests first):**
- `tests/testthat/test-05-nonresponse.R` — new test blocks appended for `redistribute_weights()`
- `R/nonresponse.R` — add `redistribute_weights()` function
- `.claude/rules/surveywts-conventions.md` — add `redistribute_weights()` to `@family nonresponse` row
- `changelog/nonresponse/feature-redistribute-weights.md` — new changelog entry

**Task sequence:**

1. Add test blocks for `redistribute_weights()` to `tests/testthat/test-05-nonresponse.R`.
   Run `devtools::test(filter = "05-nonresponse")` after writing tests — confirm new blocks **red**.

2. **Test: `redistribute_weights()` happy path**
   ```
   test_that("redistribute_weights() with data.frame input returns weighted_df")
   test_that("redistribute_weights() with weighted_df input returns weighted_df")
   test_that("redistribute_weights() with survey_nonprob input returns survey_nonprob")
   test_that("redistribute_weights() with survey_taylor input returns survey_taylor, respondents only")
   test_that("redistribute_weights() with by = NULL performs global redistribution")
   test_that("redistribute_weights() with by groups processes each group independently")
   test_that("redistribute_weights() rows matching neither indicator have unchanged weights")
   test_that("test_invariants() passes on redistribute_weights() result")
   ```

3. **Test: `redistribute_weights()` numerical correctness**
   ```
   test_that("redistribute_weights() result matches adjust_nonresponse() weighting-class for equivalent inputs")
   ```
   Build equivalent setup: `reduce_if = nonrespondent indicator`, `increase_if = respondent indicator`.
   Compare `redistribute_weights()` output weights to `adjust_nonresponse(method = "weighting-class")`.

4. **Test: `redistribute_weights()` error paths** (dual pattern for each)
   ```
   test_that("redistribute_weights() errors for survey_replicate input")
   test_that("redistribute_weights() errors for 0-row data frame")
   test_that("redistribute_weights() errors when named weight column is missing")
   test_that("redistribute_weights() errors when weight column is not numeric")
   test_that("redistribute_weights() errors when weight column has non-positive values")
   test_that("redistribute_weights() errors when weight column has NA")
   test_that("redistribute_weights() errors when wt_name is not character(1)")
   test_that("redistribute_weights() errors when wt_name is NA or empty string")
   test_that("redistribute_weights() errors when wt_name conflicts with an existing non-weight column")
   test_that("redistribute_weights() errors when reduce_if column is not found")
   test_that("redistribute_weights() errors when increase_if column is not found")
   test_that("redistribute_weights() errors when reduce_if is not binary (factor input)")
   test_that("redistribute_weights() errors when increase_if is not binary (character input)")
   test_that("redistribute_weights() errors when reduce_if has NA values")
   test_that("redistribute_weights() errors when increase_if has NA values")
   test_that("redistribute_weights() errors when reduce_if and increase_if overlap")
   test_that("redistribute_weights() errors when a group has no increase_if rows")
   test_that("redistribute_weights() errors when a by variable has NA values")
   ```

5. **Test: `redistribute_weights()` warning paths**
   ```
   test_that("redistribute_weights() warns when a group has fewer than min_cell recipients")
   test_that("redistribute_weights() warns when adjustment factor exceeds max_adjust")
   ```

6. **Test: `redistribute_weights()` edge cases**
   ```
   test_that("redistribute_weights() with no reduce_if rows leaves weights unchanged")
   test_that("redistribute_weights() handles zero-weight rows in increase_if")
   test_that("redistribute_weights() with by: one group all-reduce triggers error, other groups succeed")
   test_that("redistribute_weights() history step number is correct when chained after calibration")
   ```

7. Run `devtools::test(filter = "05-nonresponse")` — confirm new blocks **red**, existing blocks still **green**.

8. Add `redistribute_weights()` to `R/nonresponse.R`:
   - Place after `adjust_nonresponse()` definition
   - Signature matches §V exactly:
     `redistribute_weights(data, reduce_if, increase_if, weights = NULL, by = NULL, wt_name = "wts", control = list())`
   - Input class check: `survey_replicate` → `surveywts_error_unsupported_class`;
     other invalid classes → `surveywts_error_unsupported_class`
   - Call `.check_input_class()` for supported classes check
   - `nrow(data) == 0` → `surveywts_error_empty_data`
   - `wt_name` validation via `.validate_wt_name()`
   - Weight extraction via `.get_weight_vec()` / `.get_weight_col_name()` (consistent with existing)
   - `wt_name` conflict check: if `wt_name` matches an existing non-weight column → `surveywts_error_wt_name_conflict`
   - Merge `control` with defaults: `list(min_cell = 20, max_adjust = 2.0)`
   - Capture `reduce_if` and `increase_if` with `rlang::enquo()` + `rlang::as_name()`
   - Validate both indicator columns via `.validate_response_status_binary()` (reuse from `adjust_nonresponse()`)
   - NA checks for indicators → `surveywts_error_reduce_if_has_na`, `surveywts_error_increase_if_has_na`
   - Overlap check → `surveywts_error_indicators_overlap`
   - `by` tidy-select evaluation (same as `adjust_nonresponse()`)
   - `by` variable NA check → `surveywts_error_variable_has_na`
   - Per-group redistribution using the §V formula (W_total / W_increase)
   - Per-group: no `increase_if` rows but at least one `reduce_if` → `surveywts_error_no_recipients_in_group`
   - Per-group: sparse/extreme warning → `surveywts_warning_class_near_empty`
   - Output construction:
     - `data.frame`/`weighted_df` → `weighted_df` (keep zero-weight `reduce_if` rows)
     - `survey_taylor`/`survey_nonprob` → filter out `reduce_if` rows, update weights,
       use `.update_survey_weights()`
   - History entry: `operation = "redistribute_weights"`, params include `reduce_col`,
     `increase_col`, `by_variables`, `method = "general_redistribution"`
   - Roxygen:
     - `@family nonresponse`
     - `@export`
     - `@return`, full `@param` documentation
     - Note the equivalence to `adjust_nonresponse(method = "weighting-class")` in `@details`

9. Run `devtools::test(filter = "05-nonresponse")` — all tests (new and existing) **green**.

10. Run `devtools::document()` — NAMESPACE picks up `redistribute_weights` export.

11. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.

12. Update `.claude/rules/surveywts-conventions.md`: add `redistribute_weights()` to the
    `@family nonresponse` row in the `@family` table.

13. Commit: `feat(nonresponse): implement redistribute_weights() general primitive`
    Open PR to `develop`.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] Existing `test-05-nonresponse.R` tests remain green throughout
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All error classes from §V tested (dual pattern)
- [ ] Both warning classes tested
- [ ] Numerical correctness vs `adjust_nonresponse()` equivalent verified
- [ ] `test_invariants()` called in every happy-path test block
- [ ] History entry uses `operation = "redistribute_weights"`
- [ ] `@family nonresponse` in roxygen
- [ ] Changelog entry committed at `changelog/nonresponse/feature-redistribute-weights.md`
- [ ] Test coverage ≥ 95% (checked via `covr::package_coverage()` before opening PR)

**Notes:**
- The `reduce_if` and `increase_if` NSE arguments follow the same pattern as
  `response_status` in the existing `adjust_nonresponse()` — use `rlang::enquo()`
  and `rlang::as_name()` to capture the bare column name.
- `.validate_response_status_binary()` is currently named for response_status context.
  If the name makes it awkward to reuse for generic indicator columns, add a
  comment in the code explaining the reuse — do NOT rename the existing helper.
- The `wt_name` conflict check: `wt_name` is OK if it matches the current weight
  column name (renaming the output weight) — only error if it matches a DIFFERENT
  column.
- For `survey_taylor` / `survey_nonprob` output, use `.update_survey_weights()`
  with filtered rows (respondent-only), matching the behavior of `adjust_nonresponse()`.

---

## PR 4: `adjust_nonresponse(method = "propensity-cell")`

**Branch:** `feature/propensity-cell`
**Depends on:** PR 3 (merged to `develop` — same file, avoids merge conflict)

**Files (TDD order — tests first):**
- `tests/testthat/test-05-nonresponse.R` — stub test deleted; new propensity-cell test blocks appended
- `tests/testthat/_snaps/05-nonresponse.md` — stub snapshot deleted + new propensity-cell error snapshots added
- `R/nonresponse.R` — extend `adjust_nonresponse()` with propensity-cell branch
- `changelog/nonresponse/feature-propensity-cell.md` — new changelog entry

**Task sequence:**

1. Delete the propensity-cell stub test from `tests/testthat/test-05-nonresponse.R`
   (the `test_that()` block asserting `class = "surveywts_error_propensity_not_available"`
   for `method = "propensity-cell"`). Delete the corresponding snapshot entry from
   `tests/testthat/_snaps/05-nonresponse.md`. Run `devtools::test(filter = "05-nonresponse")`
   to confirm all remaining tests are **green** after the deletion.

2. Add test blocks for the propensity-cell method to `tests/testthat/test-05-nonresponse.R`.
   Run `devtools::test(filter = "05-nonresponse")` — confirm new blocks **red**, existing **green**.

3. **Test: propensity-cell happy path**
   ```
   test_that("adjust_nonresponse(method='propensity-cell') returns same class as input")
   test_that("adjust_nonresponse(method='propensity-cell') sets nonrespondent weights to 0")
   test_that("adjust_nonresponse(method='propensity-cell') history entry has operation = 'nonresponse_propensity_cell'")
   test_that("test_invariants() passes on propensity-cell result")
   ```

4. **Test: propensity-cell numerical correctness**
   ```
   test_that("propensity-cell respondent weights within each cell scale correctly")
   ```
   Verify `sum(new_weights[in_cell & resp]) == sum(old_weights[in_cell])` for each cell.

5. **Test: propensity-cell error paths** (dual pattern for each)
   ```
   test_that("adjust_nonresponse() errors when method='propensity-cell' and formula is NULL")
   test_that("adjust_nonresponse() errors when formula is not a formula object (propensity-cell)")
   test_that("adjust_nonresponse() errors when a formula variable is missing (propensity-cell)")
   test_that("adjust_nonresponse() errors when a formula variable has NA values")
   test_that("adjust_nonresponse() errors when control$n_cells = 1")
   test_that("adjust_nonresponse() still errors for method='propensity' (stub unchanged)")
   test_that("adjust_nonresponse() errors when a propensity cell contains no respondents")
   ```

6. **Test: propensity-cell warning paths**
   ```
   test_that("adjust_nonresponse() warns when by is non-NULL with method='propensity-cell'")
   test_that("adjust_nonresponse() warns when a cell has fewer than min_cell respondents")
   test_that("adjust_nonresponse() warns when adjustment factor exceeds max_adjust in a cell")
   ```

7. **Test: propensity-cell edge cases**
   ```
   test_that("propensity-cell works with control$n_cells = 2")
   test_that("propensity-cell handles high propensity concentration (all scores near 0 or 1)")
   ```

8. Run `devtools::test(filter = "05-nonresponse")` — confirm new blocks **red**, existing **green**.

9. Extend `adjust_nonresponse()` in `R/nonresponse.R`:

   a. **Signature change:** Add `formula = NULL` argument. Add `n_cells = 5` to `control`
      defaults. Update default in signature: `control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)`.
      Full new signature:
      ```r
      adjust_nonresponse(
        data,
        response_status,
        weights = NULL,
        by = NULL,
        wt_name = "wts",
        method = c("weighting-class", "propensity-cell", "propensity"),
        formula = NULL,
        control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)
      )
      ```

   b. **`method` dispatch:** Change the existing `match.arg(method)` so `"propensity-cell"`
      routes to the new branch (remove or replace the stub error for it).
      Keep `"propensity"` stub as-is.

   c. **Propensity-cell branch logic (in order):**
      1. If `!is.null(by)` → `cli_warn(class = "surveywts_warning_by_ignored_for_propensity_cell")`
      2. Validate `formula` is not NULL → `surveywts_error_formula_required_for_propensity_cell`
      3. Call `.validate_formula(formula)` → `surveywts_error_formula_invalid`
      4. Get the plain data frame (`plain_df`) — same extraction as weighting-class branch
      5. Call `.validate_formula_variables(formula, plain_df, "data")` → `surveywts_error_formula_variable_not_found`
      6. Check for NA in formula variables → `surveywts_error_formula_variable_has_na`
         Use `anyNA(plain_df[[var]])` for each `all.vars(formula)` variable.
      7. Validate `control$n_cells`: must be a whole number ≥ 2 → `surveywts_error_n_cells_invalid`
      8. Get `weights_vec` (same extraction as weighting-class branch)
      9. Fit the propensity model. Resolve `response_status` to a column name string
         (`resp_col`) before constructing the formula, then build the formula explicitly:
         ```r
         model <- stats::glm(
           stats::as.formula(paste(resp_col, "~", deparse(formula[[2]]))),
           family = stats::binomial,
           data = plain_df,
           weights = weights_vec
         )
         ```
         Do NOT pass `formula` unchanged — it has no LHS. Do NOT write
         `update(formula, response_status_vec ~ .)` — `response_status_vec` is a
         bare symbol and will not be resolved to the actual column name.
      10. Predict: `scores <- stats::predict(model, type = "response")`
      11. Cutpoints: `cuts <- stats::quantile(scores, probs = seq(0, 1, 1 / control$n_cells))`
      12. Assign cells: `cells <- findInterval(scores, cuts, rightmost.closed = TRUE)`
      13. For each cell `k` in `1:control$n_cells`:
          - Check at least one respondent → `surveywts_error_no_respondents_in_propensity_cell`
            (include cell index `k` and propensity range `[min(scores[cells==k]), max(scores[cells==k])]`)
          - Compute `W_cell = sum(weights_vec[cells == k])`
          - Compute `W_cell_resp = sum(weights_vec[cells == k & responded])`
          - Apply factor to respondent weights; zero nonrespondent weights
          - Sparse/extreme-adjustment warning check (same condition as weighting-class)
      14. Return same output class as input (same construction logic as weighting-class branch)
      15. History: `operation = "nonresponse_propensity_cell"`, params include
          `formula` (as `deparse(formula)`), `n_cells`, `by_variables = NULL`

   d. **Roxygen update for `adjust_nonresponse()`:**
      - Add `@param formula` documentation
      - Add `@param control$n_cells` to the `control` param description
      - Update `@details` to document: glm convergence warnings pass through unchanged;
        unweighted quantiles used for cell boundaries (per §VI Statistical Assumptions)
      - Add `@note` for MAR assumption and propensity-as-known limitation (per §VI)

10. Run `devtools::test(filter = "05-nonresponse")` — all tests (new and existing) **green**.

11. Run `devtools::document()` — NAMESPACE unchanged (no new exports; updated man file for `adjust_nonresponse()`).

12. Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes.

13. Commit: `feat(nonresponse): implement adjust_nonresponse() propensity-cell method`
    Open PR to `develop`.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; man/adjust_nonresponse.Rd updated
- [ ] `formula = NULL` argument present in signature
- [ ] `n_cells` key in `control` with default 5; minimum 2 enforced
- [ ] `"propensity"` stub still errors with `surveywts_error_propensity_not_available`
- [ ] All new error classes tested (dual pattern)
- [ ] All new warning classes tested
- [ ] Numerical correctness: within-cell weight scaling verified
- [ ] `test_invariants()` in every happy-path block
- [ ] Existing `test-05-nonresponse.R` tests (except the now-removed propensity-cell stub) remain green throughout
- [ ] Propensity-cell stub test and its snapshot deleted in step 1
- [ ] History entry uses `operation = "nonresponse_propensity_cell"`
- [ ] `@note` present for MAR and propensity-as-known limitations
- [ ] Changelog entry committed at `changelog/nonresponse/feature-propensity-cell.md`
- [ ] Test coverage ≥ 95% (checked via `covr::package_coverage()` before opening PR)

**Notes:**
- The `glm()` call must have the response variable on the LHS. Resolve `response_status`
  to a column name string (`resp_col`) first, then build the formula with
  `stats::as.formula(paste(resp_col, "~", deparse(formula[[2]])))`. Do NOT pass
  `formula` directly to `glm()` — it has no LHS. Do NOT use
  `update(formula, response_status_vec ~ .)` — the bare symbol is not evaluated
  as the column name string.
- `findInterval()` with `rightmost.closed = TRUE` ensures the maximum score lands in
  cell `n_cells` (not `n_cells + 1`). This matches the spec (§VI step 4).
- The `by` warning fires even if `by = NULL` is the default — it fires only when the
  user explicitly passes `by` as non-NULL.
- For the `surveywts_error_no_respondents_in_propensity_cell` message, compute
  `range(scores[cells == k])` to get the propensity score range for the cell.
- The PR depends on PR 3 being merged first to avoid merge conflicts on `nonresponse.R`
  and `test-05-nonresponse.R`. Branch off develop after PR 3 is merged.
