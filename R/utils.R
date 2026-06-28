# R/utils.R
#
# Shared internal helpers used by 2+ source files.
# All functions are unexported and .-prefixed.
#
# Contents:
#   .format_history_step()            — formats one history entry as display line
#                                       (moved here from classes.R in PR 4)
#   .get_weight_col_name()            — returns weight column name as character
#   .validate_wt_name()              — validates wt_name argument (scalar string)
#   .validate_reference_design()      — validates reference_design argument (survey_taylor or NULL)
#   .get_weight_vec()                 — extracts weight vector from any input class
#   .validate_weights()               — validates weight column (4 errors)
#   .validate_calibration_variables() — validates calibration/raking variables
#   .validate_population_marginals()  — validates named-list population targets
#   .compute_weight_stats()           — computes 11-key weight statistics
#   .make_history_entry()             — creates one weighting history entry
#   .update_survey_weights()          — updates survey object weights + history
#   .check_input_class()             — validates input class (survey_base only)
#   .get_history()                   — extracts weighting history from survey_base
#   .validate_formula()               — validates one-sided formula object
#   .validate_formula_variables()     — validates formula variables exist in data
#   .trim_weights_internal()          — clip-and-redistribute primitive for trim_weights()
#   .to_svyrep_design()               — converts survey_replicate to svyrep.design
#
# NOTE (GAP #6 departure): .make_history_entry() adds a `step` parameter not
# in the spec signature. The step number must be computed by the calling
# function as length(current_history) + 1L. The spec signature omitted it but
# every history entry requires a step field (spec §IV.5).

# ============================================================================
# .format_history_step()
# ============================================================================

