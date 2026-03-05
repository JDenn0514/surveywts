# R/constructors.R
#
# Internal constructor for survey_calibrated objects.
#
# survey_calibrated is defined in surveycore. This constructor wraps
# surveycore::survey_calibrated() to:
#   1. Preserve all design variables from the input design
#   2. Replace the weight column with the updated weights
#   3. Append the history entry to @metadata@weighting_history
#   4. Set @calibration = NULL (provenance lives in @metadata@weighting_history)
#
# No exports from this file.

#' Internal constructor for survey_calibrated
#'
#' Builds a new `surveycore::survey_calibrated` from an existing survey design,
#' replacing weights and appending a history entry.
#'
#' @param design A `survey_taylor` or `survey_calibrated` object.
#' @param updated_data A `data.frame` with the updated weight column present.
#' @param updated_weights_col Character scalar — name of the weight column in
#'   `updated_data`.
#' @param history_entry A history entry list from `.make_history_entry()`.
#'
#' @return A `surveycore::survey_calibrated` object.
#'
#' @keywords internal
#' @noRd
.new_survey_calibrated <- function(
  design,
  updated_data,
  updated_weights_col,
  history_entry
) {
  # Preserve all design variables; only update the weight column name
  new_variables <- design@variables
  new_variables$weights <- updated_weights_col

  # Append history entry to metadata
  new_metadata <- design@metadata
  new_metadata@weighting_history <- c(
    new_metadata@weighting_history,
    list(history_entry)
  )

  # Build the new survey_calibrated
  surveycore::survey_calibrated(
    data = updated_data,
    variables = new_variables,
    metadata = new_metadata,
    groups = design@groups,
    call = design@call,
    calibration = NULL
  )
}
