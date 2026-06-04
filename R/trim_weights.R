# R/trim_weights.R
#
# trim_weights() — clip survey weights to [lower, upper] and redistribute
# the trimmed mass back to untrimmed observations.

# ============================================================================
# trim_weights()
# ============================================================================

#' Trim survey weights to a specified interval
#'
#' Clips (trims) survey weights to `[lower, upper]` and redistributes the
#' trimmed excess equally across untrimmed units, preserving the total weight
#' sum. Bounds can be absolute weight values or percentiles. Applies to main
#' weights and — for `survey_replicate` input — all replicate weight columns.
#'
#' The clip-and-redistribute logic is adapted from `survey::trimWeights()`
#' (Thomas Lumley). The default upper cutoff follows Potter & Zheng (2015):
#' `median(w) + k * IQR(w)` with `k = 5`.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`,
#'   or `survey_replicate`. All survey classes supported.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column.
#'   Auto-detected for `weighted_df` and survey objects. For plain `data.frame`
#'   with `weights = NULL`, uniform weights (all 1) are used and the output
#'   column is named `wt_name`.
#' @param lower `numeric(1)` or `NULL`. Lower bound. `NULL` means no lower
#'   trimming. When `type = "percentile"`, interpreted as a quantile in
#'   \[0, 1\]. Must not be `NA`.
#' @param upper `numeric(1)` or `NULL`. Upper bound. `NULL` with
#'   `type = "absolute"` (the default) computes the cutoff as
#'   `median(w) + k * IQR(w)`. `NULL` is incompatible with
#'   `type = "percentile"`. When `type = "absolute"`, must be strictly
#'   positive. When `type = "percentile"`, must be in \[0, 1\]. Must not be `NA`.
#' @param k `numeric(1)`. IQR multiplier used only when `upper = NULL` and
#'   `type = "absolute"`. Default `5` (Potter & Zheng 2015). Must be positive.
#'   Ignored when `upper` is specified.
#' @param type `character(1)`. `"absolute"` (default): bounds are raw weight
#'   values. `"percentile"`: bounds are quantiles on \[0, 1\].
#' @param strict `logical(1)`. When `FALSE` (default), one clip-and-redistribute
#'   pass is applied. When `TRUE`, the loop repeats until all main weights fall
#'   within `[lower_abs, upper_abs]`. Not applied to replicate columns.
#' @param wt_name `character(1)`. Output weight column name. Used only when
#'   `data` is a plain `data.frame` with `weights = NULL`. Default `"wts"`.
#'
#' @return An object of the same class as `data` with trimmed weights and one
#'   new entry in the weighting history.
#'
#' @family utilities
#' @export
#' @examples
#' set.seed(42)
#' df <- data.frame(
#'   id = 1:200,
#'   age_group = sample(c("18-34", "35-54", "55+"), 200, replace = TRUE),
#'   base_weight = exp(rnorm(200, 0, 0.4))
#' )
#'
#' # Default: IQR-based upper cutpoint (Potter & Zheng 2015)
#' result <- trim_weights(df, weights = base_weight)
#'
#' # Adjust the IQR multiplier
#' result <- trim_weights(df, weights = base_weight, k = 6)
#'
#' # Percentile: trim at 1st and 99th percentile
#' result <- trim_weights(df, weights = base_weight,
#'                        lower = 0.01, upper = 0.99, type = "percentile")
trim_weights <- function(
  data,
  weights = NULL,
  lower = NULL,
  upper = NULL,
  k = 5,
  type = c("absolute", "percentile"),
  strict = FALSE,
  wt_name = "wts"
) {
  weights_quo <- rlang::enquo(weights)
  call_str <- deparse(match.call())

  # Step 0: validate wt_name for plain data.frame + NULL weights case
  is_plain_df <- !inherits(data, "weighted_df") &&
    !S7::S7_inherits(data, surveycore::survey_base)
  is_null_wt_df <- is_plain_df && rlang::quo_is_null(weights_quo)
  if (is_null_wt_df) {
    .validate_wt_name(wt_name)
  }

  # Step 1: validate class, extract data_df, check nrow
  .check_weight_utils_class(data)
  data_df <- if (S7::S7_inherits(data, surveycore::survey_base)) {
    data@data
  } else {
    as.data.frame(data)
  }
  if (nrow(data_df) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} has 0 rows.",
        "i" = "Weight trimming requires at least one observation."
      ),
      class = "surveywts_error_empty_data"
    )
  }

  # Step 2: validate type and bounds (fail fast, before weight extraction)
  type <- match.arg(type)

  if (is.null(upper)) {
    if (type == "percentile") {
      cli::cli_abort(
        c(
          "x" = "{.arg upper} must be specified when {.code type = \"percentile\"}.",
          "i" = "{.code upper = NULL} is only valid when {.code type = \"absolute\"}.",
          "v" = "Provide an explicit {.arg upper} value in [0, 1], e.g. {.code upper = 0.99}."
        ),
        class = "surveywts_error_null_bound_percentile"
      )
    }
    # Validate k (only used when upper = NULL + absolute)
    if (!is.numeric(k) || length(k) != 1L || is.na(k)) {
      cli::cli_abort(
        c(
          "x" = "{.arg k} must be a single numeric value, not {.code NA}.",
          "i" = "Got {.cls {class(k)}} of length {length(k)}."
        ),
        class = "surveywts_error_k_not_scalar"
      )
    }
    if (k <= 0) {
      cli::cli_abort(
        c(
          "x" = "{.arg k} must be positive.",
          "i" = "Got {.val {k}}.",
          "v" = "Use a positive IQR multiplier, e.g. {.code k = 5}."
        ),
        class = "surveywts_error_k_nonpositive"
      )
    }
  } else {
    # upper is not NULL: validate it
    if (!is.numeric(upper) || length(upper) != 1L || is.na(upper)) {
      cli::cli_abort(
        c(
          "x" = "{.arg upper} must be a single numeric value, not {.code NA}.",
          "i" = "Got {.cls {class(upper)}} of length {length(upper)}."
        ),
        class = "surveywts_error_upper_not_scalar"
      )
    }
    if (type == "absolute" && upper <= 0) {
      cli::cli_abort(
        c(
          "x" = "{.arg upper} must be strictly positive when {.code type = \"absolute\"}.",
          "i" = "Got {.val {upper}}.",
          "v" = "Provide a positive upper bound."
        ),
        class = "surveywts_error_upper_nonpositive"
      )
    }
    if (type == "percentile" && (upper < 0 || upper > 1)) {
      cli::cli_abort(
        c(
          "x" = "{.arg upper} must be in [0, 1] when {.code type = \"percentile\"}.",
          "i" = "Got {.val {upper}}."
        ),
        class = "surveywts_error_percentile_out_of_range"
      )
    }
  }

  if (!is.null(lower)) {
    if (!is.numeric(lower) || length(lower) != 1L || is.na(lower)) {
      cli::cli_abort(
        c(
          "x" = "{.arg lower} must be a single numeric value, not {.code NA}.",
          "i" = "Got {.cls {class(lower)}} of length {length(lower)}."
        ),
        class = "surveywts_error_lower_not_scalar"
      )
    }
    if (type == "percentile" && (lower < 0 || lower > 1)) {
      cli::cli_abort(
        c(
          "x" = "{.arg lower} must be in [0, 1] when {.code type = \"percentile\"}.",
          "i" = "Got {.val {lower}}."
        ),
        class = "surveywts_error_percentile_out_of_range"
      )
    }
  }

  # Step 3: extract weight vector
  if (is_null_wt_df) {
    weights_vec <- rep(1, nrow(data_df))
    wt_col_name <- wt_name
  } else {
    wt_col_name <- .get_weight_col_name(data, weights_quo)
    weights_vec <- .get_weight_vec(data, weights_quo)
  }

  # Step 4: validate weights (skip for uniform plain-df case)
  if (!is_null_wt_df) {
    .validate_weights(data_df, wt_col_name)
  }

  # Step 5: resolve absolute cutoffs, then verify order
  if (type == "absolute") {
    lower_abs <- if (!is.null(lower)) lower else -Inf
    upper_abs <- if (!is.null(upper)) {
      upper
    } else {
      stats::median(weights_vec) + k * stats::IQR(weights_vec)
    }
  } else {
    # percentile
    lower_abs <- if (!is.null(lower)) {
      stats::quantile(weights_vec, lower, type = 7L, names = FALSE)
    } else {
      -Inf
    }
    upper_abs <- stats::quantile(weights_vec, upper, type = 7L, names = FALSE)
  }

  if (lower_abs >= upper_abs) {
    cli::cli_abort(
      c(
        "x" = "Resolved lower bound ({lower_abs}) must be strictly less than upper bound ({upper_abs}).",
        "i" = "Bounds must satisfy {.code lower_abs < upper_abs}.",
        "v" = "Adjust {.arg lower} and {.arg upper} so that the lower bound is smaller."
      ),
      class = "surveywts_error_bounds_invalid"
    )
  }

  # Step 6: main trimming loop
  weights_vec_orig <- weights_vec
  outside_initial <- weights_vec < lower_abs | weights_vec > upper_abs

  if (!any(outside_initial)) {
    cli::cli_warn(
      c("!" = "No weights were trimmed: all main weights already fall within [{lower_abs}, {upper_abs}]."),
      class = "surveywts_warning_no_weights_trimmed"
    )
  } else {
    has_trimmed <- rep(FALSE, length(weights_vec))
    repeat {
      result_inner <- .trim_weights_internal(
        weights_vec, lower_abs, upper_abs, has_trimmed
      )
      weights_vec <- result_inner$weights
      has_trimmed <- result_inner$has_trimmed
      if (!strict || !any(weights_vec < lower_abs | weights_vec > upper_abs)) break
    }
  }

  # Step 7: replicate column trimming (survey_replicate only)
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    rep_weights <- as.matrix(data@data[data@variables$repweights])
    # pmax/pmin strip matrix attributes; restore them explicitly
    rwnew <- matrix(
      pmax(lower_abs, pmin(as.vector(rep_weights), upper_abs)),
      nrow = nrow(rep_weights)
    )
    colnames(rwnew) <- colnames(rep_weights)
    trimmings <- rep_weights - rwnew
    for (j in seq_len(ncol(rep_weights))) {
      outside_j <- rep_weights[, j] < lower_abs | rep_weights[, j] > upper_abs
      if (any(!outside_j)) {
        rwnew[!outside_j, j] <- rwnew[!outside_j, j] +
          sum(trimmings[, j]) / sum(!outside_j)
      }
      # If all outside_j: no redistribution (sum changes, no warning)
    }
  }

  # Step 8: count trimmed units from outside_initial (before redistribution)
  n_trimmed_lower <- sum(weights_vec_orig < lower_abs)
  n_trimmed_upper <- sum(weights_vec_orig > upper_abs)

  # Step 9: build history entry and output object
  before_stats <- .compute_weight_stats(weights_vec_orig)
  after_stats <- .compute_weight_stats(weights_vec)

  hist_params <- list(
    type = type,
    strict = strict,
    lower_input = lower,
    upper_input = upper,
    lower_abs = lower_abs,
    upper_abs = upper_abs,
    n_trimmed_lower = n_trimmed_lower,
    n_trimmed_upper = n_trimmed_upper
  )

  old_history <- .get_history(data)
  history_entry <- .make_history_entry(
    step = length(old_history) + 1L,
    operation = "trim_weights",
    weight_col = wt_col_name,
    call_str = call_str,
    parameters = hist_params,
    before_stats = before_stats,
    after_stats = after_stats
  )

  # Construct output by class
  if (inherits(data, "data.frame") && !S7::S7_inherits(data, surveycore::survey_base)) {
    # data.frame or weighted_df
    updated_data <- as.data.frame(data)
    updated_data[[wt_col_name]] <- weights_vec
    new_history <- c(old_history, list(history_entry))
    .make_weighted_df(updated_data, wt_col_name, new_history)
  } else if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    result_design <- .update_survey_weights(data, weights_vec, history_entry)
    result_design@data[data@variables$repweights] <- as.data.frame(rwnew)
    result_design
  } else {
    # survey_taylor or survey_nonprob
    .update_survey_weights(data, weights_vec, history_entry)
  }
}
