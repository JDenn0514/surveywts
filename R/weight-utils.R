# R/weight-utils.R
#
# Internal helpers shared by trim_weights() and rescale_weights().
#
# .check_weight_utils_class() — class check accepting all 5 input types;
#   errors with surveywts_error_unsupported_class for anything else.
# .has_repweights()           — pure Boolean predicate: does x carry
#   accessible replicate weight columns?

# ============================================================================
# .check_weight_utils_class()
# ============================================================================

# File-local class check for trim_weights() and rescale_weights().
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

# ============================================================================
# .has_repweights()
# ============================================================================

# Pure Boolean predicate. Returns TRUE when x carries accessible replicate
# weight columns — either because x is a survey_replicate (which guarantees
# their presence by class invariant) or because x is a survey_nonprob with
# a non-NULL, non-empty @variables$repweights vector.
#
# Must NOT throw for any input. Returns FALSE for NULL, plain data frames,
# survey_taylor, weighted_df, and all other inputs.
.has_repweights <- function(x) {
  if (S7::S7_inherits(x, surveycore::survey_replicate)) {
    return(TRUE)
  }
  if (S7::S7_inherits(x, surveycore::survey_nonprob)) {
    rw <- x@variables$repweights
    return(!is.null(rw) && length(rw) >= 1L)
  }
  FALSE
}
