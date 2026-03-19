# fix(calibration): modernize input validation and response_status resolution

**Date**: 2026-03-19
**Branch**: fix/input-validation
**Phase**: Phase 0
**Spec**: Changes 3 and 7 from `plans/spec-phase-0-fixes.md`

## Changes

- Replaced specific `survey_taylor || survey_nonprob` class checks with `survey_base` inheritance check in `.check_input_class()`, `.diag_validate_input()`, and `.get_history()`
- Added `survey_replicate` rejection guard to `.diag_validate_input()` (already existed in `.check_input_class()`)
- Updated unsupported-class error messages to reference documentation instead of listing specific class names
- Replaced `rlang::as_name()` with `tidyselect::eval_select()` for `response_status` resolution in `adjust_nonresponse()`
- Added new error class `surveywts_error_response_status_multiple_columns` for multi-column selection
- Added `surveywts_error_response_status_multiple_columns` to `plans/error-messages.md`

## New Error Classes

- `surveywts_error_response_status_multiple_columns` -- thrown when `response_status` selects more than one column

## New Tests

- `adjust_nonresponse()` rejects `response_status` selecting multiple columns (test-05-nonresponse.R)

## Files Modified

- `R/utils.R` -- updated `.check_input_class()` and `.get_history()` to use `survey_base`
- `R/diagnostics.R` -- updated `.diag_validate_input()` to use `survey_base` with `survey_replicate` guard
- `R/nonresponse.R` -- replaced `rlang::as_name()` with `tidyselect::eval_select()` for `response_status`
- `plans/error-messages.md` -- added `surveywts_error_response_status_multiple_columns`
- `tests/testthat/test-05-nonresponse.R` -- added multi-column response_status test
- `tests/testthat/_snaps/02-calibrate.md` -- updated unsupported-class snapshot
- `tests/testthat/_snaps/03-rake.md` -- updated unsupported-class snapshot
- `tests/testthat/_snaps/04-poststratify.md` -- updated unsupported-class snapshot
- `tests/testthat/_snaps/05-nonresponse.md` -- updated unsupported-class and response_status snapshots; added multi-column snapshot
- `tests/testthat/_snaps/06-diagnostics.md` -- updated unsupported-class snapshots
