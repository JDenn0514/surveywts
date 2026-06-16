# Test-spec — nps-calibration-path

## Reference oracle

No published reference implementation exists for NPS quasi-randomization
bootstrap or DAGJK variance estimation; there is no oracle package or function
to compare against. Correctness is validated structurally (postcondition
invariants) and analytically (weight conservation, replicate column
structure). Numerical comparisons are within the package only.

## Datasets

### Base synthetic data

All tests use the shared test infrastructure already present in the test
helpers. No new helper functions are required.

### Calibration-only NPS objects (constructed inline in each test)

A calibration-only `survey_nonprob` is constructed as follows:
1. Generate a synthetic NPS data frame using `make_surveywts_data(n = 500, seed = 42)`.
2. Construct a `survey_nonprob` from that data frame with `base_weight` as the
   weight column and a fresh `survey_metadata()`.
3. Call a calibration function on the result with fixed targets (Level A) or
   with `reference_design` set (Level B).

Do NOT call `ipw()` at any point in constructing this fixture.

The primary fixture (`nps_calib_a`, `nps_calib_b`) uses `calibrate_rake()`.
Additional dispatch-coverage fixtures are required to verify routing for all
four supported calibration operations — see the "Dispatch coverage" rows in the
happy-path tables below.

A calibration-only `survey_nonprob` for Level A (fixed targets):

```
nps_data <- make_surveywts_data(n = 500, seed = 42)
nps_base <- surveycore::survey_nonprob(
  data      = nps_data,
  variables = list(weights = "base_weight"),
  metadata  = surveycore::survey_metadata()
)
nps_calib_a <- calibrate_rake(
  nps_base,
  targets = list(
    age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
    sex       = c("M" = 0.49, "F" = 0.51)
  ),
  type = "prop"
)
```

A calibration-only `survey_nonprob` for Level B (targets from reference):

```
ref_data <- make_nps_reference(n = 1000, seed = 123)
nps_calib_b <- calibrate_rake(
  nps_base,
  targets = list(
    age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
    sex       = c("M" = 0.49, "F" = 0.51)
  ),
  type             = "prop",
  reference_design = ref_data
)
```

(`make_nps_reference()` is already defined in the test helpers.)

### Reference design for Level B tests

Use `make_nps_reference(n = 1000, seed = 123)` to produce a `survey_taylor`.
This is the same function already available in the test helpers.

### Existing fixtures for regression tests

The existing `make_nps_level_a()` and `make_nps_level_b()` helper functions
(already defined in the test helpers) produce doubly-robust `survey_nonprob`
objects (IPW + calibration). Use these for regression tests of the
doubly-robust path.

The existing `make_dagjk_datasets()` helper function (already defined in the
test helpers) produces `datasets$A` (IPW-only) and `datasets$B` (doubly-robust
Level A). Use these for regression tests in the DAGJK suite.

### NPS object with empty history

A `survey_nonprob` with no history at all:

```
nps_data <- make_surveywts_data(n = 100, seed = 7)
nps_no_history <- surveycore::survey_nonprob(
  data      = nps_data,
  variables = list(weights = "base_weight"),
  metadata  = surveycore::survey_metadata()
)
```

---

## Per-function test plan

---

### `create_bootstrap_weights()` — `type = "quasi-randomization"`

