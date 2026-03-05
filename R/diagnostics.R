# R/diagnostics.R
#
# Diagnostic functions for survey weight analysis.
#
# All three functions share the same input validation pattern via the
# private helper .diag_validate_input().
#
# Exported: effective_sample_size(), weight_variability(), summarize_weights()
#
# Private helper (used only in this file):
#   .diag_validate_input() — class check + weights_required check + data extraction

# ---------------------------------------------------------------------------
# effective_sample_size()
# ---------------------------------------------------------------------------

#' Kish's effective sample size
#'
#' Computes the effective sample size using Kish's formula:
#' \deqn{ESS = \frac{(\sum w)^2}{\sum w^2}}
#'
#' @param x A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_calibrated`. For `weighted_df` and survey objects, the weight
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
  .validate_weights(vld$data_df, vld$weight_col)

  w <- vld$data_df[[vld$weight_col]]
  c(n_eff = sum(w)^2 / sum(w^2))
}

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
  .validate_weights(vld$data_df, vld$weight_col)

  w <- vld$data_df[[vld$weight_col]]
  c(cv = stats::sd(w) / mean(w))
}

# ---------------------------------------------------------------------------
# summarize_weights()
# ---------------------------------------------------------------------------

#' Summarize the distribution of survey weights
#'
#' Returns a tibble with summary statistics for the weight column, optionally
#' computed within groups defined by `by`.
#'
#' @inheritParams effective_sample_size
#' @param by <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variables. When `NULL` (default), a single-row summary over all
#'   observations is returned. When specified, one row is returned per
#'   unique group combination.
#'
#' @return A tibble with columns `n`, `n_positive`, `n_zero`, `mean`, `cv`,
#'   `min`, `p25`, `p50`, `p75`, `max`, `ess`. When `by` is non-`NULL`,
#'   the group columns precede the summary columns.
#'
#' @family diagnostics
#' @export
#'
#' @examples
#' df <- data.frame(
#'   group = c("A", "A", "B", "B"),
#'   w = c(1.2, 0.8, 1.5, 0.9)
#' )
#' summarize_weights(df, weights = w)
#' summarize_weights(df, weights = w, by = c(group))
summarize_weights <- function(x, weights = NULL, by = NULL) {
  weights_quo <- rlang::enquo(weights)
  by_quo <- rlang::enquo(by)

  vld <- .diag_validate_input(x, weights_quo)
  .validate_weights(vld$data_df, vld$weight_col)

  data_df <- vld$data_df
  weight_col <- vld$weight_col

  by_names <- if (rlang::quo_is_null(by_quo)) {
    character(0L)
  } else {
    tidyselect::eval_select(by_quo, data_df) |> names()
  }

  if (length(by_names) == 0L) {
    w <- data_df[[weight_col]]
    tibble::as_tibble(.compute_weight_stats(w))
  } else {
    group_factor <- if (length(by_names) == 1L) {
      data_df[[by_names]]
    } else {
      interaction(lapply(by_names, function(v) data_df[[v]]), drop = TRUE)
    }
    groups <- split(seq_len(nrow(data_df)), group_factor)

    result_dfs <- lapply(names(groups), function(gkey) {
      idx <- groups[[gkey]]
      w <- data_df[[weight_col]][idx]
      stats_tbl <- tibble::as_tibble(.compute_weight_stats(w))
      group_row <- data_df[idx[[1L]], by_names, drop = FALSE]
      dplyr::bind_cols(
        tibble::as_tibble(group_row),
        stats_tbl
      )
    })

    dplyr::bind_rows(result_dfs)
  }
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Validates x and extracts (data_df, weight_col) for use by diagnostic
# functions. Checks:
#   1. x is a supported class — throws surveywts_error_unsupported_class
#   2. x is a plain data.frame with weights = NULL —
#      throws surveywts_error_weights_required
# Returns: list(data_df = <data.frame>, weight_col = <character>)
.diag_validate_input <- function(x, weights_quo) {
  is_supported <- is.data.frame(x) ||
    S7::S7_inherits(x, surveycore::survey_taylor) ||
    S7::S7_inherits(x, surveycore::survey_calibrated)

  if (!is_supported) {
    cls <- class(x)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg x} must be a data frame, {.cls weighted_df}, ",
          "{.cls survey_taylor}, or {.cls survey_calibrated}."
        ),
        "i" = "Got {.cls {cls}}."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }

  is_plain_df <- is.data.frame(x) && !inherits(x, "weighted_df")
  if (is_plain_df && rlang::quo_is_null(weights_quo)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg weights} is required when {.arg x} is a plain ",
          "data frame."
        ),
        "i" = paste0(
          "For {.cls weighted_df} and survey objects, the weight ",
          "column is detected automatically."
        ),
        "v" = paste0(
          "Pass the column name as a bare name, ",
          "e.g., {.code weights = wt_col}."
        )
      ),
      class = "surveywts_error_weights_required"
    )
  }

  data_df <- if (is.data.frame(x)) x else x@data
  weight_col <- .get_weight_col_name(x, weights_quo)

  list(data_df = data_df, weight_col = weight_col)
}
