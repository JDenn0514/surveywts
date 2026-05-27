# feat(weights): add quasi-randomization bootstrap for non-probability samples

**Date**: 2026-05-27
**Branch**: feature/nps-bootstrap-impl
**Phase**: Replicate (NPS extension)

## Changes

- Add `type = "quasi-randomization"` path to `create_bootstrap_weights()` for
  `survey_nonprob` inputs, implementing the quasi-randomization bootstrap
  (Beaumont & Émond 2022) via SRSWR resampling of both NPS and reference rows
  with rake/ipw re-estimation per draw
- Add `type = "hybrid"` stub that errors with `surveywts_error_hybrid_not_implemented`
- Migrate `mse` argument from `logical(1)` to `character(1)` accepting
  `"mse"` (default), `"chrostowski"`, or `"uncentered"`; `"uncentered"` maps
  to `mse = FALSE` for the svrep probability-sample path
- Change `replicates` default from `500L` to `NULL`; `NULL` resolves to `200L`
  for NPS types and `500L` for probability-sample types
- Add three private helpers:
  - `.validate_reference_sample()` — validates `reference_design` is a
    `survey_taylor` with a weight column; rejects `survey_nonprob`
  - `.quasi_randomization_bootstrap()` — Level A (IPW-only) and Level B
    (IPW + calibration) bootstrap loop with draw failure tolerance
  - `.reestimate_margins_from_reference()` — recomputes rake margins from
    SRSWR-resampled reference data for Level B draws
- Extend `print` method for `survey_nonprob` to display bootstrap replicate
  count, type, and level when bootstrap weights are attached
- Add full test suite `tests/testthat/test-08-nps-bootstrap.R` (17 blocks):
  happy paths (Level A, Level B, print), error paths (E1–E11), warning paths
  (W1–W2), edge cases (EC1–EC2), and numerical validation (N1)
- Fix `test-replicate-dispatch.R`: `mse = FALSE` → `mse = "uncentered"`
- Fix `test-replicate-weights.R`: NULL replicates now resolves to 500L instead
  of erroring

## Files Modified

- `R/replicate-weights.R` — Level A/B quasi-randomization bootstrap, mse API
  migration, replicates=NULL default, NPS dispatch ordering fix, roxygen update
- `R/methods-print.R` — bootstrap replicates line added to `survey_nonprob` print
- `tests/testthat/test-08-nps-bootstrap.R` — new test file (17 blocks)
- `tests/testthat/_snaps/08-nps-bootstrap.md` — new snapshot file (E1–E11, print)
- `tests/testthat/test-replicate-dispatch.R` — mse argument fix
- `tests/testthat/test-replicate-weights.R` — NULL replicates test updated
- `man/create_bootstrap_weights.Rd` — regenerated documentation
- `NAMESPACE` — regenerated (no new exports)
