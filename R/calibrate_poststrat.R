# R/calibrate_poststrat.R
#
# calibrate_poststrat() — exact post-stratification to joint population cell
# counts.
#
# Replaces old poststratify() (PR 2 of calibration-api redesign).
# Key changes vs old poststratify():
#   - `strata` (tidy-select) + `population` data frame replaced by single
#     `targets` data frame; strata variables identified from
#     setdiff(names(targets), "target")
#   - operation history field: "calibrate_poststrat" (was "poststratify")
#   - `reference_design` argument added
#   - targets must be a data.frame (not a named list)
#   - New error classes: surveywts_error_margins_format_invalid,
#     surveywts_error_no_strata_variables,
#     surveywts_error_targets_variable_not_found
#
# Private helper (only used here):
#   .validate_population_cells()  -- validates targets data frame structure
#
# All shared helpers (.get_weight_vec, .validate_weights,
# .check_input_class, .get_history, etc.) live in R/utils.R.
# Calibration-family shared helpers live in R/calibrate-utils.R.

#' Post-stratify survey weights to known joint population cell totals
#'
#' Adjusts survey weights so that the weighted cell counts (or proportions)
#' match known population values for every joint combination of stratification
#' variables. Unlike [calibrate_greg()] and [calibrate_rake()], which match
#' marginal totals, `calibrate_poststrat()` matches exact cross-tabulation
#' cells in a single pass.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`,
#'   `survey_nonprob`, or `survey_replicate`. Any other class -> error.
#'   When `data` is a `survey_replicate`, post-stratification is applied
#'   independently to every replicate weight column using the same population
#'   `targets`. Replicate columns where any cell has zero or negative total
#'   weight fail calibration; a `surveywts_warning_replicate_calibration_failed`
#'   warning is emitted and the original replicate weights are kept.
#' @param targets A `data.frame` with one column per stratification variable
#'   (column names must match column names in `data`), plus a column named
#'   `"target"`, and one row per unique cell combination. The stratification
#'   variables are automatically identified as `setdiff(names(targets), "target")`.
#'
#'   Unlike [calibrate_greg()] and [calibrate_rake()], `targets` must be a
#'   `data.frame` — named lists are not accepted
#'   (`surveywts_error_margins_format_invalid`). The `targets` data frame must
#'   have at least one non-`"target"` column
#'   (`surveywts_error_no_strata_variables` if zero).
#'
#'   For `type = "count"`: values in `target` must be strictly positive.
#'   For `type = "prop"`: values in `target` must sum to 1.0 (within `1e-6`).
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). `NULL` -> auto-detected from `weighted_df` attribute or
#'   survey object `@variables$weights`. For plain `data.frame` with
#'   `weights = NULL`, uniform starting weights are used.
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored when `data` is a survey
#'   object (`survey_taylor` or `survey_nonprob`).
#' @param type Character scalar. `"prop"` (default): `target` values are
#'   proportions summing to 1.0. `"count"`: `target` values are population
#'   counts. Consistent with [calibrate_greg()] and [calibrate_rake()].
#' @param reference_design A `survey_taylor` object or `NULL`. The probability
#'   survey from which `targets` were estimated. When non-`NULL`, stored in
#'   the history entry with `targets_from_reference = TRUE`. Any non-`NULL`
#'   non-`survey_taylor` value triggers
#'   `surveywts_error_reference_design_not_taylor`.
#'
#' @return
#'   - `data.frame` or `weighted_df` input -> `weighted_df`
#'   - `survey_taylor` or `survey_nonprob` input -> same class as input
#'     (`survey_taylor` or `survey_nonprob`; class is preserved);
#'     `@calibration` slot is populated
#'   - `survey_replicate` input -> `survey_replicate` (class preserved);
#'     `@calibration` slot is populated, including `replicate_converged`
#'
#'   The weight column in the output contains post-stratified weights. A
#'   history entry with `operation = "calibrate_poststrat"` is appended to
#'   `weighting_history`.
#'   For `survey_replicate` inputs, each replicate weight column is also
#'   post-stratified. Failed replicates retain their original weights and are
#'   recorded in `output@calibration$replicate_converged` as `FALSE`.
#'
#' @references
#'   Valliant, R. (1993). Poststratification and conditional variance
#'   estimation. *Journal of the American Statistical Association*,
#'   88(421), 89–96. doi:10.2307/2290701
#'
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
#'   Rao, J. N. K., Wu, C. F. J. and Yue, K. (1992). Some recent work on
#'   resampling methods for complex surveys. *Survey Methodology*,
#'   18(2), 209–217.
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
#' result <- calibrate_poststrat(df, targets = pop_prop)
#'
#' # Count targets (explicit type = "count")
#' pop_count <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
#'   sex = c("M", "M", "M", "F", "F", "F"),
#'   target = c(14000, 18000, 17000, 15000, 19000, 17000)
#' )
#' result2 <- calibrate_poststrat(
#'   df,
#'   targets = pop_count,
#'   type = "count"
#' )
#'
#' @family calibration
#' @export
calibrate_poststrat <- function(
  data,
  targets,
  weights = NULL,
  wt_name = "wts",
  type = c("prop", "count"),
  reference_design = NULL
) {
  # ---- Capture call and match arguments ------------------------------------
  call_str    <- deparse(match.call())
  type        <- rlang::arg_match(type)
  weights_quo <- rlang::enquo(weights)
  .validate_wt_name(wt_name)

  # ---- Validate reference_design ------------------------------------------
  .validate_reference_design(reference_design)
  targets_from_reference <- !is.null(reference_design)

  # ---- 1. Validate targets is a data.frame --------------------------------
  if (!is.data.frame(targets)) {
    cls <- class(targets)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg targets} must be a {.cls data.frame} with one column per ",
          "stratification variable and one column named {.field target}."
        ),
        "i" = "Got {.cls {cls}}.",
        "v" = paste0(
          "Pass a {.cls data.frame} where non-{.field target} columns ",
          "define the strata cells."
        )
      ),
      class = "surveywts_error_margins_format_invalid"
    )
  }

  # ---- 2. Derive strata_names from targets columns ------------------------
  strata_names <- setdiff(names(targets), "target")

  if (length(strata_names) == 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg targets} has no stratification variable columns ",
          "(only a {.field target} column was found)."
        ),
        "i" = paste0(
          "Stratification variables are identified as all columns in ",
          "{.arg targets} except {.field target}."
        ),
        "v" = paste0(
          "Add at least one column to {.arg targets} that matches a ",
          "column in {.arg data}."
        )
      ),
      class = "surveywts_error_no_strata_variables"
    )
  }

  # ---- 3. Input class check -----------------------------------------------
  .check_input_class(data)

  # ---- 4. Extract plain data frame ----------------------------------------
  data_df <- if (inherits(data, "data.frame")) as.data.frame(data) else data@data

  # ---- 5. Empty data check ------------------------------------------------
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

  # ---- 6. Check strata variable names exist in data -----------------------
  missing_vars <- setdiff(strata_names, names(data_df))
  if (length(missing_vars) > 0L) {
    var <- missing_vars[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "Stratification variable {.field {var}} from {.arg targets} not ",
          "found in {.arg data}."
        ),
        "i" = paste0(
          "Non-{.field target} column names in {.arg targets} must match ",
          "column names in {.arg data}."
        ),
        "v" = paste0(
          "Check spelling: available columns are ",
          "{.and {.field {names(data_df)}}}."
        )
      ),
      class = "surveywts_error_targets_variable_not_found"
    )
  }

  # ---- 7. Weight column name ----------------------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: create uniform starting weights
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[wt_name]] <- rep(1 / nrow(data_df), nrow(data_df))
    weight_col <- wt_name
  }

  # Resolve the plain data frame with weights present
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # Sync plain_df when we added a uniform weight column above
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    plain_df <- data_df
  }

  # ---- 8. Validate weights ------------------------------------------------
  .validate_weights(plain_df, weight_col)

  # ---- 9. Check for NA in strata variables --------------------------------
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
            "calling {.fn calibrate_poststrat}."
          )
        ),
        class = "surveywts_error_variable_has_na"
      )
    }
  }

  # ---- 10. Validate targets data frame ------------------------------------
  .validate_population_cells(targets, strata_names, plain_df, type)

  # ---- 11. Extract starting weights and compute before-stats --------------
  weights_vec  <- .get_weight_vec(data, weights_quo)
  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 12. Build cell specs -----------------------------------------------
  data_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(plain_df[[v]])),
      sep = "//")
  )
  pop_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(targets[[v]])),
      sep = "//")
  )

  # Convert proportions to counts if needed (engine always uses counts)
  total_w <- sum(weights_vec)
  target_vals <- if (type == "prop") {
    targets[["target"]] * total_w
  } else {
    targets[["target"]]
  }

  cells <- lapply(seq_along(pop_keys), function(i) {
    list(
      indices = which(data_keys == pop_keys[[i]]),
      target  = target_vals[[i]]
    )
  })

  # ---- 13. Check for empty strata cells (defensive guard) -----------------
  # With positive starting weights (.validate_weights enforces this), N_hat_h
  # is always > 0. This guard protects Replicate+ scenarios.
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

  # ---- 14. Compute post-stratified weights --------------------------------
  # Direct cell-ratio method: w_new_i = w_old_i * (target_h / N_hat_h)
  # where N_hat_h = sum of starting weights in cell h.
  # This is algebraically equivalent to survey::postStratify but handles
  # edge cases like single-PSU designs.
  new_weights <- weights_vec
  for (i in seq_along(cells)) {
    idx    <- cells[[i]]$indices
    n_hat  <- sum(weights_vec[idx])
    ratio  <- target_vals[[i]] / n_hat
    new_weights[idx] <- weights_vec[idx] * ratio
  }

  # ---- 15. Build x_matrix, cell_factors, and calibration provenance -------
  # For survey objects only. x_matrix is full cross-cell indicator: n × C
  # matrix where C = number of unique cells in targets.
  is_survey_obj <- S7::S7_inherits(data, surveycore::survey_base)
  caldata <- NULL

  if (is_survey_obj) {
    # Build cell indicator matrix (n × C)
    C <- length(cells)
    x_matrix_ps <- matrix(0, nrow = nrow(plain_df), ncol = C,
                          dimnames = list(NULL, pop_keys))
    for (i in seq_along(cells)) {
      x_matrix_ps[cells[[i]]$indices, i] <- 1
    }

    # Population totals in count scale per cell (length C)
    population_totals_ps <- stats::setNames(target_vals, pop_keys)

    # cell_factors: N_c / N_hat_c
    # N_hat_c = sum(weights_vec[cell indices])  (already computed above)
    cell_factors_ps <- stats::setNames(
      vapply(
        seq_along(cells),
        function(i) {
          n_hat_c <- sum(weights_vec[cells[[i]]$indices])
          target_vals[[i]] / n_hat_c
        },
        numeric(1L)
      ),
      pop_keys
    )

    q_weights_ps <- rep(1, nrow(plain_df))

    # Build a minimal engine_result for .build_calibration_provenance().
    # Post-stratification is exact (non-iterative): always converged, 1 step.
    engine_result_ps <- list(
      weights     = new_weights,
      convergence = list(
        converged  = TRUE,
        iterations = 1L
      )
    )

    caldata <- .build_calibration_provenance(
      engine_result     = engine_result_ps,
      x_matrix          = x_matrix_ps,
      base_weights      = weights_vec,
      q_weights         = q_weights_ps,
      population_totals = population_totals_ps,
      method            = "poststrat",
      cell_factors      = cell_factors_ps
    )

    # ---- Replicate loop (survey_replicate only) ----------------------------
    if (S7::S7_inherits(data, surveycore::survey_replicate)) {
      repwt_cols <- data@variables$repweights
      replicate_converged <- stats::setNames(
        rep(TRUE, length(repwt_cols)),
        repwt_cols
      )

      for (repwt_col in repwt_cols) {
        rep_wt <- data@data[[repwt_col]]

        # Apply post-stratification to this replicate using the same cells.
        # Scale target_vals proportionally to the replicate's own weight total.
        rep_total_w <- sum(rep_wt)
        if (type == "prop") {
          rep_target_vals <- targets[["target"]] * rep_total_w
        } else {
          rep_target_vals <- target_vals
        }

        failed <- tryCatch(
          {
            rep_new_wts <- rep_wt
            for (i in seq_along(cells)) {
              idx        <- cells[[i]]$indices
              n_hat_c    <- sum(rep_wt[idx])
              if (n_hat_c <= 0) {
                stop(paste0(
                  "Cell '", pop_keys[[i]], "' has zero or negative weighted ",
                  "count in this replicate."
                ))
              }
              ratio <- rep_target_vals[[i]] / n_hat_c
              rep_new_wts[idx] <- rep_wt[idx] * ratio
            }
            data@data[[repwt_col]] <- rep_new_wts
            FALSE
          },
          error = function(e) {
            col_nm <- repwt_col
            cli::cli_warn(
              c(
                "!" = paste0(
                  "Calibration failed for replicate weight column ",
                  "{.field {col_nm}}."
                ),
                "i" = "Reason: {conditionMessage(e)}",
                "i" = paste0(
                  "This replicate's weights are kept at their ",
                  "pre-calibration values. Variance estimates may be ",
                  "affected. Inspect {.code output@calibration$replicate_converged}."
                )
              ),
              class = "surveywts_warning_replicate_calibration_failed"
            )
            TRUE
          }
        )
        if (failed) {
          replicate_converged[[repwt_col]] <- FALSE
        }
      }

      caldata$replicate_converged <- replicate_converged
    }
  }

  # ---- 16. Build history entry --------------------------------------------
  after_stats     <- .compute_weight_stats(new_weights)
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step        = length(current_history) + 1L,
    operation   = "calibrate_poststrat",
    weight_col  = if (inherits(data, "data.frame")) wt_name else data@variables$weights,
    call_str    = call_str,
    parameters  = list(
      variables              = strata_names,
      targets                = targets,
      type                   = type,
      targets_from_reference = targets_from_reference,
      reference_design       = reference_design
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = NULL  # non-iterative
  )

  # ---- 17. Build output ---------------------------------------------------
  if (inherits(data, "data.frame")) {
    out_df            <- plain_df
    out_df[[wt_name]] <- new_weights
    new_history       <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, wt_name, new_history)
  } else {
    # survey object -> same class (class preserved; weights + history + caldata)
    .update_survey_weights(data, new_weights, history_entry, caldata = caldata)
  }
}

