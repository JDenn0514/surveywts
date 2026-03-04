# R/07-utils.R
#
# Shared internal helpers used by 2+ source files.
# All functions are unexported and .-prefixed.
#
# Contents:
#   .format_history_step()            — formats one history entry as display line
#                                       (moved here from 00-classes.R in PR 4)
#   .get_weight_col_name()            — returns weight column name as character
#   .get_weight_vec()                 — extracts weight vector from any input class
#   .validate_weights()               — validates weight column (4 errors)
#   .validate_calibration_variables() — validates calibration/raking variables
#   .validate_population_marginals()  — validates named-list population targets
#   .compute_weight_stats()           — computes 11-key weight statistics
#   .make_history_entry()             — creates one weighting history entry
#   .make_weighted_df()               — internal weighted_df constructor
#   .update_survey_weights()          — updates survey object weights + history
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
# Used by print.weighted_df() (00-classes.R) and the S7 print method
# for survey_calibrated (methods-print.R). Moved from 00-classes.R in PR 4.
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
#   x           : data.frame, weighted_df, survey_taylor, or survey_calibrated
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
      S7::S7_inherits(x, surveycore::survey_calibrated)) {
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
#   x           : data.frame, weighted_df, survey_taylor, or survey_calibrated
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
      S7::S7_inherits(x, surveycore::survey_calibrated)) {
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
      class = "surveyweights_error_weights_not_found"
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
      class = "surveyweights_error_weights_not_numeric"
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
      class = "surveyweights_error_weights_nonpositive"
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
      class = "surveyweights_error_weights_na"
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
        class = "surveyweights_error_variable_not_categorical"
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
        class = "surveyweights_error_variable_has_na"
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
      targets <- stats::setNames(as.numeric(elem$target), as.character(elem$level))
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
        class = "surveyweights_error_population_level_missing"
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
        class = "surveyweights_error_population_level_extra"
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
          class = "surveyweights_error_population_totals_invalid"
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
          class = "surveyweights_error_population_totals_invalid"
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
    package_version = as.character(utils::packageVersion("surveyweights"))
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
  if (!weight_col %in% names(data)) {
    cli::cli_abort(
      c(
        "x" = "Internal error: weight column {.field {weight_col}} not in data.",
        "i" = "This is a bug in surveyweights. Please report it."
      ),
      class = "surveyweights_error_internal"
    )
  }

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
# as the input (no class promotion — only adjust_nonresponse() uses this).
# Calibration functions use .new_survey_calibrated() for class promotion.
#
# Arguments:
#   design          : survey_taylor or survey_calibrated
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
# Throws surveyweights_error_calibration_not_converged on failure.
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

  # ---- Linear or logit calibration (GREG) ----------------------------------
  if (type %in% c("linear", "logit")) {
    mm <- .build_model_matrix(data_df, vars_spec)
    pop <- unlist(lapply(vars_spec, function(v) v$targets))

    if (type == "linear") {
      g <- .greg_linear(mm, weights_vec, pop)
      new_weights <- weights_vec * g

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
      # logit
      g <- .greg_logit(
        mm, weights_vec, pop,
        epsilon = control$epsilon,
        maxit = as.integer(control$maxit)
      )

      if (!is.null(attr(g, "failed"))) {
        .throw_not_converged(
          method = "logit",
          context = "calibrate",
          control = control,
          max_error = attr(g, "failed")
        )
      }

      new_weights <- weights_vec * g
      return(list(
        weights = new_weights,
        convergence = list(
          converged = TRUE,
          iterations = attr(g, "iterations") %||% NA_integer_,
          max_error = attr(g, "max_error") %||% 0,
          tolerance = control$epsilon
        )
      ))
    }
  }

  # ---- IPF (survey-style raking) -------------------------------------------
  if (type == "ipf") {
    margins <- lapply(vars_spec, function(v) {
      list(
        levels = as.character(data_df[[v$col]]),
        targets = v$targets
      )
    })

    result <- .ipf_calibrate(
      margins = margins,
      ww = weights_vec,
      epsilon = control$epsilon,
      maxit = as.integer(control$maxit)
    )

    if (!result$converged) {
      .throw_not_converged(
        method = "ipf",
        context = "rake_survey",
        control = control,
        max_error = result$max_error
      )
    }

    return(list(
      weights = result$weights,
      convergence = list(
        converged = TRUE,
        iterations = result$iterations,
        max_error = result$max_error,
        tolerance = control$epsilon
      )
    ))
  }

  # ---- Post-stratification (exact single-pass) -----------------------------
  if (type == "poststratify") {
    cells <- calibration_spec$cells
    new_weights <- weights_vec

    for (cell in cells) {
      idx <- cell$indices
      n_hat_h <- sum(weights_vec[idx])
      # empty_stratum is detected before engine call; defensive check
      if (n_hat_h <= 0) next
      new_weights[idx] <- weights_vec[idx] * (cell$target / n_hat_h)
    }

    # Poststratification is non-iterative: convergence = NULL per spec §IV.5
    return(list(
      weights = new_weights,
      convergence = NULL
    ))
  }

  cli::cli_abort(
    c(
      "x" = "Internal error: unknown calibration type {.val {type}}.",
      "i" = "This is a bug in surveyweights. Please report it."
    ),
    class = "surveyweights_error_internal"
  )
}

