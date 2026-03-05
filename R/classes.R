# R/classes.R
#
# weighted_df S3 class definition.
#
# Includes:
#   - print.weighted_df()             — formatted header + tibble body
#   - dplyr_reconstruct.weighted_df() — dplyr compat (filter, mutate, direct calls)
#   - select.weighted_df()            — dplyr 1.2.0 col-select path
#   - rename.weighted_df()            — detect weight col rename
#   - mutate.weighted_df()            — detect post-.keep weight col removal
#   - .reconstruct_weighted_df()      — internal helper shared by all dplyr methods
#
# .format_history_step() lives in R/utils.R (moved in PR 4).
# survey_calibrated is defined in surveycore, not here.

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
# dplyr_reconstruct.weighted_df()
# Called by filter() (via dplyr_row_slice), mutate() (via dplyr_col_modify),
# and direct dplyr_reconstruct() calls.  In dplyr >= 1.2.0, select() uses
# dplyr_col_select which does NOT call dplyr_reconstruct for tibble subclasses;
# that case is handled by select.weighted_df() below.
# ---------------------------------------------------------------------------

#' @importFrom dplyr dplyr_reconstruct
#' @export
dplyr_reconstruct.weighted_df <- function(data, template) {
  .reconstruct_weighted_df(data, template)
}

# ---------------------------------------------------------------------------
# select.weighted_df()
# In dplyr >= 1.2.0, select() uses dplyr_col_select() which bypasses
# dplyr_reconstruct for tibble subclasses (uses C-level vectbl_restore instead).
# This method restores correct behavior.
# Registered via @rawNamespace to avoid documentation requirement on the method.
# ---------------------------------------------------------------------------

#' @importFrom dplyr select
#' @export
select.weighted_df <- function(.data, ...) {
  result <- NextMethod()
  .reconstruct_weighted_df(result, .data)
}

# ---------------------------------------------------------------------------
# rename.weighted_df()
# rename.data.frame uses set_names() which preserves all attributes but makes
# the weight_col attribute stale when the weight column is renamed.
# ---------------------------------------------------------------------------

#' @importFrom dplyr rename
#' @export
rename.weighted_df <- function(.data, ...) {
  result <- NextMethod()
  .reconstruct_weighted_df(result, .data)
}

# ---------------------------------------------------------------------------
# mutate.weighted_df()
# dplyr_col_modify (used by mutate) calls dplyr_reconstruct BEFORE the .keep
# filter is applied.  When .keep = "unused" drops the weight column,
# dplyr_reconstruct sees all columns (passes), but the final result is missing
# the weight column.  This wrapper runs a second check after .keep has run.
# ---------------------------------------------------------------------------

#' @importFrom dplyr mutate
#' @export
mutate.weighted_df <- function(.data, ...) {
  result <- NextMethod()
  .reconstruct_weighted_df(result, .data)
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Core reconstruction logic shared by all dplyr integration points.
# If weight_col is present in `data`, restores weighted_df class and attributes.
# If weight_col is missing, warns (surveyweights_warning_weight_col_dropped)
# and returns a plain tibble.
.reconstruct_weighted_df <- function(data, template) {
  weight_col <- attr(template, "weight_col")

  if (weight_col %in% names(data)) {
    structure(
      data,
      class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
      weight_col = weight_col,
      weighting_history = attr(template, "weighting_history")
    )
  } else {
    cli::cli_warn(
      c(
        "!" = "Weight column {.field {weight_col}} was removed from the {.cls weighted_df}.",
        "i" = "The result has been downgraded to a plain tibble.",
        "i" = "Load {.pkg surveytidy} for rename-aware handling."
      ),
      class = "surveyweights_warning_weight_col_dropped"
    )
    # Strip custom weighted_df attributes before returning as plain tibble
    attr(data, "weight_col") <- NULL
    attr(data, "weighting_history") <- NULL
    tibble::as_tibble(data)
  }
}
