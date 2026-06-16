# Test-spec — jackknife-merge

---

## Reference oracle

- `survey::as.svrepdesign` (survey >= 4.2) — JKn and JK1 replicate counts and
  weight structure
- `svrep::as_random_group_jackknife_design` (svrep >= 0.6) — grouped
  jackknife for probability designs

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `gss_2024_svy` (package data) | Happy path for `type = "jkn"` and `type = "grouped"` + `survey_taylor`; numerical oracle for replicate count |
| `ns_wave1_svy` (package data) | Happy path for `type = "grouped"` + `survey_nonprob` (DAGJK calibration-only Level A) |
| Inline constructions | All error paths, warning paths, and edge cases |

---

## Scope

Functions under test:
- `create_jackknife_weights()` — all four dispatch paths
- `create_replicate_weights()` — dispatcher changes (removal of
  `"group-jackknife"`, pass-through of `type = "grouped"`)

---

## Per-function test plan

### `create_jackknife_weights()`

---

#### Happy path

| Scenario | Dataset | Assertion |
|----------|---------|-----------|
| `type = "jkn"`, `survey_taylor` | `gss_2024_svy` | Returns `survey_replicate`; `@variables$type == "JKn"`; replicate count equals sum of PSU counts per stratum; `@metadata@weighting_history` last entry has `operation == "replicate_creation"`, `method == "jackknife"`, `parameters$type == "jkn"` |
| `type = "jk1"`, `survey_taylor` | `gss_2024_svy` | Returns `survey_replicate`; `@variables$type == "JK1"`; replicate count equals number of rows; history entry `operation == "replicate_creation"`, `method == "jackknife"`, `parameters$type == "jk1"` |
| `type = "grouped"`, `survey_taylor` | `gss_2024_svy`, `replicates = 20L` | Returns `survey_replicate`; `@variables$type == "random-group"`; `ncol` of replicate matrix equals 20; history entry `operation == "replicate_creation"`, `method == "jackknife"`, `parameters$type == "grouped"`, `parameters$replicates == 20L` |
| `type = "grouped"`, `survey_nonprob`, calibration-only Level A | `ns_wave1_svy`, `replicates = 50L, seed = 42` | Returns `survey_nonprob`; `@variables$type == "group-jackknife"`; `length(@variables$repweights) == 50L` (assuming all succeed); `@variables$mse == TRUE`; `@variables$scale == 49/50`; history entry `operation == "jackknife_weights"`, `parameters$type == "grouped"` |

For every block that constructs a returned object, call `test_invariants(obj)`
as the first assertion (applies to the `survey_nonprob` DAGJK output; does not
apply to `survey_replicate` output).

---

#### Numerical correctness

| Scenario | Dataset | Oracle | Tolerance |
|----------|---------|--------|-----------|
| JKn replicate count matches `survey::as.svrepdesign` | `gss_2024_svy` | `ncol(as.matrix(survey::as.svrepdesign(gss_svydesign, type = "JKn")$repweights))` | Exact integer equality |
| JK1 replicate count matches `survey::as.svrepdesign` | `gss_2024_svy` | `ncol(as.matrix(survey::as.svrepdesign(gss_svydesign, type = "JK1")$repweights))` | Exact integer equality |
| JKn scale factor matches `survey::as.svrepdesign` | `gss_2024_svy` | `survey::as.svrepdesign(gss_svydesign, type = "JKn")$scale` | `1e-10` |
| DAGJK scale factor equals `(G_success - 1) / G_success` when all succeed | `ns_wave1_svy`, `replicates = 10L, seed = 1` | `9 / 10` | `1e-10` |

Both oracle tests use `skip_if_not_installed("survey")` inside the
`test_that()` block.

---

#### Argument behavior

**`replicates` silently ignored for `type = "jkn"` and `type = "jk1"`**

```
test_that("replicates is silently ignored for type = 'jkn'")
test_that("replicates is silently ignored for type = 'jk1'")
```
- Supply `replicates = 99L` alongside `type = "jkn"` (or `"jk1"`) on a
  `survey_taylor` input.