# ---- Internal helpers for .calibrate_engine() ----------------------------

# Build a model matrix of 0/1 indicators from vars_spec.
# Each element of vars_spec: list(col = <column name>, targets = <named vector>)
.build_model_matrix <- function(data_df, vars_spec) {
  cols <- lapply(vars_spec, function(v) {
    levels_vec <- as.character(data_df[[v$col]])
    all_levels <- names(v$targets)
    sapply(all_levels, function(lev) as.integer(levels_vec == lev))
  })
  do.call(cbind, cols)
}

# Throw surveyweights_error_calibration_not_converged for the maxit = 0 case.
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
      class = "surveyweights_error_calibration_not_converged"
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
      class = "surveyweights_error_calibration_not_converged"
    )
  }
}

# Throw surveyweights_error_calibration_not_converged on actual non-convergence.
# context: "calibrate", "rake_survey", "rake_anesrake"
.throw_not_converged <- function(method, context, control, max_error) {
  # Round to 6 sig figs before embedding in the message to avoid platform-
  # specific floating-point representation differences (macOS vs Linux).
  max_error <- signif(max_error, 6)
  if (context == "calibrate") {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Calibration did not converge after ",
          "{control$maxit} iterations."
        ),
        "i" = paste0(
          "Maximum calibration error: {max_error} ",
          "(tolerance: {control$epsilon})."
        ),
        "v" = paste0(
          "Increase {.code control$maxit}, relax ",
          "{.code control$epsilon}, or verify population totals ",
          "are consistent with the sample."
        )
      ),
      class = "surveyweights_error_calibration_not_converged"
    )
  } else if (context == "rake_survey") {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Raking did not converge after ",
          "{control$maxit} full sweeps."
        ),
        "i" = paste0(
          "Maximum margin error: {max_error} ",
          "(tolerance: {control$epsilon})."
        ),
        "v" = paste0(
          "Increase {.code control$maxit}, relax ",
          "{.code control$epsilon}, or verify margin totals ",
          "are consistent with the sample."
        )
      ),
      class = "surveyweights_error_calibration_not_converged"
    )
  } else if (context == "rake_anesrake") {
    improvement_pct <- max_error
    cli::cli_abort(
      c(
        "x" = paste0(
          "Raking did not converge after ",
          "{control$maxit} full sweeps."
        ),
        "i" = paste0(
          "Chi-square improvement in the final sweep: ",
          "{improvement_pct}% (threshold: {control$improvement}%)."
        ),
        "v" = paste0(
          "Increase {.code control$maxit} or relax ",
          "{.code control$improvement} in the {.arg control} list."
        )
      ),
      class = "surveyweights_error_calibration_not_converged"
    )
  }
}

# Null-coalescing operator (not exported from rlang in all versions)
`%||%` <- function(x, y) if (!is.null(x)) x else y
