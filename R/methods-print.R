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

  # Bootstrap replicates (if present)
  repwts <- x@variables$repweights
  if (!is.null(repwts) && length(repwts) > 0L) {
    boot_entries <- Filter(
      function(e) identical(e$operation, "bootstrap_weights"),
      history
    )
    if (length(boot_entries) > 0L) {
      e <- boot_entries[[length(boot_entries)]]
      cat(sprintf(
        "# Bootstrap replicates: %d (%s, level %s)\n",
        e$draws_used, e$type, e$level
      ))
    }
  }

  invisible(x)
}

# ---------------------------------------------------------------------------
# print.weighted_df()
# ---------------------------------------------------------------------------

#' Print a weighted data frame
#'
#' @param x A `weighted_df` object.
#' @param n Number of rows to show (default 10).
#' @param ... Additional arguments passed to the tibble print method.
#'
#' @return `x`, invisibly.
#'
#' @keywords internal
#' @export
print.weighted_df <- function(x, n = 10, ...) {
  weight_col <- attr(x, "weight_col")
  history <- attr(x, "weighting_history")
  w <- x[[weight_col]]
  n_rows <- nrow(x)
  n_cols <- ncol(x)

  # Delegate weight statistics to shared helper (defined in R/utils.R)
  stats <- .compute_weight_stats(w)
  w_mean <- stats$mean
  w_cv <- stats$cv
  w_ess <- stats$ess

  # Format with commas for readability
  fmt_int <- function(x) formatC(round(x), format = "d", big.mark = ",")
  fmt_2dp <- function(x) formatC(x, digits = 2, format = "f")

  # Header lines
  cat(
    "# A weighted data frame:", fmt_int(n_rows), "\u00d7", n_cols, "\n"
  )
  cat(
    "# Weight:", weight_col,
    paste0(
      "(n = ", fmt_int(n_rows),
      ", mean = ", fmt_2dp(w_mean),
      ", CV = ", fmt_2dp(w_cv),
      ", ESS = ", fmt_int(w_ess), ")"
    ),
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

  # Data divider
  width <- max(60L, getOption("width", 80L))
  rule_chars <- paste(rep("\u2500", width - 8L), collapse = "")
  cat(paste0("# \u2500\u2500 Data ", rule_chars, "\n"))

  # Delegate body to tibble's print
  NextMethod()

  invisible(x)
}

# ---------------------------------------------------------------------------
# print method for survey_replicate
# ---------------------------------------------------------------------------

# Class defined in surveycore (surveycore::survey_replicate)
S7::method(print, surveycore::survey_replicate) <- function(x, ...) {
  vars    <- x@variables
  history <- x@metadata@weighting_history
  n_rep   <- length(vars$repweights)

  cat(sprintf("<survey_replicate: %s>\n", vars$type))
  cat(sprintf(
    "N = %s observations\n",
    formatC(nrow(x@data), format = "d", big.mark = ",")
  ))

  if (n_rep > 0L) {
    first_rep <- vars$repweights[[1L]]
    last_rep  <- vars$repweights[[n_rep]]
    cat(sprintf(
      "%d replicate weights (%s ... %s)\n",
      n_rep, first_rep, last_rep
    ))
  }

  cat(sprintf("Scale: %s\n", format(vars$scale, digits = 4)))

  if (!is.null(vars$rscales) && length(vars$rscales) > 1L) {
    cat(sprintf(
      "Replicate scales: vector of length %d, range [%s, %s]\n",
      length(vars$rscales),
      format(min(vars$rscales), digits = 4),
      format(max(vars$rscales), digits = 4)
    ))
  }

  cat(sprintf("mse = %s\n", vars$mse))

  wt_vec <- x@data[[vars$weights]]
  cat("\nWeights:\n")
  cat(sprintf("  min:    %.2f\n", min(wt_vec)))
  cat(sprintf("  median: %.2f\n", stats::median(wt_vec)))
  cat(sprintf("  mean:   %.2f\n", mean(wt_vec)))
  cat(sprintf("  max:    %.2f\n", max(wt_vec)))
  cv_val <- stats::sd(wt_vec) / mean(wt_vec)
  cat(sprintf("  CV:     %.2f\n", cv_val))

  cat("\nWeighting history:\n")
  n_steps <- length(history)
  if (n_steps == 0L) {
    cat("  (none)\n")
  } else {
    for (entry in history) {
      cat("  ", .format_history_step(entry), "\n", sep = "")
    }
  }

  invisible(x)
}
