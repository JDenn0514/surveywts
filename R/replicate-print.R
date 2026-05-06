# R/replicate-print.R
#
# S7 print method for surveycore::survey_replicate.
# Class defined in surveycore (not in this package).

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
