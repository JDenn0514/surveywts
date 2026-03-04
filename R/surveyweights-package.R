#' Tools for Survey Weighting and Calibration
#'
#' @description
#' Provides tools for calibrating survey weights to known population totals
#' using GREG, raking (iterative proportional fitting), and
#' post-stratification. Supports nonresponse adjustment via the
#' weighting-class method, effective sample size diagnostics, and full
#' weighting history tracking for reproducible survey analysis workflows.
#'
#' @section Key Functions:
#' **Calibration:**
#' - `calibrate()` — GREG (linear) or logit calibration to population totals
#' - `rake()` — raking via iterative proportional fitting
#' - `poststratify()` — exact post-stratification to cell counts or proportions
#'
#' **Nonresponse:**
#' - `adjust_nonresponse()` — weighting-class nonresponse adjustment
#'
#' **Diagnostics:**
#' - `effective_sample_size()` — Kish effective sample size
#' - `weight_variability()` — coefficient of variation of weights
#' - `summarize_weights()` — full weight distribution summary table
#'
#' @keywords internal
"_PACKAGE"