# Format one history entry as a single display line.
# Used by the S7 print method for survey_nonprob (methods-print.R).
.format_history_step <- function(entry) {
  op     <- entry$operation
  params <- entry$parameters
  ts     <- entry$timestamp

  label <- switch(
    op,
    "calibrate_rake" = ,
    "raking" = {
      vars <- paste(params$variables, collapse = ", ")
      paste0("raking (targets: ", vars, ")")
    },
    "calibrate_linear" = ,
    "calibrate_logit" = {
      vars <- paste(params$variables, collapse = ", ")
      paste0(op, " (variables: ", vars, ")")
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
    "replicate_creation" = {
      method_str <- entry$method
      params     <- entry$parameters
      n_rep      <- params$replicates
      type_str <- if (!is.null(params$type)) {
        paste0(", type = \"", params$type, "\"")
      } else {
        ""
      }
      rep_str <- if (!is.null(n_rep)) paste0(", replicates = ", n_rep) else ""
      paste0("replicate_creation (method = \"", method_str, "\"", type_str, rep_str, ")")
    },
    "ipw" = {
      fml_str <- deparse(entry$formula)
      paste0(
        "ipw [", fml_str, ", ", entry$method,
        ", n_ref=", entry$n_reference,
        ", N_hat=", round(entry$estimated_population_size), "]"
      )
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
#
# Arguments:
#   x           : survey_taylor, survey_nonprob, or survey_replicate
#   weights_quo : quosure from rlang::enquo(weights) in the calling function
#
# Returns: character(1)
.get_weight_col_name <- function(x, weights_quo) {
  if (!rlang::quo_is_null(weights_quo)) {
    return(rlang::as_name(weights_quo))
  }

  if (S7::S7_inherits(x, surveycore::survey_base)) {
    return(x@variables$weights)
  }

  ".weight"
}

# ============================================================================
# .validate_wt_name()
# ============================================================================

# Validates the wt_name argument: must be a single non-empty, non-NA string.
#
# Arguments:
#   wt_name : user-supplied name for the output weight column
#
# Returns: invisible(TRUE) on success (errors otherwise).
.validate_wt_name <- function(wt_name) {
  if (is.null(wt_name)) return(invisible(TRUE))
  if (!is.character(wt_name) || length(wt_name) != 1) {
    cli::cli_abort(
      c(
        "x" = "{.arg wt_name} must be a single character string.",
        "i" = "Got {.cls {class(wt_name)}} of length {length(wt_name)}."
      ),
      class = "surveywts_error_wt_name_not_scalar"
    )
  }
  if (is.na(wt_name) || wt_name == "") {
    cli::cli_abort(
      c(
        "x" = "{.arg wt_name} must be a non-empty, non-NA string."
      ),
      class = "surveywts_error_wt_name_empty"
    )
  }
  invisible(TRUE)
}

# ============================================================================
# .validate_reference_design()
# ============================================================================

# Validates the reference_design argument: must be a survey_taylor or NULL.
# Used by rake() and calibrate() (two call sites → lives in utils.R).
#
# Arguments:
#   reference_design : object to validate
#
# Returns: invisible(NULL) on success (errors otherwise).
.validate_reference_design <- function(reference_design) {
  if (!is.null(reference_design) &&
        !S7::S7_inherits(reference_design, surveycore::survey_taylor)) {
    cli::cli_abort(
      c(
        "x" = "{.arg reference_design} must be a {.cls survey_taylor}.",
        "i" = "Got class {.cls {class(reference_design)[[1L]]}}.",
        "v" = "Pass the {.cls survey_taylor} object used to compute the targets."
      ),
      class = "surveywts_error_reference_design_not_taylor"
    )
  }
  invisible(NULL)
}

# ============================================================================
# .get_weight_vec()
# ============================================================================

# Extracts the weight vector from any supported input class.
#
# Arguments:
#   x           : survey_taylor, survey_nonprob, or survey_replicate
#   weights_quo : quosure from rlang::enquo(weights) in the calling function
#
# Returns: numeric vector (length nrow(x@data))
.get_weight_vec <- function(x, weights_quo) {
  data_df <- x@data

  if (!rlang::quo_is_null(weights_quo)) {
    col_name <- rlang::as_name(weights_quo)
    return(data_df[[col_name]])
  }

  data_df[[x@variables$weights]]
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
            "Currently only categorical (character or factor) ",
            "variables are supported."
          ),
          "v" = paste0(
            "Convert to factor or character. ",
            "Continuous auxiliary variable calibration is not ",
            "currently supported."
          )
        ),
        class = "surveywts_error_variable_not_categorical"
      )
    }

    n_na <- sum(is.na(col))
    if (n_na > 0L) {
      fn_name <- if (context == "Calibration") "calibrate_linear" else "calibrate_rake"
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
  weight_col = NULL,
  call_str,
  parameters,
  before_stats,
  after_stats,
  convergence = NULL,
  capping = NULL
) {
  list(
    step = as.integer(step),
    operation = operation,
    weight_col = weight_col,
    timestamp = Sys.time(),
    call = call_str,
    parameters = parameters,
    weight_stats = list(
      before = before_stats,
      after = after_stats
    ),
    convergence = convergence,
    capping = capping,
    package_version = as.character(utils::packageVersion("surveywts"))
  )
}

# ============================================================================
# .update_survey_weights()
# ============================================================================

# Updates a survey object's weight column and appends a history entry to
# @metadata@weighting_history. Returns a new survey object of the SAME class
# as the input. Used by calibrate_rake(), calibrate_linear(), calibrate_logit(),
# poststratify(), calibrate(), adjust_nonresponse(), redistribute_weights(),
# trim_weights(), and rescale_weights().
#
# Arguments:
#   design          : survey_taylor, survey_nonprob, or survey_replicate
#   new_weights_vec : numeric vector (length = nrow(design@data)); the
#                     full-sample weight column is updated. Replicate weight
#                     columns are written directly by the caller before this call.
#   history_entry   : list from .make_history_entry()
#   wt_name         : NULL (default) or character(1). NULL → overwrite the
#                     existing weight column in-place; non-NULL → write to a new
#                     column named wt_name and update @variables$weights.
#   caldata         : named list or NULL. When non-NULL, a fully constructed
#                     @calibration list. Written to design@calibration before
#                     returning. NULL (default) leaves @calibration unchanged.
#
# Returns: survey object of the same class as input
.update_survey_weights <- function(
  design,
  new_weights_vec,
  history_entry,
  wt_name = NULL,
  caldata = NULL
) {
  updated_data <- design@data

  if (is.null(wt_name)) {
    # Overwrite existing weight column in-place
    weight_col <- design@variables$weights
    updated_data[[weight_col]] <- new_weights_vec
    design@data <- updated_data
  } else {
    # Check for conflict: wt_name already exists as a non-weight column
    if (wt_name %in% names(design@data) && wt_name != design@variables$weights) {
      cli::cli_abort(
        c(
          "x" = "{.arg wt_name} {.field {wt_name}} already exists as a non-weight column in {.arg data}.",
          "i" = "To avoid overwriting data, choose a new output column name.",
          "v" = "Specify a {.arg wt_name} that does not conflict with existing columns."
        ),
        class = "surveywts_error_wt_name_conflict"
      )
    }
    # Write data first (so the new column exists before @variables is updated),
    # then update @variables$weights — S7 validator fires on the latter assignment.
    updated_data[[wt_name]] <- new_weights_vec
    design@data <- updated_data
    design@variables$weights <- wt_name
  }

  # Append history entry (must go through intermediate variable for S7 nested
  # property assignment)
  meta <- design@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  design@metadata <- meta

  # Populate @calibration if provided
  if (!is.null(caldata)) {
    design@calibration <- caldata
  }

  design
}


# ============================================================================
# .check_input_class()
# ============================================================================

# Validates that `data` is a survey_base object (survey_nonprob, survey_taylor,
# or survey_replicate). Used by all calibration, nonresponse, utility, and
# diagnostic functions. Throws surveywts_error_not_survey_base otherwise.
#
# Arguments:
#   data : object passed as the `data` argument to a weighting function
#
# Returns: invisible(TRUE) on success. Throws on non-survey_base input.
.check_input_class <- function(data) {
  if (!S7::S7_inherits(data, surveycore::survey_base)) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} must be a {.cls survey_nonprob}, {.cls survey_taylor}, or {.cls survey_replicate}.",
        "i" = "Got {.cls {cls}}.",
        "v" = "Use {.fn surveycore::as_survey_nonprob}, {.fn surveycore::as_survey}, or {.fn surveycore::as_survey_replicate} to construct a survey object."
      ),
      class = "surveywts_error_not_survey_base"
    )
  }
  invisible(TRUE)
}

