# chore(replicate): add infrastructure for replicate weight generation

**Date**: 2026-05-04
**Branch**: feature/replicate-infrastructure
**Phase**: Replicate

## Changes

- Bump `surveycore` floor to `>= 0.8.0`
- Add 15 new error classes and 2 warning classes to `plans/error-messages.md` under `### Replicate Weight Functions`
- Add `make_taylor_design()` and `make_paired_design()` generators to `tests/testthat/helper-test-data.R`
- Extend `test_invariants()` with a `survey_replicate` branch checking `@variables$repweights`
- Add `"replicate_creation"` case to `.format_history_step()` in `R/utils.R` for rich history display

## Files Modified

- `DESCRIPTION` — surveycore floor bumped to 0.8.0
- `plans/error-messages.md` — 15 error classes + 2 warning classes added under Replicate Weight Functions
- `tests/testthat/helper-test-data.R` — make_taylor_design(), make_paired_design() added; test_invariants() extended
- `R/utils.R` — "replicate_creation" switch case added to .format_history_step()
