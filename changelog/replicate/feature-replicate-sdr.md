# feat(replicate): add create_sdr_weights()

**Date**: 2026-05-06
**Branch**: feature/replicate-sdr
**Phase**: Replicate

## Changes

- Implement `create_sdr_weights()` for successive difference replication via `svrep::as_sdr_design()`
- Add `sort_var` NSE argument for systematic selection order; uses row-index fallback when `NULL`
- Enforce `replicates >= 4` minimum (SDR requires Hadamard matrix of at least order 4)
- Add validation for `sort_var` NA values (`surveywts_error_sort_var_has_na`)
- Add tests: happy path, sort_var variation, equivalence against `svrep::as_sdr_design()`, all error paths, edge cases
- Add `create_sdr_weights` to `_pkgdown.yml` reference section

## Files Modified

- `R/replicate-weights.R` — add `create_sdr_weights()` with validation and `.convert_and_call()` backend
- `tests/testthat/test-replicate-weights.R` — SDR happy path, error, equivalence, and edge case tests
- `tests/testthat/_snaps/replicate-weights.md` — new snapshots for SDR error messages
- `_pkgdown.yml` — add `create_sdr_weights` to replicate-weights reference section
