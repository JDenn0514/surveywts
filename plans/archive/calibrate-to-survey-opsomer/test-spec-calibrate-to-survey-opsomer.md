# Test-spec — calibrate-to-survey-opsomer

---

## Reference oracle

- `svrep::calibrate_to_sample()` — numerical oracle for validating the
  `targets = NULL, method = "linear"` path; when configured with linear
  calibration, our implementation must match svrep within 1e-8
- `survey::calibrate()` — oracle for per-replicate calibration in the Opsomer
  path; reference for constraint satisfaction
- Manual computation of perturbed totals and `a_r` constants for Opsomer
  correctness tests
- No single svrep function covers the full Opsomer mixed-target path; oracle
  for that path is the formulas restated here in the Numerical Correctness section

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `make_replicate_design(n, seed)` | Primary and control designs with matching variables; produces `survey_replicate` with `@variables$scale` populated |
| `make_nonprob_replicate_design(n, seed)` | `survey_nonprob` with replicate weights and `@variables$scale` populated |
| `make_surveywts_data(n, seed)` | Plain data frames for constructing Taylor designs and edge cases |

All `make_*` functions are defined in `tests/testthat/helper-test-data.R`.
No new helper functions are required; edge-case designs are constructed inline.
The `surveywts_error_scale_not_found` error path uses an inline pattern:
`d <- make_replicate_design(); d$primary@variables$scale <- NULL`.

### Helper function specifications

These two functions must be added to `tests/testthat/helper-test-data.R`.

**`make_replicate_design(n = 400, R = 50, seed = 42)`**

Returns a named list with elements:
- `primary` — a `survey_replicate` with:
  - `@data` containing columns: `id` (integer), `age_group` (character,
    `"18-34"` / `"35-54"` / `"55+"`), `sex` (character, `"M"` / `"F"`),
    `education` (character), `base_weight` (numeric, positive)
  - `@variables$weights` = `"base_weight"`
  - `@variables$repweights` — a list of `R` numeric vectors, each of length `n`
  - `@variables$scale` = `1 / R` (the standard bootstrap scale factor)
  - `@variables$rscales` — a numeric vector of `R` ones
  - `@variables$type` = `"bootstrap"`
- `control` — a second `survey_replicate` of the same structure with the same
  columns, same `R`, and the same `@variables$scale`. The control design must
  share column names with `primary` (so `variables` can be resolved in both).
  Use a different random seed for the control data rows to simulate a distinct
  sample.

Both designs must have `@variables$scale` non-NULL. Construct using
`create_bootstrap_weights()` or by building the `survey_replicate` directly.

**`make_nonprob_replicate_design(n = 200, R = 30, seed = 99)`**

Returns a `survey_nonprob` with:
- `@data` containing the same columns as `make_replicate_design()` primary
- `@variables$weights` = `"base_weight"` with all positive weights
- `@variables$repweights` — a list of `R` numeric vectors
- `@variables$scale` = `1 / R`
- `@variables$type` = `"bootstrap"`

Construct by creating a `survey_nonprob` from `make_surveywts_data()` then
adding replicate weights (e.g., by calling `create_bootstrap_weights()` and
transferring the `@variables$repweights`, `@variables$scale`, and
`@variables$rscales` slots).

---

## Per-function test plan

### `calibrate_to_survey()` — `targets = NULL` path (Opsomer with no fixed margins)

These tests confirm the Opsomer path runs correctly when no fixed margins are
supplied. The default behavior changes from the previous svrep delegation
(linear GREG) to rake with classic_ipf; the svrep comparison tests use
`method = "linear"` for a like-for-like check. All happy-path and history tests
run unconditionally. Place `skip_if_not_installed("svrep")` inside only the
**Numerical comparison with svrep oracle** test blocks that actually call
`svrep::calibrate_to_sample()`.

**Happy path:**

