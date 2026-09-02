# surveywts 0.2.1 (development)

## Bug fixes

* Both propensity methods of `adjust_nonresponse()` warned "non-integer
  #successes in a binomial glm!" on every call (#110). The fits passed
  `family = binomial` to `stats::glm()` with the survey weights as case
  weights. Survey weights are not integer counts, so base R warned, and the
  warning appeared twice on the help page once the examples covered all three
  methods.

  Both fits now use `family = quasibinomial`, the standard choice for a
  weighted logistic regression. The two families share the IRLS step, so the
  coefficients, the fitted propensity scores, and the adjusted weights are
  unchanged: on `gss_2024` with a simulated response indicator, the
  `"propensity"` weights match the old fit to the last bit. The convergence
  handler still fires, because "algorithm did not converge" comes from
  `glm.fit()` and does not depend on the family.

* The quasi-randomization bootstrap wrote resample-order weights into
  original-order rows (#102). `.quasi_randomization_bootstrap()` drew a
  resample, refit the weighting model on it, and stored the returned vector
  straight into a `repwt_*` column. Both vectors have the same length, so
  nothing errored: row *i* held the weight of whatever unit landed at
  position *i* of the resample. The column was a permutation of roughly the
  right values, so it summed to the base weight's scale while its
  correlation with the base weight was about 0. Every replicate estimate
  collapsed toward the unweighted mean, in the same direction across all
  columns, which `mse = TRUE` then turned into the variance. On `ns_wave1`
  weighted to `npors_2025_clean`, the four replicate estimates of mean `age`
  centred on 45.71 against the weighted 47.43; they now centre on 47.37.

  Each replicate column is now mapped back to original-unit order. A unit
  the draw picked `m` times carries the sum of the weights of its `m`
  copies, so an estimator applied to the column returns the value that draw
  produced. A unit the draw did not pick carries 0, so about 37% of each
  column is now zero where none was before. This affects
  `create_bootstrap_weights(type = "quasi-randomization")` and
  `create_replicate_weights(method = "bootstrap", type =
  "quasi-randomization")`. The five probability types were unaffected;
  their separate defect is #101 above.

* The probability replicate creators stored replication factors instead of
  finished replicate weights (#101). `survey` and `svrep` return the
  replicate matrix with `combined.weights = FALSE`, meaning each value is a
  factor to apply to the base weight. `.convert_and_call()` copied that
  matrix straight into `@variables$repweights`, which surveycore reads as
  finished weights, so the base weight was never folded in. Every variance
  estimate from `create_bootstrap_weights()`, `create_jackknife_weights()`
  (types `"jkn"`, `"jk1"`, `"grouped"`), `create_brr_weights()`,
  `create_gen_boot_weights()`, `create_gen_rep_weights()`, and
  `create_sdr_weights()` was wrong. On `gss_2024` with `weights = wtssps`,
  the mean of `age` had a confidence interval of 42.9-53.0 against 47.0-48.9
  from `survey::svymean()` on the Taylor design; it now returns 47.05-48.82.
  The base weight is folded in at extraction time, so each replicate column
  is a finished weight on the same scale as the base weight column.

  The DAGJK path (`create_jackknife_weights(type = "grouped")` on a
  `survey_nonprob`) was already correct and is unchanged. The
  quasi-randomization bootstrap has a separate defect with a different cause,
  fixed under #102 above.

* The grouped jackknife and the quasi-randomization bootstrap replay a
  stored calibration once per replicate (#111). Each replay that already met
  its margins printed its own convergence line, so a call with
  `replicates = 25` could print up to 25 identical lines.

  The message comes from the calibration call, not from the replicate loop,
  so the fix sits at the two replay sites instead of at the message's
  source. Each replicate body now runs under a handler that catches and
  counts `surveywts_message_already_calibrated`. One line after the loop
  reports the count, under a new class,
  `surveywts_message_replay_already_calibrated`. On `ns_wave1` weighted to
  `npors_2025_clean` with 25 replicates, that line reads "Raking converged
  in 1 sweep in 22 of 25 replicates: those replicates already met their
  margins." A direct call to `calibrate_rake()` still prints the
  per-replicate message on every call; only the two replay sites catch it.

  **Compatibility note:** code that wrapped a replay call in
  `withCallingHandlers()` or `tryCatch()`, matching on
  `surveywts_message_already_calibrated`, no longer fires. The muffling
  handler sits deeper in the call stack and runs first. This is intended.

## Internal

* The `surveywts_warning_class_near_empty` warning was built in three places,
  each with its own `cli_warn()` call: the `"propensity-cell"` method of
  `adjust_nonresponse()`, the `"weighting-class"` method of
  `adjust_nonresponse()`, and `redistribute_weights()` (#113). One internal
  helper, `.warn_near_empty_cell()`, now builds all three. Each call site
  passes the nouns for the grouping unit and its members, and the first
  suggested remedy. The message shape, the adjustment-factor format, and the
  class stay in the helper.

  The `redistribute_weights()` message takes the same shape as the other two.
  It read `Redistribution group "(global)" has 3 recipient(s), adjustment
  factor 8.33×.` and now reads `Redistribution group "(global)" is sparse (3
  recipient(s), adjustment factor 8.33×).` The other two messages are
  unchanged.

* Add tests for `calibrate_to_survey()` and `calibrate_to_estimate()` edge
  cases: `method = "logit"` and non-matrix `vcov_estimate`.

* Remove stale `weighted_df` references left after PR #86 — source comments,
  roxygen `@param` docs, and test descriptions updated throughout.

## Breaking changes

### All weighting functions now require survey objects

All calibration, nonresponse, utility, and diagnostic functions
(`calibrate()`, `calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`,
`poststratify()`, `adjust_nonresponse()`, `redistribute_weights()`,
`trim_weights()`, `rescale_weights()`, `effective_sample_size()`,
`weight_variability()`, `summarize_weights()`) now require a `survey_taylor`,
`survey_nonprob`, or `survey_replicate` object as the `data` (or `x`) argument.
Plain `data.frame` and `weighted_df` inputs now throw
`surveywts_error_not_survey_base`.

The `weighted_df` S3 class and all associated infrastructure have been
removed: `.make_weighted_df()`, `dplyr_reconstruct.weighted_df()`,
`print.weighted_df()`, and the `weight_col` / `weighting_history` attributes
are no longer part of the package.

### `wt_name` default changed from `"wts"` to `NULL`

All weighting functions that accept a `wt_name` argument now default to
`wt_name = NULL`. When `NULL`, calibrated / adjusted weights overwrite the
existing weight column in-place. When a character scalar, a new column is
created and `@variables$weights` is updated to point to it.

### `calibrate_to_survey()` — native Opsomer algorithm replaces svrep delegation

`calibrate_to_survey()` now implements the Opsomer & Erciulescu (2022)
replication variance adjustment natively. The svrep delegation (via
`svrep::calibrate_to_sample()`) has been removed from the main calibration
path. Existing calls with `targets = NULL` will continue to produce
calibrated designs, but the replicate weight adjustment now uses the Opsomer
algorithm directly rather than delegating to svrep. Numerical results may
differ slightly from prior versions.

The default calibration method is now `method = "rake"`. The prior
svrep-based path used linear GREG by default; callers who need that
behavior should supply `method = "linear"` explicitly.

### `calibrate_to_survey()` history entry schema change

The weighting history entry produced by `calibrate_to_survey()` now promotes
`K`, `a_constants`, `targets`, `type`, and `fixed_variables` as top-level
fields on the history entry (in addition to being stored under `parameters`).
Code that accessed these values via `entry$parameters$K` should now use
`entry$K` instead. The `parameters` sub-list retains all fields for backward
compatibility.

## Datasets

### New datasets

Seven tibble datasets replace the previous IPW-only reference designs:

* `gss_2024`: GSS 2024 (3,309 rows, 32 columns) with derived `age_f3`,
  `race_f4`, `pid_f3`, `edu_f3`, and `wt_pop` columns.
* `ns_wave1`: National Survey Wave 1 (6,422 rows, 185 columns) with derived
  `age_f3`, `race_f4`, `pid_f3`, and `edu_f3` columns; `gender` converted
  to factor.
* `npors_2025`: Pew NPORS 2025 (5,022 rows, 71 columns) with derived
  `gender` (factor), `age_f3`, `race_f4`, `pid_f3`, `edu_f3`, and `wt_pop`
  columns.
* `npors_2025_clean`: `npors_2025` filtered to complete cases on the
  derived columns (4,814 rows).
* `cps_2023`: CPS ASEC 2023 (9,999 rows, 187 columns) with derived
  `age_f3`, `race_f4`, and `edu_f3` columns.
* `pew_2016_optin`: Pew 2016 opt-in sample (2,000 rows, 305 columns).
* `pew_2016_synth_pop`: Pew 2016 synthetic population (20,000 rows,
  43 columns).

No survey design companion objects are shipped. Examples construct designs
from the tibbles with `surveycore::as_survey()` or
`surveycore::as_survey_nonprob()`.

### Retired datasets

The following datasets have been removed. Update code that references them:

| Old name | Replacement |
|---|---|
| `ns_wave1_ipw` | `ns_wave1` |
| `gss_ipw_ref` | `gss_2024` + `surveycore::as_survey(gss_2024, weights = wt_pop, ...)` |
| `npors_2025_ref` | `npors_2025` |
| `npors_2025_clean_ref` | `npors_2025_clean` |
| `acs_ipw_ref` | removed without replacement (the ACS reference is retired) |

### `ipw()` examples updated

The bundled examples in `?ipw` now use the new dataset names. Reference
designs for IPW are constructed from tibbles using `surveycore::as_survey()`:
```r
gss_ref <- surveycore::as_survey(
  gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
)
result <- ipw(ns_wave1, gss_ref, selection = ~sex + age_f3)
```

# surveywts 0.2.0

## Replicate weight generation

This release adds a full suite of replicate weight functions for variance estimation.

### New functions

* `create_bootstrap_weights()`: Generates bootstrap replicate weights from a
  `survey_taylor` or `survey_nonprob` design, wrapping `svrep::as_bootstrap_design()`.

* `create_jackknife_weights()`: Generates jackknife replicate weights with two
  strategies: `type = "delete-1"` (JK1 for unstratified, JKn for stratified designs;
  supports `survey_nonprob`) and `type = "random-groups"` (random-group jackknife
  via `svrep`).

* `create_brr_weights()`: Generates balanced repeated replication (BRR) weights from
  paired-PSU designs. A `rho` argument enables Fay's BRR variant.

* `create_gen_boot_weights()`: Generates generalized bootstrap replicate weights via
  `svrep::as_gen_boot_design()`, supporting 12 variance estimators including
  Horvitz-Thompson, Yates-Grundy, and Deville-Tille.

* `create_gen_rep_weights()`: Generates Fay's generalized replication weights via
  `svrep::as_fays_gen_rep_design()`, with the same set of variance estimators and
  a `seed` argument for reproducibility.

* `create_sdr_weights()`: Generates successive difference replication (SDR) weights
  via `svrep::as_sdr_design()`, with an optional `sort_var` argument for
  systematic selection order.

* `create_replicate_weights()`: Unified dispatcher that routes to the appropriate
  `create_*_weights()` function based on a `method` argument.

* `as_taylor_design()`: Reconstructs a `survey_taylor` design from a
  `survey_replicate`, reading the original design structure from the weighting history.

### New methods

* `print()` for `survey_replicate` objects displays the design type, replicate count,
  scale, weight summary, and full weighting history.

# surveywts 0.1.2

## Breaking changes

* The default output weight column name for `calibrate()`, `rake()`,
  `poststratify()`, and `adjust_nonresponse()` changes from `".weight"` to
  `"wts"` when the input is a plain `data.frame` with `weights = NULL`.

## New features

* `calibrate()`, `rake()`, `poststratify()`, and `adjust_nonresponse()` gain a
  `wt_name` argument (default `"wts"`) that controls the name of the output
  weight column for `data.frame` and `weighted_df` inputs. Input weight columns
  are preserved when `wt_name` differs from the input column name. `wt_name` is
  silently ignored for survey object inputs.

# surveywts 0.1.1

## Breaking changes

* `adjust_nonresponse()` now returns all rows with nonrespondent weights
  set to 0, instead of dropping nonrespondent rows. This preserves design
  structure for variance estimation. Code that uses `nrow(result)` to count
  respondents should use `sum(result$weight_col > 0)` instead.

* `poststratify()` now defaults to `type = "prop"`, consistent with
  `calibrate()` and `rake()`. Existing code that relies on the count default
  should add explicit `type = "count"`.

## Bug fixes

* `calibrate()`, `rake()`, and `poststratify()` now delegate to `survey::calibrate()`,
  `survey::rake()`, `anesrake::anesrake()`, and `survey::postStratify()` instead of
  vendored algorithm copies. This improves numerical correctness and maintainability (#16).

* `adjust_nonresponse()` `response_status` argument now resolves via
  `tidyselect::eval_select()` instead of `rlang::as_name()`, supporting
  tidy-select semantics and providing a clearer error for multi-column
  selection (#15).

* Input validation in `calibrate()`, `rake()`, `poststratify()`, and
  `adjust_nonresponse()` now uses `survey_base` inheritance checks instead
  of listing specific class names (#15).

* `summarize_weights()` grouped path now uses `paste(sep = "//")` instead of
  `interaction()`, avoiding separator collisions with factor levels containing
  dots (e.g., `"Dr."`) (#13).

* `survey_nonprob` print method now shows `"Variance: model-assisted (SRS assumption)"`
  instead of incorrectly labelling it as Taylor linearization (#13).

## Internal

* Moved shared helpers `.check_input_class()` and `.get_history()` to `R/utils.R`;
  inlined `%||%` operator (#12).

* Moved `survey` from Suggests to Imports; added `anesrake` to Imports (#16).

# surveywts 0.1.0

## Breaking changes

* `adjust_nonresponse()` now returns all rows with nonrespondent weights
  set to 0, instead of dropping nonrespondent rows. This preserves design
  structure for variance estimation. Code that uses `nrow(result)` to count
  respondents should use `sum(result$weight_col > 0)` instead.

* `poststratify()` now defaults to `type = "prop"`, consistent with
  `calibrate()` and `rake()`. Existing code that relies on the count default
  should add explicit `type = "count"`.

## Calibration: Weighting Core

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
  `by`. Methods `"propensity"` and `"propensity-cell"` are stubbed for the Propensity release.

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
