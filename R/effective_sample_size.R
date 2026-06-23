# R/effective_sample_size.R
#
# effective_sample_size() — Kish's ESS formula.

# ---------------------------------------------------------------------------
# effective_sample_size()
# ---------------------------------------------------------------------------

#' Estimate Kish's effective sample size of weighted data
#'
#' The effective sample size (ESS) measures how much statistical precision the
#' weighted sample retains relative to an equal-sized simple random sample.
#' Higher weight variability reduces the ESS, resulting in higher variance for
#' weighted estimates. Rows with zero weights (typically produced by
#' [adjust_nonresponse()]) are excluded before computing ESS.
#'
#' @param x A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. For `weighted_df` and survey objects, the weight
#'   column is auto-detected.
#' @param weights Bare name (NSE). Weight column. Auto-detected for
#'   `weighted_df` and survey objects. Required for plain `data.frame`.
#'
#' @returns A named numeric scalar: `c(n_eff = <value>)`. The name `"n_eff"`
#'   is part of the API contract.
#'
#' @section Algorithm:
#' \deqn{ESS = \frac{(\sum w)^2}{\sum w^2}}
#'
#' @references
#'   Kish, L. (1965). *Survey Sampling*. New York: John Wiley & Sons.
#'
#' @seealso [weight_variability()], [summarize_weights()]
#' @family diagnostics
#' @export
#'
#' @examples
#' df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))
#' effective_sample_size(df, weights = w)
effective_sample_size <- function(x, weights = NULL) {
  weights_quo <- rlang::enquo(weights)
  vld <- .diag_validate_input(x, weights_quo)

  # Filter out exact zeros before validation (zero weights arise from
  # nonresponse adjustment and should be excluded from diagnostics).
  # Negative weights and NAs still reach .validate_weights() for proper
  # error reporting.
  data_df <- vld$data_df
  w_all <- data_df[[vld$weight_col]]
  data_df <- data_df[is.na(w_all) | w_all != 0, , drop = FALSE]
  .validate_weights(data_df, vld$weight_col)

  w <- data_df[[vld$weight_col]]
  c(n_eff = sum(w)^2 / sum(w^2))
}
