# surveywts (development version)

## New features

* `weighting_history()` returns the weighting steps recorded on a design as
  a tibble, with one row per step and the columns `step`, `timestamp`,
  `operation`, and `description`.

## Breaking changes

* surveywts no longer replaces surveycore's `print()` for `survey_replicate`
  and `survey_nonprob` designs. `print()` on these designs now shows
  surveycore's layout, with its `design_info` and `weights_info` arguments,
  the FPC line, `rho`, and the data preview. The weighting history section
  that surveywts' print used to show is gone; call `weighting_history()`
  instead.

# surveywts 0.3.0

## New features

### Calibration

* `calibrate_rake()` replaces `rake()`. It takes `targets` in place of
  `margins` and `algorithm` in place of `method`. `algorithm = "classic_ipf"`
  is iterative proportional fitting, the engine `rake()` used.
  `algorithm = "nr"` is Newton-Raphson raking (Deville, Sarndal & Sautory
  1993), which uses the exponential calibration function.

* `calibrate_linear()` calibrates to linear (GREG) and truncated-linear
  targets, following Deville & Sarndal (1992). Bounds are optional, and
  `bounds_scale` reads them as multiplicative or absolute. The calibrated
  weights match `survey::calibrate()` to within 1e-8.

* `calibrate_logit()` calibrates with the logit calibration function,
  following Deville, Sarndal & Sautory (1993). `bounds` is required and holds
  each g-weight inside the open interval it names, so every calibrated weight
  is strictly positive. The weights match
  `survey::calibrate(calfun = "logit")` to within 1e-8.

* `calibrate_rake()`, `calibrate_linear()`, and `calibrate_logit()` take
  `unit_scale`, a vector of per-unit scaling factors (the q-weights of
  Deville & Sarndal 1992).

* The four calibration functions accept `survey_replicate` input and
  calibrate every replicate weight column.
  `@calibration$replicate_converged` names the columns that did not converge.

* A survey object returned by `calibrate_rake()`, `calibrate_linear()`,
  `calibrate_logit()`, or `poststratify()` carries a `@calibration` slot. The
  slot holds the calibration provenance: the g-weights, the discrepancy from
  the targets, the cross-product inverse, and the converged Lagrange vector.

* The four calibration functions take `reference_design`. A `survey_taylor`
  supplied here is stored in the weighting history, so a later
  quasi-randomization bootstrap can re-estimate the targets in each draw.

### Sample-based calibration

* `calibrate_to_survey()` calibrates a design to a control survey. Each
  replicate is calibrated to the matching control replicate, so the variance
  of the control totals reaches the variance estimate. `targets` adds fixed
  census margins alongside the control-survey margins.

* `calibrate_to_estimate()` calibrates to control totals given as a named
  list of counts and a variance-covariance matrix. Each replicate is
  calibrated to a perturbed draw from that distribution.

* Both functions accept a `survey_nonprob` that carries replicate weights,
  and both return the class of the design they were given.

### Non-probability samples

* `ipw()` builds inverse probability weights for a non-probability sample
  from a probability reference design, following Chen, Li & Wu (2020) and
  Elliott & Valliant (2017). The links `logit`, `probit`, and `cloglog` are
  supported. The default `estimating_eq = "gee"` solves the calibration
  estimating equation with `nleqslv::nleqslv()` and gives exact covariate
  balance; `estimating_eq = "mle"` solves the pseudo-likelihood score
  equation. `reference` accepts a `survey_taylor` or a `survey_replicate`.

* `adjust_nonresponse(method = "propensity")` fits a response propensity
  model and adjusts each respondent weight by its own inverse score. This
  method requires `formula`.

* `adjust_nonresponse(method = "propensity-cell")` sorts the propensity
  scores into quantile cells, `control$n_cells` of them, and redistributes
  the nonrespondent weight inside each cell.

* `redistribute_weights()` takes the weight of the rows that `reduce_if`
  names and transfers it to the rows that `increase_if` names, in proportion
  to the weight those rows already hold. `by` restricts the transfer to
  within groups.

### Replicate weights for non-probability samples

