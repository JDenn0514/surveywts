# R/calibrate_greg.R
#
# calibrate_greg() — GREG calibration to known marginal population totals.
#
# Replaces old calibrate() (PR 1 of calibration-api redesign).
# Key changes vs old calibrate():
#   - `variables` + `population` replaced by single `targets` arg
#   - `method` renamed to `model`
#   - operation history field: "calibrate_greg" (was "calibration")
#   - control key validation with surveywts_warning_control_param_ignored
#   - `reference_design` argument added
#
# All shared helpers (.get_weight_vec, .validate_weights, etc.) live in
# R/utils.R. Calibration-family helpers (.parse_margins, etc.) live in
# R/calibrate-utils.R.

#' Calibrate survey weights to known population totals using GREG
#'
#' Adjusts survey weights so that the weighted marginal totals match known
#' population values using Generalized Regression (GREG) estimation. Supports
#' linear (one-step exact) and logit (bounded iterative) calibration models for
#' categorical auxiliary variables.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. `survey_replicate` -> error. Any other class -> error.
#' @param targets Named list of population marginal targets (Format A) or a
#'   long data frame with columns `variable`, `level`, `target` (Format B).
#'
#'   **Format A -- named list:**
#'   ```r
#'   list(
#'     age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
#'     sex       = c("M" = 0.48, "F" = 0.52)
#'   )
#'   ```
#'
#'   **Format B -- long data frame:**
#'   ```r
#'   data.frame(
#'     variable = c("age_group", "age_group", "sex", "sex"),
#'     level    = c("18-34", "35-54", "M", "F"),
#'     target   = c(0.40, 0.60, 0.49, 0.51)
#'   )
#'   ```
#'
#'   Names must match column names in `data`. For `type = "prop"`: each
#'   element must sum to 1.0 within 1e-6. For `type = "count"`: all values
#'   must be strictly positive and all marginal sums must agree within 1e-3.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). `NULL` -> auto-detected from `weighted_df` attribute or
#'   survey object `@variables$weights`. For plain `data.frame` with
#'   `weights = NULL`, uniform starting weights are used and the output
#'   column is named by `wt_name` (default `"wts"`).
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored when `data` is a survey
#'   object (`survey_taylor` or `survey_nonprob`).
#' @param model Character scalar. `"linear"` (default): one-step exact GREG
#'   calibration (may produce negative weights). `"logit"`: bounded iterative
#'   calibration (always positive).
#' @param type Character scalar. `"prop"` (default): `targets` values are
#'   proportions. `"count"`: `targets` values are counts.
#' @param control Named list of convergence parameters. Merged with defaults
#'   `list(maxit = 50, epsilon = 1e-7)`. Omitted keys retain their defaults.
#'   Unrecognized keys trigger `surveywts_warning_control_param_ignored` per
#'   key. Valid keys are `maxit` and `epsilon`.
#' @param reference_design A `survey_taylor` object or `NULL`. The probability
#'   survey from which `targets` were estimated. When non-`NULL`, stored in
#'   the history entry with `targets_from_reference = TRUE`. Any non-`NULL`
#'   non-`survey_taylor` value triggers an error.
#'
#' @return
#'   - `data.frame` or `weighted_df` input -> `weighted_df`
#'   - `survey_taylor` or `survey_nonprob` input -> same class as input
#'     (class is preserved)
#'
#'   The weight column in the output contains calibrated weights. A history
#'   entry with `operation = "calibrate_greg"` is appended to
#'   `weighting_history`.
#'
#' @references
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376–382. doi:10.2307/2290268
#'
#'   Rao, J. N. K., Yung, W. and Hidiroglou, M. A. (2002). Estimating
#'   equations for the analysis of survey data using poststratification
#'   information. *Sankhya*, 64(2), 364–378.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013–1020.
#'   doi:10.1080/01621459.1993.10476369
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
#'   sex = c("M", "F", "M", "F", "M"),
#'   stringsAsFactors = FALSE
#' )
#' targets <- list(
#'   age_group = c("18-34" = 0.40, "35-54" = 0.40, "55+" = 0.20),
#'   sex = c("M" = 0.50, "F" = 0.50)
#' )
#' result <- calibrate_greg(df, targets = targets)
#'
#' @family calibration
#' @export
calibrate_greg <- function(
  data,
  targets,
  weights = NULL,
  wt_name = "wts",
  model = c("linear", "logit"),
  type = c("prop", "count"),
  control = list(maxit = 50, epsilon = 1e-7),
  reference_design = NULL
) {
  # ---- Capture call and arguments before any evaluation --------------------
  call_str <- deparse(match.call())
  model <- rlang::arg_match(model)
  type <- rlang::arg_match(type)
  weights_quo <- rlang::enquo(weights)
  .validate_wt_name(wt_name)

  # ---- Validate reference_design -------------------------------------------
  .validate_reference_design(reference_design)
  targets_from_reference <- !is.null(reference_design)

  # ---- Control key validation and merge with defaults ----------------------
  valid_keys <- c("maxit", "epsilon")
  unknown_keys <- setdiff(names(control), valid_keys)
  for (key in unknown_keys) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.code control${.field {key}}} is not a recognized ",
          "{.fn calibrate_greg} control parameter and will be ignored."
        ),
        "i" = paste0(
          "Valid {.arg control} keys are: {.code maxit}, {.code epsilon}."
        )
      ),
      class = "surveywts_warning_control_param_ignored"
    )
  }
  control <- control[intersect(names(control), valid_keys)]
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

  # ---- 3. Parse targets to Format A ----------------------------------------
  targets_a <- .parse_margins(targets)
  variable_names <- names(targets_a)

  # ---- 4. Weight column name and validation --------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: create uniform weights column
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[wt_name]] <- rep(1 / nrow(data_df), nrow(data_df))
    weight_col <- wt_name
  }

  # Extract the plain data frame for validation (survey objects use @data)
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # For data.frame inputs, ensure uniform-weight column is in plain_df
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    plain_df <- data_df
  }

  .validate_weights(plain_df, weight_col)

  # ---- 5. Check targets variable names are in data ------------------------
  missing_target_vars <- setdiff(variable_names, names(plain_df))
  if (length(missing_target_vars) > 0L) {
    var <- missing_target_vars[[1L]]
    cli::cli_abort(
      c(
        "x" = "Target variable {.field {var}} not found in {.arg data}.",
        "i" = "Names in {.arg targets} must match column names in {.arg data}.",
        "v" = paste0(
          "Check spelling: available columns are ",
          "{.and {.field {names(plain_df)}}}."
        )
      ),
      class = "surveywts_error_targets_variable_not_found"
    )
  }

  # ---- 6. Validate calibration variables (categorical, no NAs) ------------
  .validate_calibration_variables(plain_df, variable_names, "Calibration")

  # ---- 7. Validate population marginals -----------------------------------
  .validate_population_marginals(
    targets_a, variable_names, plain_df, type,
    target_name = "targets"
  )

  # ---- 7b. Validate count marginal consistency (cross-marginal sums) ------
  if (type == "count") {
    .validate_count_marginal_consistency(targets_a, variable_names)
  }

  # ---- 8. Extract starting weights and compute before-stats ---------------
  weights_vec <- .get_weight_vec(data, weights_quo)
  before_stats <- .compute_weight_stats(weights_vec)

  # Convert proportions to counts for the engine
  total_w <- sum(weights_vec)
  if (type == "prop") {
    population_counts <- lapply(targets_a, function(p) p * total_w)
  } else {
    population_counts <- targets_a
  }

  # ---- 9. Build calibration spec and run engine ---------------------------
  vars_spec <- lapply(variable_names, function(v) {
    list(col = v, targets = population_counts[[v]])
  })

  calibration_spec <- list(
    type = model,
    variables = vars_spec,
    total_n = nrow(plain_df)
  )

  engine_result <- .calibrate_engine(
    data_df = plain_df,
    weights_vec = weights_vec,
    calibration_spec = calibration_spec,
    method = model,
    control = control
  )

  new_weights <- engine_result$weights
  convergence <- engine_result$convergence

  # ---- 10. Warn on negative calibrated weights (linear model) -------------
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
          "Consider {.code model = \"logit\"} for bounded weights, ",
          "or review population totals."
        )
      ),
      class = "surveywts_warning_negative_calibrated_weights"
    )
  }

  # ---- 11. Compute after-stats and build history entry --------------------
  after_stats <- .compute_weight_stats(new_weights)
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "calibrate_greg",
    weight_col = if (inherits(data, "data.frame")) {
      wt_name
    } else {
      data@variables$weights
    },
    call_str = call_str,
    parameters = list(
      variables = variable_names,
      targets = targets_a,
      model = model,
      type = type,
      control = control,
      targets_from_reference = targets_from_reference,
      reference_design = reference_design
    ),
    before_stats = before_stats,
    after_stats = after_stats,
    convergence = convergence
  )

  # ---- 12. Build output ---------------------------------------------------
  if (inherits(data, "data.frame")) {
    out_df <- plain_df
    out_df[[wt_name]] <- new_weights
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, wt_name, new_history)
  } else {
    .update_survey_weights(data, new_weights, history_entry)
  }
}
