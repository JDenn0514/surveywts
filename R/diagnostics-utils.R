# R/diagnostics-utils.R
#
# Internal helpers shared by effective_sample_size(), weight_variability(),
# and summarize_weights().
#
# .diag_validate_input() — class check, weight extraction, and required-weights check.

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Validates x and extracts (data_df, weight_col) for use by diagnostic
# functions. Checks:
#   1. x is a supported class — throws surveywts_error_unsupported_class
#   2. x is a plain data.frame with weights = NULL —
#      throws surveywts_error_weights_required
# Returns: list(data_df = <data.frame>, weight_col = <character>)
.diag_validate_input <- function(x, weights_quo) {
  is_supported <- is.data.frame(x) ||
    S7::S7_inherits(x, surveycore::survey_base)

  if (!is_supported) {
    cls <- class(x)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a data frame or a supported survey design object.",
        "i" = "Got {.cls {cls}}.",
        "v" = "See package documentation for supported input types."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }

  is_plain_df <- is.data.frame(x) && !inherits(x, "weighted_df")
  if (is_plain_df && rlang::quo_is_null(weights_quo)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg weights} is required when {.arg x} is a plain ",
          "data frame."
        ),
        "i" = paste0(
          "For {.cls weighted_df} and survey objects, the weight ",
          "column is detected automatically."
        ),
        "v" = paste0(
          "Pass the column name as a bare name, ",
          "e.g., {.code weights = wt_col}."
        )
      ),
      class = "surveywts_error_weights_required"
    )
  }

  data_df <- if (is.data.frame(x)) x else x@data
  weight_col <- .get_weight_col_name(x, weights_quo)

  list(data_df = data_df, weight_col = weight_col)
}