- Expect no error, no warning.
- The returned `survey_replicate` replicate count is determined by the PSU
  structure, not by 99.

**`seed` silently ignored for `type = "jkn"` and `type = "jk1"`**

```
test_that("seed is silently ignored for type = 'jkn'")
```
- Supply `seed = 42` with `type = "jkn"`. Expect no error, no warning.

**`mse = FALSE` overridden to `TRUE` for DAGJK**

```
test_that("mse = FALSE is warned and overridden to TRUE for DAGJK path")
```
- Use a `survey_nonprob` input (inline) with calibration history.
- Call with `type = "grouped"`, `replicates = 10L`, `mse = FALSE`.
- Assert `expect_warning(..., class = "surveywts_warning_jackknife_mse_overridden")`.
- Capture return value; assert `result@variables$mse == TRUE`.

**svrep arguments warned and ignored for `survey_nonprob`**

```
test_that("var_strat non-NULL warns jackknife_svrep_args_ignored for nonprob")
test_that("adj_method non-default warns jackknife_svrep_args_ignored for nonprob")
test_that("multiple non-default svrep args emit only one warning")
```
- For each: use inline `survey_nonprob` input with calibration history.
- `var_strat = "region"`: expect exactly one `surveywts_warning_jackknife_svrep_args_ignored`.
- `adj_method = "variance-units"`: same.
- `var_strat = "region"` + `sort_var = "age"` together: expect one warning, not two.
- For all: returned object has the same `@variables` regardless of the ignored args.

**`adj_method` at its default does not warn**

```
test_that("adj_method at default value does not warn for nonprob")
```
- `adj_method = "variance-stratum-psus"` (default) with `survey_nonprob` input.
- Expect no `surveywts_warning_jackknife_svrep_args_ignored`.

**`reference_sample` silently ignored for `type = "jkn"`**

```
test_that("reference_sample is silently ignored for type = 'jkn'")
```
- Supply a valid `survey_taylor` as `reference_sample` alongside
  `type = "jkn"` on a `survey_taylor` input. Expect no error, no warning.

**`seed` controls reproducibility for DAGJK**

```
test_that("seed produces reproducible DAGJK replicates")
```
- Call twice with the same `seed`; assert replicate weight columns are
  identical (`expect_identical`).
- Call with different seeds; assert replicate columns differ.

---

#### Error paths

Every error path test uses the dual pattern: one `expect_error(class = ...)` and
one `expect_snapshot(error = TRUE, ...)`.

