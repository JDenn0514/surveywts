# R/summarize_weights.R
#
# summarize_weights() — tabular weight summary, optionally by group.

# ---------------------------------------------------------------------------
# summarize_weights()
# ---------------------------------------------------------------------------

#' Report summary statistics for the weight distribution
#'
#' Returns a tibble with n, mean, CV, percentiles (p25, p50, p75), and ESS
#' for the weight column. Pass `by` to compute statistics separately within
#' each subgroup defined by one or more grouping variables.
#'
#' @inheritParams effective_sample_size
#' @param by <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variables. When `NULL` (the default), a single-row summary over all
#'   observations is returned. When specified, one row is returned per
#'   unique group combination.
#'
#' @returns A tibble with columns `n`, `n_positive`, `n_zero`, `mean`, `cv`,
#'   `min`, `p25`, `p50`, `p75`, `max`, `ess`. When `by` is non-`NULL`,
#'   the group columns precede the summary columns.
#'
#' @seealso [effective_sample_size()], [weight_variability()]
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

  # Filter out exact zeros before validation (zero weights arise from
  # nonresponse adjustment and should be excluded from diagnostics).
  data_df <- vld$data_df
  weight_col <- vld$weight_col
  w_all <- data_df[[weight_col]]
  data_df <- data_df[is.na(w_all) | w_all != 0, , drop = FALSE]
  .validate_weights(data_df, weight_col)

  by_names <- if (rlang::quo_is_null(by_quo)) {
    character(0L)
  } else {
    tidyselect::eval_select(by_quo, data_df) |> names()
  }

  if (length(by_names) == 0L) {
    w <- data_df[[weight_col]]
    tibble::as_tibble(.compute_weight_stats(w))
  } else {
    cell_keys <- do.call(
      paste,
      c(lapply(by_names, function(v) as.character(data_df[[v]])), sep = "//")
    )
    groups <- split(seq_len(nrow(data_df)), cell_keys)
    # Preserve first-occurrence order (not alphabetical from split())
    key_order <- unique(cell_keys)
    groups <- groups[key_order]

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
