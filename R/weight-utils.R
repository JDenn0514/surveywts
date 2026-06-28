# R/weight-utils.R
#
# Internal helpers shared by trim_weights() and rescale_weights().
#
# .check_weight_utils_class() — class check; accepts only survey_base objects;
#   errors with surveywts_error_not_survey_base for anything else.
# .has_repweights()           — pure Boolean predicate: does x carry
#   accessible replicate weight columns?

# ============================================================================
# .check_weight_utils_class()
# ============================================================================

# File-local class check for trim_weights() and rescale_weights().
# Accepts survey_nonprob, survey_taylor, and survey_replicate only.
# Errors with surveywts_error_not_survey_base for any other input.
.check_weight_utils_class <- function(data) {
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
# survey_taylor, and all other inputs.
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
