# R/create_brr_weights.R
#
# create_brr_weights() — balanced repeated replication (Fay variant) weights.

# ============================================================================
# create_brr_weights()
# ============================================================================

#' Generate BRR (Fay) replicate weights
#'
#' Generates BRR (balanced repeated replication) or Fay's BRR replicate
#' weights (sets of perturbed weight columns used to compute standard
#' errors) via [survey::as.svrepdesign()]. Requires a paired-PSU design:
#' exactly 2 PSUs (primary sampling units: the first units the design
#' selects, such as counties or schools) per stratum.
#'
#' @param data A `survey_taylor` with exactly 2 PSUs per stratum.
#' @param ... Must be empty.
#' @param rho `numeric(1)`, default `0`. Fay damping coefficient. `rho = 0`
#'   gives standard BRR; `rho > 0` gives Fay's BRR variant with factors `rho`
#'   and `2 - rho`. Must satisfy `0 <= rho < 1`.
#' @param mse `logical(1)`, default `TRUE`. Centers each replicate deviation
#'   on the full-sample estimate (`TRUE`; conservative) or on the mean of
#'   the replicate estimates (`FALSE`).
#'
#' @returns A `survey_replicate` with `@variables$type` of `"BRR"` or `"Fay"`.
#'
#' @details
#' **When to use.** Choose BRR when the design holds exactly two PSUs
#' in every stratum, and especially when you estimate a quantile or
#' another nonlinear statistic — BRR is proven for those, and no
#' jackknife variant is (Valliant, Dever & Kreuter 2018, Section 15.4).
#' Set `rho > 0` when you estimate a ratio: with the default
#' `rho = 0`, one PSU per stratum drops to zero weight in each
#' replicate, which can leave a ratio undefined (Dippo, Fay &
#' Morganstein 1984).
#'
#' @section Algorithm:
#' BRR creates \eqn{R} half-sample replicates from a paired-PSU design
#' (exactly 2 PSUs per stratum). A Hadamard matrix of order \eqn{R}
#' determines which PSU in each stratum belongs to each half-sample.
#' Within replicate \eqn{r}, PSU 1 receives weight \eqn{2(1-\rho)} and
#' PSU 2 receives weight \eqn{2\rho} (or vice versa). The BRR variance
#' estimator is:
#' \deqn{\hat{V}_{BRR} = \frac{1}{R(1-\rho)^2}
#'   \sum_{r=1}^{R} (\hat{\theta}^{(r)} - \hat{\theta})^2.}
#' When `rho = 0`, this simplifies to standard BRR. The Fay variant
#' (`rho > 0`) reduces variance instability from extreme replicate
#' estimates.
#'
#' @references
#'   Fay, R.E. (1984). Some properties of estimates of variance based on
#'   replication methods. *Proceedings of the Section on Survey Research
#'   Methods, American Statistical Association*, 495--500.
#'
#'   Fay, R.E. (1989). Theory and application of replicate weighting for
#'   variance calculations. *Proceedings of the Section on Survey Research
#'   Methods, American Statistical Association*.
#'
#'   Dippo, C., Fay, R.E. and Morganstein, D. (1984). Computing variances
#'   from complex samples with replicate weights. *Proceedings of the
#'   Section on Survey Research Methods, American Statistical Association*,
#'   489--494.
#'
#'   Valliant, R., Dever, J. and Kreuter, F. (2018). *Practical Tools for
#'   Designing and Weighting Survey Samples*, 2nd edition. New York:
#'   Springer.
#'
#' @examples
#' # standard BRR on a stratified 2-PSU-per-stratum design ----------------
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' create_brr_weights(gss_svy)
#'
#' # Fay's BRR with damping coefficient -----------------------------------
#' create_brr_weights(gss_svy, rho = 0.5)
#'
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_gen_boot_weights()], [create_gen_rep_weights()],
#'   [create_sdr_weights()], [create_replicate_weights()], [as_taylor_design()].
#'   For the class system, the standard workflows, and a glossary of terms,
#'   see the [Getting started
#'   article](https://jdenn0514.github.io/surveywts/articles/getting-started.html).
#' @family replicate-weights
#' @export
create_brr_weights <- function(data, ..., rho = 0, mse = TRUE) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "BRR requires a paired-PSU design; {.cls survey_nonprob} has no PSU structure.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  if (is.null(data@variables$strata) || is.null(data@variables$ids)) {
    cli::cli_abort(
      c(
        "x" = "BRR requires a design with both strata and PSU IDs.",
        "i" = paste0(
          "Strata: ",
          if (is.null(data@variables$strata)) "missing" else "present",
          "; PSU IDs: ",
          if (is.null(data@variables$ids)) "missing" else "present",
          "."
        ),
        "v" = "Build the design with both {.arg ids} and {.arg strata} in {.fn surveycore::as_survey}."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  psu_col <- data@variables$ids
  strata_col <- data@variables$strata
  df <- data@data
  counts <- tapply(
    df[[psu_col]],
    df[[strata_col]],
    function(x) length(unique(x))
  )
  bad <- names(counts)[counts != 2L]
  if (length(bad) > 0L) {
    show <- utils::head(bad, 5L)
    suffix <- if (length(bad) > 5L) {
      paste0(" ... (", length(bad) - 5L, " more)")
    } else {
      ""
    }
    cli::cli_abort(
      c(
        "x" = "BRR requires exactly 2 PSUs per stratum.",
        "i" = paste0(
          "Stratum/a with wrong PSU count: ",
          paste(show, collapse = ", "),
          suffix,
          "."
        ),
        "v" = "Use {.fn create_gen_rep_weights} for designs with unequal PSU counts per stratum."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  if (rho < 0 || rho >= 1) {
    cli::cli_abort(
      c(
        "x" = "{.arg rho} must satisfy 0 <= rho < 1; got {.val {rho}}.",
        "i" = "{.arg rho} = 0 gives standard BRR; {.arg rho} > 0 gives Fay's BRR variant."
      ),
      class = "surveywts_error_brr_rho_invalid"
    )
  }

  if (rho == 0) {
    .convert_and_call(
      data = data,
      backend_fn = function(d) {
        survey::as.svrepdesign(d, type = "BRR", mse = mse)
      },
      method = "brr",
      params = list(rho = 0, mse = mse)
    )
  } else {
    .convert_and_call(
      data = data,
      backend_fn = function(d) {
        survey::as.svrepdesign(d, type = "Fay", fay.rho = rho, mse = mse)
      },
      method = "brr",
      params = list(rho = rho, mse = mse)
    )
  }
}
