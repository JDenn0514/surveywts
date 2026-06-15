# feature/calibrate-nonprob

## Changes

- `calibrate_to_survey()` and `calibrate_to_estimate()` now accept
  `survey_nonprob` objects with replicate weights in addition to
  `survey_replicate` objects.
- The output class now matches the input class of the primary design (or
  `design` for `calibrate_to_estimate()`): a `survey_nonprob` input returns
  a `survey_nonprob`; a `survey_replicate` input returns a `survey_replicate`.
- New error classes: `surveywts_error_primary_no_repweights`,
  `surveywts_error_control_no_repweights`,
  `surveywts_error_design_no_repweights` — fire when a `survey_nonprob`
  input lacks replicate weights.
- `@param` and `@returns` documentation updated for both functions to reflect
  the relaxed type constraint and the class-preservation rule.
- Existing `_not_replicate` error messages updated to mention
  `survey_nonprob` as an additionally accepted type.
