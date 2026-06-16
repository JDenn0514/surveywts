# Test-spec — nonprob-repweights

## Reference oracle

- No external numerical oracle is required. Correctness is verified by
  hand-computable properties: weight sums, scale factors, column dimensions,
  class preservation, and Boolean predicate outputs.
- `surveycore::as_survey_nonprob()` is used to construct `survey_nonprob`
  objects with replicate weight columns in tests.

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `make_surveywts_data(n = 200, seed = *)` + manual rep columns | Base data for `survey_nonprob` with repweights |
| `make_replicate_design(seed = *)` | Existing `survey_replicate` fixture; used unchanged for regression tests |
| Inline 5–10-row data frames | Edge cases: empty-repweights, zero-length repweights, single-row, all-outside-bounds |
| `make_surveywts_data(n = 500, seed = *)` | Diagnostic function tests with `survey_replicate` input |

### Standard nonprob-with-repweights fixture

All tests that require a `survey_nonprob` with replicate weight columns
construct it as follows (adapt `seed`, `n_rep`, and `n` as needed):

```r
df <- make_surveywts_data(n = 200, seed = <seed>)
n_rep <- 10L
set.seed(<seed>)
for (j in seq_len(n_rep)) {
  df[[paste0("rep_", j)]] <- df$base_weight *
    exp(stats::rnorm(nrow(df), 0, 0.2))
}
nonprob_rep <- surveycore::as_survey_nonprob(
  df,
  weights    = base_weight,
  repweights = tidyselect::starts_with("rep_"),
  type       = "bootstrap",
  scale      = 1 / n_rep,
  mse        = TRUE
)
```

A variant without repweights (use the public constructor):
```r
nonprob_norep <- surveycore::as_survey_nonprob(
  make_surveywts_data(n = 200, seed = <seed>),
  weights = base_weight
)
```

---

## Per-function test plan

### `.has_repweights` (internal predicate)

> Tests go in `tests/testthat/test-weight-utils.R`.
> The predicate is internal — tests call it directly via `surveywts:::.has_repweights()`.

#### Happy path

| Scenario | Input | Expected |
|----------|-------|----------|
| `survey_nonprob` with 10 rep columns | `nonprob_rep` fixture | `TRUE` |
| `survey_replicate` | `make_replicate_design(seed = 1)` | `TRUE` |
| `survey_nonprob` with `repweights = NULL` | `nonprob_norep` fixture | `FALSE` |
| Plain `data.frame` | `data.frame(x = 1:5, w = 1:5)` | `FALSE` |
| `survey_taylor` | `make_taylor_design(seed = 1)` | `FALSE` |
| `weighted_df` | result of `calibrate_linear(...)` | `FALSE` |

#### Edge cases

| Case | Input construction | Expected |
|------|-------------------|----------|
| `survey_nonprob` with `repweights = character(0)` (zero-length) | `obj <- nonprob_norep; obj@variables <- modifyList(obj@variables, list(repweights = character(0)))` | `FALSE` |
| `survey_nonprob` with a single replicate column | `n_rep = 1L` fixture | `TRUE` |
| `NULL` | `NULL` | `FALSE` (must not throw) |

---

### `trim_weights()` — nonprob-repweights additions

> Tests go in `tests/testthat/test-weight-utils.R`, in a new subsection after
> the existing `trim_weights()` tests.

#### Happy path — class preservation and replicate update

| Scenario | Input | Expected |
|----------|-------|----------|
| `survey_nonprob` with repweights — class preserved | `nonprob_rep` | `S7::S7_inherits(result, surveycore::survey_nonprob)` is `TRUE` |
| `survey_nonprob` with repweights — repweight columns exist in output | same | `data@variables$repweights` columns all present in `result@data` |
| `survey_nonprob` with repweights — replicate column values changed | tight upper bound (90th pct) | `result@data[repweights]` not identical to input `@data[repweights]` |
| `survey_nonprob` with repweights — matrix dimensions preserved | any valid bound | `dim(result@data[repweights]) == dim(input@data[repweights])` |
| `survey_nonprob` without repweights — unaffected | `nonprob_norep`, any bound | no replicate columns to check; `result@variables$repweights` is `NULL` |

**Invariant**: for every test that constructs a `survey_nonprob` result,
`test_invariants(result)` is the first assertion.

#### Numerical correctness

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| Replicate column sums preserved after trimming (90th pct upper, sufficient untrimmed rows) | `nonprob_rep`, `upper = 0.9, type = "percentile"` | `abs(colSums(result_rep[, j]) - colSums(orig_rep[, j])) < tol` for the majority of columns (>50%) | `1e-8` |
| Bounds from main weights applied to rep columns: max(result_rep) <= upper_abs + eps | `nonprob_rep` | `max(as.vector(result_rep)) <= upper_abs + .Machine$double.eps` | — |
| Replicate columns clipped below upper_abs: values above original upper_abs are gone | `nonprob_rep` | all `result_rep` values <= upper_abs + eps | — |
| Main weight trimming is independent of replicate trimming: main weights within [lower_abs, upper_abs] | `nonprob_rep` | `all(main_w <= upper_abs + eps)` | — |
| History entry `upper_abs` is the same as for `survey_replicate` trim | compare `nonprob_rep` vs `make_replicate_design()` with same bounds | `hist_entry$parameters$upper_abs` equal across both | `1e-10` |

