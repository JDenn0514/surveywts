# feat(calibration): port anesrake engine and add pre-cap weights to history

**Date**: 2026-05-11
**Branch**: feature/rake-anesrake-port
**Phase**: Calibration

## Changes

- Ports the anesrake raking algorithm into `R/rake-anesrake-engine.R` as
  internal helpers (`.rake_anesrake()`, `.rake_list()`, and supporting
  functions). The ported engine is a faithful translation of the anesrake
  package source (formatted with `air`, `%>%` replaced with `|>`).

- Adds a `precap_weightvec` snapshot inside `.rake_list()`, captured after
  each full variable sweep and before the capping block. This pre-cap state
  is returned by the engine and surfaced in `weighting_history` as a
  `capping` field on each raking history entry.

- The `capping` field is `NULL` when `cap = NULL` (no cap set). When a cap
  is set, it is a list with keys `applied`, `cap_threshold`, `n_capped`,
  `max_precap`, `mean_excess`, and `precap_weights`.

- Fixes a bug where `cap = NULL` silently applied a cap of 5 (the
  `anesrake::anesrake()` default). `cap = NULL` now correctly means no cap
  (`Inf` internally).

- Moves `anesrake` from `Imports` to `Suggests`. The package is now used
  only in tests (parity checks against our internal engine).

## Files Modified

- `R/rake-anesrake-engine.R` — new file; ported internal helpers
- `R/utils.R` — `.calibrate_engine()` calls `.rake_anesrake()` instead of
  `anesrake::anesrake()`; `.make_history_entry()` gains `capping = NULL`
- `R/rake.R` — extracts and forwards `capping` from engine result
- `DESCRIPTION` — `anesrake` moved to `Suggests`
- `tests/testthat/test-03-rake.R` — 3 new pre-cap history tests; renamed
  cap=NULL test; `skip_if_not_installed("anesrake")` on all parity tests
