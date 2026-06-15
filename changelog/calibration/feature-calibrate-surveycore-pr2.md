# Changelog — calibrate-surveycore PR 2: @calibration slot and replicate loop

**Branch:** `feature/calibrate-surveycore-functions`
**Date:** 2026-06-05
**Status:** Implemented

## Summary

Wires `@calibration` provenance and `survey_replicate` replicate loop support
into `calibrate_greg()`, `calibrate_rake()`, and `calibrate_poststrat()`. Each
function now populates a 12-field `@calibration` list on survey objects and
iterates over every replicate weight column when the input is a
`survey_replicate`.

## Changes

### `R/calibrate_greg.R`

- Added `is_survey_obj` branch that calls `.build_calibration_provenance()`
  to populate the 12-field `@calibration` list for `survey_taylor`,
  `survey_nonprob`, and `survey_replicate` inputs.
- Added replicate loop (`survey_replicate` only): iterates over every column
  in `data@variables$repweights`, scales population counts to each replicate's
  own weight total, calls `.calibrate_engine()` per replicate, and writes
  calibrated weights back. Failed replicates are recorded in
  `caldata$replicate_converged` as `FALSE` (names = failed column names).
- `@calibration` list includes `replicate_converged` (named logical vector)
  for `survey_replicate` outputs.
- `caldata` is passed to `.update_survey_weights()` via the `caldata =`
  argument added in PR 1.

### `R/calibrate_rake.R`

- Same structure as `calibrate_greg.R`: `is_survey_obj` branch builds
  `@calibration` provenance using `method = "raking"` and `cell_factors = NULL`.
- Replicate loop scales population counts to each replicate's own weight total
  using the same `type == "prop"` / `"count"` logic as the full-sample path.
- `caldata$replicate_converged` populated with named logical for failed
  replicates.

### `R/calibrate_poststrat.R`

- `is_survey_obj` branch builds a full cross-cell indicator `x_matrix` (n × C)
  and computes `cell_factors` (ratio of population target to weighted cell count
  for each cell), then calls `.build_calibration_provenance()` with
  `method = "poststrat"`.
- A minimal `engine_result_ps` stub (`converged = TRUE`, `iterations = 1L`)
  is constructed because post-stratification is non-iterative.
- Replicate loop applies the cell-ratio method independently per replicate,
  scaling `target_vals` proportionally to the replicate's own weight total
  when `type == "prop"`. A replicate fails if any cell has zero or negative
  weighted count; the original weights are retained and the column is recorded
  as `FALSE` in `replicate_converged`.
- `caldata$replicate_converged` populated for `survey_replicate` outputs.

### `tests/testthat/test-02-calibrate.R`

- Added PR-2 test sections for `calibrate_greg()` with `survey_replicate`
  input: happy-path `@calibration` slot checks, `replicate_converged`
  structure, warning on failed replicate, and convergence flag propagation.

### `tests/testthat/test-03-rake.R`

- Added PR-2 test sections for `calibrate_rake()` with `survey_replicate`
  input: same structure as test-02.

### `tests/testthat/test-04-poststratify.R`

- Added PR-2 test sections for `calibrate_poststrat()` with `survey_replicate`
  input: including `cell_factors` field presence and zero-cell replicate failure.

## Key behaviors

- **12-field `@calibration` list**: all three calibration functions now set
  `@calibration` on survey objects via `.build_calibration_provenance()` +
  `.update_survey_weights(caldata = ...)`.
- **`replicate_converged` named logical**: element names are the replicate
  weight column names from `data@variables$repweights`; `TRUE` = converged,
  `FALSE` = kept at original values.
- **`cell_factors` for poststrat**: `calibrate_poststrat()` is the only
  function that passes a non-`NULL` `cell_factors` to
  `.build_calibration_provenance()` — it contains the N_c / N_hat_c ratio per
  cell.
- **Per-replicate weight scaling**: replicate loops scale the population target
  to `sum(rep_wt)` (for `type = "prop"`) rather than the full-sample total,
  ensuring the intercept constraint is correct for each replicate.
- **Failure isolation**: a replicate that fails calibration (any error from
  `.calibrate_engine()`) emits `surveywts_warning_replicate_calibration_failed`
  and retains its pre-calibration weights; the full-sample calibration is
  unaffected.

## CRAN compliance

- [x] No `<<-` — tryCatch returns `TRUE`/`FALSE`; outer loop collects failed
  column names with `<-`
- [x] `::` used for all external calls
- [x] No bare `print()` / `cat()`
- [x] `TRUE`/`FALSE` throughout (no `T`/`F`)
- [x] All `cli_abort()` and `cli_warn()` have `class=`
