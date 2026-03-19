# R/poststratify.R
#
# poststratify() -- exact post-stratification to joint population cell counts.
#
# Unlike calibrate() and rake(), poststratify() calibrates to joint cells
# (cross-tabulations), not marginal totals. One-pass exact: no iteration.
#
# Private helper (only used here):
#   .validate_population_cells()  -- validates population data frame structure
#
# All shared helpers (.get_weight_vec, .validate_weights,
# .check_input_class, .get_history, etc.) live in R/utils.R.

#' Post-stratify survey weights to known joint population cell totals
#'
#' Adjusts survey weights so that the weighted cell counts (or proportions)
#' match known population values for every joint combination of stratification
#' variables. Unlike [calibrate()] and [rake()], which match marginal totals,
#' `poststratify()` matches exact cross-tabulation cells in a single pass.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. `survey_replicate` -> error. Any other class -> error.
#' @param strata <[`tidy-select`][tidyselect::language]> Stratification
#'   variables that jointly define the cells. Specify as a bare name or
#'   `c(var1, var2, ...)`. Unlike [calibrate()] and [rake()], strata
#'   variables may be any type (character, factor, integer, numeric).
#' @param population A `data.frame` with one column per variable selected by
#'   `strata` (column names must match exactly), one column named `"target"`,
#'   and one row per unique cell combination.
#'
#'   For `type = "count"`: values in `target` must be strictly positive.
#'   For `type = "prop"`: values in `target` must sum to 1.0 (within `1e-6`).
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). `NULL` -> auto-detected from `weighted_df` attribute or
#'   survey object `@variables$weights`. For plain `data.frame` with
#'   `weights = NULL`, uniform starting weights are used and the output
#'   column is named `".weight"`.
#' @param type Character scalar. `"prop"` (default): `target` values are
#'   proportions summing to 1.0. `"count"`: `target` values are population
#'   counts. Consistent with [calibrate()] and [rake()].
#'
#' @return
#'   - `data.frame` or `weighted_df` input -> `weighted_df`
#'   - `survey_taylor` or `survey_nonprob` input -> same class as input
#'     (`survey_taylor` or `survey_nonprob`; class is preserved)
#'
#'   The weight column in the output contains post-stratified weights. A
#'   history entry with `operation = "poststratify"` is appended to
#'   `weighting_history`.
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
#'   sex = c("M", "M", "M", "F", "F", "F"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Proportion targets (default type = "prop")
#' pop_prop <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
#'   sex = c("M", "M", "M", "F", "F", "F"),
#'   target = c(0.14, 0.18, 0.17, 0.15, 0.19, 0.17)
#' )
#' result <- poststratify(df, strata = c(age_group, sex), population = pop_prop)
#'
#' # Count targets (explicit type = "count")
#' pop_count <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
#'   sex = c("M", "M", "M", "F", "F", "F"),
#'   target = c(14000, 18000, 17000, 15000, 19000, 17000)
#' )
#' result2 <- poststratify(df, strata = c(age_group, sex),
#'   population = pop_count, type = "count")
#'
#' @family calibration
#' @export
poststratify <- function(
  data,
  strata,
  population,
  weights = NULL,
  type = c("prop", "count")
) {
  # ---- Capture call and match arguments ------------------------------------
  call_str    <- deparse(match.call())
  type        <- rlang::arg_match(type)
  weights_quo <- rlang::enquo(weights)

  # ---- 1. Input class check -----------------------------------------------
  .check_input_class(data)

  # ---- 2. Extract plain data frame ----------------------------------------
  data_df <- if (inherits(data, "data.frame")) as.data.frame(data) else data@data

  # ---- 3. Empty data check ------------------------------------------------
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

  # ---- 4. Weight column name ----------------------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: create uniform starting weights
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[weight_col]] <- rep(1 / nrow(data_df), nrow(data_df))
  }

  # Resolve the plain data frame with weights present
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # Sync plain_df when we added a uniform weight column above
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    plain_df <- data_df
  }

  # ---- 5. Validate weights ------------------------------------------------
  .validate_weights(plain_df, weight_col)

  # ---- 6. Resolve strata names via tidy-select ----------------------------
  strata_quo   <- rlang::enquo(strata)
  strata_names <- tidyselect::eval_select(strata_quo, plain_df) |> names()

  # ---- 7. Check for NA in strata variables --------------------------------
  for (var in strata_names) {
    n_na <- sum(is.na(plain_df[[var]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Strata variable {.field {var}} contains {n_na} NA value(s)."
          ),
          "i" = "NA values in strata variables are not allowed.",
          "v" = paste0(
            "Remove or impute NA values in {.field {var}} before ",
            "calling {.fn poststratify}."
          )
        ),
        class = "surveywts_error_variable_has_na"
      )
    }
  }

  # ---- 8. Validate population data frame ----------------------------------
  .validate_population_cells(population, strata_names, plain_df, type)

  # ---- 9. Extract starting weights and compute before-stats ---------------
  weights_vec  <- .get_weight_vec(data, weights_quo)
  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 10. Build cell specs -----------------------------------------------
  # Create a string key for each row by pasting joint strata values together.
  data_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(plain_df[[v]])),
      sep = "//")
  )
  pop_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(population[[v]])),
      sep = "//")
  )

  # Convert proportions to counts if needed (engine always uses counts)
  total_w <- sum(weights_vec)
  targets <- if (type == "prop") {
    population[["target"]] * total_w
  } else {
    population[["target"]]
  }

  cells <- lapply(seq_along(pop_keys), function(i) {
    list(
      indices = which(data_keys == pop_keys[[i]]),
      target  = targets[[i]]
    )
  })

  # ---- 11. Check for empty strata cells (defensive guard) -----------------
  # With positive starting weights (enforced by .validate_weights), N_hat_h
  # is always > 0 in Phase 0. This guard protects Phase 1+ scenarios.
  for (i in seq_along(cells)) {
    n_hat_h <- sum(weights_vec[cells[[i]]$indices])
    # nocov start
    if (n_hat_h <= 0) {
      cell_label <- pop_keys[[i]]
      cli::cli_abort(
        c(
          "x" = paste0(
            "Stratum cell {.val {cell_label}} has zero weighted count."
          ),
          "i" = paste0(
            "Post-stratification requires at least one positive-weight ",
            "observation in every cell."
          ),
          "v" = "Collapse small cells before post-stratifying."
        ),
        class = "surveywts_error_empty_stratum"
      )
    }
    # nocov end
  }

  # ---- 12. Run calibration engine (poststratify type) ---------------------
  calibration_spec <- list(
    type  = "poststratify",
    cells = cells
  )

  engine_result <- .calibrate_engine(
    data_df          = plain_df,
    weights_vec      = weights_vec,
    calibration_spec = calibration_spec,
    method           = "poststratify",
    control          = list()
  )

  new_weights <- engine_result$weights

  # ---- 13. Build history entry --------------------------------------------
  after_stats     <- .compute_weight_stats(new_weights)
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step        = length(current_history) + 1L,
    operation   = "poststratify",
    call_str    = call_str,
    parameters  = list(
      variables  = strata_names,
      population = population,
      type       = type
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = NULL  # non-iterative
  )

  # ---- 14. Build output ---------------------------------------------------
  if (inherits(data, "data.frame")) {
    out_df                  <- plain_df
    out_df[[weight_col]]    <- new_weights
    new_history             <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, weight_col, new_history)
  } else {
    # survey object → same class (class preserved; only weights + history updated)
    .update_survey_weights(data, new_weights, history_entry)
  }
}

