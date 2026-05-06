# test(calibration): add anesrake wrapper parity tests and remove dead vendor code

**Date**: 2026-05-04
**Branch**: test/anesrake-wrapper-parity
**Phase**: Calibration

## Changes

- Drop `R/vendor-rake-anesrake.R` — `.anesrake_calibrate()` was never called;
  the engine delegates directly to `anesrake::anesrake()`
- Remove duplicate `cap` guard block in `R/rake.R` that was left over after
  vendor delegation
- Add five weight-for-weight parity tests verifying the engine correctly
  marshals inputs to `anesrake::anesrake()`: argument mapping
  (`pctlim`/`choosemethod`/`nlim`), the `cap=NULL→5` substitution, and
  count-to-proportion conversion

## Files Modified

- `R/rake.R` — remove duplicate cap guard block (dead code after vendor delegation)
- `R/vendor-rake-anesrake.R` — deleted (274 lines of dead vendored code)
- `tests/testthat/test-03-rake.R` — add five anesrake wrapper parity tests