#### Happy path

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| Calibration-only Level A: returns `survey_nonprob` with repweights | `nps_calib_a`, `replicates = 20L`, `seed = 1L` | Class is `survey_nonprob`; `@variables$repweights` has length 20; each repwt column present in `@data` | structural |
| Calibration-only Level A: `test_invariants()` passes | same | `test_invariants(result)` passes | n/a |
| Calibration-only Level A: history entry appended | same | Last history entry has `operation = "bootstrap_weights"` and `level = "A"` | structural |
| Calibration-only Level A: weight conservation per replicate | same | `sum(result@data[["repwt_1"]])` within 1e-6 of `sum(nps_calib_a@data[["wts"]])` | 1e-6 relative |
| Calibration-only Level B: returns `survey_nonprob` with repweights | `nps_calib_b`, `replicates = 20L`, `seed = 2L`, `reference_sample = ref_data` | Class is `survey_nonprob`; `@variables$repweights` has length 20 | structural |
| Calibration-only Level B: `test_invariants()` passes | same | passes | n/a |
| Calibration-only Level B: history entry records level "B" | same | `entry$level == "B"` | structural |
| Calibration-only Level A: `@data` original columns unchanged | `nps_calib_a`, 20 replicates | Non-repweight columns in `@data` are identical to input | structural |
| Calibration-only: repwt column names are `repwt_1` ... `repwt_B` | `nps_calib_a`, 20 replicates | `result@variables$repweights == paste0("repwt_", seq_len(20))` | structural |
| Seed produces reproducible results | `nps_calib_a`, `seed = 42L`, run twice | Both runs produce identical `repwt_1` vectors | structural |
| Dispatch — `calibrate_linear`: returns `survey_nonprob` with repweights | `survey_nonprob` calibrated via `calibrate_linear()` (Level A targets), `replicates = 10L` | Class is `survey_nonprob`; `@variables$repweights` has length 10 | structural |
| Dispatch — `calibrate_logit`: returns `survey_nonprob` with repweights | `survey_nonprob` calibrated via `calibrate_logit()` (Level A targets), `replicates = 10L` | Class is `survey_nonprob`; `@variables$repweights` has length 10 | structural |
| Dispatch — `poststratify`: returns `survey_nonprob` with repweights | `survey_nonprob` calibrated via `poststratify()` (Level A targets), `replicates = 10L` | Class is `survey_nonprob`; `@variables$repweights` has length 10 | structural |

#### Regression tests (existing paths must be unchanged)

| Scenario | Dataset | Expected |
|----------|---------|----------|
| IPW-only path still works | `make_nonprob_no_repweights()` (IPW-only, from test helpers) | Returns `survey_nonprob` with repweights; no error |
| Doubly-robust path still works (Level A) | `make_nps_level_a()` | Returns `survey_nonprob` with repweights; no error |
| Doubly-robust path still works (Level B) | `make_nps_level_b()` | Returns `survey_nonprob` with repweights; no error |

#### Error paths

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_qr_bootstrap_requires_nonprob` | `type = "quasi-randomization"` with a `survey_taylor` input | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_qr_bootstrap_no_history` | `survey_nonprob` with empty history (`nps_no_history`) | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_qr_bootstrap_no_reference` | `nps_calib_b` (Level B), no `reference_sample` arg, and no reference in history | Construct a `nps_calib_b` variant whose calibration history entry has `reference_design = NULL`; call without `reference_sample`; `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_reference_sample_class` | `reference_sample = data.frame(x = 1)` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_qr_bootstrap_requires_nonprob` — error message fix | `type = "quasi-randomization"` with a `survey_taylor` | Snapshot must NOT contain the phrase "with IPW history" |

