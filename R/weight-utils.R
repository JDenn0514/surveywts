# R/weight-utils.R
#
# Internal helpers shared by trim_weights() and stabilize_weights().
#
# .check_weight_utils_class() — class check accepting all 5 input types;
#   errors with surveywts_error_unsupported_class for anything else.

# ============================================================================
# .check_weight_utils_class()
# ============================================================================

# File-local class check for trim_weights() and stabilize_weights().
# Accepts all 5 input types; errors with surveywts_error_unsupported_class
# for anything else. Does NOT call .check_input_class() (which errors on
# survey_replicate).
.check_weight_utils_class <- function(data) {
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