# ---------------------------------------------------------------------------
# .validate_population_cells() -- private helper
# ---------------------------------------------------------------------------

# Validates the targets data frame for calibrate_poststrat().
#
# Checks (in order):
#   1. Required columns present (strata_names + "target")
#   2. No duplicate rows in targets (same cell combination > once)
#   3. Every cell in data has a matching row in targets
#   4. Every row in targets has observations in data
#   5. Target values are valid for the given type
#
# Arguments:
#   targets      : data.frame -- one row per cell
#   strata_names : character vector -- names of strata columns
#   data         : data.frame (plain) -- used for data<->targets matching
#   type         : "count" or "prop"
#
# Returns invisible(TRUE) on success. Throws typed errors on failure.
.validate_population_cells <- function(targets, strata_names, data, type) {
  # ---- 1. Required columns in targets -------------------------------------
  required_cols <- c(strata_names, "target")
  missing_cols  <- setdiff(required_cols, names(targets))
  if (length(missing_cols) > 0L) {
    col <- missing_cols[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg targets} is missing required column {.field {col}}."
        ),
        "i" = paste0(
          "{.arg targets} must have columns for each strata variable ",
          "({.and {.field {strata_names}}}) plus {.field target}."
        ),
        "v" = paste0(
          "Add the {.field {col}} column to {.arg targets}."
        )
      ),
      class = "surveywts_error_population_cell_missing"
    )
  }

  # ---- Build row keys (string representation of each cell) ----------------
  data_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(data[[v]])),
      sep = "//")
  )
  pop_keys <- do.call(
    paste,
    c(lapply(strata_names, function(v) as.character(targets[[v]])),
      sep = "//")
  )

  data_unique_keys <- unique(data_keys)

  # ---- 2. No duplicate rows in targets ------------------------------------
  dup_tab  <- table(pop_keys)
  dup_keys <- names(dup_tab)[dup_tab > 1L]
  if (length(dup_keys) > 0L) {
    cell_label <- dup_keys[[1L]]
    n          <- as.integer(dup_tab[[cell_label]])
    cli::cli_abort(
      c(
        "x" = paste0(
          "Population cell {.val {cell_label}} appears {n} times in ",
          "{.arg targets}."
        ),
        "i" = "Each cell combination must appear exactly once in {.arg targets}.",
        "v" = paste0(
          "Remove duplicate rows for {.val {cell_label}} from ",
          "{.arg targets} before calling {.fn calibrate_poststrat}."
        )
      ),
      class = "surveywts_error_population_cell_duplicate"
    )
  }

  # ---- 3. Every data cell has a matching targets row ----------------------
  data_missing <- setdiff(data_unique_keys, pop_keys)
  if (length(data_missing) > 0L) {
    cell_label <- data_missing[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "Cell {.val {cell_label}} is present in {.arg data} but has ",
          "no matching row in {.arg targets}."
        ),
        "i" = paste0(
          "Every cell combination in the data must appear in {.arg targets}."
        ),
        "v" = paste0(
          "Add a row for {.val {cell_label}} to {.arg targets}."
        )
      ),
      class = "surveywts_error_population_cell_missing"
    )
  }

  # ---- 4. Every targets row has observations in data ----------------------
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
          "Extra cells in {.arg targets} are not allowed -- they may ",
          "indicate a misspecified population."
        ),
        "v" = paste0(
          "Remove rows for {.val {cell_label}} from {.arg targets} ",
          "before calling {.fn calibrate_poststrat}."
        )
      ),
      class = "surveywts_error_population_cell_not_in_data"
    )
  }

  # ---- 5. Validate target values ------------------------------------------
  tgt <- targets[["target"]]

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
            "When {.code type = \"prop\"}, targets in {.arg targets} ",
            "must sum to 1.0 (within 1e-6 tolerance)."
          ),
          "v" = paste0(
            "Adjust the values in the {.field target} column of ",
            "{.arg targets}."
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
            "{.field target} column of {.arg targets}."
          )
        ),
        class = "surveywts_error_population_totals_invalid"
      )
    }
  }

  invisible(TRUE)
}