| Scenario | Input | Expected | Assertion |
|----------|-------|----------|-----------|
| Returns same class as primary (replicate) | `make_replicate_design()`, no `targets` | `survey_replicate` | `S7::S7_inherits(result, survey_replicate)` |
| Returns same class as primary (nonprob) | `make_nonprob_replicate_design()`, no `targets` | `survey_nonprob` | `S7::S7_inherits(result, survey_nonprob)` |
| Weights change after calibration | `make_replicate_design(n=200)`, `variables = c(sex)` | At least some weights differ from input | `expect_false(identical(...))` |
| History entry operation | `make_replicate_design(n=200)` | `last$operation == "calibrate_to_survey"` | `expect_identical` |
| `type` argument ignored when `targets = NULL` | Supply `type = "prop"`, `targets = NULL` | No error; result is valid | `test_invariants(result)` |
| History records `a_constants` when `targets = NULL` | `R=50`, `R_C=50`, `targets = NULL` | `length(params$a_constants) == 50` (= R_eff when K=1) | `expect_identical` |
| History records `K = 1L` when `targets = NULL` | Standard case, `R_C <= R` | `params$K == 1L` | `expect_identical` |
| History does NOT record `fixed_variables` when `targets = NULL` | `targets = NULL` | `is.null(params$fixed_variables)` | `expect_true` |
| History does NOT record `targets` field when `targets = NULL` | `targets = NULL` | `is.null(params$targets)` | `expect_true` |
| History does NOT record `type` field when `targets = NULL` | `targets = NULL` | `is.null(params$type)` | `expect_true` |

**Numerical comparison with svrep oracle:**

| Scenario | Input | Expected | Tolerance |
|----------|-------|----------|-----------|
| `method = "linear"` weights match `svrep::calibrate_to_sample()` | `n=200`, `control_col_matches` fixed, `targets = NULL`, `method = "linear"` | Matches svrep | 1e-8 |
| `method = "rake"` (default) differs from `svrep::calibrate_to_sample()` | `n=200`, `targets = NULL` | Differs from svrep (different method — expected) | Not applicable |
| Default call satisfies control-survey totals | `n=200`, `targets = NULL`, defaults | Full-sample calibrated weights satisfy `t̂_{Cx}` | 1e-6 |

---

### `calibrate_to_survey()` — Opsomer path (`targets` non-NULL)

`test_invariants(result)` is the first assertion in every test that constructs
a design object. `skip_if_not_installed("svrep")` is not required for this
section — the function no longer delegates to svrep. Place it inside only those
test blocks (e.g., mock tests) that explicitly call svrep functions.

**Happy path:**

| Scenario | Input | Expected | Assertion |
|----------|-------|----------|-----------|
| Returns `survey_replicate` when primary is `survey_replicate` | `make_replicate_design()`, `targets` list with one variable | `survey_replicate` | `S7::S7_inherits(result, survey_replicate)` |
| Returns `survey_nonprob` when primary is `survey_nonprob` | `make_nonprob_replicate_design()`, `targets` non-NULL | `survey_nonprob` | `S7::S7_inherits(result, survey_nonprob)` |
| Data dimensions unchanged | `n=200`, one `targets` variable | Same nrow and ncol as primary | `expect_identical(nrow, ncol)` |
| History entry operation | `n=200`, `targets` non-NULL | `last$operation == "calibrate_to_survey"` | `expect_identical` |
| History grows by exactly 1 | `n=200`, `targets` non-NULL | Pre-call length + 1 | `expect_identical(n_after - n_before, 1L)` |
| History records `fixed_variables` | `targets = list(age_group = ...)` | `params$fixed_variables == "age_group"` | `expect_identical` |
| History records `a_constants` as numeric vector length `R_eff = R` when `K = 1` | `R=50` replicates, `R_C=50` | `length(params$a_constants) == 50` | `expect_identical` |
| History records `a_constants` as numeric vector length `R_eff = K * R` when `K > 1` | `R=30`, `R_C=50`, `K=2` | `length(params$a_constants) == 60` (= 2 × 30) | `expect_identical` |
| History records `K = 1L` when `R_C <= R` | `R=50`, `R_C=50` | `params$K == 1L` | `expect_identical` |
| History records `K > 1L` when `R_C > R` | `R=30`, `R_C=50` | `params$K == 2L` (`ceiling(50/30)`) | `expect_identical` |
| History records `type` | Supply `type = "count"` | `params$type == "count"` | `expect_identical` |
| `type = "prop"` accepted | Supply proportions summing to 1 | No error; valid result | `test_invariants(result)` |
| `type = "count"` accepted | Supply counts > 0 | No error; valid result | `test_invariants(result)` |
| Format B (tibble) targets accepted | `targets = list(age_group = tibble(age_group = c("18-34","35-54","55+"), n = c(12000L, 15000L, 10000L)))`, `type = "count"` | No error; result satisfies fixed margin | `test_invariants(result)` + `expect_equal(sum_by_level, targets_counts, tolerance = 1e-6)` |
| Mixed-format targets accepted | One element Format A (named vector), one element Format B (tibble), `type = "count"` | No error; both fixed margins satisfied | `test_invariants(result)` + `expect_equal` on both margin sums |
| `reference_design` stored in history | Supply valid `survey_taylor` | `!is.null(params$reference_design)` | `expect_true` |
| `control_col_matches` not in history | Supply via `control` | `!"control_col_matches" %in% names(params$control)` | `expect_false` |
| Replicate weight columns preserve names | `primary` has named rep columns | Output rep column names == input rep column names | `expect_identical(result@variables$repweights, orig_names)` |

