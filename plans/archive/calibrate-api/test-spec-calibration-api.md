# Test-spec — calibration-api

**Status**: SPEC_REVIEWED
**Corresponding spec**: spec-calibration-api.md (do not cross-reference)

---

## Reference Oracle

- `survey::calibrate` (survey package ≥ 4.2) — numerical oracle for GREG
  calibration weight totals
- `survey::rake` (survey package ≥ 4.2) — numerical oracle for raking weights
- `survey::postStratify` (survey package ≥ 4.2) — numerical oracle for
  poststratification weights

All oracle comparisons use `skip_if_not_installed("survey")` inside the
relevant `test_that()` block, never at file level.

---

## Datasets

| Dataset | Construction | Purpose |
|---------|-------------|---------|
| `make_surveywts_data(n = 500, seed = 42)` | Standard generator | Happy-path tests for all three functions |
| `make_surveywts_data(n = 500, seed = 99)` | Alternate seed | Numerical oracle comparisons (avoids fixture dependency on seed 42) |
| Inline 5-row data frame | Created inline per test | Edge cases and error path tests |
| Inline 0-row data frame | `data[0, ]` inline | Empty-data error tests |
| Inline 1-row data frame | Created inline | Single-row behavior |
| `make_surveywts_data(n = 500, seed = 42)` as `weighted_df` | After `calibrate_greg()` call | Tests that `weighted_df` input is accepted |
| `make_surveywts_data(n = 500, seed = 42)` as `survey_nonprob` | Constructed via `survey_nonprob()` | Tests that `survey_nonprob` input is accepted |
| `make_surveywts_data(n = 500, seed = 42)` as `survey_taylor` | Constructed via `as_taylor_design()` with `ids = ~1` | Tests that `survey_taylor` input is accepted and class preserved |

---

## Invariant requirement

`test_invariants(obj)` must be the **first assertion** in every `test_that()`
block that produces a `weighted_df` or `survey_nonprob` output. This applies
to all happy-path and edge-case tests below.

---

## Per-function test plan

---

### `calibrate_greg()`

**Test file**: `tests/testthat/test-02-calibrate.R` (updated in place)

#### Happy path

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| `data.frame` input, `type = "prop"`, `model = "linear"` | `make_surveywts_data(500, 42)` | Returns `weighted_df`; weighted proportions for each calibrated variable match targets | 1e-10 |
| `data.frame` input, `type = "count"`, `model = "linear"` | `make_surveywts_data(500, 42)` | Returns `weighted_df`; weighted counts match targets | 1e-10 |
| `data.frame` input, `model = "logit"` | `make_surveywts_data(500, 42)` | Returns `weighted_df`; all calibrated weights positive | 1e-10 |
| `weighted_df` input | Output of prior `calibrate_greg()` call | Returns `weighted_df`; `test_invariants()` passes; weight column name preserved | 1e-10 |
| `survey_nonprob` input | `survey_nonprob` constructed from `make_surveywts_data(500, 42)` | Returns `survey_nonprob`; `test_invariants()` passes; class preserved | 1e-10 |
| `survey_taylor` input | `survey_taylor` constructed from `make_surveywts_data(500, 42)` | Returns `survey_taylor`; `test_invariants()` passes; class preserved; `@variables$ids` and `@variables$strata` unchanged | 1e-10 |
| Format B long data frame `targets` | `make_surveywts_data(500, 42)` | Same result as equivalent Format A targets | 1e-10 |
| `reference_design` non-`NULL` | `make_surveywts_data(500, 42)` | History entry `targets_from_reference = TRUE` | — |
| History entry appended correctly | `make_surveywts_data(500, 42)` | `weighting_history` has one entry; `operation == "calibrate_greg"` | — |
| `weights = NULL` on plain `data.frame` | `make_surveywts_data(500, 42)` (no weight col) | Output weight column named `"wts"`; uniform starting weights used | — |
| Custom `wt_name` | `make_surveywts_data(500, 42)` | Output weight column named by `wt_name` | — |

**Numerical oracle** (inside block with `skip_if_not_installed("survey")`):