#### Warning paths

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_repweights_overwritten` | Call `create_bootstrap_weights()` twice on the same `nps_calib_a` | `expect_warning(class = ...)` on second call; result has new repwt columns only |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| `nps_no_history` (empty history) | `nps_no_history`, `type = "quasi-randomization"` | Error `surveywts_error_qr_bootstrap_no_history` |
| Calibration-only Level A with `reference_sample` supplied | `nps_calib_a`, `reference_sample = ref_data` | No error; `reference_sample` accepted but not used for Level A |
| `replicates = 2L` (minimum allowed) | `nps_calib_a`, `replicates = 2L`, `seed = 1L` | Returns with exactly 2 repweight columns; no error |
| Calibration-only: prior repweights overwritten | Call twice on `nps_calib_a` | Warning `surveywts_warning_repweights_overwritten`; result has the new repweights only |
| Calibration entry with `parameters$targets = NULL` and `parameters$margins = NULL` | Construct a `survey_nonprob` whose last calibration history entry has both fields set to `NULL`; call `create_bootstrap_weights(type = "quasi-randomization", replicates = 5L)` | All 5 draws fail; error `surveywts_error_bootstrap_all_draws_failed`. Pattern: dual `expect_error(class=...)` + `expect_snapshot(error=TRUE)`. |

#### Snapshot cleanup

Before running `devtools::test()` after implementation, delete or update any
snapshot entries for the retired error classes `surveywts_error_qr_bootstrap_no_ipw_history`
in `tests/testthat/_snaps/test-replicate-weights.txt`. Run
`testthat::snapshot_review()` after the first test run to accept the new
snapshots for `surveywts_error_qr_bootstrap_no_history`.

Additionally, the `"i"` bullet text of `surveywts_warning_bootstrap_draws_failed`
is changed in this PR (now path-agnostic rather than IPW-centric). Any existing
snapshot entries for this warning class in
`tests/testthat/_snaps/test-replicate-weights.txt` must be updated via
`testthat::snapshot_review()` to reflect the new text. Do NOT revert the text
change to make the snapshot pass.

#### Invariants

Every `test_that()` block that calls `create_bootstrap_weights()` and assigns
the result to a variable must call `test_invariants(result)` as the first
assertion after the call returns successfully.

---

### `create_group_jackknife_weights()`

#### Happy path

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| Calibration-only Level A: returns `survey_nonprob` with repweights | `nps_calib_a`, `groups = 10L`, `seed = 42L` | Class is `survey_nonprob`; `@variables$repweights` has length 10 | structural |
| Calibration-only Level A: `test_invariants()` passes | same | passes | n/a |
| Calibration-only Level A: replicate column structure | same | Each row has exactly 1 zero and `groups - 1` non-negative values across replicate columns | structural |
| Calibration-only Level A: history entry appended | same | Last entry has `operation = "group_jackknife_weights"` | structural |
| Calibration-only Level A: `@variables$scale`, `rscales`, `mse`, `type` | same | `scale = 9/10`; `rscales = rep(1, 10)`; `mse = TRUE`; `type = "group-jackknife"` | 1e-12 for scale |
| Calibration-only Level A: weight conservation per replicate | same | `sum(result@data[["repwt_1"]][result@data[["repwt_1"]] > 0])` within 1e-6 of `sum(nps_calib_a@data[[wt_col]])` | 1e-6 relative |
| Calibration-only Level B: returns `survey_nonprob` with repweights | `nps_calib_b`, `groups = 10L`, `seed = 42L`, `reference_sample = ref_data` | Class is `survey_nonprob`; `@variables$repweights` has length ≤ 10 | structural |
| Calibration-only Level B: `test_invariants()` passes | same | passes | n/a |
| Calibration-only Level A: `@data` original columns unchanged | `nps_calib_a`, 10 groups | Non-repweight columns in `@data` identical to input | structural |
| Seed produces reproducible results | `nps_calib_a`, `seed = 99L`, run twice | Both runs produce identical `repwt_1` vectors | structural |
| Dispatch — `calibrate_linear`: returns `survey_nonprob` with repweights | `survey_nonprob` calibrated via `calibrate_linear()` (Level A targets), `groups = 10L` | Class is `survey_nonprob`; `@variables$repweights` has length 10 | structural |
| Dispatch — `calibrate_logit`: returns `survey_nonprob` with repweights | `survey_nonprob` calibrated via `calibrate_logit()` (Level A targets), `groups = 10L` | Class is `survey_nonprob`; `@variables$repweights` has length 10 | structural |
| Dispatch — `poststratify`: returns `survey_nonprob` with repweights | `survey_nonprob` calibrated via `poststratify()` (Level A targets), `groups = 10L` | Class is `survey_nonprob`; `@variables$repweights` has length 10 | structural |

#### Regression tests (existing paths must be unchanged)

| Scenario | Dataset | Expected |
|----------|---------|----------|
| IPW-only path still works | `datasets$A` (from `make_dagjk_datasets()`) | Returns `survey_nonprob` with repweights; no error |
| Doubly-robust Level A still works | `datasets$B` (from `make_dagjk_datasets()`) | Returns `survey_nonprob` with repweights; no error |

#### Error paths

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_dagjk_requires_nonprob` | `data = make_taylor_design()` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_dagjk_requires_nonprob` — error message fix | same trigger | Snapshot must NOT contain the phrase "IPW weighting history" |
| `surveywts_error_dagjk_no_history` | `nps_no_history`, `groups = 10L` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_dagjk_no_reference` | `nps_calib_b` with no stored reference and no `reference_sample` arg | Construct `nps_calib_b_no_ref` where the calibration history entry has `reference_design = NULL`; call without `reference_sample`; `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_reference_sample_class` | `reference_sample = data.frame(x = 1)` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_dagjk_groups_invalid` | `groups = "10"` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_dagjk_groups_not_whole_number` | `groups = 10.5` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_dagjk_groups_too_small` | `groups = 1L` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_dagjk_groups_exceeds_n` | `groups = 10000L` with small `nps_calib_a` | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |
| `surveywts_error_dagjk_all_replicates_failed` | Construct a `survey_nonprob` calibrated to tight count targets where every group replicate fails (e.g., a stratum-level count target whose level disappears when any group-sized subset is removed); `groups = 2L` so that both groups fail. Expected: error `surveywts_error_dagjk_all_replicates_failed`. | `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)` |

