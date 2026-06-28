# R/diagnostics-utils.R
#
# Internal helpers shared by effective_sample_size(), weight_variability(),
# and summarize_weights().
#
# .diag_validate_input() — class check and weight extraction.

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Validates x and extracts (data_df, weight_col) for use by diagnostic
# functions. Checks:
#   1. x is a survey_base object — throws surveywts_error_not_survey_base otherwise
# Returns: list(data_df = <data.frame>, weight_col = <character>)
.diag_validate_input <- function(x, weights_quo) {
  if (!S7::S7_inherits(x, surveycore::survey_base)) {
    cls <- class(x)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg x} must be a {.cls survey_nonprob}, {.cls survey_taylor}, or {.cls survey_replicate}.",
        "i" = "Got {.cls {cls}}.",
        "v" = "Use {.fn surveycore::as_survey_nonprob}, {.fn surveycore::as_survey}, or {.fn surveycore::as_survey_replicate} to construct a survey object."
      ),
      class = "surveywts_error_not_survey_base"
    )
  }

  data_df <- x@data
  weight_col <- .get_weight_col_name(x, weights_quo)

  list(data_df = data_df, weight_col = weight_col)
}