| Scenario | Dataset | Oracle call | Tolerance |
|----------|---------|------------|-----------|
| `model = "linear"` weights match `survey::calibrate` | `make_surveywts_data(500, 99)` | `survey::calibrate(design, formula, pop.totals)` | 1e-8 |

#### Error paths

Every error class uses the dual pattern: `expect_error(class = ...)` AND
`expect_snapshot(error = TRUE)`.

| Error class | Trigger |
|-------------|---------|
| `surveywts_error_unsupported_class` | Pass a `list` as `data` |
| `surveywts_error_replicate_not_supported` | Pass a `survey_replicate` object as `data` |
| `surveywts_error_empty_data` | `data` with 0 rows |
| `surveywts_error_weights_not_found` | `weights = nonexistent_col` |
| `surveywts_error_weights_not_numeric` | Weight column is `character` |
| `surveywts_error_weights_nonpositive` | Weight column contains a 0 |
| `surveywts_error_weights_na` | Weight column contains `NA` |
| `surveywts_error_wt_name_not_scalar` | `wt_name = c("a", "b")` |
| `surveywts_error_wt_name_empty` | `wt_name = ""` |
| `surveywts_error_reference_design_not_taylor` | `reference_design = list()` |
| `surveywts_error_margins_format_invalid` | `targets = 42` (not a list or data frame) |
| `surveywts_error_targets_variable_not_found` | `targets` names a column absent from `data` |
| `surveywts_error_variable_not_categorical` | Calibration variable is `numeric` |
| `surveywts_error_variable_has_na` | Calibration variable contains `NA` |
| `surveywts_error_population_level_missing` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | A `targets` level not in `data` |
| `surveywts_error_population_totals_invalid` | `type = "prop"` targets summing to 0.9 |
| `surveywts_error_population_totals_invalid` | `type = "count"` with two variables whose marginal sums differ by more than 1e-3 |
| `surveywts_error_calibration_not_converged` | Force non-convergence via `control = list(maxit = 1)` with extreme targets and `model = "logit"` |

#### Warning paths

| Warning class | Trigger | Assertion |
|---------------|---------|-----------|
| `surveywts_warning_negative_calibrated_weights` | `model = "linear"` with targets that force negative weights | `expect_warning(class = ...)` wrapping call; result still returned |
| `surveywts_warning_control_param_ignored` | `control = list(maxit = 10, pval = 0.05)` (unrecognized key `pval`) | `expect_warning(class = ...)` per unrecognized key; calibration still proceeds |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| 0-row `data` | `data[0, ]` | Error: `surveywts_error_empty_data` |
| 1-row `data` | Inline 1-row data frame | Calibration completes; `test_invariants()` passes |
| Single-level calibration variable (all values identical) | Inline data, all `age_group = "18-34"` | Completes without error; output weights are uniform scalar multiple |
| `targets` is a Format B data frame | Build equivalent Format B; compare output | Identical weights to Format A equivalent (within 1e-10) |
| `model = "linear"` negative weights produced | Extreme targets | Warning emitted; output returned with negative weights present |
| `weights = NULL` on plain `data.frame` | `make_surveywts_data(500, 42)` without weight column | Output `weight_col` attribute equals `"wts"` |
| `type = "count"` with inconsistent marginal sums | Two target variables whose sums differ by > 1e-3 | Error: `surveywts_error_population_totals_invalid` |

---

### `calibrate_rake()`

**Test file**: `tests/testthat/test-03-rake.R` (updated in place)

