# R/calibrate.R
#
# calibrate() — thin dispatcher routing to calibrate_greg(), calibrate_rake(),
# or calibrate_poststrat() based on the `method` argument.
#
# This function adds no validation or calibration logic of its own.
# All errors propagate from the dispatched function.
#
# All substantive functions live in:
#   R/calibrate_greg.R    — GREG calibration
#   R/calibrate_rake.R    — raking (iterative proportional fitting)
#   R/calibrate_poststrat.R  — exact post-stratification

#' Calibrate survey weights
#'
#' Thin dispatcher that routes to [calibrate_greg()], [calibrate_rake()], or
#' [calibrate_poststrat()] based on `method`. All arguments are forwarded
#' unchanged to the dispatched function; all validation and error handling
#' occurs there.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. Forwarded to the dispatched function.
#' @param targets Target specification. Forwarded to the dispatched function.
#'   See [calibrate_greg()], [calibrate_rake()], or [calibrate_poststrat()]
#'   for accepted formats.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). Forwarded to the dispatched function.
#' @param wt_name Character scalar. Name of the output weight column.
#'   Default `"wts"`. Forwarded to the dispatched function.
#' @param type Character scalar. `"prop"` (default) or `"count"`. Forwarded
#'   to the dispatched function.
#' @param reference_design A `survey_taylor` object or `NULL`. Forwarded to
#'   the dispatched function.
#' @param ... Additional arguments passed to the dispatched function. See
#'   [calibrate_greg()], [calibrate_rake()], or [calibrate_poststrat()] for
#'   available arguments.
#' @param method Character scalar. Calibration method: `"greg"` (default),
#'   `"rake"`, or `"poststrat"`. Matched with [rlang::arg_match()].
#'
#' @return A `weighted_df` or survey object (same class as `data`), as
#'   returned by the dispatched function. See [calibrate_greg()],
#'   [calibrate_rake()], or [calibrate_poststrat()] for details.
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
#'   sex = c("M", "F", "M", "F", "M"),
#'   stringsAsFactors = FALSE
#' )
#' targets <- list(
#'   age_group = c("18-34" = 0.40, "35-54" = 0.40, "55+" = 0.20),
#'   sex = c("M" = 0.50, "F" = 0.50)
#' )
#' # Dispatch to calibrate_greg() (default method)
#' result_greg <- calibrate(df, targets = targets)
#'
#' # Dispatch to calibrate_rake() explicitly
#' result_rake <- calibrate(df, targets = targets, method = "rake")
#'
#' @family calibration
#' @export
calibrate <- function(
  data,
  targets,
  weights = NULL,
  wt_name = "wts",
  type = c("prop", "count"),
  reference_design = NULL,
  ...,
  method = c("greg", "rake", "poststrat")
) {
  method      <- rlang::arg_match(method)
  weights_quo <- rlang::enquo(weights)

  switch(
    method,
    greg = calibrate_greg(
      data,
      targets          = targets,
      weights          = !!weights_quo,
      wt_name          = wt_name,
      type             = type,
      reference_design = reference_design,
      ...
    ),
    rake = calibrate_rake(
      data,
      targets          = targets,
      weights          = !!weights_quo,
      wt_name          = wt_name,
      type             = type,
      reference_design = reference_design,
      ...
    ),
    poststrat = calibrate_poststrat(
      data,
      targets          = targets,
      weights          = !!weights_quo,
      wt_name          = wt_name,
      type             = type,
      reference_design = reference_design,
      ...
    )
  )
}
