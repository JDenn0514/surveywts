# R/calibrate.R
#
# calibrate() — general calibration to known marginal population totals.
#
# Supports:
#   - method = "linear"  (GREG, one-step exact)
#   - method = "logit"   (bounded, iterative via IRLS)
#   - type = "prop"      (population proportions; default)
#   - type = "count"     (population counts)
#
# All shared helpers (.get_weight_vec, .validate_weights, etc.) live in
# R/utils.R. All vendored algorithms live in R/vendor-calibrate-greg.R.
# Internal constructor .new_survey_calibrated() lives in R/constructors.R.

#' Calibrate survey weights to known population totals
#'
#' Adjusts survey weights so that the weighted marginal totals match known
#' population values. Supports linear (GREG) and logit calibration methods
#' for categorical auxiliary variables.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_calibrated`. `survey_replicate` → error. Any other class → error.
#' @param variables <[`tidy-select`][tidyselect::language]> Columns to
#'   calibrate on. Must be categorical (character or factor). Specify as a
#'   bare name or `c(var1, var2, ...)`.
#' @param population Named list of population targets. Names must match the
#'   column names selected by `variables`. Each element: a named numeric
#'   vector `c(level = target, ...)`.
#'
#'   For `type = "prop"`: values must sum to 1.0 (within `1e-6` tolerance).
#'   For `type = "count"`: values must be strictly positive.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). `NULL` → auto-detected from `weighted_df` attribute or
#'   survey object `@variables$weights`. For plain `data.frame` with
#'   `weights = NULL`, uniform starting weights are used and the output
#'   column is named `".weight"`.
#' @param method Character scalar. `"linear"` (default): one-step exact
#'   GREG calibration (may produce negative weights). `"logit"`: bounded
#'   iterative calibration (always positive).
#' @param type Character scalar. `"prop"` (default): `population` values
#'   are proportions. `"count"`: `population` values are counts.
#' @param control Named list of convergence parameters. Merged with defaults
#'   `list(maxit = 50, epsilon = 1e-7)` — omitted keys retain their defaults.
#'
#' @return
#'   - `data.frame` or `weighted_df` input → `weighted_df`
#'   - `survey_taylor` or `survey_calibrated` input →
#'     `surveycore::survey_calibrated`
#'
#'   The weight column in the output contains calibrated weights. A history
#'   entry with `operation = "calibration"` is appended to
#'   `weighting_history`.
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
#'   sex = c("M", "F", "M", "F", "M"),
#'   stringsAsFactors = FALSE
#' )
#' pop <- list(
#'   age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
#'   sex = c("M" = 0.48, "F" = 0.52)
#' )
#' result <- calibrate(df, variables = c(age_group, sex), population = pop)
#'
#' @family calibration
#' @export
calibrate <- function(
  data,
  variables,
  population,
  weights = NULL,
  method = c("linear", "logit"),
  type = c("prop", "count"),
  control = list(maxit = 50, epsilon = 1e-7)
) {
  # ---- Capture call and arguments before any evaluation --------------------
  call_str <- deparse(match.call())
  method <- rlang::arg_match(method)
  type <- rlang::arg_match(type)
  weights_quo <- rlang::enquo(weights)

  # Merge control with defaults
  control <- utils::modifyList(list(maxit = 50, epsilon = 1e-7), control)

  # ---- 1. Input class check -----------------------------------------------
  .check_input_class(data)

  # ---- 2. Empty data check ------------------------------------------------
  data_df <- if (inherits(data, "data.frame")) as.data.frame(data) else data@data
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

  # ---- 3. Weight column name and validation --------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: create uniform weights column
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[weight_col]] <- rep(1 / nrow(data_df), nrow(data_df))
  }

  # Extract the plain data frame for validation (survey objects use @data)
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # For data.frame inputs, we need the weight column in plain_df
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    # This case is already handled above (uniform weights added to data_df)
    plain_df <- data_df
  }

  .validate_weights(plain_df, weight_col)

  # ---- 4. Resolve variable names via tidy-select --------------------------
  vars_expr <- rlang::enquo(variables)
  variable_names <- tidyselect::eval_select(vars_expr, plain_df) |> names()

  # ---- 5. Check population names are in data ------------------------------
  pop_names <- names(population)
  missing_pop_vars <- setdiff(pop_names, names(plain_df))
  if (length(missing_pop_vars) > 0L) {
    var <- missing_pop_vars[[1L]]
    cli::cli_abort(
      c(
        "x" = "Population variable {.field {var}} not found in {.arg data}.",
        "i" = "Names in {.arg population} must match column names in {.arg data}.",
        "v" = paste0(
          "Check spelling: available columns are ",
          "{.and {.field {names(plain_df)}}}."
        )
      ),
      class = "surveywts_error_population_variable_not_found"
    )
  }

  # ---- 6. Validate calibration variables (categorical, no NAs) ------------
  .validate_calibration_variables(plain_df, variable_names, "Calibration")

  # ---- 7. Validate population marginals -----------------------------------
  .validate_population_marginals(population, pop_names, plain_df, type)

  # ---- 8. Extract starting weights and compute before-stats ---------------
  weights_vec <- .get_weight_vec(data, weights_quo)
  before_stats <- .compute_weight_stats(weights_vec)

  # Convert proportions to counts for the engine
  total_w <- sum(weights_vec)
  if (type == "prop") {
    population_counts <- lapply(population, function(p) p * total_w)
  } else {
    population_counts <- population
  }

  # ---- 9. Build calibration spec and run engine ---------------------------
  vars_spec <- lapply(variable_names, function(v) {
    targets <- population_counts[[v]]
    list(col = v, targets = targets)
  })

  calibration_spec <- list(
    type = method,
    variables = vars_spec,
    total_n = nrow(plain_df)
  )

  engine_result <- .calibrate_engine(
    data_df = plain_df,
    weights_vec = weights_vec,
    calibration_spec = calibration_spec,
    method = method,
    control = control
  )

  new_weights <- engine_result$weights
  convergence <- engine_result$convergence

  # ---- 10. Warn on negative calibrated weights (linear method) ------------
  n_neg <- sum(new_weights < 0, na.rm = TRUE)
  if (n_neg > 0L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Linear calibration produced {n_neg} ",
          "negative calibrated weight(s)."
        ),
        "i" = "Negative weights can cause invalid variance estimates.",
        "i" = paste0(
          "Consider {.code method = \"logit\"} for bounded weights, ",
          "or review population totals."
        )
      ),
      class = "surveywts_warning_negative_calibrated_weights"
    )
  }

  # ---- 11. Compute after-stats and build history entry --------------------
  after_stats <- .compute_weight_stats(new_weights)

  # Determine current history for step number
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "calibration",
    call_str = call_str,
    parameters = list(
      variables = variable_names,
      population = population,
      method = method,
      type = type,
      control = control
    ),
    before_stats = before_stats,
    after_stats = after_stats,
    convergence = convergence
  )

  # ---- 12. Build output ---------------------------------------------------
  if (inherits(data, "data.frame")) {
    # data.frame or weighted_df → weighted_df
    out_df <- plain_df
    out_df[[weight_col]] <- new_weights
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, weight_col, new_history)
  } else {
    # survey object → survey_calibrated
    updated_data <- data@data
    updated_data[[weight_col]] <- new_weights
    .new_survey_calibrated(data, updated_data, weight_col, history_entry)
  }
}