#### Happy path

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| `data.frame` input, `type = "prop"`, `algorithm = "anesrake"` | `make_surveywts_data(500, 42)` | Returns `weighted_df`; weighted marginal proportions match targets | 1e-10 |
| `data.frame` input, `type = "count"`, `algorithm = "anesrake"` | `make_surveywts_data(500, 42)` | Returns `weighted_df`; weighted marginal counts match targets | 1e-10 |
| `algorithm = "survey"` | `make_surveywts_data(500, 42)` | Returns `weighted_df` with raked weights | 1e-10 |
| `weighted_df` input | Prior `calibrate_rake()` output | Returns `weighted_df`; `test_invariants()` passes | 1e-10 |
| `survey_nonprob` input | Constructed `survey_nonprob` | Returns `survey_nonprob`; class preserved; `test_invariants()` passes | 1e-10 |
| `survey_taylor` input | `survey_taylor` constructed from `make_surveywts_data(500, 42)` | Returns `survey_taylor`; `test_invariants()` passes; class preserved; `@variables$ids` and `@variables$strata` unchanged | 1e-10 |
| Format B `targets` | `make_surveywts_data(500, 42)` | Same result as equivalent Format A | 1e-10 |
| `cap` applied (`algorithm = "anesrake"`) | `make_surveywts_data(500, 42)` with `cap = 3` | All output weights satisfy `w / mean(w) <= 3` | 1e-10 |
| History entry `operation` field | `make_surveywts_data(500, 42)` | `operation == "calibrate_rake"` | — |
| `reference_design` non-`NULL` | `make_surveywts_data(500, 42)` | `targets_from_reference = TRUE` in history | — |

**Numerical oracle** (inside block with `skip_if_not_installed("survey")`):

| Scenario | Dataset | Oracle call | Tolerance |
|----------|---------|------------|-----------|
| `algorithm = "survey"` weights match `survey::rake` | `make_surveywts_data(500, 99)` | `survey::rake(design, sample.margins, population.margins)` | 1e-8 |

#### Error paths