#### Warning paths

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_dagjk_repweights_overwritten` | Call `create_group_jackknife_weights()` twice on the same `nps_calib_a` | `expect_warning(class = ...)` on second call |
| `surveywts_warning_dagjk_small_groups` | `nps_calib_a` with `groups = 499L` (average group size ≈ 1) | `expect_warning(class = ...)` |
| `surveywts_warning_dagjk_replicates_failed` | Construct a `survey_nonprob` calibrated to targets that produce calibration failure when one group is deleted (e.g., a stratum cell with exactly 1 unit); `groups = 10L` | `expect_warning(class = 'surveywts_warning_dagjk_replicates_failed')`; result still returned with fewer than 10 replicate columns |
| `surveywts_warning_dagjk_negative_replicate_weights` | Construct a `survey_nonprob` calibrated to tight count targets where group deletion forces `calibrate_rake()` to produce negative weights for at least one retained unit | `expect_warning(class = 'surveywts_warning_dagjk_negative_replicate_weights')`; result is returned (not errored) and `@variables$repweights` is non-empty |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| `nps_no_history` | `nps_no_history`, `groups = 10L` | Error `surveywts_error_dagjk_no_history` |
| Calibration-only Level A: groups ceiling uses `n_A` only | `nps_calib_a` (500 rows), `groups = 501L` | Error `surveywts_error_dagjk_groups_exceeds_n` (combined_n = 500 for Level A) |
| Calibration-only Level A with `reference_sample` supplied | `nps_calib_a`, `reference_sample = ref_data` | No error; `reference_sample` accepted but not used |
| Calibration-only: prior repweights overwritten | Call twice on `nps_calib_a` | Warning `surveywts_warning_dagjk_repweights_overwritten`; result has new repweights only |
| `groups = 2L` (minimum) | `nps_calib_a`, `groups = 2L`, `seed = 1L` | Returns with 2 successful (or fewer if one fails) repweight columns; no error unless both fail |

#### Snapshot cleanup

Before running `devtools::test()` after implementation, delete or update any
snapshot entries for the retired error class `surveywts_error_dagjk_no_ipw_history`
in `tests/testthat/_snaps/test-nps-group-jackknife.txt`. Run
`testthat::snapshot_review()` after the first test run to accept the new
snapshots for `surveywts_error_dagjk_no_history`.

#### Invariants

Every `test_that()` block that calls `create_group_jackknife_weights()` and
assigns the result must call `test_invariants(result)` as the first assertion
after the call returns successfully.

---

## Tolerances

| Estimand | Tolerance | Justification |
|----------|-----------|---------------|
| Weight conservation (`sum(repwt) ≈ sum(main_wt)`) | 1e-6 (relative) | Raking is iterative; exact equality not guaranteed; 1e-6 is comfortably within acceptable calibration error |
| `@variables$scale` (DAGJK: `(G-1)/G`) | 1e-12 | Exact arithmetic; tight tolerance appropriate |
| Structural checks (column names, lengths, class membership) | exact (`expect_identical`) | Not numerical; must be exact |

No point estimate or SE oracle comparisons are required: no reference
implementation exists for NPS bootstrap or DAGJK variance.

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] R CMD check --as-cran — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown scope)
- [ ] `covr::package_coverage()` — >= 95% (target 98%)