* `create_bootstrap_weights(type = "quasi-randomization")` produces
  quasi-randomization bootstrap weights for a `survey_nonprob`. Each draw
  resamples the sample and the reference with replacement, then re-estimates
  the weights. Three histories are supported: IPW alone, calibration alone,
  and both.

* `create_jackknife_weights(type = "grouped")` produces delete-a-group
  jackknife weights for a `survey_nonprob` (Valliant, Brick & Dever 2008).
  It refits the propensity model in every replicate and replays a stored
  calibration.

### Weight utilities

* `trim_weights()` clips extreme weights and redistributes the trimmed weight
  to the units it kept, following Potter & Zheng (2015). The cutpoints come
  from the interquartile range, from absolute bounds, or from percentiles.
  `strict = TRUE` repeats the trim until every weight is inside the bounds.

* `rescale_weights()` scales the weights so they sum to the sample size,
  either across the sample or inside groups that `by` names.

* Both functions also operate on each replicate weight column of a
  `survey_replicate`, and of a `survey_nonprob` that carries replicate
  weights.

### Diagnostics

* `effective_sample_size()`, `weight_variability()`, and
  `summarize_weights()` accept `survey_replicate` input. They read the main
  weight column; they do not compute the replicate variance of a diagnostic.

## Breaking changes

### `rake()` is removed

Call `calibrate_rake()` instead. `targets` replaces `margins`, and
`algorithm` replaces `method`. The algorithm named `"anesrake"` is now
`"classic_ipf"`; the algorithm itself is unchanged. Algorithm `"survey"` is
removed. The history `operation` field reads `"calibrate_rake"`, not
`"raking"`.

### `calibrate()` is a dispatcher

`calibrate()` now routes to `calibrate_rake()`, `calibrate_linear()`, or
`calibrate_logit()`. The `method` argument changes from
`c("linear", "logit")` with default `"linear"` to
`c("rake", "linear", "logit")` with default `"rake"`. One `targets` argument
replaces `variables` and `population`. Code that relied on the old default
should call `calibrate_linear()`.

### `poststratify()` takes `targets`

`poststratify(data, strata, population, ...)` becomes
`poststratify(data, targets, ...)`. `targets` is one data frame. Every column
except `target` names a stratifying variable.

### `create_jackknife_weights()` type values are renamed

| Old | New |
|---|---|
| `type = "delete-1"` | `type = "jkn"` (stratified) or `type = "jk1"` (unstratified) |
| `type = "random-groups"` | `type = "grouped"` |

`type = "delete-1"` read the design and chose JKn or JK1 for the caller. The
caller now names the one they want. The delete-a-group jackknife for
non-probability samples arrives on the same argument, as `type = "grouped"`
with a `survey_nonprob` input.

### `create_bootstrap_weights()` reads `mse` as a string

`mse` moves from `TRUE` or `FALSE` to `"mse"` (the default),
`"chrostowski"`, or `"uncentered"`. Replace `mse = FALSE` with
`mse = "uncentered"`.

The `replicates` default moves from `500L` to `NULL`. `NULL` resolves to
`500L` for the probability-sample types and to `200L` for
`type = "quasi-randomization"`.

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

## Bug fixes

