# fix/nonresponse-zero-weights

**PR:** 6 of phase-0-fixes
**Spec:** plans/spec-phase-0-fixes.md, Change 2 (Section III)
**Date:** 2026-03-19

## Summary

Breaking change to `adjust_nonresponse()`: nonrespondent rows are now retained
with weights set to 0 instead of being dropped. This preserves design structure
(strata, PSUs, FPC) for variance estimation.

## Changes

### R/nonresponse.R
- **Step 14:** replaced respondent-only row subsetting with weight zeroing
  (`new_weights[!is_respondent] <- 0`)
- **Step 15:** `after_stats` now computed on respondent weights only
  (`new_weights[is_respondent]`)
- **Step 16:** `survey_nonprob` path no longer filters `@data`; `survey_taylor`
  path retains old filtering behavior (its validator rejects zero weights)
- Updated `@description`, `@return`, and added `@details` documenting
  zero-weight behavior

### R/diagnostics.R
- `effective_sample_size()`, `weight_variability()`, and `summarize_weights()`
  now filter out exact-zero weights before calling `.validate_weights()`,
  enabling diagnostics on post-nonresponse objects

### tests/testthat/helper-test-data.R
- `test_invariants()` `survey_nonprob` branch: `all(w > 0)` -> `all(w >= 0) && any(w > 0)`
- `test_invariants()` `survey_taylor` branch: same change for consistency

### tests/testthat/test-05-nonresponse.R
- Updated 6 existing tests: `nrow(result) < nrow(input)` -> `nrow(result) == nrow(input)`
- Updated hand-calculation test to assert zero weights for nonrespondents
- Updated svrep comparison to compare all rows (not just respondents)
- Added 3 new tests: data.frame zero-weight verification, survey_nonprob
  metadata preservation, re-calibration error on zero-weight data

### tests/testthat/test-06-diagnostics.R
- Added 3 new tests for diagnostics on post-nonresponse data (zero weights)
- Changed `weights_nonpositive` test from zero to negative value (zeros now
  filtered)
- Added test verifying zero-weight filtering behavior

### DESCRIPTION
- Pinned `surveycore (>= 0.6.1)` (relaxed `survey_nonprob` validator)

### NEWS.md
- Added breaking change entry for `adjust_nonresponse()`
