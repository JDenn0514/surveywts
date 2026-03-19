# R/utils.R
#
# Shared internal helpers used by 2+ source files.
# All functions are unexported and .-prefixed.
#
# Contents:
#   .format_history_step()            — formats one history entry as display line
#                                       (moved here from classes.R in PR 4)
#   .get_weight_col_name()            — returns weight column name as character
#   .get_weight_vec()                 — extracts weight vector from any input class
#   .validate_weights()               — validates weight column (4 errors)
#   .validate_calibration_variables() — validates calibration/raking variables
#   .validate_population_marginals()  — validates named-list population targets
#   .compute_weight_stats()           — computes 11-key weight statistics
#   .make_history_entry()             — creates one weighting history entry
#   .make_weighted_df()               — internal weighted_df constructor
#   .update_survey_weights()          — updates survey object weights + history
#   .check_input_class()             — validates input class (4 callers)
#   .get_history()                   — extracts weighting history from any class
#   .calibrate_engine()               — dispatches to calibration algorithms
#
# NOTE (GAP #6 departure): .make_history_entry() adds a `step` parameter not
# in the spec signature. The step number must be computed by the calling
# function as length(current_history) + 1L. The spec signature omitted it but
# every history entry requires a step field (spec §IV.5).

# ============================================================================
# .format_history_step()
# ============================================================================

# Format one history entry as a single display line.
# Used by print.weighted_df() (classes.R) and the S7 print method
# for survey_nonprob (methods-print.R). Moved from classes.R in PR 4.
.format_history_step <- function(entry) {
  op <- entry$operation
  params <- entry$parameters
  ts <- entry$timestamp

  label <- switch(
    op,
    "raking" = {
      vars <- paste(params$variables, collapse = ", ")
      paste0("raking (margins: ", vars, ")")
    },
    "calibration" = {
      vars <- paste(params$variables, collapse = ", ")
      paste0("calibration (variables: ", vars, ")")
    },
    "poststratify" = {
      vars <- paste(params$variables, collapse = ", ")
      paste0("poststratify (strata: ", vars, ")")
    },
    "nonresponse_weighting_class" = {
      by <- params$by_variables
      if (is.null(by) || length(by) == 0L) {
        "weighting-class nonresponse"
      } else {
        paste0(
          "weighting-class nonresponse (by: ",
          paste(by, collapse = ", "),
          ")"
        )
      }
    },
    op # default: just the operation name
  )

  date_str <- format(ts, "%Y-%m-%d")
  paste0("#   Step ", entry$step, " [", date_str, "]: ", label)
}

# ============================================================================
# .get_weight_col_name()
# ============================================================================

# Returns the name of the weight column as a character(1).
# For a plain data.frame with weights_quo = NULL, returns ".weight" —
# this is the authoritative default per spec §II.d.
#
# Arguments:
#   x           : data.frame, weighted_df, survey_taylor, or survey_nonprob
#   weights_quo : quosure from rlang::enquo(weights) in the calling function
#
# Returns: character(1)
.get_weight_col_name <- function(x, weights_quo) {
  if (!rlang::quo_is_null(weights_quo)) {
    return(rlang::as_name(weights_quo))
  }

  if (inherits(x, "weighted_df")) {
    return(attr(x, "weight_col"))
  }

  if (S7::S7_inherits(x, surveycore::survey_taylor) ||
      S7::S7_inherits(x, surveycore::survey_nonprob)) {
    return(x@variables$weights)
  }

  # Plain data.frame with no weights argument: default column name
  ".weight"
}

# ============================================================================
# .get_weight_vec()
# ============================================================================

