# PR 1: calibrate_greg + calibrate_rake + shared utils

- Adds `calibrate_greg()`: replaces old `calibrate()`. New `targets` arg unifies
  old `variables` + `population`; `model` replaces `method`. Adds
  `reference_design` parameter for tracking targets provenance.
- Adds `calibrate_rake()`: replaces old `rake()`. New `targets` arg replaces
  `margins`; `algorithm` replaces `method`. Adds `reference_design` parameter.
- Adds `R/calibrate-utils.R` with shared `.parse_margins()`, `.validate_reference_design()`,
  and `.validate_count_marginal_consistency()` helpers.
- Deletes `R/calibrate.R` and `R/rake.R`.
- Error class `surveywts_error_targets_variable_not_found` replaces both
  `surveywts_error_population_variable_not_found` and
  `surveywts_error_margins_variable_not_found`.
- History `operation` fields: `"calibrate_greg"` (was `"calibration"`) and
  `"calibrate_rake"` (was `"raking"`).
- `calibrate_greg()` validates and drops unrecognized `control` keys with
  `surveywts_warning_control_param_ignored`.
- `type = "count"` now validates cross-marginal consistency (all marginal sums
  within 1e-3) in both `calibrate_greg()` and `calibrate_rake()`.
