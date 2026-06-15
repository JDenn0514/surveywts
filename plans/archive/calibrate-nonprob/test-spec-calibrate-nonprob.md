# Test-spec — calibrate-nonprob

---

## Reference oracle

No external numerical oracle. All happy-path output correctness assertions
compare the returned object's class and structure against the known contract.
The existing numerical oracle tests (svrep identity comparisons) are NOT
repeated here — they cover `survey_replicate` inputs and are already in the
test suite. New tests focus on class dispatch and the new error classes.

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `make_replicate_design(n = 200L, seed = 1L)` | Standard `survey_replicate` input; existing happy-path baseline |
| `make_nonprob_replicate_design(n = 200L, seed = 1L)` | `survey_nonprob` with bootstrap replicates; new happy-path input |
| `make_nonprob_no_repweights(n = 200L, seed = 1L)` | `survey_nonprob` without replicate weights; triggers new error classes |
| Inline: `surveycore::survey_taylor(...)` from `make_surveywts_data()` | Plain wrong-type input for `_not_replicate` regression guard |
| Inline: `data.frame` from `make_surveywts_data()` | Plain wrong-type input for `_not_replicate` regression guard |

### New helper definitions (add to `helper-test-data.R`)

**`make_nonprob_replicate_design(n = 200L, seed = 1L)`**

Returns a `survey_nonprob` with `@variables$repweights` populated with 50
bootstrap replicate columns. Construction method: create a `survey_nonprob`
using `ipw()` (which already populates a `survey_nonprob`), then call
`create_bootstrap_weights()` on it. The resulting object must pass
`S7::S7_inherits(obj, surveycore::survey_nonprob)` and must have
`length(obj@variables$repweights) > 0`.

Concrete construction sketch for the helper:

1. Call `make_surveywts_data(n = n, seed = seed)` to get a plain data frame.
2. Create a reference design from a separate call to `make_surveywts_data()`
   wrapped in `surveycore::as_survey(...)`.
3. Call `ipw(data = nps_df, reference = ref, selection = ~sex + age_group)` to
   get a `survey_nonprob` with IPW weights.
4. Call `create_bootstrap_weights(ipw_result, replicates = 50L, type = "quasi-randomization", seed = seed)` to populate
   replicate weights. The `type = "quasi-randomization"` argument is required —
   the default prob-sample type returns `survey_replicate`, not `survey_nonprob`.
5. Return the result.

The helper must use `set.seed(seed)` before the random operations so output is
reproducible across runs.

**`make_nonprob_no_repweights(n = 200L, seed = 1L)`**

Returns a `survey_nonprob` with `@variables$repweights` either `NULL` or an
empty character vector. Construction method: call `ipw()` and return the result
without calling any `create_*_weights()` function. The result of `ipw()` does
not have replicate weights, making this helper trivially the `ipw()` output.

Concrete construction sketch:

1. Call `make_surveywts_data(n = n, seed = seed)` for NPS data.
2. Create a reference as `surveycore::as_survey(make_surveywts_data(n = n * 5L, seed = seed + 100L), weights = base_weight)`.
3. Return `ipw(data = nps_df, reference = ref, selection = ~sex + age_group)`.

This returns a `survey_nonprob` without replicate weights.

---

## Per-function test plan

### `calibrate_to_survey()`

#### Happy paths — new scenarios

| Scenario | Inputs | Expected class | Assertion |
|----------|--------|---------------|-----------|
| `survey_nonprob` primary, `survey_replicate` control | `make_nonprob_replicate_design()`, `make_replicate_design()` | `survey_nonprob` | `S7::S7_inherits(result, surveycore::survey_nonprob)` is TRUE |
| `survey_replicate` primary, `survey_nonprob` control | `make_replicate_design()`, `make_nonprob_replicate_design()` | `survey_replicate` | `S7::S7_inherits(result, surveycore::survey_replicate)` is TRUE |
| Both `survey_nonprob` with repweights | `make_nonprob_replicate_design(seed=1)`, `make_nonprob_replicate_design(seed=2)` | `survey_nonprob` | `S7::S7_inherits(result, surveycore::survey_nonprob)` is TRUE |

For each of these three scenarios:
- Call `test_invariants(result)` as the first assertion.
- Verify `nrow(result@data)` equals `nrow(primary_design@data)`.
- Verify the last `@metadata@weighting_history` entry has `operation == "calibrate_to_survey"`.
- Verify the result class does NOT equal the alternate class (i.e., `survey_nonprob`
  result is not a `survey_replicate`, and vice versa).

**Regression guard — existing behavior unchanged**:

Verify that `make_replicate_design()` as `primary_design` (both `survey_replicate`
inputs) still returns `survey_replicate`. This is already tested in the existing
test suite but a single assertion in the new test file's setup section documents
the regression expectation.

#### Error paths — new classes (dual pattern required for each)

Each entry below requires BOTH an `expect_error(class = ...)` call AND an
`expect_snapshot(error = TRUE, ...)` call in the same `test_that()` block.