# Extracts the weight vector from any supported input class.
# For a plain data.frame with weights_quo = NULL, returns uniform weights
# (1 / nrow(x)) — these are the starting weights before calibration.
#
# Arguments:
#   x           : data.frame, weighted_df, survey_taylor, or survey_nonprob
#   weights_quo : quosure from rlang::enquo(weights) in the calling function
#
# Returns: numeric vector (length nrow(data))
.get_weight_vec <- function(x, weights_quo) {
  data_df <- if (inherits(x, "data.frame")) {
    x
  } else {
    x@data
  }

  if (!rlang::quo_is_null(weights_quo)) {
    col_name <- rlang::as_name(weights_quo)
    return(data_df[[col_name]])
  }

  if (inherits(x, "weighted_df")) {
    return(data_df[[attr(x, "weight_col")]])
  }

  if (S7::S7_inherits(x, surveycore::survey_taylor) ||
      S7::S7_inherits(x, surveycore::survey_nonprob)) {
    return(data_df[[x@variables$weights]])
  }

  # Plain data.frame with no weights: uniform starting weights
  rep(1 / nrow(data_df), nrow(data_df))
}

# ============================================================================
# .validate_weights()
# ============================================================================

# Validates that the weight column exists, is numeric, all positive, no NAs.
# Throws typed errors on failure. Returns invisible(TRUE) on success.
#
# Arguments:
#   data       : data.frame (plain; extract @data before calling for S7 objects)
#   weight_col : character(1) — name of the weight column in data
.validate_weights <- function(data, weight_col) {
  if (!weight_col %in% names(data)) {
    cli::cli_abort(
      c(
        "x" = "Weight column {.field {weight_col}} not found in {.arg data}.",
        "i" = "Available columns: {.and {.field {names(data)}}}.",
        "v" = paste0(
          "Pass the column name as a bare name, ",
          "e.g., {.code weights = wt_col}."
        )
      ),
      class = "surveywts_error_weights_not_found"
    )
  }

  wt_col <- data[[weight_col]]

  if (!is.numeric(wt_col)) {
    cli::cli_abort(
      c(
        "x" = "Weight column {.field {weight_col}} must be numeric.",
        "i" = "Got {.cls {class(wt_col)[[1]]}}.",
        "v" = paste0(
          "Use {.code as.numeric({.field {weight_col}})} to convert."
        )
      ),
      class = "surveywts_error_weights_not_numeric"
    )
  }

  n_nonpos <- sum(wt_col <= 0, na.rm = TRUE)
  if (n_nonpos > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Weight column {.field {weight_col}} contains ",
          "{n_nonpos} non-positive value(s)."
        ),
        "i" = "All starting weights must be strictly positive (> 0).",
        "v" = "Remove or replace non-positive weights before proceeding."
      ),
      class = "surveywts_error_weights_nonpositive"
    )
  }

  n_na <- sum(is.na(wt_col))
  if (n_na > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Weight column {.field {weight_col}} contains ",
          "{n_na} NA value(s)."
        ),
        "i" = "Weights must be fully observed.",
        "v" = "Remove rows with missing weights before proceeding."
      ),
      class = "surveywts_error_weights_na"
    )
  }

  invisible(TRUE)
}

# ============================================================================
# .validate_calibration_variables()
# ============================================================================

# Validates that calibration/raking variables are categorical (character or
# factor) and contain no NAs. Used by calibrate() and rake().
#
# Arguments:
#   data           : data.frame
#   variable_names : character vector of column names to check
#   context        : character(1) — "Calibration" or "Raking";
#                    appears in error messages to disambiguate the caller
#
# Returns invisible(TRUE) on success. Throws on first failing variable.
.validate_calibration_variables <- function(data, variable_names, context) {
  for (var in variable_names) {
    col <- data[[var]]

    if (!is.character(col) && !is.factor(col)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{context} variable {.field {var}} is ",
            "{.cls {class(col)[[1]]}}."
          ),
          "i" = paste0(
            "Phase 0 supports categorical (character or factor) ",
            "variables only."
          ),
          "v" = paste0(
            "Convert to factor or character. ",
            "Continuous auxiliary variable calibration is not ",
            "supported in Phase 0."
          )
        ),
        class = "surveywts_error_variable_not_categorical"
      )
    }

    n_na <- sum(is.na(col))
    if (n_na > 0L) {
      fn_name <- if (context == "Calibration") "calibrate" else "rake"
      cli::cli_abort(
        c(
          "x" = paste0(
            "{context} variable {.field {var}} contains ",
            "{n_na} NA value(s)."
          ),
          "i" = paste0(
            "NA values in calibration variables are not allowed."
          ),
          "v" = paste0(
            "Remove or impute NA values in {.field {var}} before ",
            "calling {.fn {fn_name}}."
          )
        ),
        class = "surveywts_error_variable_has_na"
      )
    }
  }

  invisible(TRUE)
}

