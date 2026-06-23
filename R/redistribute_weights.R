# R/redistribute_weights.R
#
# redistribute_weights() — general-purpose weight redistribution primitive.
# Transfers weight from a "reduce" group to an "increase" group.

# ---------------------------------------------------------------------------
# redistribute_weights() — exported
# ---------------------------------------------------------------------------

#' Transfer weight from excluded rows to retained rows
#'
#' Sets the weights of rows satisfying `reduce_if` to zero and proportionally
#' redistributes their weight to rows satisfying `increase_if` within groups
#' defined by `by`. Rows matching neither condition are unchanged.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. `survey_replicate` -> error.
#' @param reduce_if Bare name (NSE). Binary indicator column (`logical` or
#'   integer `0`/`1`). Rows where this is `TRUE`/`1` have their weight set
#'   to 0 and their weight redistributed.
#' @param increase_if Bare name (NSE). Binary indicator column. Rows where
#'   this is `TRUE`/`1` receive the redistributed weight.
#' @param weights Bare name (NSE). Weight column. Auto-detected from
#'   `weighted_df` attribute or `@variables$weights`. For plain `data.frame`
#'   with `weights = NULL`, uniform starting weights are used.
#' @param by <[`tidy-select`][tidyselect::language]> Grouping variable(s).
#'   Redistribution is performed within each group. `NULL` -> global
#'   redistribution.
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored for survey objects.
#' @param control Named list of warning thresholds. Merged with defaults
#'   `list(min_cell = 20, max_adjust = 2.0)`. `min_cell`: warn when a
#'   group has fewer than this many `increase_if` rows. `max_adjust`: warn
#'   when the adjustment factor exceeds this value.
#'
#' @section Algorithm:
#' Within each group \eqn{h} defined by `by`, the adjustment factor applied to
#' each `increase_if` row is
#' \deqn{f_h = \frac{W_{h,\text{reduce}} + W_{h,\text{increase}}}{W_{h,\text{increase}}}}
#' where \eqn{W_{h,\text{reduce}}} and \eqn{W_{h,\text{increase}}} are the
#' summed weights of `reduce_if` and `increase_if` rows in group \eqn{h}.
#' Each `increase_if` weight becomes \eqn{w_{i,new} = w_i \times f_h}.
#' Rows matching neither indicator are unchanged.
#'
#' @returns
#'   - `data.frame` or `weighted_df` input -> `weighted_df` (all rows
#'     retained; `reduce_if` rows have weight 0).
#'   - `survey_nonprob` or `survey_taylor` input -> same class as input,
#'     with `reduce_if` rows removed (zero weights violate survey validators).
#'
#'   A history entry with `operation = "redistribute_weights"` is appended.
#'
#' @details
#'   This function is the general form of
#'   [adjust_nonresponse(method = "weighting-class")][adjust_nonresponse()].
#'   When `reduce_if = nonrespondent indicator` and `increase_if = respondent
#'   indicator`, the two produce equivalent results (within `1e-10`).
#'   `adjust_nonresponse()` does not call `redistribute_weights()` internally
#'   because it is currently the only call site; refactor if a second emerges.
#'
#' @examples
#' # data.frame path: add reduce_if and increase_if columns ----------------
#' gss <- gss_2024[!is.na(gss_2024$sex), ]
#' gss$excluded <- sample(
#'   c(0L, 1L), nrow(gss), replace = TRUE, prob = c(0.8, 0.2)
#' )
#' gss$retained <- as.integer(!gss$excluded)
#' result <- redistribute_weights(
#'   gss,
#'   reduce_if   = excluded,
#'   increase_if = retained,
#'   weights     = wtssps,
#'   by          = sex
#' )
#'
#' # survey_taylor path: mutate the tibble first, then construct the design --
#' gss_excl <- gss_2024[!is.na(gss_2024$sex), ]
#' gss_excl$excluded <- sample(
#'   c(0L, 1L), nrow(gss_excl), replace = TRUE, prob = c(0.8, 0.2)
#' )
#' gss_excl$retained <- as.integer(!gss_excl$excluded)
#' gss_svy <- surveycore::as_survey(
#'   gss_excl, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' result <- redistribute_weights(
#'   gss_svy, reduce_if = excluded, increase_if = retained, by = sex
#' )
#'
#' @seealso [adjust_nonresponse()]
#' @family nonresponse
#' @export
redistribute_weights <- function(
  data,
  reduce_if,
  increase_if,
  weights = NULL,
  by = NULL,
  wt_name = "wts",
  control = list()
) {
  # ---- Capture call and quosures -------------------------------------------
  call_str     <- paste0(deparse(match.call()), collapse = " ")
  weights_quo  <- rlang::enquo(weights)
  reduce_quo   <- rlang::enquo(reduce_if)
  increase_quo <- rlang::enquo(increase_if)

  # ---- 1. Input class check -------------------------------------------------
  .check_input_class(data)

  # survey_replicate is not yet supported for weight redistribution.
  # (calibrate_greg/rake/poststrat accept survey_replicate; this function does not.)
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.cls survey_replicate} objects are not supported by {.fn redistribute_weights}.",
        "i" = "Replicate-weight support for weight redistribution is not yet available.",
        "v" = "Use a {.cls survey_taylor} or {.cls survey_nonprob} design."
      ),
      class = "surveywts_error_replicate_not_supported"
    )
  }

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

  # ---- 4. wt_name validation ------------------------------------------------
  .validate_wt_name(wt_name)

  # ---- 5. Weight column name ------------------------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # ---- 6. wt_name conflict check (data.frame / weighted_df only) ------------
  # For plain data.frame + weights = NULL, weight_col is the sentinel ".weight"
  # which never appears in user data, so any existing column with wt_name
  # is treated as a conflict.
  if (inherits(data, "data.frame") &&
      wt_name %in% names(data_df) &&
      !identical(wt_name, weight_col)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg wt_name} {.val {wt_name}} conflicts with an existing ",
          "column in {.arg data}."
        ),
        "i" = paste0(
          "{.field {wt_name}} is already present and is not the weight ",
          "column."
        ),
        "v" = "Choose a different name for the output weight column."
      ),
      class = "surveywts_error_wt_name_conflict"
    )
  }

  # ---- 7. Create uniform starting weights for plain data.frame + NULL -------
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[wt_name]] <- rep(1 / nrow(data_df), nrow(data_df))
    weight_col <- wt_name
  }

  # Sync plain_df after potentially adding uniform weights
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # ---- 8. Validate weights --------------------------------------------------
  .validate_weights(plain_df, weight_col)

  # ---- 9. Merge control with defaults ---------------------------------------
  control <- utils::modifyList(list(min_cell = 20L, max_adjust = 2.0), control)

  # ---- 10. Resolve indicator column names -----------------------------------
  reduce_col   <- rlang::as_name(reduce_quo)
  increase_col <- rlang::as_name(increase_quo)

  # ---- 11. Check indicator columns exist ------------------------------------
  if (!reduce_col %in% names(plain_df)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg reduce_if} column {.field {reduce_col}} not found in ",
          "{.arg data}."
        ),
        "i" = "Available columns: {.and {.field {names(plain_df)}}}.",
        "v" = paste0(
          "Pass a bare column name, e.g., ",
          "{.code reduce_if = my_indicator}."
        )
      ),
      class = "surveywts_error_reduce_if_not_found"
    )
  }
  if (!increase_col %in% names(plain_df)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg increase_if} column {.field {increase_col}} not found in ",
          "{.arg data}."
        ),
        "i" = "Available columns: {.and {.field {names(plain_df)}}}.",
        "v" = paste0(
          "Pass a bare column name, e.g., ",
          "{.code increase_if = my_indicator}."
        )
      ),
      class = "surveywts_error_increase_if_not_found"
    )
  }

  # ---- 12. Binary validation for reduce_if ----------------------------------
  .validate_response_status_binary(
    plain_df, reduce_col,
    col_label   = "reduce_if column",
    fn_name     = "redistribute_weights",
    error_class = "surveywts_error_reduce_if_not_binary"
  )

  # ---- 13. NA check for reduce_if -------------------------------------------
  n_na_reduce <- sum(is.na(plain_df[[reduce_col]]))
  if (n_na_reduce > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg reduce_if} column {.field {reduce_col}} contains ",
          "{n_na_reduce} NA value(s)."
        ),
        "i" = "The reduce indicator must be fully observed.",
        "v" = paste0(
          "Remove rows with missing values in {.field {reduce_col}} ",
          "before calling {.fn redistribute_weights}."
        )
      ),
      class = "surveywts_error_reduce_if_has_na"
    )
  }

  # ---- 14. Binary validation for increase_if --------------------------------
  .validate_response_status_binary(
    plain_df, increase_col,
    col_label   = "increase_if column",
    fn_name     = "redistribute_weights",
    error_class = "surveywts_error_increase_if_not_binary"
  )

  # ---- 15. NA check for increase_if -----------------------------------------
  n_na_increase <- sum(is.na(plain_df[[increase_col]]))
  if (n_na_increase > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg increase_if} column {.field {increase_col}} contains ",
          "{n_na_increase} NA value(s)."
        ),
        "i" = "The increase indicator must be fully observed.",
        "v" = paste0(
          "Remove rows with missing values in {.field {increase_col}} ",
          "before calling {.fn redistribute_weights}."
        )
      ),
      class = "surveywts_error_increase_if_has_na"
    )
  }

  # ---- 16. Convert to logical and check overlap -----------------------------
  is_reduce  <- as.logical(plain_df[[reduce_col]])
  is_increase <- as.logical(plain_df[[increase_col]])

  n_overlap <- sum(is_reduce & is_increase, na.rm = TRUE)
  if (n_overlap > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{n_overlap} row(s) have both {.arg reduce_if} and ",
          "{.arg increase_if} set to {.code TRUE}."
        ),
        "i" = paste0(
          "{.arg reduce_if} and {.arg increase_if} must be mutually ",
          "exclusive."
        ),
        "v" = paste0(
          "Ensure no row has both indicators set to 1 or {.code TRUE}."
        )
      ),
      class = "surveywts_error_indicators_overlap"
    )
  }

  # ---- 17. Resolve by variable names ----------------------------------------
  by_quo   <- rlang::enquo(by)
  by_names <- if (rlang::quo_is_null(by_quo)) {
    character(0)
  } else {
    tidyselect::eval_select(by_quo, plain_df) |> names()
  }

  # ---- 18. Check for NA in by variables -------------------------------------
  for (var in by_names) {
    n_na <- sum(is.na(plain_df[[var]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "By variable {.field {var}} contains {n_na} NA value(s)."
          ),
          "i" = "NA values in grouping variables are not allowed.",
          "v" = paste0(
            "Remove or impute NA values in {.field {var}} before calling ",
            "{.fn redistribute_weights}."
          )
        ),
        class = "surveywts_error_variable_has_na"
      )
    }
  }

  # ---- 19. Extract weights and compute before-stats -------------------------
  weights_vec  <- plain_df[[weight_col]]
  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 20. Build cell keys --------------------------------------------------
  if (length(by_names) == 0L) {
    cell_keys <- rep("__global__", nrow(plain_df))
  } else {
    cell_keys <- do.call(
      paste,
      c(lapply(by_names, function(v) as.character(plain_df[[v]])),
        sep = "//")
    )
  }

  # ---- 21. Per-group redistribution -----------------------------------------
  new_weights  <- weights_vec
  unique_cells <- unique(cell_keys)

  for (cell in unique_cells) {
    cell_idx     <- which(cell_keys == cell)
    reduce_idx   <- cell_idx[is_reduce[cell_idx]]
    increase_idx <- cell_idx[is_increase[cell_idx]]

    # No reduce_if rows in this group: skip (nothing to redistribute)
    if (length(reduce_idx) == 0L) next

    # reduce_if rows present but no increase_if rows: error
    if (length(increase_idx) == 0L) {
      cell_label <- if (cell == "__global__") "(all rows)" else cell
      cli::cli_abort(
        c(
          "x" = paste0(
            "Group {.val {cell_label}} has {length(reduce_idx)} ",
            "reduce_if row(s) but no increase_if rows."
          ),
          "i" = "Cannot redistribute weight to an empty recipient set.",
          "v" = paste0(
            "Ensure each group has at least one row with ",
            "{.arg increase_if} = {.code TRUE}."
          )
        ),
        class = "surveywts_error_no_recipients_in_group"
      )
    }

    w_reduce   <- sum(weights_vec[reduce_idx])
    w_increase <- sum(weights_vec[increase_idx])
    adj_factor <- (w_reduce + w_increase) / w_increase
    n_increase  <- length(increase_idx)

    # Warn on sparse or extreme-adjustment groups
    cell_label <- if (cell == "__global__") "(global)" else cell
    if (n_increase < control$min_cell || adj_factor > control$max_adjust) {
      adj_factor_fmt <- sprintf("%.2f", adj_factor)
      cli::cli_warn(
        c(
          "!" = paste0(
            "Redistribution group {.val {cell_label}} has {n_increase} ",
            "recipient(s), adjustment factor {adj_factor_fmt}\u00d7."
          ),
          "i" = "Small or high-adjustment groups may produce extreme weights.",
          "i" = paste0(
            "Consider collapsing groups or adjusting ",
            "{.code control$min_cell} / {.code control$max_adjust}."
          )
        ),
        class = "surveywts_warning_class_near_empty"
      )
    }

    new_weights[increase_idx] <- weights_vec[increase_idx] * adj_factor
    new_weights[reduce_idx]   <- 0
  }

  # ---- 22. Build output data frame ------------------------------------------
  out_col <- if (inherits(data, "data.frame")) wt_name else weight_col
  out_df  <- plain_df
  out_df[[out_col]] <- new_weights

  # ---- 23. Build history entry ----------------------------------------------
  after_stats     <- .compute_weight_stats(new_weights[is_increase])
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step        = length(current_history) + 1L,
    operation   = "redistribute_weights",
    weight_col  = if (inherits(data, "data.frame")) {
      wt_name
    } else {
      data@variables$weights
    },
    call_str    = call_str,
    parameters  = list(
      reduce_col   = reduce_col,
      increase_col = increase_col,
      by_variables = by_names,
      method       = "general_redistribution"
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = NULL
  )

  # ---- 24. Return output ----------------------------------------------------
  if (inherits(data, "data.frame")) {
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, wt_name, new_history)
  } else {
    # For survey objects: filter out reduce_if rows (zero weights violate
    # the strictly-positive-weights validator on survey_taylor, and for
    # consistency, survey_nonprob follows the same contract here).
    keep_rows         <- which(!is_reduce)
    filtered_design   <- data
    filtered_design@data <- out_df[keep_rows, , drop = FALSE]
    .update_survey_weights(filtered_design, new_weights[keep_rows], history_entry)
  }
}
