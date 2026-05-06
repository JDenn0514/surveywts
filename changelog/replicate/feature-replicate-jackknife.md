# feat(replicate): add create_jackknife_weights()

**Date**: 2026-05-05
**Branch**: feature/replicate-jackknife
**Phase**: Replicate

## Changes

- Add `create_jackknife_weights()` exported function to `R/replicate-weights.R`:
  - `type = "delete-1"` (default): uses `survey::as.svrepdesign()`, auto-selecting JK1 (unstratified) or JKn (stratified)
  - `type = "random-groups"`: uses `svrep::as_random_group_jackknife_design()` with optional `seed`
  - `survey_nonprob` supported for `delete-1` only; `random-groups` with `survey_nonprob` raises `surveywts_error_jackknife_type_unsupported_for_nonprob`
  - `replicates` required (and validated) for `random-groups`; ignored for `delete-1`
- Extend `tests/testthat/test-replicate-weights.R` with jackknife test suite:
  - Happy paths (JK1, JKn, random-groups, survey_nonprob)
  - Error paths (shared input-class errors + jackknife-specific: missing replicates, nonprob+random-groups, fractional/too-small replicates)
  - Numerical equivalence against `survey::as.svrepdesign()` (JK1 and JKn) and `svrep::as_random_group_jackknife_design()` (random-groups)
  - Edge cases (single-PSU, replicates > PSU count, all-equal base weights)
- Update `_pkgdown.yml` to add `create_jackknife_weights` to the Replicate Weights reference section

## Files Modified

- `R/replicate-weights.R` — `create_jackknife_weights()` appended
- `tests/testthat/test-replicate-weights.R` — jackknife tests added (127 total)
- `tests/testthat/_snaps/replicate-weights.md` — new snapshots for jackknife error messages
- `man/create_jackknife_weights.Rd` — generated documentation
- `NAMESPACE` — export for `create_jackknife_weights` added
- `_pkgdown.yml` — `create_jackknife_weights` added to Replicate Weights section
- `plans/impl-replicate.md` — PR 3 marked complete
