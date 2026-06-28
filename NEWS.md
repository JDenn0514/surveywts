# surveywts 0.2.1 (development)

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

### `calibrate_to_survey()` history entry schema change

The weighting history entry produced by `calibrate_to_survey()` now promotes
`K`, `a_constants`, `targets`, `type`, and `fixed_variables` as top-level
fields on the history entry (in addition to being stored under `parameters`).
Code that accessed these values via `entry$parameters$K` should now use
`entry$K` instead. The `parameters` sub-list retains all fields for backward
compatibility.

## Datasets

### New datasets

Seven new tibble datasets and seven paired survey design companion objects
replace the previous IPW-only reference designs.

New tibbles:
* `gss_2024`: GSS 2024 (3,309 rows, 30 columns) with derived `gender`,
  `age_group`, and `wt_pop` columns.
* `ns_wave1`: National Survey Wave 1 (6,422 rows, 174 columns) with derived
  `age_group`, `race_ethn`, and `educ` columns; `gender` converted to factor.
* `npors_2025`: Pew NPORS 2025 (5,022 rows, 69 columns) with derived
  `gender` (factor), `age_group`, `race_ethn`, `educ`, and `wt_pop` columns.
* `npors_2025_clean`: `npors_2025` filtered to complete cases on the four
  derived columns (approximately 4,814 rows).
* `acs_wy_2022`: ACS PUMS 2022 Wyoming adults (4,736 rows, 100 columns) with
  derived `gender`, `age_group`, `race_ethn`, and `educ` columns.

Companion survey design objects (one per tibble, plus two for the pew_2016
datasets):
* `gss_2024_svy`: `survey_taylor` using `wtssps` with `vstrat`/`vpsu`.
* `ns_wave1_svy`: `survey_nonprob` using `weight`.
* `npors_2025_svy`: `survey_taylor` using `weight`.
* `npors_2025_clean_svy`: `survey_taylor` using `weight`.
* `acs_wy_2022_svy`: `survey_replicate` (SDR, 80 replicates, `mse = TRUE`).
* `pew_2016_optin_svy`: `survey_nonprob` with equal weights.
* `pew_2016_synth_pop_svy`: `survey_taylor` (SRS) with equal weights.

### Retired datasets

The following datasets have been removed. Update code that references them:

| Old name | Replacement |
|---|---|
| `ns_wave1_ipw` | `ns_wave1` |
| `gss_ipw_ref` | `gss_2024` + `surveycore::as_survey(gss_2024, weights = wt_pop, ...)` |
| `npors_2025_ref` | `npors_2025` |
| `npors_2025_clean_ref` | `npors_2025_clean` |
| `acs_ipw_ref` | `acs_wy_2022` + `surveycore::as_survey(acs_wy_2022, weights = pwgtp)` |

### `ipw()` examples updated

The bundled examples in `?ipw` now use the new dataset names. Reference
designs for IPW are constructed from tibbles using `surveycore::as_survey()`:
```r
gss_ref <- surveycore::as_survey(
  gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
)
result <- ipw(ns_wave1, gss_ref, selection = ~gender + age_group)
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