**`a_r` constants correctness:**

| Scenario | Input | Expected | Tolerance |
|----------|-------|----------|-----------|
| `a_r = sqrt(A_C / A)` for all `r` when `R == R_C` | `R = R_C = 50`, `A = 1/50`, `A_C = 1/50` | All `a_r == 1.0` | 1e-10 |
| `a_r == 0` for `r > R_C` when `R > R_C` | `R = 60`, `R_C = 50` | `a_constants[51:60]` all zero | `expect_equal(..., 0, tolerance = 1e-10)` |
| `a_r > 0` for `r <= R_C` when `R > R_C` | `R = 60`, `R_C = 50` | `a_constants[1:50]` all `== sqrt(A_C / A_eff)` | 1e-10 |
| `K = ceiling(R_C / R)` when `R_C > R` | `R = 30`, `R_C = 50` | `K == 2L` | `expect_identical` |
| `A_eff = A / K` used in `a_r` computation when `R_C > R` | `R = 30`, `R_C = 50`, `A = 1/30` | `a_r == sqrt(A_C / (A/2))` | 1e-10 |

**Numerical correctness — Opsomer path:**

These tests construct the perturbed target manually and compare against the
function output.

| Scenario | Description | Assertion | Tolerance |
|----------|-------------|-----------|-----------|
| Full-sample fixed-margin constraint satisfied | After calibration, `sum(w_i[v == lev])` equals `T_fixed[[v]][[lev]]` for every level of every `targets` variable | `expect_equal` | 1e-6 (raking convergence tolerance) |
| Full-sample random-margin constraint satisfied | After calibration, `sum(w_i[v == lev])` equals `t̂_{Cx}[[v]][[lev]]` for every level of every `variables` variable | `expect_equal` | 1e-6 |
| Per-replicate fixed-margin constraint | For at least one replicate `r`, check that calibrated replicate weights satisfy the fixed margin to within raking tolerance | `expect_equal` | 1e-4 (raking may not converge to tight tolerance on small replicates) |
| `type = "prop"` conversion uses original primary weights as N | Supply `type = "prop"` proportions; manually compute `N = sum(original primary weights)` and verify that `N × proportion[lev]` equals the calibrated full-sample total for each level of each `targets` variable | `expect_equal` | 1e-6 |
| Per-replicate calibration starts from original replicate weights | For one replicate `r`, confirm that the calibrated replicate weights `w_i^*(r)` differ from the calibrated full-sample weights `w_i^*` by more than raking tolerance (i.e., replicate calibration did not start from `w_i^*`) | `expect_false(isTRUE(all.equal(..., tolerance = 1e-4)))` | — |
| Variance increase for non-calibration variable | Variance of a variable NOT in `variables` or `targets` computed from replicate weights is >= variance from uncalibrated design | `expect_gte(var_opsomer, var_uncal * 0.5)` — see GAP below | relaxed |

> **GAP: variance increase test.** The property that Opsomer calibration
> increases (or at least does not drastically reduce) variance for
> non-calibration variables is a distributional property of the method, not
> guaranteed in small samples or for specific random seeds. The recommended
> approach: construct a test with large `n` and `R` where this property holds
> with high probability, or validate only that the replicate weights differ
> from the pre-calibration replicates (i.e., calibration changed something).
> A strict `expect_gte` on variance may be fragile. The tester should run this
> test at `n = 500`, `R = 200` with a fixed seed and visually confirm the
> property holds once, then pin the specific values as a snapshot or numerical
> comparison. If the property cannot be confirmed in that configuration, mark
> this test row as out of scope with a comment.

**Gotcha coverage:**

