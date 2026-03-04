# feat(utils): add make_surveyweights_data() and test_invariants() helpers

**Date**: 2026-03-03
**Branch**: feature/phase-0-test-helpers
**Phase**: Phase 0

## Changes

- Add `make_surveyweights_data()` synthetic data generator with `n`, `seed`, and `include_nonrespondents` parameters; produces realistic unequal-sized groups with log-normally distributed weights
- Add `test_invariants()` helper that asserts structural correctness of `weighted_df` and `survey_calibrated` objects; guarded so it loads before Phase 0 classes land
- Mark PR 2 acceptance criteria complete in `plans/impl-phase-0.md`

## Files Modified

- `tests/testthat/helper-test-data.R` — new file defining `make_surveyweights_data()` and `test_invariants()` for use across all Phase 0 test files
- `plans/impl-phase-0.md` — mark PR 2 acceptance criteria as complete