| Error class | Trigger | Setup |
|-------------|---------|-------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` | `create_jackknife_weights(data.frame(x = 1:5, w = 1))` |
| `surveywts_error_already_replicate` | `data` is `survey_replicate` | Use inline `survey_replicate` object |
| `surveywts_error_jackknife_type_nonprob_only` (`type = "jkn"`) | `survey_nonprob` + `type = "jkn"` | Inline `survey_nonprob` with any history |
| `surveywts_error_jackknife_type_nonprob_only` (`type = "jk1"`) | `survey_nonprob` + `type = "jk1"` | Inline `survey_nonprob` with any history |
| `surveywts_error_jackknife_replicates_required` (`survey_taylor`) | `type = "grouped"`, `replicates = NULL`, `survey_taylor` input | Use `gss_2024_svy` |
| `surveywts_error_jackknife_replicates_required` (`survey_nonprob`) | `type = "grouped"`, `replicates = NULL`, `survey_nonprob` input | Inline `survey_nonprob` with calibration history |
| `surveywts_error_jackknife_replicates_invalid` | `replicates = "fifty"` with DAGJK path | Inline `survey_nonprob` |
| `surveywts_error_replicates_not_whole_number` | `replicates = 5.5` with DAGJK path | Inline `survey_nonprob` |
| `surveywts_error_jackknife_replicates_too_small` | `replicates = 1L` with DAGJK path | Inline `survey_nonprob` |
| `surveywts_error_jackknife_replicates_exceeds_n` | `replicates` > combined row count with DAGJK path | Inline `survey_nonprob` with small `n` (e.g., 5 rows); `replicates = 10L` |
| `surveywts_error_reference_sample_class` | `reference_sample` is a `data.frame` | DAGJK path; inline setup |
| `surveywts_error_jackknife_no_history` | `survey_nonprob` with no IPW or calibration history | Inline `survey_nonprob` with empty weighting history |
| `surveywts_error_jackknife_no_reference` (IPW path) | IPW history entry with no stored reference and `reference_sample = NULL` | Inline `survey_nonprob` with `ipw()` history entry but no reference stored |
| `surveywts_error_jackknife_no_reference` (Level B) | Calibration history entry with `targets_from_reference = TRUE` and no reference | Inline `survey_nonprob` with calibration history, `targets_from_reference = TRUE` |
| `surveywts_error_jackknife_all_replicates_failed` | All replicates fail | Use an inline `survey_nonprob` engineered to cause every replicate to fail (e.g., calibration targets impossible to meet on any leave-one-group-out subset); or mock the engine |

For `surveywts_error_jackknife_degenerate_replicate`: this error is caught
inside the replicate loop and does not surface to the user directly; it is
counted as a failed replicate. No direct dual-pattern test is required for
it. It is exercised indirectly via the
`surveywts_error_jackknife_all_replicates_failed` scenario (when all reps fail,
the degenerate replicate error is the mechanism of failure in the loop).

---

#### Warning paths

Every warning path test uses `expect_warning(class = ...)` wrapping the call.
Capture the return value and assert on it separately.

| Warning class | Trigger | Additional assertion |
|---------------|---------|----------------------|
| `surveywts_warning_jackknife_mse_overridden` | `mse = FALSE`, DAGJK path | `test_invariants(result)`; `result@variables$mse == TRUE` |
| `surveywts_warning_jackknife_svrep_args_ignored` | `var_strat = "x"`, DAGJK path | `test_invariants(result)`; return value is a valid `survey_nonprob` |
| `surveywts_warning_jackknife_repweights_overwritten` | DAGJK path; call twice on the same object | `test_invariants(result)`; returned object has the new replicate count |
| `surveywts_warning_jackknife_small_groups` | `replicates` chosen so `floor(combined_n / replicates) < 5` | `test_invariants(result)`; function still returns a result |
| `surveywts_warning_jackknife_replicates_failed` | > 10% of replicates fail | `test_invariants(result)`; `G_success` < `replicates`; scale = `(G_success-1)/G_success`; `length(result@variables$repweights) == G_success` |
| `surveywts_warning_jackknife_negative_replicate_weights` | Post-calibration negative replicate weights | `test_invariants(result)`; at least one replicate weight column has a negative value |

---

#### Edge cases

| Case | Input | Expected behavior |
|------|-------|-------------------|
| `replicates = 50.0` (double) on DAGJK path | Inline `survey_nonprob`, `replicates = 50.0` | `test_invariants(result)`; no error; `result@variables$scale == 49/50` |
| `replicates = 2L` (minimum) on DAGJK path | Inline `survey_nonprob` | `test_invariants(result)`; succeeds; `length(result@variables$repweights) == 2` |
| `replicates = 1L` on DAGJK path | Inline `survey_nonprob` | `surveywts_error_jackknife_replicates_too_small` |
| `mse = TRUE` (explicit default) on DAGJK path | Inline `survey_nonprob` | No warning; `result@variables$mse == TRUE` |
| `seed = NULL`, DAGJK | Inline `survey_nonprob` | No error; two calls may produce different replicates (non-deterministic) |
| All svrep args at default for `survey_nonprob` | `var_strat = NULL, sort_var = NULL, adj_method = "variance-stratum-psus"` etc. | No `surveywts_warning_jackknife_svrep_args_ignored` emitted |
| `type = "grouped"`, `survey_nonprob`, history has both IPW entry and calibration entry | Inline `survey_nonprob` | Routes to IPW (doubly-robust) path; `test_invariants(result)` |
| `type = "grouped"`, `survey_nonprob`, calibration-only Level A (no reference needed) | `ns_wave1_svy` or inline equivalent | Succeeds without `reference_sample`; `test_invariants(result)` |
| `...` non-empty | `create_jackknife_weights(data, "jkn", extra = 1)` | Error from `rlang::check_dots_empty()` |
| `type = "jkn"`, `survey_taylor` with no strata | Inline `survey_taylor` with no strata column | Succeeds (backend auto-selects JK1 behavior internally if no strata); confirmed by `survey::as.svrepdesign` oracle |

---

### `create_replicate_weights()` — dispatcher changes

**Pass-through test: `type = "grouped"` reaches the jackknife engine**

```
test_that("create_replicate_weights(method = 'jackknife', type = 'grouped') dispatches to create_jackknife_weights()")
```
- Call with a `survey_nonprob` that has calibration history, `method = "jackknife"`,
  `type = "grouped"`, `replicates = 10L`, `seed = 1`.
- Assert the returned object is a `survey_nonprob` (DAGJK output class).
- Assert `@variables$type == "group-jackknife"`.

**Retired `"group-jackknife"` method errors**

```
test_that("create_replicate_weights(method = 'group-jackknife') errors")
```
- Call with any valid `survey_nonprob` input.
- Expect error from `rlang::arg_match()` — `"group-jackknife"` is no longer a
  valid `method` choice.
- Use dual pattern: `expect_error(class = ...)` and `expect_snapshot(error = TRUE, ...)`.
- The error class is whatever `rlang::arg_match()` emits; no custom
  surveywts class is required here.

---

## History entry validation

For each dispatch path, a dedicated block asserts the exact structure of the
last history entry appended:

| Path | `operation` | `method` | `parameters$type` | Key fields |
|------|-------------|----------|-------------------|------------|
| JKn | `"replicate_creation"` | `"jackknife"` | `"jkn"` | `parameters$mse` is the value passed |
| JK1 | `"replicate_creation"` | `"jackknife"` | `"jk1"` | `parameters$mse` is the value passed |
| Grouped + `survey_taylor` | `"replicate_creation"` | `"jackknife"` | `"grouped"` | `parameters$replicates` equals passed value |
| DAGJK | `"jackknife_weights"` | *(not present)* | `"grouped"` | `parameters$replicates`, `parameters$replicates_used`, `parameters$replicates_failed`, `parameters$scale`, `parameters$mse == TRUE` |

The probability paths (JKn, JK1, grouped + `survey_taylor`) write history entries
via `.convert_and_call()`, consistent with all other `create_*_weights()` functions:
`operation = "replicate_creation"`, `method = "jackknife"`, with `parameters$type`
recording the variant. The DAGJK path writes `operation = "jackknife_weights"`
directly (not via `.convert_and_call()`) and has no `method` field.

---

## Tolerances

| Estimand | Tolerance |
|----------|-----------|
| Scale factors (exact fractions) | `1e-10` |
| Replicate weight values vs. oracle | `1e-8` |
| Integer-valued assertions (replicate counts) | Exact (`expect_identical`) |

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown scope)
- [ ] `covr::package_coverage()` — >= 95% (target 98%)

---

## Test file mapping

| Test file | Scenarios covered |
|-----------|-------------------|
| `tests/testthat/test-replicate-weights.R` | JKn happy path; JK1 happy path; `type = "grouped"` + `survey_taylor` happy path; numerical oracle comparisons; `replicates` and `seed` ignored for jkn/jk1; `reference_sample` ignored for jkn; `...` non-empty error; `type = "grouped"` + `survey_taylor` replicates required error |
| `tests/testthat/test-nps-jackknife.R` (renamed from `test-nps-group-jackknife.R`) | All DAGJK happy path scenarios; `mse = FALSE` warning + override; svrep args warning; repweights overwrite warning; small groups warning; replicates failed warning; negative replicate weights warning; all DAGJK error classes; seed reproducibility; edge cases for DAGJK argument validation; history entry structure for DAGJK path |
| `tests/testthat/test-replicate-dispatch.R` | `create_replicate_weights(method = "jackknife", type = "grouped")` pass-through; `"group-jackknife"` method errors from `rlang::arg_match()` |