#### Weighting history

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| History entry appended after trim | `nonprob_rep`, any valid bound | `length(result@metadata@weighting_history) == length(input@metadata@weighting_history) + 1` | — |
| History entry records correct operation | same | `result@metadata@weighting_history[[n]]$operation == "trim_weights"` where `n` is the new entry | — |
| History entry `upper_abs` matches resolved bound | `nonprob_rep`, absolute `upper = 2` | `result@metadata@weighting_history[[n]]$parameters$upper_abs == 2` | `1e-10` |

#### Warning paths (inherited, unchanged behavior)

| Warning class | Trigger | Pattern |
|---------------|---------|---------|
| `surveywts_warning_no_weights_trimmed` | `nonprob_rep` input with `upper = Inf` (all main weights within bounds) | `expect_warning(class = ...)` |

#### Error paths (inherited, regression — input class unchanged)

No new error classes. These tests verify that all existing errors continue to
fire for `survey_nonprob` inputs:

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_empty_data` | 0-row `survey_nonprob` with repweights | `expect_error(class = ...)` + snapshot |
| `surveywts_error_weights_nonpositive` | `survey_nonprob` with repweights and main weight ≤ 0 | `expect_error(class = ...)` + snapshot |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| All replicate column values outside bounds | Inline fixture: 2-row `nonprob_rep`, bounds set so every rep value is outside | No error; columns clipped to bounds; sum changes (redistribution impossible); no warning emitted for replicate columns |
| Single replicate column | `n_rep = 1L` fixture | `result@data[repweights]` has 1 column; values clipped |
| `survey_nonprob` with `repweights = NULL` — no replicate path taken | `nonprob_norep`, percentile trim | `result@variables$repweights` is `NULL`; no error |
| Main weights within bounds but some replicate column values outside | Inline: set explicit `lower_abs` / `upper_abs` that all main weights satisfy but some rep values violate; trigger via `type = "absolute"` with a tight bound applied only after normalizing main weights | `expect_warning(class = "surveywts_warning_no_weights_trimmed")` fires (main); at least one replicate column value in `result@data[repweights]` differs from input; main weights unchanged |

---

### `stabilize_weights()` — nonprob-repweights additions

> Tests go in `tests/testthat/test-weight-utils.R`, in a new subsection after
> the existing `stabilize_weights()` tests.

#### Happy path — class preservation and replicate update

| Scenario | Input | Expected |
|----------|-------|----------|
| `survey_nonprob` with repweights — class preserved | `nonprob_rep` | `S7::S7_inherits(result, surveycore::survey_nonprob)` is `TRUE` |
| `survey_nonprob` with repweights — replicate column values changed when main weights don't sum to n | `nonprob_rep`, no `by` | at least some `result_rep` values differ from `orig_rep` values |
| `survey_nonprob` without repweights — unaffected | `nonprob_norep` | result is `survey_nonprob`, `@variables$repweights` is `NULL` |

**Invariant**: `test_invariants(result)` is the first assertion for every test
that produces a `survey_nonprob` result.

#### Weighting history

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| History entry appended after stabilize | `nonprob_rep`, no `by` | `length(result@metadata@weighting_history) == length(input@metadata@weighting_history) + 1` | — |
| History entry records correct operation | same | `result@metadata@weighting_history[[n]]$operation == "stabilize_weights"` | — |

#### Numerical correctness — global stabilization

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| Global: `sum(result_main) == n` | `nonprob_rep`, no `by` | `abs(sum(result_main) - n) < tol` | `1e-10` |
| Global: each rep column scaled by `n / sum(main_w)` | `nonprob_rep`, no `by` | `colSums(result_rep) == colSums(orig_rep) * scale_f` | `1e-10` |
| Global: scale factor matches history entry | same | `hist_entry$parameters$scale_factor == n / sum(orig_main)` | `1e-10` |

#### Numerical correctness — per-group stabilization

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| By group: within each group `h`, `sum(result_main[h]) == n_h` | `nonprob_rep`, `by = age_group` | per-group sum check | `1e-10` |
| By group: each group's rep column values scaled by `n_h / W_h` | same | for each group `h` and column `j`: `sum(result_rep[h, j]) == sum(orig_rep[h, j]) * (n_h / W_h)` | `1e-10` |

#### Error paths (regression)

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_empty_data` | 0-row `survey_nonprob` with repweights | `expect_error(class = ...)` + snapshot |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| Main weights already sum to `n` | `nonprob_rep` with artificially normalized weights | Scale factor is `1.0`; replicate columns multiplied by `1.0` (values unchanged) |
| `survey_nonprob` with `repweights = NULL` — no replicate scaling | `nonprob_norep` | no error; result is `survey_nonprob` without repweights |
| Single replicate column | `n_rep = 1L` fixture | one column in `@data` scaled correctly |

