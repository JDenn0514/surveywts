# R/weight_variability.R
#
# weight_variability() — coefficient of variation and related weight spread metrics.

# ---------------------------------------------------------------------------
# weight_variability()
# ---------------------------------------------------------------------------

#' Coefficient of variation of survey weights
#'
#' Computes the coefficient of variation (CV) of the weight column:
#' \deqn{CV = \frac{sd(w)}{mean(w)}}
#'
#' @inheritParams effective_sample_size
#'
#' @return A named numeric scalar: `c(cv = <value>)`. The name `"cv"` is
#'   part of the API contract.
#'
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