| Gotcha from comprehension | Test row | Scope |
|---------------------------|----------|-------|
| Fixed targets treated as invariant (not perturbed across replicates) | Construct perturbed totals manually for a given `r`; verify the fixed margin column in the combined target equals `T_fixed` unchanged | In scope |
| `A` and `A_C` from `@variables$scale` not `rscales` | Set `@variables$scale = NULL` after design construction; confirm `surveywts_error_scale_not_found` fires | In scope |
| svrep not used in any code path | Mock `svrep::calibrate_to_sample` to throw an error; confirm no error is raised from any valid call (both `targets = NULL` and non-NULL) | In scope — mock test |
| `R > R_C` replicates: `a_r = 0` for `r > R_C` | Construct designs with `R = 60, R_C = 50`; inspect `params$a_constants` | In scope |
| `R_C > R` expansion: repeat primary, don't drop control | Construct `R = 30, R_C = 50`; confirm `K = 2L` in history; confirm output has `R = 30` replicate columns (not 50) | In scope |
| Perturbed totals inconsistent with fixed totals — convergence failure | Construct a pathological case where the perturbed random margin and the fixed margin are contradictory (e.g., rows summing to different totals); confirm `surveywts_error_calibration_not_converged` or `surveywts_error_calibration_failed` is raised | In scope |
| Near-zero cells in replicate weights expected, not bugs | For `R > R_C` replicates where `a_r = 0`, perturbed total equals full-sample total; calibration should not introduce divergence; confirm result has no `Inf` or `NaN` replicate weights | In scope |
| `control_col_matches` is random by default | Call without `control_col_matches`; run twice with different `set.seed()` values; confirm full-sample calibrated weights are identical (Step 6 uses full-sample control totals `t̂_{Cx}` directly and does not depend on `control_col_matches`, so full-sample calibration is always deterministic) but replicate calibrated weights differ across calls because the control replicate assignment changes with the seed | In scope |
| `control_col_matches` is fixed when supplied | Supply fixed `control_col_matches`; run twice without `set.seed()`; all weights are identical (deterministic) | In scope |

---

**Error paths:**

Every error class gets `expect_error(class = ...)` AND `expect_snapshot(error = TRUE)` (dual pattern). No section-wide skip required; place `skip_if_not_installed("svrep")` only inside blocks that call svrep functions directly.

| Error class | Trigger | Dual pattern |
|-------------|---------|--------------|
| `surveywts_error_scale_not_found` | Set `primary_design@variables$scale <- NULL`; `targets` non-NULL | Yes |
| `surveywts_error_scale_not_found` | Set `control_design@variables$scale <- NULL`; `targets` non-NULL | Yes |
| `surveywts_error_scale_not_found` | Set `primary_design@variables$scale <- NULL`; `targets = NULL` | Yes — fires on all calls, not only when `targets` non-NULL |
| `surveywts_error_targets_not_named_list` | `targets = list(c(1000, 2000))` (unnamed element) | Yes |
| `surveywts_error_targets_not_named_list` | `targets = list()` (empty list) | Yes |
| `surveywts_error_targets_not_named_list` | `targets = c(age = 1000)` (not a list at all) | Yes |
| `surveywts_error_targets_variable_not_found` | `targets = list(nonexistent_col = c(a = 100))` | Yes |
| `surveywts_error_targets_element_invalid` | `targets = list(sex = "not_a_vector")` | Yes |
| `surveywts_error_targets_element_invalid` | `targets = list(sex = c(100, 200))` (unnamed vector) | Yes |
| `surveywts_error_targets_totals_invalid` | `type = "count"`, a level total is `0` | Yes |
| `surveywts_error_targets_totals_invalid` | `type = "count"`, a level total is negative | Yes |
| `surveywts_error_targets_totals_invalid` | `type = "count"`, a level total is `NA` | Yes |
| `surveywts_error_targets_totals_invalid` | `type = "prop"`, proportions sum to 1.1 (not 1) | Yes |
| `surveywts_error_control_level_missing` | `variables` variable has a level in `primary_design@data` that is absent from `control_design@data` (with `targets = NULL`) | Yes |
| `surveywts_error_control_level_missing` | Same condition when `targets` non-NULL | Yes |
| `surveywts_error_calibration_not_converged` (Opsomer path) | Mock `.calibrate_engine()` to emit a convergence warning during per-replicate calibration with `targets` non-NULL | Yes |
| `surveywts_error_calibration_failed` (Opsomer path) | Mock `.calibrate_engine()` to throw a hard error during per-replicate calibration with `targets` non-NULL | Yes |

Existing error classes must continue to fire on the same triggers (tested with `targets = NULL`):

| Error class | Trigger | Dual pattern |
|-------------|---------|--------------|
| `surveywts_error_primary_not_replicate` | `primary_design` is a plain `data.frame` | Yes (regression guard) |
| `surveywts_error_primary_no_repweights` | `primary_design` is `survey_nonprob` with no rep weights | Yes (regression guard) |
| `surveywts_error_control_not_replicate` | `control_design` is `survey_taylor` | Yes (regression guard) |
| `surveywts_error_control_no_repweights` | `control_design` is `survey_nonprob` with no rep weights | Yes (regression guard) |
| `surveywts_error_reference_design_not_taylor` | `reference_design` is a `survey_replicate` | Yes (regression guard) |
| `surveywts_error_unit_scale_invalid` | `unit_scale = "bad"` | Yes (regression guard) |
| `surveywts_error_variables_not_found` | `variables = c(nonexistent_var)` | Yes (regression guard) |

