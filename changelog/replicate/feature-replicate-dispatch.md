# feat(replicate): add create_replicate_weights() dispatcher and as_taylor_design()

**Date**: 2026-05-06
**Branch**: feature/replicate-dispatch
**Phase**: Replicate

## Changes

- Add `create_replicate_weights()` dispatcher that routes to the appropriate `create_*_weights()` function based on `method` argument
- Add `as_taylor_design()` to reconstruct a `survey_taylor` from a `survey_replicate`, reading original design structure from the weighting history
- Add comprehensive tests covering all six dispatch paths, happy-path conversion, round-trips for SRS designs, and all error/warning conditions

## Files Modified

- `R/replicate-dispatch.R` — new file with `create_replicate_weights()` and `as_taylor_design()`
- `tests/testthat/test-replicate-dispatch.R` — new test file with 22 test blocks covering dispatch, conversion, warnings, and errors
- `NAMESPACE` — export `create_replicate_weights` and `as_taylor_design`
- `man/create_replicate_weights.Rd` — new man page
- `man/as_taylor_design.Rd` — new man page
- `_pkgdown.yml` — add `create_replicate_weights` and `as_taylor_design` to replicate-weights reference section
