# Changelog

## surveywts 0.1.0

### Phase 0: Weighting Core

This is the first release of surveywts, implementing the core survey
weighting workflow.

#### New classes

- `weighted_df`: An S3 subclass of tibble that carries a `weight_col`
  attribute identifying the weight column and a `weighting_history`
  attribute recording every weighting operation applied. Produced as
  output from calibration and nonresponse functions when the input is a
  plain `data.frame` or `weighted_df`. Supports dplyr verbs (`select()`,
  `rename()`, `mutate()`) with automatic downgrade to a plain tibble
  (with a warning) if the weight column is removed.

- `survey_calibrated` (from surveycore): surveywts implements
  [`print()`](https://rdrr.io/r/base/print.html) for `survey_calibrated`
  objects, displaying design variables and weighting history.

#### New functions

- [`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md):
  Calibrate survey weights to known marginal population totals using
  linear (GREG) or logit (bounded IRLS) calibration for categorical
  auxiliary variables.

- [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md):
  Iterative proportional fitting to marginal population targets.
  Supports two methods: `"anesrake"` (chi-square variable selection with
  improvement-based convergence) and `"survey"` (fixed-order IPF with
  epsilon-based convergence). Margins may be a named list or a long data
  frame with `variable`, `level`, and `target` columns.

- [`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md):
  Exact post-stratification to known joint population cell counts or
  proportions in a single non-iterative pass.

- [`adjust_nonresponse()`](https://jdenn0514.github.io/surveywts/reference/adjust_nonresponse.md):
  Weighting-class nonresponse adjustment that redistributes
  nonrespondent weights to respondents within cells defined by `by`.
  Methods `"propensity"` and `"propensity-cell"` are stubbed for Phase
  2.

- [`effective_sample_size()`](https://jdenn0514.github.io/surveywts/reference/effective_sample_size.md):
  Kish’s effective sample size (`ESS = (Σw)² / Σw²`).

- [`weight_variability()`](https://jdenn0514.github.io/surveywts/reference/weight_variability.md):
  Coefficient of variation of survey weights.

- [`summarize_weights()`](https://jdenn0514.github.io/surveywts/reference/summarize_weights.md):
  Full distributional summary (n, mean, CV, ESS, percentiles),
  optionally grouped by one or more variables.

All functions accept `data.frame`, `weighted_df`, `survey_taylor`, and
`survey_calibrated` inputs, and append a structured weighting history
entry on every call.

#### Bug fixes

- [`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md),
  [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md),
  and
  [`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md)
  now preserve the input class (`survey_taylor` or `survey_calibrated`)
  rather than promoting all survey object inputs to `survey_calibrated`
  ([\#10](https://github.com/JDenn0514/surveywts/issues/10)).
