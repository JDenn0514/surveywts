# R/weight_variability.R
#
# weight_variability() — coefficient of variation and related weight spread metrics.

# ---------------------------------------------------------------------------
# weight_variability()
# ---------------------------------------------------------------------------

#' Measure how unequal the survey weights are
#'
#' The coefficient of variation (CV) measures how spread out the weights are
#' relative to their mean. A CV near zero indicates near-uniform weights;
#' higher values signal greater variability and a correspondingly larger design
#' effect. Rows with zero weights (typically produced by [adjust_nonresponse()])
#' are excluded before computing CV.
#'
#' @inheritParams effective_sample_size
#'
#' @returns A named numeric scalar: `c(cv = <value>)`. The name `"cv"` is
#'   part of the API contract.
#'
#' @section Algorithm:
#' `cv(w) = sd(w) / mean(w)`
#'
#' @seealso [effective_sample_size()], [summarize_weights()]
#' @family diagnostics
#' @export
#'
#' @examples
#' df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))
#' weight_variability(df, weights = w)
weight_variability <- function(x, weights = NULL) {
  weights_quo <- rlang::enquo(weights)
  vld <- .diag_validate_input(x, weights_quo)

  # Filter out exact zeros before validation (zero weights arise from
  # nonresponse adjustment and should be excluded from diagnostics).
  data_df <- vld$data_df
  w_all <- data_df[[vld$weight_col]]
  data_df <- data_df[is.na(w_all) | w_all != 0, , drop = FALSE]
  .validate_weights(data_df, vld$weight_col)

  w <- data_df[[vld$weight_col]]
  c(cv = stats::sd(w) / mean(w))
}
