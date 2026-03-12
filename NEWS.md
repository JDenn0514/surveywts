# surveywts 0.1.0

## Phase 0: Weighting Core

This is the first release of surveywts, implementing the core survey weighting
workflow.

### New classes

- `weighted_df`: An S3 subclass of tibble that carries a `weight_col` attribute
  identifying the weight column and a `weighting_history` attribute recording
  every weighting operation applied. Produced as output from calibration and
  nonresponse functions when the input is a plain `data.frame` or `weighted_df`.
  Supports dplyr verbs (`select()`, `rename()`, `mutate()`) with automatic
  downgrade to a plain tibble (with a warning) if the weight column is removed.

- `survey_nonprob` (from surveycore): surveywts implements `print()` for
  `survey_nonprob` objects, displaying design variables and weighting history.

### New functions

- `calibrate()`: Calibrate survey weights to known marginal population totals
  using linear (GREG) or logit (bounded IRLS) calibration for categorical
  auxiliary variables.

- `rake()`: Iterative proportional fitting to marginal population targets.
  Supports two methods: `"anesrake"` (chi-square variable selection with
  improvement-based convergence) and `"survey"` (fixed-order IPF with
  epsilon-based convergence). Margins may be a named list or a long data frame
  with `variable`, `level`, and `target` columns.

- `poststratify()`: Exact post-stratification to known joint population cell
  counts or proportions in a single non-iterative pass.

- `adjust_nonresponse()`: Weighting-class nonresponse adjustment that
  redistributes nonrespondent weights to respondents within cells defined by
  `by`. Methods `"propensity"` and `"propensity-cell"` are stubbed for Phase 2.

- `effective_sample_size()`: Kish's effective sample size (`ESS = (Σw)² / Σw²`).

- `weight_variability()`: Coefficient of variation of survey weights.

- `summarize_weights()`: Full distributional summary (n, mean, CV, ESS,
  percentiles), optionally grouped by one or more variables.

All functions accept `data.frame`, `weighted_df`, `survey_taylor`, and
`survey_nonprob` inputs, and append a structured weighting history entry
on every call.

### Bug fixes

- `calibrate()`, `rake()`, and `poststratify()` now preserve the input class
  (`survey_taylor` or `survey_nonprob`) rather than promoting all survey
  object inputs to `survey_nonprob` (#10).