# ============================================================================
# .get_history()
# ============================================================================

# Extracts weighting history from a survey_base object.
# Used by calibrate(), rake(), poststratify(), and adjust_nonresponse().
#
# Arguments:
#   x : survey_taylor, survey_nonprob, or survey_replicate
#
# Returns: list (possibly empty) of history entries.
.get_history <- function(x) {
  if (S7::S7_inherits(x, surveycore::survey_base)) {
    wh <- x@metadata@weighting_history
    if (is.null(wh)) list() else wh # nocov
  } else {
    list()
  }
}


# ============================================================================
# .validate_formula()
# ============================================================================

# Validates that formula is a one-sided formula object (~ RHS).
# A two-sided formula (LHS ~ RHS) is rejected because calibration and
# nonresponse functions construct the LHS internally.
#
# Arguments:
#   formula : object to validate
#
# Returns: invisible(TRUE) on success (errors otherwise).
.validate_formula <- function(formula) {
  if (!inherits(formula, "formula") || length(formula) != 2L) {
    cli::cli_abort(
      c(
        "x" = "{.arg formula} must be a one-sided formula (e.g., {.code ~ age + sex}).",
        "i" = "Got {.cls {class(formula)[[1]]}}."
      ),
      class = "surveywts_error_formula_invalid"
    )
  }
  invisible(TRUE)
}

# ============================================================================
# .validate_formula_variables()
# ============================================================================