# ============================================================================
# .validate_population_marginals()
# ============================================================================

# Validates the named-list population targets for calibrate() and rake().
# Called after prop→count conversion in the calling function; targets are
# in count form when this function is invoked.
#
# Arguments:
#   population     : named list. Each element is a named numeric vector OR
#                    a data.frame with $level and $target columns. Names of
#                    the list are variable names.
#   variable_names : character vector of expected variable names
#   data           : data.frame (plain) — used to check that data levels are
#                    covered by population targets
#   type           : "prop" or "count" — used to validate target values
#   target_name    : character(1), either "population" (calibrate) or
#                    "margins" (rake). Determines message wording.
#                    NOTE: departure from spec §XI signature (added for
#                    consistent error messages across calibrate and rake).
#
# Returns invisible(TRUE) on success. Throws on first error found.
.validate_population_marginals <- function(
  population,
  variable_names,
  data,
  type,
  target_name = "population"
) {
  noun <- if (target_name == "margins") "margin" else "variable"

  for (var in variable_names) {
    # Extract targets as a named numeric vector
    elem <- population[[var]]
    if (is.data.frame(elem)) {
      targets <- stats::setNames(as.numeric(elem$target), as.character(elem$level)) # nocov
    } else {
      targets <- elem
    }

    pop_levels <- names(targets)
    data_levels <- unique(as.character(data[[var]]))

    # Data levels absent from population
    missing_in_pop <- setdiff(data_levels, pop_levels)
    if (length(missing_in_pop) > 0L) {
      level <- missing_in_pop[[1L]]
      cli::cli_abort(
        c(
          "x" = paste0(
            "Level {.val {level}} of {noun} {.field {var}} is present ",
            "in {.arg data} but not in {.arg {target_name}}."
          ),
          "i" = paste0(
            "Every level in the data must have a corresponding ",
            "population target."
          ),
          "v" = paste0(
            "Add {.val {level}} to the {.field {var}} entry in ",
            "{.arg {target_name}}."
          )
        ),
        class = "surveywts_error_population_level_missing"
      )
    }

    # Population levels absent from data
    extra_in_pop <- setdiff(pop_levels, data_levels)
    if (length(extra_in_pop) > 0L) {
      level <- extra_in_pop[[1L]]
      cli::cli_abort(
        c(
          "x" = paste0(
            "Level {.val {level}} of {noun} {.field {var}} is present ",
            "in {.arg {target_name}} but not in {.arg data}."
          ),
          "i" = paste0(
            "Population targets for levels absent from the sample ",
            "are undefined."
          ),
          "v" = paste0(
            "Remove {.val {level}} from the {.field {var}} entry in ",
            "{.arg {target_name}}."
          )
        ),
        class = "surveywts_error_population_level_extra"
      )
    }

    # Validate target values
    if (type == "prop") {
      sum_val <- sum(targets)
      tol <- 1e-6
      if (abs(sum_val - 1.0) > tol) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "Population totals for {.field {var}} sum to ",
              "{sum_val}, not 1.0."
            ),
            "i" = paste0(
              "When {.code type = \"prop\"}, each variable's targets ",
              "must sum to 1.0 (within 1e-6 tolerance)."
            ),
            "v" = paste0(
              "Adjust the values in ",
              "{.code {target_name}${.field {var}}}."
            )
          ),
          class = "surveywts_error_population_totals_invalid"
        )
      }
    } else {
      # type = "count"
      n_nonpos <- sum(targets <= 0, na.rm = TRUE)
      if (n_nonpos > 0L) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "Population targets for {.field {var}} contain ",
              "{n_nonpos} non-positive value(s)."
            ),
            "i" = paste0(
              "When {.code type = \"count\"}, all targets must be ",
              "strictly positive (> 0)."
            ),
            "v" = paste0(
              "Remove or correct non-positive entries in ",
              "{.code {target_name}${.field {var}}}."
            )
          ),
          class = "surveywts_error_population_totals_invalid"
        )
      }
    }
  }

  invisible(TRUE)
}