# ---------------------------------------------------------------------------
# .validate_population_cells() -- private helper
# ---------------------------------------------------------------------------

# Validates the population data frame for poststratify().
#
# Checks (in order):
#   1. Required columns present (strata_names + "target")
#   2. No duplicate rows in population (same cell combination > once)
#   3. Every cell in data has a matching row in population
#   4. Every row in population has observations in data
#   5. Target values are valid for the given type
#
# Arguments:
#   population   : data.frame -- one row per cell
#   strata_names : character vector -- names of strata columns
#   data         : data.frame (plain) -- used for data<->population matching
#   type         : "count" or "prop"
#
# Returns invisible(TRUE) on success. Throws typed errors on failure.
.validate_population_cells <- function(population, strata_names, data, type) {
  # ---- 1. Required columns in population ----------------------------------
  required_cols <- c(strata_names, "target")
  missing_cols  <- setdiff(required_cols, names(population))
  if (length(missing_cols) > 0L) {
    col <- missing_cols[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg population} is missing required column {.field {col}}."
        ),
        "i" = paste0(
          "{.arg population} must have columns for each strata variable ",
          "({.and {.field {strata_names}}}) plus {.field target}."
        ),
        "v" = paste0(
          "Add the {.field {col}} column to {.arg population}."
        )
      ),
      class = "surveywts_error_population_cell_missing"
    )
  }

  # ---- Build row keys (string representation of each cell) ---------------
  data_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(data[[v]])),
      sep = "//")
  )
  pop_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(population[[v]])),
      sep = "//")
  )

  data_unique_keys <- unique(data_keys)

  # ---- 2. No duplicate rows in population ---------------------------------
  dup_tab <- table(pop_keys)
  dup_keys <- names(dup_tab)[dup_tab > 1L]
  if (length(dup_keys) > 0L) {
    cell_label <- dup_keys[[1L]]
    n          <- as.integer(dup_tab[[cell_label]])
    cli::cli_abort(
      c(
        "x" = paste0(
          "Population cell {.val {cell_label}} appears {n} times in ",
          "{.arg population}."
        ),
        "i" = "Each cell combination must appear exactly once in {.arg population}.",
        "v" = paste0(
          "Remove duplicate rows for {.val {cell_label}} from ",
          "{.arg population} before calling {.fn poststratify}."
        )
      ),
      class = "surveywts_error_population_cell_duplicate"
    )
  }

  # ---- 3. Every data cell has a matching population row -------------------
  data_missing <- setdiff(data_unique_keys, pop_keys)
  if (length(data_missing) > 0L) {
    cell_label <- data_missing[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "Cell {.val {cell_label}} is present in {.arg data} but has ",
          "no matching row in {.arg population}."
        ),
        "i" = "Every cell combination in the data must appear in {.arg population}.",
        "v" = paste0(
          "Add a row for {.val {cell_label}} to {.arg population}."
        )
      ),
      class = "surveywts_error_population_cell_missing"
    )
  }

  # ---- 4. Every population row has observations in data -------------------
  pop_extra <- setdiff(pop_keys, data_unique_keys)
  if (length(pop_extra) > 0L) {
    cell_label <- pop_extra[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "Population cell {.val {cell_label}} has no observations in ",
          "{.arg data}."
        ),
        "i" = paste0(
          "Extra cells in the population frame are not allowed -- they ",
          "may indicate a misspecified population."
        ),
        "v" = paste0(
          "Remove rows for {.val {cell_label}} from {.arg population} ",
          "before calling {.fn poststratify}."
        )
      ),
      class = "surveywts_error_population_cell_not_in_data"
    )
  }

  # ---- 5. Validate target values ------------------------------------------
  tgt <- population[["target"]]

  if (type == "prop") {
    sum_val <- sum(tgt)
    tol     <- 1e-6
    if (abs(sum_val - 1.0) > tol) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Population targets sum to {sum_val}, not 1.0."
          ),
          "i" = paste0(
            "When {.code type = \"prop\"}, targets in {.arg population} ",
            "must sum to 1.0 (within 1e-6 tolerance)."
          ),
          "v" = paste0(
            "Adjust the values in the {.field target} column of ",
            "{.arg population}."
          )
        ),
        class = "surveywts_error_population_totals_invalid"
      )
    }
  } else {
    # type = "count"
    n_nonpos <- sum(tgt <= 0, na.rm = TRUE)
    if (n_nonpos > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Population targets contain {n_nonpos} non-positive value(s)."
          ),
          "i" = paste0(
            "When {.code type = \"count\"}, all targets must be ",
            "strictly positive (> 0)."
          ),
          "v" = paste0(
            "Remove or correct non-positive entries in the ",
            "{.field target} column of {.arg population}."
          )
        ),
        class = "surveywts_error_population_totals_invalid"
      )
    }
  }

  invisible(TRUE)
}
