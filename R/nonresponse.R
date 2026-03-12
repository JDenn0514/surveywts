# R/nonresponse.R
#
# adjust_nonresponse() — weighting-class nonresponse adjustment.
#
# Redistributes nonrespondent weights to respondents within weighting
# classes defined by `by`. Returns only respondent rows with adjusted weights.
#
# No private helpers. Cell-grouping logic is inline (~15 lines).
# All shared helpers (.get_weight_vec, .validate_weights, etc.) live in
# R/utils.R. .check_input_class() and .get_history() are in R/calibrate.R.

#' Adjust survey weights for unit nonresponse
#'
#' Redistributes the weights of nonrespondents to respondents within weighting
#' classes defined by `by`. The adjustment formula within each cell `h` is:
#'
#' \deqn{w_{i,new} = w_i \times \frac{\sum w_h}{\sum w_{h,resp}}}
#'
#' where \eqn{\sum w_h} is the sum of all weights (respondents + nonrespondents)
#' in cell `h` and \eqn{\sum w_{h,resp}} is the sum of respondent weights only.
#' Only respondent rows are returned.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. Must include BOTH respondents and nonrespondents.
#'   `survey_replicate` → error. Any other class → error.
#' @param response_status Bare name (NSE). Binary response indicator column.
#'   Must be `logical` or integer `0`/`1`. `1` / `TRUE` = respondent.
#' @param weights Bare name (NSE). Weight column. `NULL` → auto-detected from
#'   `weighted_df` attribute or survey object `@variables$weights`. For plain
#'   `data.frame` with `weights = NULL`, uniform starting weights are used and
#'   the output column is named `".weight"`.
#' @param by <[`tidy-select`][tidyselect::language]> Weighting class variables.
#'   Redistribution is performed within each cell defined by the joint
#'   combination of these variables. `NULL` → global redistribution across
#'   all rows.
#' @param method Character scalar. Adjustment method. In Phase 0, only
#'   `"weighting-class"` is supported. `"propensity"` and `"propensity-cell"`
#'   are API-stable stubs that error until Phase 2.
#' @param control Named list of warning thresholds:
#'   - `min_cell`: warn when a cell has fewer than this many respondents
#'     (default 20, per NAEP methodology).
#'   - `max_adjust`: warn when the nonresponse adjustment factor for a cell
#'     exceeds this value (default 2.0, per `survey::sparseCells()` convention).
#'   Either condition alone triggers the warning.
#'
#' @return
#'   - `data.frame` or `weighted_df` input → `weighted_df` (respondents only)
#'   - `survey_taylor` input → `survey_taylor` (same class; respondents only)
#'   - `survey_nonprob` input → `survey_nonprob` (same class;
#'     respondents only)
#'
#'   The weight column in the output contains adjusted weights. A history entry
#'   with `operation = "nonresponse_weighting_class"` is appended to
#'   `weighting_history`.
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
#'   responded = c(1L, 1L, 1L, 0L, 1L),
#'   stringsAsFactors = FALSE
#' )
#' result <- adjust_nonresponse(df, response_status = responded)
#'
#' @family nonresponse
#' @export
adjust_nonresponse <- function(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  method = c("weighting-class", "propensity-cell", "propensity"),
  control = list(min_cell = 20, max_adjust = 2.0)
) {
  # ---- Capture call and match arguments -------------------------------------
  call_str    <- paste0(deparse(match.call()), collapse = " ")
  method      <- rlang::arg_match(method)
  weights_quo <- rlang::enquo(weights)
  rs_quo      <- rlang::enquo(response_status)

  # Merge control with defaults
  control <- utils::modifyList(list(min_cell = 20, max_adjust = 2.0), control)

  # ---- 1. Input class check -------------------------------------------------
  .check_input_class(data)

  # ---- 2. Extract plain data frame ------------------------------------------
  data_df <- if (inherits(data, "data.frame")) as.data.frame(data) else data@data

  # ---- 3. Empty data check --------------------------------------------------
  if (nrow(data_df) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} has 0 rows.",
        "i" = "This operation is undefined on empty data.",
        "v" = "Ensure {.arg data} has at least one row."
      ),
      class = "surveywts_error_empty_data"
    )
  }

  # ---- 4. Weight column name ------------------------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: create uniform starting weights
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[weight_col]] <- rep(1 / nrow(data_df), nrow(data_df))
  }

  # Sync plain_df when we added a uniform weight column
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    plain_df <- data_df
  }

  # ---- 5. Validate weights --------------------------------------------------
  .validate_weights(plain_df, weight_col)

  # ---- 6. Method stub for Phase 2 -------------------------------------------
  if (method %in% c("propensity", "propensity-cell")) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.code method = {.val {method}}} is not available in Phase 0."
        ),
        "i" = paste0(
          "Propensity-based methods ({.val \"propensity\"} and ",
          "{.val \"propensity-cell\"}) require Phase 2 (v0.3.0)."
        ),
        "v" = paste0(
          "Use {.code method = \"weighting-class\"} for now."
        )
      ),
      class = "surveywts_error_propensity_requires_phase2"
    )
  }

  # ---- 7. Resolve and validate response_status column -----------------------
  status_var <- rlang::as_name(rs_quo)

  if (!status_var %in% names(plain_df)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Response status column {.field {status_var}} not found in ",
          "{.arg data}."
        ),
        "i" = "Available columns: {.and {.field {names(plain_df)}}}.",
        "v" = paste0(
          "Pass the column name as a bare name, ",
          "e.g., {.code response_status = responded}."
        )
      ),
      class = "surveywts_error_response_status_not_found"
    )
  }

  status_col <- plain_df[[status_var]]

  # Check for NAs in response_status
  n_na_status <- sum(is.na(status_col))
  if (n_na_status > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Response status column {.field {status_var}} contains ",
          "{n_na_status} NA value(s)."
        ),
        "i" = "The response indicator must be fully observed.",
        "v" = paste0(
          "Remove rows with missing response status before calling ",
          "{.fn adjust_nonresponse}."
        )
      ),
      class = "surveywts_error_response_status_has_na"
    )
  }

  # Check binary: must be logical or integer 0/1 (not factor, not other)
  .validate_response_status_binary(plain_df, status_var)

  # Convert to logical for consistent handling
  is_respondent <- as.logical(status_col)

  # Check that at least one respondent exists
  if (!any(is_respondent)) {
    cli::cli_abort(
      c(
        "x" = "No respondents found in {.arg data}.",
        "i" = paste0(
          "All values of {.field {status_var}} are 0 or {.code FALSE}."
        ),
        "v" = paste0(
          "Ensure {.arg data} contains both respondents and ",
          "nonrespondents before adjustment."
        )
      ),
      class = "surveywts_error_response_status_all_zero"
    )
  }

  # ---- 8. Resolve by variable names via tidy-select ------------------------
  by_quo   <- rlang::enquo(by)
  by_names <- if (rlang::quo_is_null(by_quo)) {
    character(0)
  } else {
    tidyselect::eval_select(by_quo, plain_df) |> names()
  }

  # ---- 9. Check for NA in by variables --------------------------------------
  for (var in by_names) {
    n_na <- sum(is.na(plain_df[[var]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Weighting class variable {.field {var}} contains ",
            "{n_na} NA value(s)."
          ),
          "i" = "NA values in weighting class variables are not allowed.",
          "v" = paste0(
            "Remove or impute NA values in {.field {var}} before ",
            "calling {.fn adjust_nonresponse}."
          )
        ),
        class = "surveywts_error_variable_has_na"
      )
    }
  }

  # ---- 10. Extract weights and compute before-stats ------------------------
  weights_vec  <- plain_df[[weight_col]]
  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 11. Build cell keys for redistribution ------------------------------
  if (length(by_names) == 0L) {
    # Global redistribution: all rows in one cell
    cell_keys <- rep("__global__", nrow(plain_df))
  } else {
    cell_keys <- do.call(
      paste,
      c(lapply(by_names, function(v) as.character(plain_df[[v]])),
        sep = "//")
    )
  }

  # ---- 12. Check for empty respondent cells --------------------------------
  unique_cells <- unique(cell_keys)
  for (cell in unique_cells) {
    cell_idx  <- which(cell_keys == cell)
    n_resp_cell <- sum(is_respondent[cell_idx])

    if (n_resp_cell == 0L) {
      cell_label <- if (cell == "__global__") "(all rows)" else cell
      cli::cli_abort(
        c(
          "x" = "Weighting class cell {.val {cell_label}} has no respondents.",
          "i" = paste0(
            "Cannot redistribute nonrespondent weights to an empty ",
            "respondent cell."
          ),
          "v" = paste0(
            "Collapse weighting classes to ensure each cell has at ",
            "least one respondent."
          )
        ),
        class = "surveywts_error_class_cell_empty"
      )
    }
  }

  # ---- 13. Compute adjusted weights ----------------------------------------
  new_weights <- weights_vec

  for (cell in unique_cells) {
    cell_idx       <- which(cell_keys == cell)
    resp_idx       <- cell_idx[is_respondent[cell_idx]]
    sum_all        <- sum(weights_vec[cell_idx])
    sum_resp       <- sum(weights_vec[resp_idx])
    adj_factor     <- sum_all / sum_resp
    n_resp_cell    <- length(resp_idx)

    # Warn if cell is sparse or adjustment is extreme
    cell_label <- if (cell == "__global__") "(global)" else cell
    if (n_resp_cell < control$min_cell || adj_factor > control$max_adjust) {
      adj_factor_fmt <- sprintf("%.2f", adj_factor)
      cli::cli_warn(
        c(
          "!" = paste0(
            "Weighting class cell {.val {cell_label}} is sparse ",
            "({n_resp_cell} respondent(s), ",
            "adjustment factor {adj_factor_fmt}\u00d7)."
          ),
          "i" = "Small or high-adjustment cells may produce extreme weights.",
          "i" = paste0(
            "Consider collapsing weighting classes or adjusting ",
            "{.code control$min_cell} / {.code control$max_adjust}."
          )
        ),
        class = "surveywts_warning_class_near_empty"
      )
    }

    new_weights[resp_idx] <- weights_vec[resp_idx] * adj_factor
  }

  # ---- 14. Subset to respondent rows only ----------------------------------
  resp_rows   <- which(is_respondent)
  out_df      <- plain_df[resp_rows, , drop = FALSE]
  out_weights <- new_weights[resp_rows]
  out_df[[weight_col]] <- out_weights

  # ---- 15. Build history entry ---------------------------------------------
  after_stats     <- .compute_weight_stats(out_weights)
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step        = length(current_history) + 1L,
    operation   = "nonresponse_weighting_class",
    call_str    = call_str,
    parameters  = list(
      by_variables = by_names,
      method       = method
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = NULL  # non-iterative
  )

  # ---- 16. Build output -----------------------------------------------------
  if (inherits(data, "data.frame")) {
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, weight_col, new_history)
  } else {
    # For survey objects: filter to respondent rows then update weights + history.
    # We update @data directly (S7 property assignment) to filter rows, then
    # delegate weight-column update and history append to .update_survey_weights().
    filtered_design       <- data
    filtered_design@data  <- out_df  # already filtered to respondent rows with updated weights
    .update_survey_weights(filtered_design, out_weights, history_entry)
  }
}