| Error class | Trigger | Dual pattern |
|-------------|---------|-------------|
| `surveywts_error_primary_no_repweights` | `primary_design = make_nonprob_no_repweights()`, valid `control_design` | `expect_error(class = "surveywts_error_primary_no_repweights")` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_control_no_repweights` | valid `primary_design`, `control_design = make_nonprob_no_repweights()` | `expect_error(class = "surveywts_error_control_no_repweights")` + `expect_snapshot(error = TRUE, ...)` |

**Regression guard — existing `_not_replicate` classes still fire for wrong types**:

| Error class | Trigger | Note |
|-------------|---------|------|
| `surveywts_error_primary_not_replicate` | `primary_design = data.frame(...)` (plain data frame) | `expect_error(class = ...)` only; snapshot text changed due to message update, so a new snapshot is required |
| `surveywts_error_control_not_replicate` | `control_design = surveycore::survey_taylor(...)` | same as above |

Because the error messages for `_not_replicate` classes change in this update
(the message body now mentions `survey_nonprob` as an additional accepted type),
the existing snapshots for these two error classes will fail. The tester must
delete the old snapshots and record new ones by running
`testthat::snapshot_review()` and accepting the updated text.

#### Warning paths

No new warning classes are introduced. All existing warning tests are unchanged.

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|------------------|
| `primary_design` is `survey_nonprob` with 0-length `@variables$repweights` (empty character vector) | Manually construct a `survey_nonprob` where `@variables$repweights = character(0)` | Errors: `surveywts_error_primary_no_repweights` |
| `control_design` is `survey_nonprob` with `NULL` `@variables$repweights` | Inline construction | Errors: `surveywts_error_control_no_repweights` |
| Mixed: `primary_design` is `survey_nonprob` with repweights, `control_design` is `survey_nonprob` with repweights | Both from `make_nonprob_replicate_design()` | Succeeds; returns `survey_nonprob`; `test_invariants(result)` passes |
| History `control_design_class` field records the actual control class | `primary_design = make_nonprob_replicate_design()`, `control_design = make_replicate_design()` | `result@metadata@weighting_history[[end]]$parameters$control_design_class == "survey_replicate"` |
| History `control_design_class` field when both nonprob | Both `make_nonprob_replicate_design()` | `result@metadata@weighting_history[[end]]$parameters$control_design_class` contains `"survey_nonprob"` |

---

### `calibrate_to_estimate()`

#### Happy paths — new scenarios

| Scenario | Inputs | Expected class | Assertion |
|----------|--------|---------------|-----------|
| `design` is `survey_nonprob` with repweights | `make_nonprob_replicate_design()`, standard `targets`, `vcov_est` | `survey_nonprob` | `S7::S7_inherits(result, surveycore::survey_nonprob)` is TRUE |

For this scenario:
- Call `test_invariants(result)` as the first assertion.
- Verify `nrow(result@data)` equals `nrow(design@data)`.
- Verify the last `@metadata@weighting_history` entry has
  `operation == "calibrate_to_estimate"`.
- Verify result is NOT `survey_replicate`:
  `expect_false(S7::S7_inherits(result, surveycore::survey_replicate))`.

**Standard targets to use with `make_nonprob_replicate_design()`**: The `sex`
variable is available in the underlying data. Use:
```
targets  <- list(sex = c("F" = 110, "M" = 90))
vcov_est <- diag(c(100, 100))
```

#### Error paths — new class (dual pattern required)

| Error class | Trigger | Dual pattern |
|-------------|---------|-------------|
| `surveywts_error_design_no_repweights` | `design = make_nonprob_no_repweights()`, standard `targets`, `vcov_est` | `expect_error(class = "surveywts_error_design_no_repweights")` + `expect_snapshot(error = TRUE, ...)` |

**Regression guard — existing `_not_replicate` class still fires**:

| Error class | Trigger | Note |
|-------------|---------|------|
| `surveywts_error_design_not_replicate` | `design = data.frame(...)` (plain data frame) | `expect_error(class = ...)` only; snapshot text changed — tester must accept new snapshot |

#### Warning paths

No new warning classes. All existing warning tests are unchanged.

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|------------------|
| `design` is `survey_nonprob` with `@variables$repweights = character(0)` | Inline construction | Errors: `surveywts_error_design_no_repweights` |
| `design` is `survey_nonprob` with `@variables$repweights = NULL` | Output of `make_nonprob_no_repweights()` | Errors: `surveywts_error_design_no_repweights` |
| `design` is `survey_nonprob` with repweights; `targets` are mismatched levels | `make_nonprob_replicate_design()` + wrong level names | Errors: `surveywts_error_targets_levels_mismatch` (existing class, existing behavior) |

---

## Validation order

The following order tests must pass for the new validation structure:

| Test description | Expected |
|-----------------|----------|
| `calibrate_to_survey()` with `primary_design` that is a plain `data.frame` AND `control_design` that is `survey_nonprob` without repweights — `primary` check fires first | `surveywts_error_primary_not_replicate` |
| `calibrate_to_survey()` with valid `primary_design = survey_nonprob with repweights` AND `control_design = survey_nonprob without repweights` — `control` check fires | `surveywts_error_control_no_repweights` |
| `calibrate_to_estimate()` with `design = survey_nonprob without repweights` AND invalid `targets` — `design` check fires first | `surveywts_error_design_no_repweights` |

---

## Snapshot management notes

Three existing snapshot files will break because the error message text for
`surveywts_error_primary_not_replicate`, `surveywts_error_control_not_replicate`,
and `surveywts_error_design_not_replicate` is updated to mention
`survey_nonprob` as an additionally accepted type. The tester must:

1. Run the full test suite and let the snapshot failures surface.
2. Run `testthat::snapshot_review()` and inspect each diff individually.
3. Accept each updated snapshot after verifying the new message text matches
   the contract in this test-spec.
4. Commit the updated snapshot files as part of the PR.

---

## Tolerances

No new numerical tolerances are introduced by this change. The existing
tolerance for numerical oracle comparisons (1e-8) applies to any future
numerical correctness tests that add `survey_nonprob` as input.

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass, including new nonprob-path tests
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown scope)
- [ ] `covr::package_coverage()` — >= 95% (target 98%)

All tests touching `calibrate_to_survey()` and `calibrate_to_estimate()` require
`svrep` to be installed. Each `test_that()` block that calls either function must
contain `skip_if_not_installed("svrep")` as the first line inside the block.