* `create_sdr_weights()` did not forward `use_normal_hadamard` to
  `svrep::as_sdr_design()` (#119), so the back end always ran at the svrep
  default `FALSE`. On that path the Hadamard order doubles from 4 — 4, 8, 16,
  32, 64, 128, 256 and on up — so a request for 50 returned 64.

  `use_normal_hadamard` is now an argument, with the same default `FALSE`. No
  existing call changes. At `TRUE` the order comes from a finer grid, so a
  request for 50 returns 56 and a request for 20 returns 20. The finer grid
  costs inactive replicates — columns whose replicate factors all equal 1. The
  count rises as the PSU count falls relative to the order. An inactive
  replicate is valid for variance estimation.

  The two settings give different variance estimates once the PSU count
  exceeds the smaller order, and the gap grows with the PSU count. Both are
  valid. Keep the default to reproduce existing results. The Algorithm section
  of `?create_sdr_weights` gives the check to run and the measured sizes.

  Two further differences at the same order. For a total both settings give
  the same variance at `mse = TRUE`; for a mean they can differ. At
  `mse = FALSE` they differ for a total as well.

  This reverses decision Q8 of the replicate phase, which hid the argument.

* The SDR variance formula in the `create_sdr_weights()` help page printed the
  scale factor as `1 / (2R)`. The scale factor is `4 / R`, which is what the
  function has always computed. The published formula understated the variance
  by a factor of 8, so a reader who reimplemented it, or who checked surveywts
  against it, got a standard error too small by a factor of about 2.83. No
  computed result changes; only the documented formula does.

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

* `create_gen_boot_weights()`, `create_gen_rep_weights()`, and
  `create_sdr_weights()` printed an unclassed `svrep` message on every
  successful call (#114). The messages were plain `message()` calls, so the
  only way to quiet one was a blanket `suppressMessages()`, which also
  swallowed every surveywts message.

  All three now carry a class: `surveywts_message_row_order_assumed`,
  `surveywts_message_replicates_rounded_up`, and
  `surveywts_message_replicates_subsampled`. A message from the back end
  that surveywts does not recognise keeps its text and arrives as
  `surveywts_message_backend_note`.

  Two of the texts changed. The `create_sdr_weights()` message now names
  `replicates` and the real column count, and it fires only when the two
  differ. `create_gen_rep_weights()` now points at `seed` when it keeps a
  random sample of the replicates and no seed was given.

* The quasi-randomization bootstrap left `@variables$scale`,
  `@variables$rscales`, `@variables$type`, and `@variables$mse` empty on the
  `survey_nonprob` it returned (#78). `calibrate_to_survey()` reads `scale`,
  so it threw `surveywts_error_scale_not_found` when a bootstrapped design
  arrived as `primary_design` or `control_design`. All four fields are now
  set: `scale` is `1 / draws_used`, `rscales` holds one 1 per draw, `type` is
  `"bootstrap"`, and `mse` follows the `mse` argument.

* `cap = NULL` applied a cap of 5 in the raking engine, the
  `anesrake::anesrake()` default. `cap = NULL` now means no cap.

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

## Internal

* No test held `create_sdr_weights()` to the SDR variance scale factor
  (#126). The help page states `4 / R`, and PR #124 corrected it there, but
  nothing tied that number to the object the function returns. A new block in
  `tests/testthat/test-replicate-weights.R` asserts the scale two ways: a
  fixed pin, `4 / 32` on a 20-PSU design at `replicates = 20L`, and the
  relation `scale == 4 / length(repweights)` over both settings of
  `use_normal_hadamard` and three more replicate counts. `R` is the full
  column count, inactive replicates included. No code changed.

* `test_invariants()` in `tests/testthat/helper-test-data.R` never checked a
  `survey_nonprob` object (#117). The branch for that class tested a bare
  class name behind a guard: `exists("survey_nonprob") &&
  S7::S7_inherits(obj, survey_nonprob)`. surveywts does not re-export the
  class, and `tests/testthat.R` attaches only `testthat` and `surveywts`, so
  the bare name resolved nowhere and the guard was always `FALSE`. The parent
  of `survey_nonprob` is the abstract `survey_base`, not `survey_taylor` or
  `survey_replicate`, so no other branch caught the object either. 77 of the
  282 calls registered zero expectations, most of them in the
  non-probability code: `ipw()`, the DAGJK, the quasi-randomization
  bootstrap, and propensity nonresponse.

  The branch now tests `surveycore::survey_nonprob`, the form the other two
  branches already use. Each of the 77 calls now asserts the four weight
  invariants: the weight column name is a character scalar, the name is
  present in `@data`, the column is numeric, and all values are `>= 0` with
  at least one `> 0`. The suite goes from 3837 to 4145 passing expectations
  and still reports zero failures, so no `survey_nonprob` object in the tests
  was breaking a weight invariant.

  `.claude/standards/testing-surveywts.md` recorded the guard as deliberate.
  It now states that all three branches test the qualified class name.

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

* Dependency changes. `svrep (>= 0.9.1)` and `nleqslv (>= 3.3.2)` move to
  Imports. `anesrake` moves to Suggests, because the raking engine is now
  ported into the package and `anesrake` is used only for parity tests. The
  minimum `surveycore` version is 1.0.0.

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
