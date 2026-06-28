# refactor(classes): remove weighted_df and plain data.frame inputs; require survey_base objects

**Date**: 2026-06-28
**Branch**: refactor/drop-weighted-df
**Phase**: Class System Refactor

## Changes

- **Remove `weighted_df` S3 class entirely**: delete `R/weighted-df-dplyr.R`
  (removes `dplyr_reconstruct.weighted_df()`, `select.weighted_df()`,
  `rename.weighted_df()`, `mutate.weighted_df()`); delete `print.weighted_df()`
  from `R/methods-print.R`; remove `.make_weighted_df()` from `R/utils.R`;
  remove `tests/testthat/test-00-classes.R`.
- **All weighting functions now require `survey_base` objects**: calibration
  (`calibrate()`, `calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`,
  `poststratify()`), nonresponse (`adjust_nonresponse()`,
  `redistribute_weights()`), utilities (`trim_weights()`, `rescale_weights()`),
  and diagnostics (`effective_sample_size()`, `weight_variability()`,
  `summarize_weights()`) now abort with `surveywts_error_not_survey_base` when
  passed a plain `data.frame` or `weighted_df`.
- **New error class `surveywts_error_not_survey_base`**: added to
  `plans/error-messages.md`; retire `surveywts_error_unsupported_class`.
- **`wt_name` default changed from `"wts"` to `NULL`**: `NULL` means
  "overwrite the registered weight column in-place"; a non-NULL character
  scalar writes calibrated weights to a new column and updates
  `@variables$weights` to point to it (original column preserved).
- **`.update_survey_weights()` gains `wt_name` argument**: shared helper in
  `R/utils.R` now handles the new-column path; all callers pass
  `wt_name = wt_name`.
- **`.check_input_class()` rewritten**: replaces multi-branch `data.frame` /
  `weighted_df` / `survey_base` dispatch with a strict
  `S7::S7_inherits(data, surveycore::survey_base)` guard.
- **`.check_weight_utils_class()` updated**: same consolidation for
  `trim_weights()` and `rescale_weights()`; error class changed to
  `surveywts_error_not_survey_base`.
- **`R/diagnostics-utils.R` updated**: remove `is_plain_df` and
  `weighted_df` branches; update error class.
- **All examples updated**: every function now uses
  `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or
  `surveycore::as_survey_replicate()` as the input constructor; no bare
  `data.frame` examples remain.
- **`summarize_weights()` added to first two examples in each function**.
- **Tests updated**: remove all `weighted_df` / `data.frame` happy-path
  blocks; add `surveywts_error_not_survey_base` dual-pattern error tests
  (`expect_error(class=)` + `expect_snapshot(error = TRUE)`) across all
  affected test files.
- **`NEWS.md` entry written** describing the breaking API changes.

## Files Modified

- `R/weighted-df-dplyr.R` — **deleted**
- `R/methods-print.R` — remove `print.weighted_df()`
- `R/utils.R` — remove `.make_weighted_df()`; update `.validate_wt_name()`,
  `.get_weight_vec()`, `.get_history()`, `.check_input_class()`,
  `.update_survey_weights()`
- `R/weight-utils.R` — update `.check_weight_utils_class()`
- `R/diagnostics-utils.R` — remove `weighted_df` / plain df branches
- `R/calibrate.R` — `@param data`, `@returns`, `@param wt_name`, examples
- `R/calibrate_rake.R` — dispatch, `@param`, `@returns`, `wt_name`, history, examples
- `R/calibrate_linear.R` — same
- `R/calibrate_logit.R` — same
- `R/poststratify.R` — same
- `R/calibrate_to_survey.R` — examples only
- `R/calibrate_to_estimate.R` — examples only
- `R/adjust_nonresponse.R` — dispatch, `@param`, `@returns`, `wt_name`, history, examples
- `R/redistribute_weights.R` — same
- `R/trim_weights.R` — same
- `R/rescale_weights.R` — same
- `R/effective_sample_size.R` — `@param`, examples
- `R/weight_variability.R` — `@param`, examples
- `R/summarize_weights.R` — `@param`, examples
- `R/data.R` — dataset docs (updated examples)
- `plans/error-messages.md` — add `surveywts_error_not_survey_base`; retire
  `surveywts_error_unsupported_class`
- `NAMESPACE` — regenerated (removes `weighted_df` method registrations)
- `man/` — regenerated; `man/print.weighted_df.Rd` deleted
- `tests/testthat/test-00-classes.R` — **deleted**
- `tests/testthat/test-02-calibrate.R` — modified
- `tests/testthat/test-03-rake.R` — modified
- `tests/testthat/test-04-poststratify.R` — modified
- `tests/testthat/test-05-nonresponse.R` — modified
- `tests/testthat/test-calibrate-linear.R` — modified
- `tests/testthat/test-calibrate-logit.R` — modified
- `tests/testthat/test-weight-utils.R` — modified
- `tests/testthat/test-06-diagnostics.R` — modified
- `tests/testthat/test-nps-jackknife.R` — modified
- `tests/testthat/test-calibrate-utils-nr.R` — modified
- `tests/testthat/_snaps/` — stale snapshots removed; new error snapshots approved
- `NEWS.md` — breaking change entry
- `changelog/class-system-refactor/refactor-drop-weighted-df.md` — this file
