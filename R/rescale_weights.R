# R/rescale_weights.R
#
# rescale_weights() — rescale weights so they sum to n (or group n).

# ============================================================================
# rescale_weights()
# ============================================================================

#' Rescale survey weights to a target mean or sum
#'
#' Rescales weights so they sum to the sample size `n` (globally) or to the
#' group sample size within each group (when `by` is specified). Relative
#' weights within the sample are preserved exactly. Applies to main weights
#' and — for inputs carrying replicate weight columns (`survey_replicate` or
#' `survey_nonprob` with `repweights`) — all replicate columns.
#'
#' The scale factor is `n / sum(w)` globally, or `n_h / W_h` per group `h`.
#' This operation preserves ratio estimators (means, proportions) but changes
#' population total estimates by the factor `n / W`.
#'
#' @param data A `survey_taylor`, `survey_nonprob`, or `survey_replicate`. For
#'   inputs carrying replicate weight columns, see the **Replicate Weights**
#'   section.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column.
#'   Auto-detected from survey object `@variables$weights`.
#' @param by <[`tidy-select`][tidyselect::language]> Grouping variable(s).
#'   Rescaling is performed within each group (weights in group `h` sum to
#'   `n_h`). `NULL` → global rescaling (all weights sum to `n`).
#' @param wt_name `NULL` (default) or a `character(1)`. When `NULL`, rescaled
#'   weights overwrite the existing weight column in place. When a character
#'   string, a new column is added and `@variables$weights` updated.
#'
#' @returns An object of the same class as `data` with rescaled weights. A
#'   new entry with `operation = "rescale_weights"` is appended to the
#'   weighting history.
#'
#' @section Replicate Weights:
#' When the input carries replicate weight columns (either `survey_replicate`
#' or `survey_nonprob` with `repweights`), all replicate columns are scaled by
#' the same factor(s) derived from the main weights — globally `n / sum(w)` or
#' per group `n_h / W_h`. Each row's replicate values are multiplied by the
#' same scalar (global) or per-group scalar that was applied to the main weight.
#'
#' @seealso [trim_weights()]
#' @family utilities
#' @export
#' @examples
#' ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#'
#' # Rescale weights to unit mean (default) -----------------------------------
#' summarize_weights(ns_wave1_svy)
#'
#' result <- rescale_weights(ns_wave1_svy)
#' summarize_weights(result)
#'
#' # Rescale within groups using by = -----------------------------------------
#' result_by <- rescale_weights(ns_wave1_svy, by = ns_region)
#' summarize_weights(result_by, by = ns_region)
rescale_weights <- function(
  data,
  weights = NULL,
  by = NULL,
  wt_name = NULL
) {
  weights_quo <- rlang::enquo(weights)
  by_quo <- rlang::enquo(by)
  call_str <- deparse(match.call())

  # Step 0: validate wt_name
  .validate_wt_name(wt_name)

  # Step 1: validate class and check nrow
  .check_weight_utils_class(data)
  data_df <- data@data
  # nocov start
  # Unreachable via public API: surveycore S7 validators prevent 0-row objects.
  if (nrow(data_df) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} has 0 rows.",
        "i" = "Weight rescaling requires at least one observation."
      ),
      class = "surveywts_error_empty_data"
    )
  }
  # nocov end

  # Step 2: extract weight vector and validate
  wt_col_name <- .get_weight_col_name(data, weights_quo)
  weights_vec <- .get_weight_vec(data, weights_quo)
  .validate_weights(data_df, wt_col_name)

  # Step 3: by resolution and validation
  if (rlang::quo_is_null(by_quo)) {
    by_names <- character(0L)
  } else {
    by_names <- tryCatch(
      tidyselect::eval_select(by_quo, data_df) |> names(),
      error = function(e) {
        by_str <- rlang::as_label(by_quo)
        cli::cli_abort(
          c(
            "x" = "{.arg by} variable {.field {by_str}} not found in {.arg data}.",
            "i" = conditionMessage(e),
            "v" = "Check that all grouping variables exist as columns in {.arg data}."
          ),
          class = "surveywts_error_by_variable_not_found"
        )
      }
    )
    # Validate each by variable for NAs
    for (v in by_names) {
      n_na <- sum(is.na(data_df[[v]]))
      if (n_na > 0L) {
        cli::cli_abort(
          c(
            "x" = "{.arg by} variable {.field {v}} contains {n_na} NA value(s).",
            "i" = "Grouping variables must be fully observed.",
            "v" = "Remove rows with missing {.field {v}} before calling {.fn rescale_weights}."
          ),
          class = "surveywts_error_variable_has_na"
        )
      }
    }
  }

  n <- nrow(data_df)

  # Steps 4-5: compute scale factors and apply
  if (length(by_names) == 0L) {
    # Global rescaling
    scale_factor <- n / sum(weights_vec)
    weights_new <- weights_vec * scale_factor
    scale_factor_record <- scale_factor

    # For objects with replicate columns: apply same factor to all rep columns
    if (.has_repweights(data)) {
      rep_weights <- as.matrix(data@data[data@variables$repweights])
      rep_weights_new <- rep_weights * scale_factor
    }
  } else {
    # Per-group rescaling
    cell_keys <- do.call(
      paste,
      c(lapply(by_names, function(v) as.character(data_df[[v]])), sep = " | ")
    )
    group_levels <- unique(cell_keys)
    scale_factors_vec <- numeric(n)
    scale_factor_record <- numeric(length(group_levels))
    names(scale_factor_record) <- group_levels

    for (grp in group_levels) {
      idx <- cell_keys == grp
      n_h <- sum(idx)
      W_h <- sum(weights_vec[idx])
      sf_h <- n_h / W_h
      scale_factors_vec[idx] <- sf_h
      scale_factor_record[[grp]] <- sf_h
    }

    weights_new <- weights_vec * scale_factors_vec

    # For objects with replicate columns: apply per-group factors to all rep columns
    if (.has_repweights(data)) {
      rep_weights <- as.matrix(data@data[data@variables$repweights])
      rep_weights_new <- rep_weights * scale_factors_vec
    }
  }

  # Step 6: build history and output
  before_stats <- .compute_weight_stats(weights_vec)
  after_stats <- .compute_weight_stats(weights_new)

  hist_params <- list(
    by = if (length(by_names) == 0L) NULL else by_names,
    scale_factor = scale_factor_record
  )

  old_history <- .get_history(data)
  history_entry <- .make_history_entry(
    step = length(old_history) + 1L,
    operation = "rescale_weights",
    weight_col = if (is.null(wt_name)) wt_col_name else wt_name,
    call_str = call_str,
    parameters = hist_params,
    before_stats = before_stats,
    after_stats = after_stats
  )

  # Construct output
  if (.has_repweights(data)) {
    result_design <- .update_survey_weights(data, weights_new, history_entry,
                                            wt_name = wt_name)
    result_design@data[data@variables$repweights] <- as.data.frame(rep_weights_new)
    result_design
  } else {
    .update_survey_weights(data, weights_new, history_entry, wt_name = wt_name)
  }
}
