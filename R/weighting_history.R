# R/weighting_history.R
#
# weighting_history() — the weighting history of a survey design as a tibble.

# ---------------------------------------------------------------------------
# weighting_history()
# ---------------------------------------------------------------------------

#' List the weighting steps recorded on a design
#'
#' Returns one row for each weighting step recorded on the design, in the
#' order the steps ran. surveywts functions record a step each time they
#' change the weights: the calibration functions, the nonresponse
#' functions, the weight utilities, [ipw()], and the `create_*_weights()`
#' functions.
#'
#' @param x A `survey_taylor`, `survey_nonprob`, or `survey_replicate`. Any
#'   other class -> error.
#'
#' @returns A tibble with one row per history entry and four columns:
#'   * `step` (integer): the step number. An entry with no step number gets
#'     its row position.
#'   * `timestamp` (POSIXct): when the step ran. `NA` when the entry has no
#'     timestamp.
#'   * `operation` (character): the operation the step recorded, for example
#'     `"raking"` or `"replicate_creation"`. `NA` when the entry has no
#'     operation.
#'   * `description` (character): a short description of the step, for
#'     example `raking (targets: sex, age_f3)`. For an operation that has no
#'     longer description, this is the operation name.
#'
#'   A design with no recorded steps gives a zero-row tibble with the same
#'   four columns.
#'
#' @details
#' The history is stored in `x@metadata@weighting_history`. Entries written
#' by another package, or by an older version of surveywts, can lack some
#' fields. `weighting_history()` fills the gaps as the **Value** section
#' describes and does not raise an error.
#'
#' @seealso [summarize_weights()] for the distribution of the current
#'   weights.
#' @export
#'
#' @examples
#' ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#'
#' # no weighting steps yet ---------------------------------------------------
#' weighting_history(ns_wave1_svy)
#'
#' # two weighting steps ------------------------------------------------------
#' targets <- list(
#'   sex    = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#' raked <- calibrate_rake(ns_wave1_svy, targets = targets)
#' rescaled <- rescale_weights(raked)
#' weighting_history(rescaled)
weighting_history <- function(x) {
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

  history <- x@metadata@weighting_history
  if (!is.list(history)) {
    history <- list()
  }
  # An entry that is not a list has no fields to read; treat it as empty.
  history <- lapply(history, function(e) if (is.list(e)) e else list())
  idx <- seq_along(history)

  step <- vapply(
    idx,
    function(i) {
      s <- history[[i]]$step
      if (is.numeric(s) && length(s) == 1L && !is.na(s)) as.integer(s) else i
    },
    integer(1L)
  )

  ts_list <- lapply(history, function(e) {
    t <- e$timestamp
    if (inherits(t, "POSIXct") && length(t) == 1L) t else NULL
  })
  ts_ok <- Filter(Negate(is.null), ts_list)
  tz <- if (length(ts_ok) > 0L) attr(ts_ok[[1L]], "tzone") else NULL
  ts_num <- vapply(
    ts_list,
    function(t) if (is.null(t)) NA_real_ else as.numeric(t),
    numeric(1L)
  )
  timestamp <- .POSIXct(ts_num, tz = tz)

  operation <- vapply(history, .history_operation, character(1L))

  description <- vapply(
    idx,
    function(i) {
      label <- tryCatch(
        .history_step_label(history[[i]]),
        error = function(e) NA_character_
      )
      if (!is.character(label) || length(label) != 1L || is.na(label)) {
        operation[[i]]
      } else {
        label
      }
    },
    character(1L)
  )

  tibble::tibble(
    step = step,
    timestamp = timestamp,
    operation = operation,
    description = description
  )
}
