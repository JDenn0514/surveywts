# R/create_gen_rep_weights.R
#
# create_gen_rep_weights() — generalized replication weights.

# ============================================================================
# create_gen_rep_weights()
# ============================================================================

#' Generate generalized replication replicate weights
#'
#' Generates Fay's generalized replication weights via
#' [svrep::as_fays_gen_rep_design()]. Produces deterministic replicate weights
#' (no randomness). Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design.
#' @param ... Must be empty.
#' @param variance_estimator `character(1)`. Target variance estimator. Same
#'   options as [create_gen_boot_weights()]. Default `"SD2"`.
#' @param max_replicates `numeric(1)`, default `Inf`. Maximum number of
#'   replicates; `Inf` uses the natural count.
#' @param balanced `logical(1)`, default `TRUE`. Equal contribution of
#'   replicates to variance estimates.
#' @param aux_var_names `<tidy-select>` or `NULL`. Required for
#'   `"Deville-Tille"`.
#' @param mse `logical(1)`, default `TRUE`. Centers each replicate deviation
#'   on the full-sample estimate (`TRUE`; conservative) or on the mean of
#'   the replicate estimates (`FALSE`).
#' @param seed `integer(1)` or `NULL`. RNG seed for reproducibility. The
#'   construction is deterministic unless `max_replicates` is below the
#'   fully efficient replicate count; in that case the svrep back-end
#'   retains a random sample of replicates, and the seed makes that draw
#'   reproducible.
#'
#' @returns A `survey_replicate` with generalized replication weights and
#'   `@variables$type = "other"` (the svrep back-end does not assign a
#'   method-specific type for generalized replication).
#'
#' @details
#' **When to use.** Choose generalized replication when you want the
#' deterministic counterpart of the generalized bootstrap: it is built
#' from the same target variance estimators, but decomposes the target
#' matrix into fixed components instead of drawing random multipliers
#' (Fay 1989). There is no `replicates` argument — the construction
#' sets the count, and `max_replicates` caps it. For choosing
#' `variance_estimator`, see the **Choosing a target** section of
#' [create_gen_boot_weights()]; note the defaults differ (`"SD2"`
#' here, `"SD1"` there).
#'
#' @section Algorithm:
#' Generalized replication (GR) is a BRR extension that removes the
#' requirement for exactly 2 PSUs per stratum. It constructs
#' \eqn{R \geq H} replicates (where \eqn{H} is the number of strata)
#' using a generalized Hadamard matrix, assigning each stratum-PSU unit a
#' weight that satisfies the BRR variance formula
#' \deqn{\hat{V}_{GR} = \frac{1}{R} \sum_{r=1}^{R}
#'   (\hat{\theta}^{(r)} - \hat{\theta})^2.}
#' Delegates to [svrep::as_fays_gen_rep_design()].
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
#' @examples
#' # generalized replication with reproducible seed -----------------------
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' create_gen_rep_weights(gss_svy, seed = 42L)
#'
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_sdr_weights()], [create_replicate_weights()], [as_taylor_design()]
#' @family replicate-weights
#' @export
create_gen_rep_weights <- function(
  data,
  ...,
  variance_estimator = "SD2",
  max_replicates = Inf,
  balanced = TRUE,
  aux_var_names = NULL,
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_gen_rep_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by this method.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  variance_estimator <- rlang::arg_match(
    variance_estimator,
    c(
      "SD1",
      "SD2",
      "Horvitz-Thompson",
      "Yates-Grundy",
      "Poisson Horvitz-Thompson",
      "Stratified Multistage SRS",
      "Ultimate Cluster",
      "Deville-1",
      "Deville-2",
      "Deville-Tille",
      "BOSB",
      "Beaumont-Emond"
    )
  )

  aux_quo <- rlang::enquo(aux_var_names)

  if (
    identical(variance_estimator, "Deville-Tille") &&
      rlang::quo_is_null(aux_quo)
  ) {
    cli::cli_abort(
      c(
        "x" = "{.code variance_estimator = \"Deville-Tille\"} requires {.arg aux_var_names}.",
        "v" = "Pass column names, e.g. {.code aux_var_names = c(x1, x2)}."
      ),
      class = "surveywts_error_variance_estimator_requires_aux"
    )
  }

  resolved_aux <- if (rlang::quo_is_null(aux_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(aux_quo, data = data@data))
  }

  .convert_and_call(
    data = data,
    backend_fn = function(d) {
      svrep::as_fays_gen_rep_design(
        d,
        variance_estimator = variance_estimator,
        max_replicates = max_replicates,
        balanced = balanced,
        aux_var_names = resolved_aux,
        mse = mse
      )
    },
    method = "generalized-replicate",
    params = list(
      variance_estimator = variance_estimator,
      max_replicates = max_replicates,
      balanced = balanced,
      mse = mse
    ),
    seed = seed
  )
}
