# R/create_sdr_weights.R
#
# create_sdr_weights() — successive difference replication (SDR) weights.

# ============================================================================
# create_sdr_weights()
# ============================================================================

#' Generate successive difference replication weights
#'
#' Generates successive difference replication weights via
#' [svrep::as_sdr_design()]. Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design. PSUs should be in systematic
#'   selection order, or use `sort_var`.
#' @param replicates `integer(1)`, default `100L`. Target replicate count
#'   (>= 4). Actual count may be slightly larger due to Hadamard matrix sizing.
#' @param ... Must be empty.
#' @param sort_var <[`tidy-select`][tidyselect::language]> Bare column name
#'   giving the systematic selection order. Required for stratified designs
#'   (svrep >= 0.9.1); for non-stratified designs row order is used as fallback.
#' @param mse `logical(1)`, default `TRUE`.
#'
#' @returns A `survey_replicate` with `@variables$type = "successive-difference"`.
#'
#' @section Algorithm:
#' Successive difference replication (SDR) pairs adjacent PSUs in
#' systematic selection order. A Hadamard matrix of order \eqn{R} assigns
#' each pair to a half-sample. The SDR variance estimator is:
#' \deqn{\hat{V}_{SDR} = \frac{1}{2R} \sum_{r=1}^{R}
#'   (\hat{\theta}^{(r)} - \hat{\theta}_{\text{full}})^2.}
#' This estimator matches the variance of a systematic random sample when
#' PSUs are in selection order (Ash, 2014; Fay & Train, 1995). Delegates
#' to [svrep::as_sdr_design()].
#'
#' @references
#'   Ash, S. (2014). Using successive difference replication for
#'   estimating variances. *Survey Methodology, Statistics Canada*,
#'   40(1), 47--59.
#'
#'   Fay, R.E. and Train, G.F. (1995). Aspects of survey and model-based
#'   postcensal estimation of income and poverty characteristics for
#'   states and counties. *Joint Statistical Meetings, Proceedings of
#'   the Section on Government Statistics*, 154--159.
#'
#' @examples
#' # apply SDR to a Taylor-linearization design ---------------------------
#' create_sdr_weights(gss_2024_svy)
#'
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_replicate_weights()], [as_taylor_design()]
#' @family replicate-weights
#' @export
create_sdr_weights <- function(
  data,
  replicates = 100L,
  ...,
  sort_var = NULL,
  mse = TRUE
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_sdr_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by SDR.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  replicates <- .validate_replicates_arg(replicates, min_val = 4L)

  sort_quo <- rlang::enquo(sort_var)
  sort_col <- if (rlang::quo_is_null(sort_quo)) NULL else rlang::as_name(sort_quo)

  if (!is.null(sort_col)) {
    n_na <- sum(is.na(data@data[[sort_col]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = "{.arg sort_var} column {.field {sort_col}} contains {n_na} NA value(s).",
          "v" = "Remove rows with missing sort values before calling {.fn create_sdr_weights}."
        ),
        class = "surveywts_error_sort_var_has_na"
      )
    }
  }

  .convert_and_call(
    data       = data,
    backend_fn = function(d) {
      if (is.null(sort_col)) {
        d$variables[[".row_order"]] <- seq_len(nrow(d$variables))
        effective_sort <- ".row_order"
      } else {
        effective_sort <- sort_col
      }
      result <- svrep::as_sdr_design(
        d,
        replicates    = replicates,
        sort_variable = effective_sort,
        mse           = mse
      )
      result$variables[[".row_order"]] <- NULL
      result
    },
    method     = "successive-difference",
    params     = list(replicates = replicates, sort_var = sort_col, mse = mse)
  )
}
