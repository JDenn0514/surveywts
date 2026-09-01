# R/create_gen_boot_weights.R
#
# create_gen_boot_weights() — generalized bootstrap replicate weights.

# ============================================================================
# create_gen_boot_weights()
# ============================================================================

#' Generate generalized bootstrap replicate weights
#'
#' Generates generalized bootstrap replicate weights (sets of perturbed
#' weight columns used to compute standard errors) via
#' [svrep::as_gen_boot_design()]. Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design.
#' @param replicates `integer(1)`, default `500L`. Number of bootstrap replicates.
#' @param ... Must be empty.
#' @param variance_estimator `character(1)`. Target variance estimator. One of
#'   `"SD1"` (default), `"SD2"`, `"Horvitz-Thompson"`, `"Yates-Grundy"`,
#'   `"Poisson Horvitz-Thompson"`, `"Stratified Multistage SRS"`,
#'   `"Ultimate Cluster"`, `"Deville-1"`, `"Deville-2"`, `"Deville-Tille"`,
#'   `"BOSB"`, or `"Beaumont-Emond"`.
#' @param tau `numeric(1)` or `"auto"`, default `1`. Rescaling constant to
#'   prevent negative replicate weights.
#' @param aux_var_names <[`tidy-select`][tidyselect::language]> or `NULL`.
#'   Auxiliary variable columns. Required when
#'   `variance_estimator = "Deville-Tille"`.
#' @param mse `logical(1)`, default `TRUE`. Centers each replicate deviation
#'   on the full-sample estimate (`TRUE`; conservative) or on the mean of
#'   the replicate estimates (`FALSE`).
#' @param seed `integer(1)` or `NULL`. RNG seed.
#'
#' @returns A `survey_replicate` with `@variables$type = "bootstrap"` (the
#'   stored replicate type, not the method name).
#'
#' @details
#' **When to use.** Choose the generalized bootstrap when the design
#' fits none of the named methods — Poisson sampling, or an unusual
#' multi-stage structure — or when you must name the target variance
#' estimator yourself (Beaumont & Patak 2012). The choice of
#' `variance_estimator` is the central decision; see the **Choosing a
#' target** section. Beaumont & Patak recommend at least 750
#' replicates; the default is 500.
#'
#' @section Algorithm:
#' The generalized bootstrap (Beaumont & Patak, 2012) generates replicate
#' weights using unit-level random multipliers:
#' \deqn{w_k^{(r)} = w_k \cdot u_k^{(r)}}
#' where \eqn{u_k^{(r)}} are drawn from a distribution calibrated to the
#' design's first-order inclusion probabilities. Unlike SRSWR bootstrap,
#' the multipliers are chosen to satisfy \eqn{E[u_k] = 1} and
#' \eqn{Var(u_k) = (1 - \pi_k) / \pi_k}. Delegates to
#' [svrep::as_gen_boot_design()].
#'
#' @section Choosing a target:
#' `variance_estimator` names the variance formula the replicate
#' weights are built to reproduce. The mapped sources cover five of
#' the options:
#'
#' - `"SD1"` (the default) and `"SD2"`: the successive-difference
#'   estimators, which read the row order of the data (Ash 2014).
#'   They suit systematic samples.
#' - `"Horvitz-Thompson"`: valid for any design with computable
#'   inclusion probabilities, but for some designs its form implies a
#'   negative variance and the construction fails (Beaumont & Patak
#'   2012).
#' - `"Yates-Grundy"`: requires a fixed sample size; not appropriate
#'   for Poisson sampling (Beaumont & Patak 2012).
#' - `"Poisson Horvitz-Thompson"`: the valid choice under Poisson
#'   sampling (Beaumont & Patak 2012).
#'
#' The remaining options (`"Stratified Multistage SRS"`,
#' `"Ultimate Cluster"`, `"Deville-1"`, `"Deville-2"`,
#' `"Deville-Tille"`, `"BOSB"`, `"Beaumont-Emond"`) come from the
#' svrep back end; see [svrep::as_gen_boot_design()] for their
#' definitions.
#'
#' @references
#'   Beaumont, J.-F. and Patak, Z. (2012). On the generalized bootstrap for
#'   sample surveys with special attention to Poisson sampling.
#'   *International Statistical Review*, 80(1), 127--148.
#'
#'   Fay, R.E. (1984). Some properties of estimates of variance based on
#'   replication methods. *Proceedings of the Section on Survey Research
#'   Methods, American Statistical Association*, 495--500.
#'
#'   Dippo, C., Fay, R.E. and Morganstein, D. (1984). Computing variances
#'   from complex samples with replicate weights. *Proceedings of the
#'   Section on Survey Research Methods, American Statistical Association*,
#'   489--494.
#'
#'   Bellhouse, D.R. (1985). Computing methods for variance estimation in
#'   complex surveys. *Journal of Official Statistics*, 1(3), 323--329.
#'
#'   Ash, S. (2014). Using successive difference replication for estimating
#'   variances. *Survey Methodology*, 40(1), 47--59.
#'
#' @examples
#' # generalized bootstrap with reproducible seed -------------------------
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' # Real analyses use more replicates; 100 keeps `R CMD check` fast.
#' gen_boot_design <- create_gen_boot_weights(
#'   gss_svy,
#'   replicates = 100L,
#'   seed = 42L
#' )
#' summarize_weights(gen_boot_design)
#' # The confidence interval below is computed from the 100 replicate
#' # columns, which is what the replicate weights are for.
#' surveycore::get_means(gen_boot_design, age)
#'
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_rep_weights()],
#'   [create_sdr_weights()], [create_replicate_weights()], [as_taylor_design()].
#'   For the class system, the standard workflows, and a glossary of terms,
#'   see the [Getting started
#'   article](https://jdenn0514.github.io/surveywts/articles/getting-started.html).
#' @family replicate-weights
#' @export
create_gen_boot_weights <- function(
  data,
  replicates = 500L,
  ...,
  variance_estimator = "SD1",
  tau = 1,
  aux_var_names = NULL,
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_gen_boot_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by this method.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  replicates <- .validate_replicates_arg(replicates)
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
      svrep::as_gen_boot_design(
        d,
        variance_estimator = variance_estimator,
        replicates = replicates,
        tau = tau,
        aux_var_names = resolved_aux,
        mse = mse
      )
    },
    method = "generalized-bootstrap",
    params = list(
      variance_estimator = variance_estimator,
      replicates = replicates,
      tau = tau,
      mse = mse
    ),
    seed = seed,
    type_override = "bootstrap"
  )
}