# ---------------------------------------------------------------------------
# .validate_response_status_binary() — private helper
# ---------------------------------------------------------------------------

# Validates that response_status is binary (integer 0/1 or logical).
# Factors are explicitly rejected even if they have 2 levels.
#
# Arguments:
#   data       : plain data.frame
#   status_var : character(1) — name of the response status column
#
# Returns invisible(TRUE) on success. Throws on failure.
.validate_response_status_binary <- function(data, status_var) {
  col <- data[[status_var]]

  # Factors are not binary regardless of their levels
  if (is.factor(col)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Response status column {.field {status_var}} must be binary ",
          "(0/1 or logical)."
        ),
        "i" = paste0(
          "Got {.cls {class(col)[[1]]}} with values: ",
          "{.val {unique(col)}}."
        ),
        "i" = "Factor columns are not binary regardless of their levels.",
        "v" = paste0(
          "Convert to logical ({.code TRUE}/{.code FALSE}) or integer ",
          "({.code 0}/{.code 1}) before calling {.fn adjust_nonresponse}."
        )
      ),
      class = "surveywts_error_response_status_not_binary"
    )
  }

  if (is.logical(col)) {
    return(invisible(TRUE))
  }

  if (is.integer(col) || is.numeric(col)) {
    unique_vals <- sort(unique(col[!is.na(col)]))
    if (!all(unique_vals %in% c(0L, 1L))) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Response status column {.field {status_var}} must be binary ",
            "(0/1 or logical)."
          ),
          "i" = paste0(
            "Got {.cls {class(col)[[1]]}} with values: ",
            "{.val {unique(col)}}."
          ),
          "i" = "Factor columns are not binary regardless of their levels.",
          "v" = paste0(
            "Convert to logical ({.code TRUE}/{.code FALSE}) or integer ",
            "({.code 0}/{.code 1}) before calling {.fn adjust_nonresponse}."
          )
        ),
        class = "surveywts_error_response_status_not_binary"
      )
    }
    return(invisible(TRUE))
  }

  # All other types (character, etc.) are not binary
  cli::cli_abort(
    c(
      "x" = paste0(
        "Response status column {.field {status_var}} must be binary ",
        "(0/1 or logical)."
      ),
      "i" = paste0(
        "Got {.cls {class(col)[[1]]}} with values: ",
        "{.val {unique(col)}}."
      ),
      "i" = "Factor columns are not binary regardless of their levels.",
      "v" = paste0(
        "Convert to logical ({.code TRUE}/{.code FALSE}) or integer ",
        "({.code 0}/{.code 1}) before calling {.fn adjust_nonresponse}."
      )
    ),
    class = "surveywts_error_response_status_not_binary"
  )
}
