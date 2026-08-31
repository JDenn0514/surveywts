#' Tools for Survey Weighting and Calibration
#'
#' @description
#' Provides the full weight adjustment workflow for survey data. Calibrates
#' weights to known population totals by raking, linear (GREG), logit-bounded,
#' or post-stratification estimators. Corrects unit nonresponse, estimates
#' inverse probability weights for a non-probability sample, and generates
#' replicate weights for variance estimation. Trims and rescales weights,
#' reports weight diagnostics, and records every adjustment in the weighting
#' history of the survey object.
#'
#' @section Key Functions:
#' **Calibration:**
#' - `calibrate()`: a thin dispatcher that routes to `calibrate_rake()`,
#'   `calibrate_linear()`, or `calibrate_logit()` based on `method`
#' - `calibrate_linear()`: linear (GREG) calibration to marginal totals;
#'   `bounds` switches it to truncated-linear calibration
#' - `calibrate_logit()`: logit-bounded calibration; the g-weights stay inside
#'   an open interval, so the calibrated weights stay positive
#' - `calibrate_rake()`: raking (iterative proportional fitting) to several
#'   marginal totals at the same time
#' - `poststratify()`: matches the exact cross-tabulation cells in one pass
#'   instead of the marginal totals
#'
#' **Sample-Based Calibration:**
#' - `calibrate_to_survey()`: reweights a design to the totals estimated from
#'   a control survey, and propagates the uncertainty of those estimates
#' - `calibrate_to_estimate()`: reweights a design to externally supplied
#'   count totals, with a variance-covariance matrix for those totals
#'
#' **Propensity Weighting:**
#' - `ipw()`: estimates inverse probability weights for a non-probability
#'   sample from the participation propensity against a reference sample
#'
#' **Nonresponse Adjustment:**
#' - `adjust_nonresponse()`: moves the weight of the nonrespondents to the
#'   respondents inside weighting classes
#' - `redistribute_weights()`: sets the weight of the excluded rows to zero
#'   and moves that weight to the retained rows
#'
#' **Replicate Weights:**
#' - `create_replicate_weights()`: a dispatcher that routes to one of the
#'   `create_*_weights()` functions based on `method`
#' - `create_bootstrap_weights()`: bootstrap replicate weights, or
#'   quasi-randomization bootstrap weights for a non-probability sample
#' - `create_jackknife_weights()`: jackknife replicate weights, including the
#'   delete-a-group jackknife for a non-probability sample
#' - `create_brr_weights()`: balanced repeated replication (BRR) or Fay's BRR
#'   weights; the design must have exactly 2 PSUs per stratum
#' - `create_sdr_weights()`: successive difference replication weights
#' - `create_gen_boot_weights()`: generalized bootstrap replicate weights for
#'   a given target variance estimator
#' - `create_gen_rep_weights()`: Fay's generalized replication weights, which
#'   are deterministic
#' - `as_taylor_design()`: converts a replicate design back to a Taylor
#'   design and drops the replicate weight columns
#'
#' **Weight Utilities:**
#' - `trim_weights()`: clips the weights to a bounded interval and spreads the
#'   trimmed excess across the untrimmed units
#' - `rescale_weights()`: rescales the weights to sum to the sample size,
#'   either overall or within each group
#'
#' **Diagnostics:**
#' - `effective_sample_size()`: Kish's effective sample size
#' - `weight_variability()`: the coefficient of variation of the weights
#' - `summarize_weights()`: a table of weight distribution statistics,
#'   optionally by group
#'
#' @keywords internal
"_PACKAGE"