# ============================================================================
# .compute_weight_stats()
# ============================================================================

# Computes summary statistics for a weight vector.
# Used by .make_history_entry() and summarize_weights().
#
# Arguments:
#   weights_vec : numeric vector (all positive, no NAs assumed by caller)
#
# Returns: named list with 11 keys: n, n_positive, n_zero, mean, cv, min,
#          p25, p50, p75, max, ess
.compute_weight_stats <- function(weights_vec) {
  n <- length(weights_vec)
  n_positive <- sum(weights_vec > 0)
  n_zero <- sum(weights_vec == 0)
  w_mean <- mean(weights_vec)
  w_cv <- if (w_mean > 0) stats::sd(weights_vec) / w_mean else NA_real_
  w_min <- min(weights_vec)
  w_max <- max(weights_vec)
  qs <- stats::quantile(weights_vec, probs = c(0.25, 0.50, 0.75), names = FALSE)
  w_ess <- sum(weights_vec)^2 / sum(weights_vec^2)

  list(
    n = n,
    n_positive = n_positive,
    n_zero = n_zero,
    mean = w_mean,
    cv = w_cv,
    min = w_min,
    p25 = qs[[1L]],
    p50 = qs[[2L]],
    p75 = qs[[3L]],
    max = w_max,
    ess = w_ess
  )
}

# ============================================================================
# .make_history_entry()
# ============================================================================

# Creates one weighting history entry per spec §IV.5.
#
# Arguments:
#   step         : integer — position in the history (length(history) + 1L)
#   operation    : character(1) — "calibration", "raking", "poststratify", or
#                  "nonresponse_weighting_class"
#   call_str     : character(1) — deparsed call from deparse(match.call())
#   parameters   : named list — function-specific resolved parameters
#   before_stats : named list from .compute_weight_stats() (before calibration)
#   after_stats  : named list from .compute_weight_stats() (after calibration)
#   convergence  : named list or NULL; NULL for non-iterative operations
#
# Returns: named list matching spec §IV.5 history entry format.
#
# NOTE: `step` is not in the spec §XI signature but is required per spec §IV.5.
# The calling function computes step = length(current_history) + 1L.
.make_history_entry <- function(
  step,
  operation,
  call_str,
  parameters,
  before_stats,
  after_stats,
  convergence = NULL
) {
  list(
    step = as.integer(step),
    operation = operation,
    timestamp = Sys.time(),
    call = call_str,
    parameters = parameters,
    weight_stats = list(
      before = before_stats,
      after = after_stats
    ),
    convergence = convergence,
    package_version = as.character(utils::packageVersion("surveywts"))
  )
}

# ============================================================================
# .make_weighted_df()
# ============================================================================

# Internal constructor for weighted_df. Sets class vector and attributes.
# Errors if weight_col is not a column name in data.
#
# Arguments:
#   data       : data.frame (must already contain weight_col)
#   weight_col : character(1) — name of the weight column
#   history    : list of history entries to attach (default: empty list)
#
# Returns: weighted_df
.make_weighted_df <- function(data, weight_col, history = list()) {
  # nocov start
  if (!weight_col %in% names(data)) {
    cli::cli_abort(
      c(
        "x" = "Internal error: weight column {.field {weight_col}} not in data.",
        "i" = "This is a bug in surveywts. Please report it."
      ),
      class = "surveywts_error_internal"
    )
  }
  # nocov end

  structure(
    tibble::as_tibble(data),
    class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
    weight_col = weight_col,
    weighting_history = history
  )
}

# ============================================================================
# .update_survey_weights()
# ============================================================================

# Updates a survey object's weight column and appends a history entry to
# @metadata@weighting_history. Returns a new survey object of the SAME class
# as the input (no class promotion). Used by calibrate(), rake(),
# poststratify(), and adjust_nonresponse().
#
# Arguments:
#   design          : survey_taylor or survey_nonprob
#   new_weights_vec : numeric vector (length = nrow(design@data))
#   history_entry   : list from .make_history_entry()
#
# Returns: survey object of the same class as input
.update_survey_weights <- function(design, new_weights_vec, history_entry) {
  weight_col <- design@variables$weights

  # Update data
  updated_data <- design@data
  updated_data[[weight_col]] <- new_weights_vec
  design@data <- updated_data

  # Append history entry (must go through intermediate variable for S7 nested
  # property assignment)
  meta <- design@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  design@metadata <- meta

  design
}


