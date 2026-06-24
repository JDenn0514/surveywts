# R/as_taylor_design.R
#
# as_taylor_design() — convert a survey_replicate back to a survey_taylor
# using the stored replicate_creation history entry.

# ============================================================================
# as_taylor_design()
# ============================================================================

#' Convert a replicate design back to a Taylor design
#'
#' Reconstructs a `survey_taylor` from a `survey_replicate` created by
#' `create_*_weights()`. The original Taylor structure (PSU IDs, strata, FPC,
#' nest flag) is read from the `"replicate_creation"` entry in the weighting
#' history. Replicate weight columns are dropped from `@data`.
#'
#' Returns `data` unchanged (with a warning) if `data` is already a
#' `survey_taylor`.
#'
#' @param data A `survey_replicate` created by `create_*_weights()`, or a
#'   `survey_taylor` (returns unchanged with a warning).
#'
#' @returns A `survey_taylor`.
#'
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_sdr_weights()],
#'   [create_replicate_weights()]
#' @family replicate-weights
#' @export
as_taylor_design <- function(data) {
  if (S7::S7_inherits(data, surveycore::survey_taylor)) {
    cli::cli_warn(
      c("!" = "{.arg data} is already a {.cls survey_taylor}; returning unchanged."),
      class = "surveywts_warning_already_taylor"
    )
    return(data)
  }

  if (!S7::S7_inherits(data, surveycore::survey_replicate)) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} must be a {.cls survey_replicate} or {.cls survey_taylor}.",
        "i" = "Got {.cls {cls}}."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }

  history      <- data@metadata@weighting_history
  creation_idx <- which(
    vapply(
      history,
      function(e) identical(e$operation, "replicate_creation"),
      logical(1)
    )
  )

  if (length(creation_idx) == 0L) {
    cli::cli_abort(
      c(
        "x" = "No {.val replicate_creation} entry found in the weighting history.",
        "i" = "Cannot reconstruct the original Taylor design without the stored structure.",
        "v" = "Only designs created with {.fn create_*_weights} functions can be converted back."
      ),
      class = "surveywts_error_no_taylor_structure"
    )
  }

  last_idx      <- max(creation_idx)
  last_creation <- history[[last_idx]]

  # Check for post-creation weight adjustments
  if (last_idx < length(history)) {
    post_ops <- vapply(
      history[(last_idx + 1L):length(history)],
      function(e) e$operation,
      character(1)
    )
    cli::cli_abort(
      c(
        "x" = "Cannot reconstruct Taylor design: replicate weights were adjusted after creation.",
        "i" = "Post-creation operation(s): {.and {.val {post_ops}}}.",
        "v" = "Conversion back to Taylor is only supported for unadjusted replicate designs."
      ),
      class = "surveywts_error_taylor_from_calibrated_replicate"
    )
  }

  # Check source class — must not be survey_nonprob
  if (isTRUE(last_creation$source_design$is_nonprob)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Source design was a {.cls survey_nonprob}; ",
          "cannot reconstruct a {.cls survey_taylor}."
        ),
        "i" = paste0(
          "Non-probability samples lack the probability-design structure ",
          "required for Taylor linearization."
        )
      ),
      class = "surveywts_error_taylor_from_nonprob_replicate"
    )
  }

  cli::cli_warn(
    c("!" = "Converting to {.cls survey_taylor} discards replicate weights and variance capability."),
    class = "surveywts_warning_taylor_loses_variance"
  )

  source_vars <- last_creation$source_design$variables
  rep_cols    <- data@variables$repweights
  clean_data  <- data@data[, !names(data@data) %in% rep_cols, drop = FALSE]

  # source_vars$ids/strata/weights/fpc are stored character column names.
  # as_survey() uses tidy-eval (enquo), so character strings must be converted
  # to symbols with rlang::sym() and unquoted with !! inside rlang::inject().
  # ids may be NULL for SRS designs (no cluster structure); guard all optional args.
  weights_sym <- rlang::sym(source_vars$weights)
  optional    <- list()
  if (!is.null(source_vars$ids))    optional$ids    <- rlang::sym(source_vars$ids)
  if (!is.null(source_vars$strata)) optional$strata <- rlang::sym(source_vars$strata)
  if (!is.null(source_vars$fpc))    optional$fpc    <- rlang::sym(source_vars$fpc)

  rlang::inject(surveycore::as_survey(
    clean_data,
    weights = !!weights_sym,
    nest    = isTRUE(source_vars$nest),
    !!!optional
  ))
}
