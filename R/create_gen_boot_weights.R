# R/create_gen_boot_weights.R
#
# create_gen_boot_weights() — generalized bootstrap replicate weights.

# ============================================================================
# create_gen_boot_weights()
# ============================================================================

#' Create generalized bootstrap replicate weights
#'
#' Generates generalized bootstrap replicate weights via
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
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed.
#'
#' @return A `survey_replicate` with `@variables$type = "bootstrap"`.
#'
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

  replicates         <- .validate_replicates_arg(replicates)
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
    data          = data,
    backend_fn    = function(d) {
      svrep::as_gen_boot_design(
        d,
        variance_estimator = variance_estimator,
        replicates         = replicates,
        tau                = tau,
        aux_var_names      = resolved_aux,
        mse                = mse
      )
    },
    method        = "generalized-bootstrap",
    params        = list(
      variance_estimator = variance_estimator,
      replicates         = replicates,
      tau                = tau,
      mse                = mse
    ),
    seed          = seed,
    type_override = "bootstrap"
  )
}
