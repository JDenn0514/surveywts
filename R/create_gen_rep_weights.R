# R/create_gen_rep_weights.R
#
# create_gen_rep_weights() — generalized replication weights.

# ============================================================================
# create_gen_rep_weights()
# ============================================================================

#' Create generalized replication replicate weights
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
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed for reproducibility.
#'
#' @return A `survey_replicate` with generalized replication weights.
#'
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

  variance_estimator <- rlang::arg_match(variance_estimator, c(
    "SD1", "SD2", "Horvitz-Thompson", "Yates-Grundy",
    "Poisson Horvitz-Thompson", "Stratified Multistage SRS",
    "Ultimate Cluster", "Deville-1", "Deville-2", "Deville-Tille",
    "BOSB", "Beaumont-Emond"
  ))

  aux_quo <- rlang::enquo(aux_var_names)

  if (identical(variance_estimator, "Deville-Tille") && rlang::quo_is_null(aux_quo)) {
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
    data       = data,
    backend_fn = function(d) {
      svrep::as_fays_gen_rep_design(
        d,
        variance_estimator = variance_estimator,
        max_replicates     = max_replicates,
        balanced           = balanced,
        aux_var_names      = resolved_aux,
        mse                = mse
      )
    },
    method     = "generalized-replicate",
    params     = list(
      variance_estimator = variance_estimator,
      max_replicates     = max_replicates,
      balanced           = balanced,
      mse                = mse
    ),
    seed       = seed
  )
}