**Warning paths:**

| Warning class | Trigger | Assertion |
|---------------|---------|-----------|
| `surveywts_warning_control_param_ignored` | `control = list(bad_param = 99)` with `targets` non-NULL | `expect_warning(class = ...)` wrapping result; result is a valid design |
| `surveywts_warning_control_param_ignored` | `control = list(bad_param = 99)` with `targets = NULL` | Existing behavior regression guard |
| `surveywts_warning_replicate_scheme_mismatch` | `control_design@variables$type <- "JK1"` with `targets` non-NULL | `expect_warning(class = ...)` |
| `surveywts_warning_negative_calibrated_weights` | `method = "linear"`, Opsomer path produces negative full-sample weight (mock `survey::calibrate()` to return negative pweight) | `expect_warning(class = ...)` + full-sample weights all positive after clipping |

**Edge cases:**

| Case | Input | Expected behavior |
|------|-------|-------------------|
| `targets = NULL`, `type = "prop"` supplied | `type = "prop"`, `targets = NULL` | No error; `type` is matched by `rlang::arg_match()` but otherwise ignored; result identical to calling with neither argument |
| `targets` variable overlaps with `variables` | Same variable in both `variables` and `targets` | No error; calibration runs using the fixed margin from `targets` for that variable |
| `targets` has a single variable with one level | `targets = list(sex = c(F = 10000))` | No error if proportions/counts are valid; calibration proceeds |
| `unit_scale` non-NULL with Opsomer path | Supply valid `unit_scale`; `targets` non-NULL | No error; `unit_scale` passed to each `.calibrate_engine()` call; result is a valid design |
| Both `variables` and `targets` are the same set | All control-margin variables also have fixed margins | No error; fixed margins take precedence; result satisfies `T_fixed` |
| R and R_C are both 2 (minimum replicate count) | `R = 2`, `R_C = 2` | No error; `K = 1L`, `a_r = sqrt(A_C / A)` for both replicates; result is valid |
| `R = 1` (single primary replicate) | `R = 1`, `R_C = 50` | `K = 50`; method still runs; result has 1 replicate column |
| `targets` supplied with `method = "logit"` | `method = "logit"`, finite `bounds`, valid `targets` | No error; `survey::calibrate()` uses logit calfun per replicate |
| `targets` supplied with `method = "linear"` | `method = "linear"`, valid `targets` | No error; result is valid; negative replicate weights are NOT clipped |
| `algorithm` silently ignored when `method = "linear"` | `method = "linear"`, `algorithm = "nr"`, `targets` non-NULL | No error; result identical to same call without `algorithm` argument | `expect_equal(result_with_alg@variables$repweights, result_without_alg@variables$repweights, tolerance = 1e-10)` |
| `a_r = 0` case: perturbed total equals full-sample total | Force `a_r = 0` by making `R > R_C`; check replicates `r > R_C` | Calibrated replicate weights for those replicates satisfy the combined target (using full-sample control totals, not perturbed) |
| Negative replicate weights do NOT trigger `surveywts_warning_negative_calibrated_weights` | `method = "linear"`, `targets` non-NULL; calibration produces some negative replicate weights while full-sample weights remain positive | No warning raised; result is a valid design; at least one replicate weight is negative | `expect_no_warning(result <- calibrate_to_survey(...))` + `expect_true(any(unlist(result@variables$repweights) < 0))` |

---

## Tolerances

| Estimand | Tolerance | Justification |
|----------|-----------|---------------|
| Full-sample constraint satisfaction (fixed margins) | 1e-6 | Raking convergence tolerance; tighter than `control$epsilon = 1e-7` to confirm actual convergence |
| Full-sample constraint satisfaction (random margins) | 1e-6 | Same |
| Per-replicate constraint satisfaction | 1e-4 | Small per-replicate designs may not reach tight tolerance |
| `a_r` value correctness | 1e-10 | Pure arithmetic on known scalars |
| svrep comparison (`targets = NULL`, `method = "linear"`) | 1e-8 | Validates our Opsomer implementation against svrep's linear calibration |
| `K` and `R` counts | exact integer | `expect_identical` |
| `A_eff` correctness | 1e-10 | Pure arithmetic |

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown scope per roadmap)
- [ ] `covr::package_coverage()` — ≥ 95% (target 98%)