| Error class | Trigger |
|-------------|---------|
| `surveywts_error_unsupported_class` | Pass a `list` as `data` |
| `surveywts_error_replicate_not_supported` | Pass `survey_replicate` as `data` |
| `surveywts_error_empty_data` | 0-row `data` |
| `surveywts_error_weights_not_found` | `weights = nonexistent_col` |
| `surveywts_error_weights_not_numeric` | Character weight column |
| `surveywts_error_weights_nonpositive` | Weight column has 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_wt_name_not_scalar` | `wt_name = c("a", "b")` |
| `surveywts_error_wt_name_empty` | `wt_name = ""` |
| `surveywts_error_reference_design_not_taylor` | `reference_design = "bad"` |
| `surveywts_error_margins_format_invalid` | `targets = 42` |
| `surveywts_error_margins_format_invalid` | Format B data frame missing `level` column |
| `surveywts_error_targets_variable_not_found` | `targets` names a column absent from `data` |
| `surveywts_error_variable_not_categorical` | Raking variable is `numeric` |
| `surveywts_error_variable_has_na` | Raking variable contains `NA` |
| `surveywts_error_population_level_missing` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | A `targets` level not in `data` |
| `surveywts_error_population_totals_invalid` | `type = "prop"` targets summing to 1.1 |
| `surveywts_error_population_totals_invalid` | `type = "count"` with two variables whose marginal sums differ by more than 1e-3 |
| `surveywts_error_calibration_not_converged` | `control = list(maxit = 1)` with extreme targets |
| `surveywts_error_cap_not_supported_survey` | `cap = 3` with `algorithm = "survey"` |

#### Warning paths

| Warning class | Trigger | Assertion |
|---------------|---------|-----------|
| `surveywts_warning_control_param_ignored` | Pass `control = list(pval = 0.01)` with `algorithm = "survey"` | `expect_warning(class = ...)` for each ignored key |
| `surveywts_warning_control_param_ignored` | Pass `control = list(epsilon = 1e-9)` with `algorithm = "anesrake"` | `expect_warning(class = ...)` |

#### Message paths

| Message class | Trigger | Assertion |
|---------------|---------|-----------|
| `surveywts_message_already_calibrated` | `algorithm = "anesrake"` and data already matches all targets | `expect_message(class = ...)` |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| 0-row `data` | `data[0, ]` | Error: `surveywts_error_empty_data` |
| `cap` non-`NULL` + `algorithm = "survey"` | `cap = 3, algorithm = "survey"` | Error: `surveywts_error_cap_not_supported_survey` before margin parsing |
| Format B `targets` | Equivalent Format B | Identical result to Format A (within 1e-10) |
| All variables pass chi-square at start | Weights perfectly matching targets | Message: `surveywts_message_already_calibrated`; weights unchanged |
| Wrong-algorithm `control` keys | `control = list(pval = 0.01)` with `algorithm = "survey"` | Warning per ignored key; calibration still proceeds |
| Single-level raking variable | Inline data, all `sex = "M"` | Completes without error; all weights scaled by same factor |
| `type = "count"` with inconsistent marginal sums | Two target variables whose sums differ by > 1e-3 | Error: `surveywts_error_population_totals_invalid` |

---

### `calibrate_poststrat()`

**Test file**: `tests/testthat/test-04-poststratify.R` (updated in place)

#### Happy path

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| `data.frame` input, `type = "prop"`, single strata variable | Inline 6-row data frame with `age_group` | Returns `weighted_df`; weighted cell proportions match targets | 1e-10 |
| `data.frame` input, `type = "prop"`, joint strata (2 variables) | Inline data with `age_group` × `sex` cells | Returns `weighted_df`; joint cell weighted proportions match targets | 1e-10 |
| `data.frame` input, `type = "count"` | Inline data with count targets | Returns `weighted_df`; weighted cell counts match targets | 1e-10 |
| `weighted_df` input | Output of prior call | Returns `weighted_df`; `test_invariants()` passes | 1e-10 |
| `survey_nonprob` input | Constructed `survey_nonprob` | Returns `survey_nonprob`; class preserved; `test_invariants()` passes | 1e-10 |
| `survey_taylor` input | `survey_taylor` constructed from `make_surveywts_data(500, 42)` | Returns `survey_taylor`; `test_invariants()` passes; class preserved; `@variables$ids` and `@variables$strata` unchanged | 1e-10 |
| `reference_design` non-`NULL` | Any accepted input with `reference_design = <survey_taylor>` | History entry `targets_from_reference = TRUE` | — |
| History entry `operation` field | Any accepted input | `operation == "calibrate_poststrat"` | — |
| `strata_names` derived from `targets` column names | `targets` with `age_group`, `sex`, `target` columns | History `parameters$variables` equals `c("age_group", "sex")` | — |

**Numerical oracle** (inside block with `skip_if_not_installed("survey")`):

| Scenario | Dataset | Oracle call | Tolerance |
|----------|---------|------------|-----------|
| Weights match `survey::postStratify` | Inline 6-row data frame | `survey::postStratify(design, ~age_group + sex, population)` | 1e-8 |

#### Error paths

| Error class | Trigger |
|-------------|---------|
| `surveywts_error_unsupported_class` | Pass a `list` as `data` |
| `surveywts_error_replicate_not_supported` | Pass `survey_replicate` as `data` |
| `surveywts_error_empty_data` | 0-row `data` |
| `surveywts_error_weights_not_found` | `weights = nonexistent_col` |
| `surveywts_error_weights_not_numeric` | Character weight column |
| `surveywts_error_weights_nonpositive` | Weight column has 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_wt_name_not_scalar` | `wt_name = c("a", "b")` |
| `surveywts_error_wt_name_empty` | `wt_name = ""` |
| `surveywts_error_reference_design_not_taylor` | `reference_design = list()` (non-`NULL`, not `survey_taylor`) |
| `surveywts_error_margins_format_invalid` | `targets` is a named list (not a data frame) |
| `surveywts_error_no_strata_variables` | `targets = data.frame(target = 1.0)` (no non-`"target"` columns) |
| `surveywts_error_targets_variable_not_found` | A non-`"target"` column name in `targets` is absent from `data` |
| `surveywts_error_variable_has_na` | A strata column in `data` contains `NA` |
| `surveywts_error_population_totals_invalid` | `type = "prop"` targets summing to 0.99 |
| `surveywts_error_population_totals_invalid` | `type = "count"` target of 0 in one cell |
| `surveywts_error_population_cell_duplicate` | `targets` has two rows for the same cell |
| `surveywts_error_population_cell_missing` | A cell in `data` absent from `targets` |
| `surveywts_error_population_cell_missing` | `targets` missing the `"target"` column |
| `surveywts_error_population_cell_not_in_data` | A `targets` row cell with no data observations |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| 0-row `data` | `data[0, ]` | Error: `surveywts_error_empty_data` |
| 1-row `data`, 1-cell `targets` | Inline 1-row data, 1-row targets | Calibration completes; `test_invariants()` passes; weight equals target/starting_sum |
| Single stratification variable | `targets` has only `age_group` + `target` columns | Completes without error; strata variable list has 1 element |
| `targets` has only a `"target"` column (zero strata variables) | `targets = data.frame(target = 1)` | Error: `surveywts_error_no_strata_variables` |
| NA in a strata variable | Inline data with `NA` in `sex` | Error: `surveywts_error_variable_has_na` |
| Cell in `data` not in `targets` | Add a new level to `age_group` in data without updating `targets` | Error: `surveywts_error_population_cell_missing` |
| Cell in `targets` not in `data` | Add extra row to `targets` for non-existent cell | Error: `surveywts_error_population_cell_not_in_data` |
| Duplicate cell in `targets` | Add second row for same cell combination | Error: `surveywts_error_population_cell_duplicate` |