---

### Diagnostic functions — `survey_replicate` now accepted

> Tests go in `tests/testthat/test-06-diagnostics.R`, in a new subsection.

The three diagnostic functions (`effective_sample_size()`, `weight_variability()`,
`summarize_weights()`) now accept `survey_replicate` input. Computation is on
the main weight column only.

#### Happy path

| Scenario | Function | Input | Expected |
|----------|----------|-------|----------|
| `survey_replicate` accepted without error | `effective_sample_size()` | `make_replicate_design(seed = 1)` | Returns named numeric `n_eff` with no error |
| `survey_replicate` accepted without error | `weight_variability()` | `make_replicate_design(seed = 1)` | Returns named numeric `cv` with no error |
| `survey_replicate` accepted without error | `summarize_weights()` | `make_replicate_design(seed = 1)` | Returns tibble with no error |
| `survey_replicate` result matches `survey_taylor` with same main weights | `effective_sample_size()` | Both objects share same main weight column | `n_eff` values equal | `1e-10` |

#### Numerical correctness

| Scenario | Dataset | Expected | Tolerance |
|----------|---------|----------|-----------|
| `effective_sample_size()` on `survey_replicate` equals hand calc from main weights | `make_replicate_design(seed = 2)` | `result[["n_eff"]] == sum(w)^2 / sum(w^2)` where `w` = main weight column | `1e-10` |
| `weight_variability()` on `survey_replicate` equals hand calc from main weights | same | `result[["cv"]] == sd(w) / mean(w)` | `1e-10` |

#### Error paths — retired class no longer thrown

| Scenario | Test |
|----------|------|
| `effective_sample_size()` with `survey_replicate` does NOT throw `surveywts_error_replicate_not_supported` | `expect_no_error(effective_sample_size(rep_design))` |
| `weight_variability()` with `survey_replicate` does NOT throw `surveywts_error_replicate_not_supported` | `expect_no_error(weight_variability(rep_design))` |
| `summarize_weights()` with `survey_replicate` does NOT throw `surveywts_error_replicate_not_supported` | `expect_no_error(summarize_weights(rep_design))` |

Note: The snapshot tests that previously captured the
`surveywts_error_replicate_not_supported` message must be deleted from the
snapshot directory (`tests/testthat/_snaps/`) as part of this change. The
tester must run `devtools::test()` and accept the deletion of those snapshots
via `testthat::snapshot_review()`.

#### Regression — pre-existing error paths still fire

| Error class | Trigger | Pattern |
|-------------|---------|---------|
| `surveywts_error_weights_required` | Plain `data.frame` with `weights = NULL` | Both functions — `expect_error(class = ...)` + snapshot |
| `surveywts_error_unsupported_class` | List input | Both functions — `expect_error(class = ...)` + snapshot |

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| `survey_replicate` with `by` grouping in `summarize_weights()` | `make_replicate_design(seed = 1)`, `by = age_group` | Returns grouped tibble; each group row reflects main weight column statistics |
| `survey_replicate` with equal main weights | Inline: all main weights = 1 | `n_eff == n`; `cv == 0` |

---

## Tolerances

| Estimand | Tolerance | Justification |
|----------|-----------|---------------|
| Weight computations (sums, column sums, scale factors) | `1e-10` | Standard for weight operations per package convention |
| ESS and CV against hand calculation | `1e-10` | Exact formula; tolerance matches existing diagnostic tests |
| Replicate column sum preservation | `1e-8` | Redistribution involves floating-point accumulation over multiple columns; `1e-8` is the standard SE tolerance |

No deviations from standard tolerances.

---

## Profile gates

The tester runs ALL gates unless the skip condition applies.

- [ ] `devtools::document()` — NAMESPACE and `man/` unchanged after run
- [ ] `devtools::test()` — all tests pass, including all pre-existing tests in `test-weight-utils.R` and `test-06-diagnostics.R`
- [ ] Snapshot review — any snapshots for `surveywts_error_replicate_not_supported` that appeared in `test-06-diagnostics.R` are deleted; review via `testthat::snapshot_review()` before accepting
- [ ] `devtools::run_examples()` — all `@examples` run clean (no change to examples in scope)
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown scope)
- [ ] `covr::package_coverage()` — ≥ 95% (target 98%); new branches in `.has_repweights()` and the nonprob-repweights output routing must be covered
