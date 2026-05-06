# fix(calibration): replace vendored algorithms with survey/anesrake delegation

**Date**: 2026-03-19
**Branch**: fix/vendor-delegation
**Phase**: Phase 0
**Spec**: Change 5 from `plans/spec-phase-0-fixes.md`

## Changes

### Deleted files

- `R/vendor-calibrate-greg.R` (185 lines) -- vendored GREG linear/logit calibration
- `R/vendor-calibrate-ipf.R` (127 lines) -- vendored IPF raking
- `R/vendor-rake-anesrake.R` (274 lines) -- vendored anesrake chi-square raking

### Rewritten engine

- Rewrote `.calibrate_engine()` in `R/utils.R` to delegate to:
  - `survey::calibrate()` with `cal.linear` for linear GREG calibration
  - `survey::calibrate()` with `cal.logit` for logit GREG calibration
  - `survey::rake()` for IPF raking (method = "survey")
  - `anesrake::anesrake()` for chi-square raking (method = "anesrake")
  - `survey::postStratify()` for post-stratification
- Removed `.build_model_matrix()` and `.throw_not_converged()` (no remaining callers)
- Kept `.throw_not_converged_zero_maxit()` (still used by maxit=0 guard)

### Dependencies

- Moved `survey (>= 4.2-1)` from Suggests to Imports
- Added `anesrake (>= 0.80)` to Imports

### New error class

- `surveywts_error_cap_not_supported_survey` -- thrown when `cap` is specified with `method = "survey"` in `rake()`

### Convergence detection

- Linear calibration: closed-form, always converges
- Logit calibration: `withCallingHandlers()` intercepts `grake()` "converge" warnings, re-throws as `surveywts_error_calibration_not_converged`
- IPF raking: same `withCallingHandlers()` pattern for `survey::rake()` warnings
- Anesrake: checks `$converge` character string; "Complete convergence" and "Results are stable" are treated as converged; "No variables are off" error is caught and translated to `surveywts_message_already_calibrated`
- Post-stratification: non-iterative, convergence = NULL

### Tests updated

- Updated cap+method="survey" test to expect error (was happy-path)
- Updated min_cell_n exclusion test (anesrake handles nlim differently from vendored code)
- Updated anesrake non-convergence test to use maxit=0 guard
- Removed `skip_if_not_installed("survey")` guards (survey now in Imports)
- Updated vendor-referencing comments in test files
- Regenerated snapshot files for calibrate, rake, and poststratify
- Updated `VENDORED.md` to document delegation (no longer vendored)