---

### `calibrate()` — Thin Dispatcher

**Test file**: `tests/testthat/test-02-calibrate.R` (section added to existing file)

#### Happy path

| Scenario | Expected |
|----------|----------|
| `calibrate(data, method = "greg", targets = ..., ...)` | Returns same result as direct `calibrate_greg(data, targets = ..., ...)` call |
| `calibrate(data, method = "rake", targets = ..., ...)` | Returns same result as direct `calibrate_rake(data, targets = ..., ...)` call |
| `calibrate(data, method = "poststrat", targets = ..., ...)` | Returns same result as direct `calibrate_poststrat(data, targets = ..., ...)` call |
| Default `method = "greg"` | `calibrate(data, targets = ...)` dispatches to `calibrate_greg()` |

#### Error paths

| Trigger | Expected |
|---------|----------|
| `method = "bad_method"` | Native `rlang::arg_match()` error (no snapshot required — not a `cli_abort()` class) |
| Unknown `...` argument for `method = "greg"` | Native "unused argument" error from `calibrate_greg()` |

#### Invariants

- `calibrate()` adds no behavior of its own beyond method resolution.
- `test_invariants(obj)` applies to the result whenever the dispatched
  function would produce a `weighted_df` or `survey_nonprob`.

---

## Deleted function regression guard

Add one `test_that()` block in `test-02-calibrate.R` to confirm that the old
`calibrate()` signature (with `variables` + `population` arguments) is gone:

```
test_that("old calibrate() signature no longer exists (variables + population args)", {
  # calibrate() now takes 'targets', not 'variables' + 'population'.
  # Passing the old signature should produce an unused-argument error.
  df <- data.frame(x = c("a", "b"), stringsAsFactors = FALSE)
  expect_error(
    calibrate(df, method = "greg", variables = c(x),
              population = list(x = c(a = 0.5, b = 0.5)))
  )
})
```

Add equivalent blocks in `test-03-rake.R` (old `rake()` / `margins` arg gone)
and `test-04-poststratify.R` (old `poststratify()` / `strata` + `population`
args gone).

---

## History field tests

One `test_that()` block per function confirms the history operation value:

| Function | Expected `operation` value |
|----------|---------------------------|
| `calibrate_greg()` | `"calibrate_greg"` |
| `calibrate_rake()` | `"calibrate_rake"` |
| `calibrate_poststrat()` | `"calibrate_poststrat"` |

Each block: call the function on `make_surveywts_data(500, 42)`, extract
`attr(result, "weighting_history")[[1]]$operation`, assert with
`expect_identical()`.

---

## Tolerances

| Estimand | Tolerance | Justification |
|----------|-----------|---------------|
| Weight computations (marginal/cell totals, conservation) | 1e-10 | Default per `testing-surveywts.md` |
| Numerical oracle comparison vs `survey` package | 1e-8 | Default per `testing-surveywts.md` |

No deviations from default tolerances are required for this feature.

---

## Profile gates

The tester runs ALL gates. Skip conditions noted where applicable.

- [ ] `devtools::document()` — NAMESPACE and `man/` unchanged after run (confirms deleted function Rd files are removed and new ones are generated)
- [ ] `devtools::test()` — all tests pass, including updated test-02, test-03, test-04
- [ ] `devtools::run_examples()` — all `@examples` blocks in new functions run clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown / scope); run if site already building
- [ ] `covr::package_coverage()` — ≥ 95% (target 98%); test-02/03/04 updates must not drop coverage
