# R/calibrate.R
#
# calibrate() — thin dispatcher routing to calibrate_rake(), calibrate_linear(),
# or calibrate_logit() based on the `method` argument.
#
# PR 4 changes:
#   - Default method changed from "greg" to "rake"
#   - Removed "greg" and "poststrat" method options
#   - Added "linear" and "logit" method options
#   - Dispatches to calibrate_rake(), calibrate_linear(), calibrate_logit()
#
# This function adds no validation or calibration logic of its own.
# All errors propagate from the dispatched function.
#
# All substantive functions live in:
#   R/calibrate_rake.R    — raking (iterative proportional fitting or NR)
#   R/calibrate_linear.R  — GREG / linear calibration
#   R/calibrate_logit.R   — logit-bounded calibration

#' Calibrate survey weights
#'
#' Thin dispatcher that routes to [calibrate_rake()], [calibrate_linear()], or
#' [calibrate_logit()] based on `method`. All arguments are forwarded
#' unchanged to the dispatched function; all validation and error handling
#' occurs there.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. Forwarded to the dispatched function.
#' @param targets Target specification. Forwarded to the dispatched function.
#'   See [calibrate_rake()], [calibrate_linear()], or [calibrate_logit()]
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
#'   [calibrate_rake()], [calibrate_linear()], or [calibrate_logit()] for
#'   available arguments.
#' @param method Character scalar. Calibration method: `"rake"` (default),
#'   `"linear"`, or `"logit"`. Matched with [rlang::arg_match()].
#'
#' @return A `weighted_df` or survey object (same class as `data`), as
#'   returned by the dispatched function. See [calibrate_rake()],
#'   [calibrate_linear()], or [calibrate_logit()] for details.
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
#' # Dispatch to calibrate_rake() (default method)
#' result_rake <- calibrate(df, targets = targets)
#'
#' # Dispatch to calibrate_linear() explicitly
#' result_linear <- calibrate(df, targets = targets, method = "linear")
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
  method = c("rake", "linear", "logit")
) {
  method      <- rlang::arg_match(method)
  weights_quo <- rlang::enquo(weights)

  switch(
    method,
    rake = calibrate_rake(
      data,
      targets          = targets,
      weights          = !!weights_quo,
      wt_name          = wt_name,
      type             = type,
      reference_design = reference_design,
      ...
    ),
    linear = calibrate_linear(
      data,
      targets          = targets,
      weights          = !!weights_quo,
      wt_name          = wt_name,
      type             = type,
      reference_design = reference_design,
      ...
    ),
    logit = calibrate_logit(
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
