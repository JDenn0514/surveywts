# rake() — Phase 0 Raking

## New functions

- `rake()`: Calibrate survey weights to known marginal population totals using
  iterative proportional fitting (raking). Supports two raking methods:
  `"anesrake"` (chi-square variable selection with improvement-based convergence,
  vendored from the `anesrake` package by Pasek & Tahk) and `"survey"` (fixed-order
  IPF with epsilon-based convergence, vendored from the `survey` package by Lumley).
  Accepts `data.frame`, `weighted_df`, `survey_taylor`, and `survey_calibrated`
  inputs; returns `weighted_df` for data frame inputs and `survey_calibrated` for
  survey object inputs. Margins may be specified as a named list (Format A) or
  a long data frame with `variable`, `level`, and `target` columns (Format B).
  Population targets may be specified as proportions (`type = "prop"`) or counts
  (`type = "count"`). Optional `cap` parameter limits each weight relative to the
  mean weight at each IPF step. Weighting history is appended on every call.
