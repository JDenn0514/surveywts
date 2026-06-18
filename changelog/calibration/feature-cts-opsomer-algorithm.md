# Changelog — feature/cts-opsomer-algorithm

**PR**: 2 of 2 for calibrate-to-survey-opsomer
**Branch**: `feature/cts-opsomer-algorithm`
**Date**: 2026-06-18

## Changes

### `calibrate_to_survey()` — Opsomer & Erciulescu (2022) algorithm

- Replaced svrep delegation (`svrep::calibrate_to_sample()`) with a
  self-contained implementation of the Opsomer & Erciulescu (2022) replication
  variance adjustment. The function no longer calls svrep for any valid code
  path.
- **Breaking default change**: default method changes from linear GREG (svrep's
  default) to rake with `algorithm = "classic_ipf"`. Callers requiring the
  prior behavior must pass `method = "linear"` explicitly.
- **New `targets` support**: when `targets` is non-NULL, the specified census
  margins are applied as fixed constraints during calibration (Opsomer algorithm
  §Fixed margins). Random-margin variables (from `variables`) are calibrated
  per-replicate using perturbed control-survey totals.
- **K expansion**: when `R_C > R` (control has more replicates than primary),
  `K = ceiling(R_C / R)` virtual replicates are constructed per primary
  replicate and averaged. Output always has R replicate columns.
- **History entry schema**: `a_constants` (numeric vector of length R_eff) and
  `K` (integer) are now always present in the history entry. When `targets` is
  non-NULL, `targets`, `type`, and `fixed_variables` are also recorded.

### New internal helpers

- `.compute_control_totals()`: computes full-sample and per-replicate control
  totals; also performs control-level alignment check (supersedes
  `.check_control_levels()` from PR 1).
- `.calibrate_replicate_opsomer()`: calibrates a single virtual replicate
  combining perturbed random-margin totals and fixed census margins.

### Helpers moved

- `.to_svyrep()` and `.method_to_calfun()` moved from `calibrate_to_survey.R`
  to `calibrate-utils.R` (still used by `calibrate_to_estimate()`).
- `.svrep_calibrate_to_sample()` deleted (was only in `calibrate_to_survey.R`;
  no other call sites).

### Documentation

- `calibrate_to_survey()` upgraded to Tier 3 documentation with `@section
  Algorithm`, `@section Convergence`, `@section Warnings`, `@section
  Limitations`, and `@references` (Opsomer & Erciulescu 2022; Fuller 1998).
- `@param bounds` stale svrep-specific note removed; replaced with description
  matching `.calibrate_engine()` bounds behavior.
- `@returns` updated to document `a_constants`, `K`, and conditional fields.
- `@examples` updated to use `acs_wy_2022` and `acs_wy_2022_svy`; no
  `\dontrun{}`.

### Tests

- Sections 26–33 added to `tests/testthat/test-sample-calibration.R` covering:
  happy paths (both `targets = NULL` and non-NULL), numerical comparison with
  svrep oracle (`method = "linear"` within 1e-8), `a_r` constants correctness
  (1e-10), full-sample constraint satisfaction (1e-6), Format B and
  mixed-format targets, and history schema assertions.
