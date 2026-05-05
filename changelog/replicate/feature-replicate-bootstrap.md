# feat(replicate): add create_bootstrap_weights() and shared helpers

**Date**: 2026-05-05
**Branch**: feature/replicate-bootstrap
**Phase**: Replicate

## Changes

- Add five shared internal helpers to `R/replicate-weights.R`:
  - `.validate_replicate_input()` — rejects `data.frame`, `weighted_df`, `survey_replicate`, and unsupported classes
  - `.validate_replicates_arg()` — validates whole-number replicates ≥ min_val, coerces to integer
  - `.snapshot_variables_for_history()` — captures `@variables` + `is_nonprob` flag for history entries
  - `.convert_and_call()` — core pipeline: converts S7 design → svydesign → svyrep → `survey_replicate`; handles `survey_nonprob` via `survey::svydesign()` since `as_svydesign()` rejects it
- Add `create_bootstrap_weights()` exported function (wraps `svrep::as_bootstrap_design()`)
- Add full test suite in `tests/testthat/test-replicate-weights.R` covering error paths, happy paths, metadata preservation, and svrep equivalence
- Update `_pkgdown.yml` with new "Replicate Weights" reference section
- Update `.claude/rules/surveywts-conventions.md` Section 2 with `replicate-weights` family

## Files Modified

- `R/replicate-weights.R` — new file with 5 helpers + `create_bootstrap_weights()`
- `R/vendor-calibrate-greg.R` — deleted (vendored GREG calibration helpers; no longer referenced)
- `R/vendor-calibrate-ipf.R` — deleted (vendored IPF calibration helper; no longer referenced)
- `tests/testthat/test-replicate-weights.R` — new test file (68 tests, including NULL/character/NA replicates coverage)
- `tests/testthat/test-06-diagnostics.R` — 3 tests added for `survey_replicate` rejection in diagnostic functions
- `tests/testthat/_snaps/replicate-weights.md` — new snapshots for error messages
- `tests/testthat/_snaps/06-diagnostics.md` — new snapshot for `survey_replicate` rejection
- `man/create_bootstrap_weights.Rd` — generated documentation
- `NAMESPACE` — export for `create_bootstrap_weights` added
- `_pkgdown.yml` — Replicate Weights reference section added
- `.claude/rules/surveywts-conventions.md` — `replicate-weights` family added
- `plans/error-messages.md` — added `surveywts_error_internal` to Internal/Utility section
- `plans/impl-replicate.md` — marked PR 2 as complete