# ============================================================================
# .check_input_class()
# ============================================================================

# Validates that `data` is a supported input class for calibration/weighting
# functions. Used by calibrate(), rake(), poststratify(), and
# adjust_nonresponse().
#
# Arguments:
#   data : object passed as the `data` argument to a calibration function
#
# Returns: invisible(TRUE) on success. Throws on unsupported class.
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
    S7::S7_inherits(data, surveycore::survey_base)

  if (!is_supported) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} must be a data frame or a supported survey design object.",
        "i" = "Got {.cls {cls}}.",
        "v" = "See package documentation for supported input types."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }
}

# ============================================================================
# .get_history()
# ============================================================================

# Extracts weighting history from any supported input class.
# Used by calibrate(), rake(), poststratify(), and adjust_nonresponse().
#
# Arguments:
#   x : data.frame, weighted_df, survey_taylor, or survey_nonprob
#
# Returns: list (possibly empty) of history entries.
.get_history <- function(x) {
  if (inherits(x, "weighted_df")) {
    wh <- attr(x, "weighting_history")
    if (is.null(wh)) list() else wh
  } else if (S7::S7_inherits(x, surveycore::survey_base)) {
    wh <- x@metadata@weighting_history
    if (is.null(wh)) list() else wh
  } else {
    list()
  }
}

# ============================================================================
# .calibrate_engine()
# ============================================================================

