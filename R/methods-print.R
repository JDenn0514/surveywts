# R/methods-print.R
#
# S7 print methods for surveycore classes.
# Per code-style.md §2: S7 methods live in a dedicated file, not with class defs.
#
# Class defined in surveycore (not in this package).

# ---------------------------------------------------------------------------
# Internal helper: format design variable list as ~var1 + var2 notation
# ---------------------------------------------------------------------------

.format_design_vars <- function(vars) {
  if (is.null(vars) || length(vars) == 0L || all(vars == "")) {
    return("~1")
  }
  paste0("~", paste(vars, collapse = " + "))
}

# ---------------------------------------------------------------------------
# print method for survey_nonprob
# ---------------------------------------------------------------------------

# Class defined in surveycore (surveycore::survey_nonprob).
S7::method(print, surveycore::survey_nonprob) <- function(x, n = 10, ...) {
  n_rows <- nrow(x@data)
  n_cols <- ncol(x@data)
  vars <- x@variables
  history <- x@metadata@weighting_history

  # Header
  cat(
    "# A calibrated survey design:",
    formatC(n_rows, format = "d", big.mark = ","), "observations,",
    n_cols, "variables\n"
  )

  # Variance method (hardcoded for Calibration release — see spec §X)
  cat("# Variance: model-assisted (SRS assumption)\n")

  # Design structure line
  ids_str <- .format_design_vars(vars$ids)
  strata_str <- if (is.null(vars$strata) || length(vars$strata) == 0L ||
                      all(vars$strata == "")) {
    "NULL"
  } else {
    paste0("~", paste(vars$strata, collapse = " + "))
  }
  weights_str <- if (is.null(vars$weights) || vars$weights == "") "NULL" else vars$weights
  cat(
    "# IDs:", ids_str,
    "| Strata:", strata_str,
    "| Weights:", weights_str,
    "\n"
  )

  # Weighting history
  n_steps <- length(history)
  if (n_steps == 0L) {
    cat("# Weighting history: none\n")
  } else {
    step_word <- if (n_steps == 1L) "step" else "steps"
    cat("# Weighting history:", n_steps, step_word, "\n")
    for (entry in history) {
      cat(.format_history_step(entry), "\n")
    }
  }

  invisible(x)
}