# Validates that all variables in formula exist in data.
# Errors on the first missing variable found.
#
# Arguments:
#   formula      : a validated one-sided formula (call .validate_formula() first)
#   data         : data.frame to check against
#   design_label : character(1) — name shown in error messages (e.g., "primary_design")
#   error_class  : character(1) or NULL — when NULL, uses
#                  "surveywts_error_formula_variable_not_found" (existing behavior);
#                  when non-NULL, uses the supplied class instead (e.g., for
#                  reporting that the variable is missing from the reference design)
#
# Returns: invisible(TRUE) on success (errors otherwise).
.validate_formula_variables <- function(formula, data, design_label,
                                        error_class = NULL) {
  cls <- if (is.null(error_class)) {
    "surveywts_error_formula_variable_not_found"
  } else {
    error_class
  }
  vars <- all.vars(formula)
  for (var in vars) {
    if (!var %in% names(data)) {
      cli::cli_abort(
        c(
          "x" = "Variable {.field {var}} not found in {.arg {design_label}}.",
          "i" = "All variables in {.arg formula} must be columns in {.arg {design_label}}.",
          "v" = "Check spelling or add {.field {var}} to the data before calling this function."
        ),
        class = cls
      )
    }
  }
  invisible(TRUE)
}

# ============================================================================
# .trim_weights_internal()
# ============================================================================

# Clip-and-redistribute logic adapted from survey::do_trimWeights (Thomas Lumley, GPL-2/3).
# Source: https://github.com/cran/survey/blob/4834b8bc91f6414ad4514552daaed8990a86d9c1/R/grake.R#L449
.trim_weights_internal <- function(weights, lower, upper, has_trimmed) {
  outside <- weights < lower | weights > upper
  if (!any(outside)) return(list(weights = weights, has_trimmed = has_trimmed))
  weights_new <- pmax(lower, pmin(weights, upper))
  trimmings <- weights - weights_new
  can_adjust <- !outside & !has_trimmed
  if (!any(can_adjust)) {
    cli::cli_warn(
      c("!" = "Weight redistribution failed: no untrimmed units remain to absorb the trimmed excess."),
      class = "surveywts_warning_trimming_failed"
    )
  } else {
    weights_new[can_adjust] <- weights_new[can_adjust] + sum(trimmings) / sum(can_adjust)
  }
  list(weights = weights_new, has_trimmed = outside | has_trimmed)
}

# ============================================================================
# .to_svyrep_design()
# ============================================================================

# Converts a survey_replicate object to a survey::svyrep.design for use with
# svrep calibration functions.
#
# surveywts stores replicate weights as scale factors (combined.weights = FALSE),
# matching svrep::as_bootstrap_design() and survey::as.svrepdesign(). The
# survey::svrepdesign() default is combined.weights = TRUE, which would
# misinterpret scale factors as full sampling weights. This function always
# passes combined.weights = FALSE.
#
# Arguments:
#   design : survey_replicate object
#
# Returns: svyrep.design object
.to_svyrep_design <- function(design) {
  vars <- design@variables
  weights_vec <- design@data[[vars$weights]]
  repweights_df <- design@data[vars$repweights]
  mse_val <- if (!is.null(vars$mse)) vars$mse else TRUE

  type_map <- c(
    "bootstrap" = "bootstrap",
    "BRR" = "BRR",
    "Fay" = "Fay",
    "JK1" = "JK1",
    "JK2" = "JK2",
    "JKn" = "JKn",
    "successive-difference" = "successive-difference",
    "ACS" = "ACS",
    "Random-groups jackknife" = "JK1",
    "other" = "other"
  )
  svyrep_type <- type_map[vars$type]
  if (is.na(svyrep_type)) svyrep_type <- "other"

  survey::svrepdesign(
    data = design@data,
    weights = weights_vec,
    repweights = repweights_df,
    type = svyrep_type,
    scale = vars$scale,
    rscales = vars$rscales,
    combined.weights = FALSE,
    mse = mse_val
  )
}

# ============================================================================
# .has_package()
# ============================================================================

# Thin wrapper around requireNamespace() so tests can mock package availability
# without needing to mock a base function.
.has_package <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}