# The shared computation engine used by calibrate(), rake(), and
# poststratify(). Takes only plain data (no S7/S3 dispatch). Returns a
# named list with the calibrated weight vector and convergence information.
#
# Arguments:
#   data_df          : plain data.frame
#   weights_vec      : numeric vector (length = nrow(data_df)),
#                      all positive, no NAs
#   calibration_spec : list describing the calibration problem (see below)
#   method           : character(1) — "linear", "logit", "ipf", "anesrake",
#                      or "poststratify"
#   control          : list with at least $maxit; method-appropriate defaults
#                      already applied by the calling function
#
# calibration_spec format:
#   list(
#     type      = <method string — same as method argument>,
#     variables = list(  # for "linear"/"logit"/"ipf"/"anesrake"
#       list(col = "age_group", targets = c("18-34" = 420, ...)),  # counts
#       ...
#     ),
#     cells     = list(  # for "poststratify" only
#       list(indices = <integer vector>, target = <count>),
#       ...
#     ),
#     total_n   = <sum of starting weights; for reference>
#   )
#
# Targets in calibration_spec must be in COUNT form (not proportions).
# The calling function converts prop→count via prop * sum(weights_vec).
#
# Returns: list(
#   weights     = <numeric vector of calibrated weights>,
#   convergence = list(
#     converged  = <logical>,
#     iterations = <integer>,
#     max_error  = <numeric>,
#     tolerance  = <numeric>
#   )
# )
# For "poststratify", convergence = NULL (non-iterative).
#
# Throws surveywts_error_calibration_not_converged on failure.
#
# NOTE (GAP #6): calibration_spec format may be refined during implementation
# of PRs 5–7. Document departures here.
.calibrate_engine <- function(data_df, weights_vec, calibration_spec, method, control) {
  # Handle maxit = 0: algorithm never runs
  if (isTRUE(control$maxit == 0L) || isTRUE(control$maxit == 0)) {
    .throw_not_converged_zero_maxit(method, control)
  }

  type <- calibration_spec$type
  vars_spec <- calibration_spec$variables

  # ---- Linear or logit calibration (via survey::calibrate()) ---------------
  if (type %in% c("linear", "logit")) {
    var_names <- vapply(vars_spec, function(v) v$col, character(1))

    # Use R default treatment contrasts (k-1 dummies per factor + intercept).
    # This is mathematically equivalent to full indicator encoding without
    # intercept, and is the natural interface for survey::calibrate().
    for (v in vars_spec) {
      col_name <- v$col
      lvls <- names(v$targets)
      data_df[[col_name]] <- factor(data_df[[col_name]], levels = lvls)
    }

    # Check if all variables have only 1 level — trivially calibrated
    all_single <- all(vapply(
      vars_spec, function(v) length(v$targets) == 1L, logical(1)
    ))
    if (all_single) {
      return(list(
        weights = weights_vec,
        convergence = list(
          converged = TRUE,
          iterations = 1L,
          max_error = 0,
          tolerance = control$epsilon
        )
      ))
    }

    # Build formula with intercept: ~var1 + var2
    # Only include variables with 2+ levels (single-level factors cannot
    # generate dummy columns and are handled by the intercept constraint).
    fml_vars <- var_names[vapply(
      vars_spec, function(v) length(v$targets) >= 2L, logical(1)
    )]
    fml <- stats::as.formula(
      paste("~", paste(fml_vars, collapse = " + "))
    )

    # Build named population totals vector matching model.matrix() column names
    mm <- stats::model.matrix(fml, data = data_df)
    total_w <- sum(weights_vec)

    # Construct population totals: intercept = population total (sum of any
    # variable's targets — they should all sum to the same total for marginal
    # calibration), then for each variable's non-reference levels, the target.
    pop_total <- sum(vars_spec[[1]]$targets)

    pop_totals <- stats::setNames(numeric(ncol(mm)), colnames(mm))
    pop_totals["(Intercept)"] <- pop_total

    for (v in vars_spec) {
      if (length(v$targets) < 2L) next
      col_name <- v$col
      lvls <- names(v$targets)
      # Reference level is first; columns in model.matrix start from 2nd level
      for (lev in lvls[-1L]) {
        col_nm <- paste0(col_name, lev)
        if (col_nm %in% names(pop_totals)) {
          pop_totals[col_nm] <- v$targets[[lev]]
        }
      }
    }

    # Add temporary weight column
    data_df$.wt_tmp <- weights_vec
    svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)

    calfun <- if (type == "linear") survey::cal.linear else survey::cal.logit

    if (type == "linear") {
      # Linear: closed-form, no convergence check needed
      cal_result <- survey::calibrate(
        svy_tmp,
        formula = fml,
        population = pop_totals,
        calfun = calfun,
        maxit = control$maxit,
        epsilon = control$epsilon
      )
      new_weights <- as.numeric(stats::weights(cal_result))

      return(list(
        weights = new_weights,
        convergence = list(
          converged = TRUE,
          iterations = 1L,
          max_error = 0,
          tolerance = control$epsilon
        )
      ))
    } else {
      # Logit: intercept non-convergence warning and re-throw as typed error
      # cal.logit requires finite bounds; use wide bounds matching vendored
      # behavior (lower ≈ 0, upper ≈ Inf)
      cal_result <- tryCatch(
        withCallingHandlers(
          survey::calibrate(
            svy_tmp,
            formula = fml,
            population = pop_totals,
            calfun = calfun,
            bounds = c(1e-6, 1e6),
            maxit = control$maxit,
            epsilon = control$epsilon
          ),
          warning = function(w) {
            msg <- conditionMessage(w)
            if (grepl("converge", msg, ignore.case = TRUE)) {
              cli::cli_abort(
                c(
                  "x" = paste0(
                    "Calibration did not converge after ",
                    "{control$maxit} iterations."
                  ),
                  "i" = "survey::calibrate() reported: {msg}",
                  "v" = paste0(
                    "Increase {.code control$maxit}, relax ",
                    "{.code control$epsilon}, or verify population totals ",
                    "are consistent with the sample."
                  )
                ),
                class = "surveywts_error_calibration_not_converged"
              )
            }
            # Muffle benign rescaling warnings from grake()
            if (grepl("rescaling", msg, ignore.case = TRUE)) {
              tryInvokeRestart("muffleWarning")
            }
          }
        ),
        error = function(e) {
          if (inherits(e, "surveywts_error_calibration_not_converged")) {
            stop(e)
          }
          # Re-throw unexpected errors
          stop(e) # nocov
        }
      )

      new_weights <- as.numeric(stats::weights(cal_result))

      return(list(
        weights = new_weights,
        convergence = list(
          converged = TRUE,
          iterations = NA_integer_,
          max_error = 0,
          tolerance = control$epsilon
        )
      ))
    }
  }

  # ---- IPF (via survey::rake()) -------------------------------------------
  if (type == "ipf") {
    var_names <- vapply(vars_spec, function(v) v$col, character(1))

    # Build margin formulas and population data frames
    sample_margins <- lapply(var_names, function(v) {
      stats::as.formula(paste("~", v))
    })

    population_margins <- lapply(vars_spec, function(v) {
      pop_df <- data.frame(
        level = names(v$targets),
        Freq = as.numeric(v$targets),
        stringsAsFactors = FALSE
      )
      names(pop_df)[1] <- v$col
      pop_df
    })

    # Add temporary weight column
    data_df$.wt_tmp <- weights_vec
    svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)

    raked <- tryCatch(
      withCallingHandlers(
        survey::rake(
          svy_tmp,
          sample.margins = sample_margins,
          population.margins = population_margins,
          control = list(
            maxit = as.integer(control$maxit),
            epsilon = control$epsilon
          )
        ),
        warning = function(w) {
          msg <- conditionMessage(w)
          if (grepl("converge", msg, ignore.case = TRUE)) {
            cli::cli_abort(
              c(
                "x" = paste0(
                  "Raking did not converge after ",
                  "{control$maxit} full sweeps."
                ),
                "i" = "survey::rake() reported: {msg}",
                "v" = paste0(
                  "Increase {.code control$maxit}, relax ",
                  "{.code control$epsilon}, or verify margin totals ",
                  "are consistent with the sample."
                )
              ),
              class = "surveywts_error_calibration_not_converged"
            )
          }
        }
      ),
      error = function(e) {
        if (inherits(e, "surveywts_error_calibration_not_converged")) {
          stop(e)
        }
        stop(e) # nocov
      }
    )

    new_weights <- as.numeric(stats::weights(raked))

    return(list(
      weights = new_weights,
      convergence = list(
        converged = TRUE,
        iterations = NA_integer_,
        max_error = 0,
        tolerance = control$epsilon
      )
    ))
  }

  # ---- Anesrake (via anesrake::anesrake()) ---------------------------------
  if (type == "anesrake") {
    var_names <- vapply(vars_spec, function(v) v$col, character(1))

    # Build named list of target vectors (proportions for anesrake)
    targets_list <- lapply(vars_spec, function(v) {
      tgt <- v$targets
      tgt / sum(tgt)  # anesrake expects proportions
    })
    names(targets_list) <- var_names

    # Ensure data columns are factors with correct levels
    for (v in vars_spec) {
      lvls <- names(v$targets)
      data_df[[v$col]] <- factor(data_df[[v$col]], levels = lvls)
    }

    # Create synthetic caseid
    data_df$.anesrake_id <- seq_len(nrow(data_df))

    # anesrake::anesrake() default cap is 5; NULL is not accepted
    anesrake_cap <- calibration_spec$cap %||% 5

    # anesrake uses print() for status messages; suppress the console output.
    # When data is already calibrated, anesrake::selecthighestpcts() throws
    # an error "No variables are off by more than ...". Catch that and treat
    # as already-calibrated.
    anesrake_error <- NULL
    utils::capture.output(
      result <- tryCatch(
        suppressWarnings(
          anesrake::anesrake(
            inputter     = targets_list,
            dataframe    = data_df,
            caseid       = data_df$.anesrake_id,
            weightvec    = weights_vec,
            choosemethod = control$variable_select,
            cap          = anesrake_cap,
            pctlim       = control$improvement,
            nlim         = as.integer(control$min_cell_n),
            iterate      = TRUE,
            maxit        = as.integer(control$maxit),
            type         = "pctlim",
            force1       = FALSE
          )
        ),
        error = function(e) {
          if (grepl("No variables are off", conditionMessage(e),
                    ignore.case = TRUE)) {
            anesrake_error <<- "already_calibrated"
            NULL
          } else {
            stop(e) # nocov
          }
        }
      )
    )

    # Already-calibrated: anesrake threw an error because no variables
    # exceeded the improvement threshold
    if (identical(anesrake_error, "already_calibrated")) {
      cli::cli_inform(
        c("i" = paste0(
          "Raking converged in 1 sweep: all variables already met their ",
          "margins. Weights were not adjusted."
        )),
        class = "surveywts_message_already_calibrated"
      )
      return(list(
        weights = weights_vec,
        convergence = list(
          converged  = TRUE,
          iterations = 1L,
          max_error  = 0,
          tolerance  = control$improvement
        )
      ))
    }

    # anesrake::anesrake()$converge is a character string:
    #   "Complete convergence was achieved" — fully converged
    #   "Results are stable, but do not perfectly match..." — partial,
    #     treated as converged (matches old vendored behaviour)
    #   Other strings (e.g. containing "Did Not Converge") — failure
    converged <- grepl(
      "Complete convergence|Results are stable",
      result$converge, ignore.case = TRUE
    )

    if (!converged) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Raking did not converge after ",
            "{control$maxit} full sweeps."
          ),
          "i" = paste0(
            "anesrake::anesrake() reported: {result$converge}"
          ),
          "v" = paste0(
            "Increase {.code control$maxit} or relax ",
            "{.code control$improvement} in the {.arg control} list."
          )
        ),
        class = "surveywts_error_calibration_not_converged"
      )
    }

    if (result$iterations == 0L) {
      cli::cli_inform(
        c("i" = paste0(
          "Raking converged in 1 sweep: all variables already met their ",
          "margins. Weights were not adjusted."
        )),
        class = "surveywts_message_already_calibrated"
      )
    }

    new_weights <- as.numeric(result$weightvec)

    return(list(
      weights = new_weights,
      convergence = list(
        converged  = converged,
        iterations = as.integer(result$iterations),
        max_error  = 0,
        tolerance  = control$improvement
      )
    ))
  }

  # ---- Post-stratification (via survey::postStratify()) --------------------
  if (type == "poststratify") {
    strata_names <- calibration_spec$strata_names
    pop_input <- calibration_spec$population

    # Build formula from strata_names
    ps_fml <- stats::as.formula(
      paste("~", paste(strata_names, collapse = " + "))
    )

    # Build population data frame: rename "target" -> "Freq"
    pop_df <- pop_input
    names(pop_df)[names(pop_df) == "target"] <- "Freq"

    # Add temporary weight column
    data_df$.wt_tmp <- weights_vec
    svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)

    ps_result <- survey::postStratify(
      svy_tmp,
      strata = ps_fml,
      population = pop_df
    )
    new_weights <- as.numeric(stats::weights(ps_result))

    # Poststratification is non-iterative: convergence = NULL per spec §IV.5
    return(list(
      weights = new_weights,
      convergence = NULL
    ))
  }

  # nocov start
  cli::cli_abort(
    c(
      "x" = "Internal error: unknown calibration type {.val {type}}.",
      "i" = "This is a bug in surveywts. Please report it."
    ),
    class = "surveywts_error_internal"
  )
  # nocov end
}

# ---- Internal helpers for .calibrate_engine() ----------------------------

# Throw surveywts_error_calibration_not_converged for the maxit = 0 case.
# context: the calibration method (linear, logit, ipf, anesrake, poststratify)
.throw_not_converged_zero_maxit <- function(method, control) {
  if (method %in% c("linear", "logit")) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Calibration did not converge after 0 iterations."
        ),
        "i" = "Setting {.code control$maxit = 0} means no calibration is attempted.",
        "v" = paste0(
          "Set {.code control$maxit} to a positive integer ",
          "(default: 50)."
        )
      ),
      class = "surveywts_error_calibration_not_converged"
    )
  } else {
    cli::cli_abort(
      c(
        "x" = "Raking did not converge after 0 iterations.",
        "i" = "Setting {.code control$maxit = 0} means no raking is attempted.",
        "v" = paste0(
          "Set {.code control$maxit} to a positive integer."
        )
      ),
      class = "surveywts_error_calibration_not_converged"
    )
  }
}

