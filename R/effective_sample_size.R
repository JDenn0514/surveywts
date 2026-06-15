# R/effective_sample_size.R
#
# effective_sample_size() — Kish's ESS formula.

# ---------------------------------------------------------------------------
# effective_sample_size()
# ---------------------------------------------------------------------------

#' Kish's effective sample size
#'
#' Computes the effective sample size using Kish's formula:
#' \deqn{ESS = \frac{(\sum w)^2}{\sum w^2}}
#'
#' @param x A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. For `weighted_df` and survey objects, the weight
#'   column is auto-detected.
#' @param weights Bare name (NSE). Weight column. Auto-detected for
#'   `weighted_df` and survey objects. Required for plain `data.frame`.
#'
#' @return A named numeric scalar: `c(n_eff = <value>)`. The name `"n_eff"`
#'   is part of the API contract.
#'
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
