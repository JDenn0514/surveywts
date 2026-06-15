
<!-- README.md is generated from README.Rmd. Please edit that file -->

# surveywts <a href = "https://jdenn0514.github.io/surveywts/index.html"><img src="man/figures/logo.png" align="right" height="138" /></a>

<!-- badges: start -->

[![R-CMD-check](https://github.com/JDenn0514/surveywts/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/JDenn0514/surveywts/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/JDenn0514/surveywts/branch/main/graph/badge.svg)](https://app.codecov.io/gh/JDenn0514/surveywts?branch=main)
[![surveywts status
badge](https://jdenn0514.r-universe.dev/badges/surveywts)](https://jdenn0514.r-universe.dev/surveywts)
<!-- badges: end -->

Part of the [surveyverse](https://github.com/JDenn0514), surveywts is
the one-stop shop for survey weighting. It covers the full weight
adjustment workflow: calibrating to population benchmarks, handling unit
nonresponse, weighting non-probability samples via inverse probability
weighting, generating replicate weights for variance estimation, and
diagnosing weight quality, all with a full audit trail recorded on the
result object.

## Installation

``` r
# From GitHub (development version)
pak::pak("JDenn0514/surveywts")

# From r-universe (pre-built binaries, no GitHub PAT needed)
install.packages("surveywts", repos = "https://jdenn0514.r-universe.dev")
```

## The surveyverse

surveywts is the weighting layer of the surveyverse ecosystem.
[surveycore](https://jdenn0514.github.io/surveycore/) is the foundation,
representing sampling designs and enabling analysis. surveywts operates
on the survey objects surveycore creates, adjusting and calibrating
their weights. [surveytidy](https://jdenn0514.github.io/surveytidy/)
rounds out the ecosystem with tidy data manipulation for survey objects.

## Functions

### Calibration

| Function | Purpose |
|----|----|
| `calibrate()` | Calibrate to population `targets`; choose method with `method = "rake"`, `"linear"`, or `"logit"` |
| `calibrate_linear()` | Linear (GREG) calibration |
| `calibrate_rake()` | Raking (iterative proportional fitting) |
| `calibrate_logit()` | Logit-bounded calibration (guaranteed positive weights) |
| `poststratify()` | Exact cell-level post-stratification |
| `calibrate_to_survey()` | Calibrate against a control survey, propagating its sampling uncertainty |
| `calibrate_to_estimate()` | Calibrate against external estimates with a known variance-covariance matrix |

### Nonresponse adjustment

| Function | Purpose |
|----|----|
| `adjust_nonresponse()` | Nonresponse adjustment via weighting class, propensity cell, or propensity score |
| `redistribute_weights()` | Low-level weight redistribution between any two groups |

### Non-probability samples

| Function | Purpose |
|----|----|
| `ipw()` | Inverse probability weighting via logistic regression (pseudo-likelihood or calibration GEE) |

### Replicate weights

| Function | Purpose |
|----|----|
| `create_replicate_weights()` | Dispatcher for all replicate weight methods |
| `create_bootstrap_weights()` | Bootstrap replicate weights (Rao-Wu-Yue-Beaumont; quasi-randomization for NPS) |
| `create_jackknife_weights()` | Jackknife replicate weights (JK1, JKn, random groups) |
| `create_brr_weights()` | Balanced repeated replication (standard or Fay’s variant) |
| `create_gen_boot_weights()` | Generalized bootstrap weights |
| `create_gen_rep_weights()` | Generalized replication weights (Fay’s method) |
| `create_sdr_weights()` | Successive difference replication |
| `create_group_jackknife_weights()` | Delete-a-group jackknife for non-probability samples |
| `as_taylor_design()` | Convert a replicate design back to Taylor linearization |

### Diagnostics

| Function | Purpose |
|----|----|
| `effective_sample_size()` | Kish effective sample size |
| `weight_variability()` | Coefficient of variation of the weights |
| `summarize_weights()` | Full distributional summary, optionally by group |

### Utilities

| Function              | Purpose                                       |
|-----------------------|-----------------------------------------------|
| `trim_weights()`      | Clip extreme weights with mass redistribution |
| `stabilize_weights()` | Rescale weights to unit mean                  |

## Usage

### Weighting a non-probability sample

`ipw()` constructs weights for a non-probability sample by fitting a
participation propensity model against a probability reference survey.
surveywts ships with a harmonized online panel (`ns_wave1_ipw`) and a
GSS 2024 reference design (`gss_ipw_ref`) to illustrate the workflow.

``` r
library(surveywts)

nps_wts <- ipw(
  ns_wave1_ipw,
  npors_2025_clean_ref,
  predictors = c("gender", "age_group", "race_ethn", "educ"),
  missing_method = "omit"
)
#> Warning: ! 120 row(s) in `data` dropped: NA in race_ethn.
#> ℹ Rows with any NA in a `selection` variable are excluded when `missing_method
#>   = "omit"`.
#> ✔ Use `missing_method = "separate"` or `missing_method = "impute"` to retain
#>   rows with NA.

summarize_weights(nps_wts)
#> # A tibble: 1 × 11
#>       n n_positive n_zero   mean    cv    min    p25    p50    p75     max   ess
#>   <int>      <int>  <int>  <dbl> <dbl>  <dbl>  <dbl>  <dbl>  <dbl>   <dbl> <dbl>
#> 1  6302       6302      0 39682. 0.951 13082. 17522. 26166. 45433. 596465. 3310.
effective_sample_size(nps_wts)
#>    n_eff 
#> 3309.588
```

### Calibrating to population benchmarks

`calibrate()` adjusts weights to match known population `targets`. Here
we rake the IPW-weighted panel to census marginals for a doubly robust
estimate.

``` r
targets <- list(
  gender = c("Male" = 0.49, "Female" = 0.51),
  age_group = c("18-34" = 0.28, "35-54" = 0.37, "55+" = 0.35)
)

calibrated <- calibrate(
  nps_wts,
  targets = targets,
  method = "rake"
)

summarize_weights(calibrated)
#> # A tibble: 1 × 11
#>       n n_positive n_zero  mean    cv   min   p25   p50   p75   max   ess
#>   <int>      <int>  <int> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#> 1  6302       6302      0  1.00 0.917 0.339 0.502 0.615  1.18  14.3 3425.
```

### Calibrating to a reference survey

`calibrate_to_survey()` calibrates a primary design to match estimates
from a control survey, propagating the control’s own sampling
uncertainty into the final variance estimates. Both designs must carry
replicate weights.

``` r
npors_rep <- create_bootstrap_weights(npors_2025_clean_ref, seed = 1)
gss_rep <- create_bootstrap_weights(gss_ipw_ref, seed = 1)

calibrated_to_ref <- calibrate_to_survey(
  npors_rep,
  gss_rep,
  variables = c(gender, age_group)
)
#> Matching between primary and control replicates will be done at random.
#> For tips on reproducible matching, see `help('calibrate_to_sample')`
```

### Generating replicate weights

`create_bootstrap_weights()` adds replicate weight columns for variance
estimation. For non-probability samples it applies a quasi-randomization
bootstrap.

``` r
rep_design <- create_bootstrap_weights(calibrated, seed = 1)
```

## Learn more

Full documentation is available at
<https://jdenn0514.github.io/surveywts/>.
