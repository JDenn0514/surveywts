# calibrate() — Phase 0 Calibration Core

## New functions

- `calibrate()`: Calibrate survey weights to known marginal population totals.
  Supports linear (GREG, one-step exact) and logit (bounded IRLS) calibration
  for categorical auxiliary variables. Accepts `data.frame`, `weighted_df`,
  `survey_taylor`, and `survey_calibrated` inputs; returns `weighted_df` for
  data frame inputs and `survey_calibrated` for survey object inputs.
  Population targets may be specified as proportions (`type = "prop"`) or
  counts (`type = "count"`). Weighting history is appended on every call.