# ---------------------------------------------------------------------------
# .check_input_class() — input class validation (used only by calibrate())
# ---------------------------------------------------------------------------

.check_input_class <- function(data) {
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.cls survey_replicate} objects are not supported in Phase 0.",
        "i" = "Replicate-weight support requires Phase 1.",
        "v" = "Use a {.cls survey_taylor} design, or wait for Phase 1."
      ),
      class = "surveywts_error_replicate_not_supported"
    )
  }

  is_supported <- inherits(data, "data.frame") ||
    S7::S7_inherits(data, surveycore::survey_taylor) ||
    S7::S7_inherits(data, surveycore::survey_calibrated)

  if (!is_supported) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg data} must be a data frame, {.cls weighted_df}, ",
          "{.cls survey_taylor}, or {.cls survey_calibrated}."
        ),
        "i" = "Got {.cls {cls}}."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }
}

# ---------------------------------------------------------------------------
# .get_history() — extract weighting history from any input class
# ---------------------------------------------------------------------------

.get_history <- function(x) {
  if (inherits(x, "weighted_df")) {
    attr(x, "weighting_history") %||% list()
  } else if (S7::S7_inherits(x, surveycore::survey_taylor) ||
               S7::S7_inherits(x, surveycore::survey_calibrated)) {
    x@metadata@weighting_history %||% list()
  } else {
    list()
  }
}
