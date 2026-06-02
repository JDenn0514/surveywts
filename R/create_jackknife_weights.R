# R/create_jackknife_weights.R
#
# create_jackknife_weights() — jackknife replicate weights.

# ============================================================================
# create_jackknife_weights()
# ============================================================================

#' Create jackknife replicate weights
#'
#' Generates jackknife replicate weights via [survey::as.svrepdesign()] (for
#' delete-1) or [svrep::as_random_group_jackknife_design()] (for random-groups).
#'
#' @param data A `survey_taylor` or `survey_nonprob` design. `survey_nonprob`
#'   supports `type = "delete-1"` only.
#' @param replicates `integer(1)` or `NULL`. Number of random groups when
#'   `type = "random-groups"`. Required for random-groups; ignored for
#'   delete-1.
#' @param ... Must be empty.
#' @param type `character(1)`. `"delete-1"` (default): one replicate per PSU,
#'   auto-selecting JK1 (unstratified) or JKn (stratified). `"random-groups"`:
#'   PSUs randomly divided into `replicates` groups.
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed for random-group assignment
#'   (ignored for delete-1).
#'
#' @return A `survey_replicate` with `@variables$type` of `"JK1"` or `"JKn"`.
#'
#' @family replicate-weights
#' @export
create_jackknife_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c("delete-1", "random-groups"),
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)
  type <- rlang::arg_match(type)

  # nonprob + random-groups: error first (before replicates validation)
  if (S7::S7_inherits(data, surveycore::survey_nonprob) &&
        type == "random-groups") {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.cls survey_nonprob} input is not supported with ",
          "{.code type = \"random-groups\"}."
        ),
        "i" = "Only {.code type = \"delete-1\"} is supported for non-probability designs.",
        "v" = "Use {.code type = \"delete-1\"} or convert to {.cls survey_taylor}."
      ),
      class = "surveywts_error_jackknife_type_unsupported_for_nonprob"
    )
  }

  if (type == "random-groups") {
    if (is.null(replicates)) {
      cli::cli_abort(
        c(
          "x" = "{.arg replicates} is required when {.code type = \"random-groups\"}.",
          "v" = "Supply an integer, e.g. {.code replicates = 20L}."
        ),
        class = "surveywts_error_replicates_required_for_jkn"
      )
    }
    replicates <- .validate_replicates_arg(replicates)
    .convert_and_call(
      data       = data,
      backend_fn = function(d) {
        svrep::as_random_group_jackknife_design(d, replicates = replicates, mse = mse)
      },
      method     = "jackknife",
      params     = list(type = "random-groups", replicates = replicates, mse = mse),
      seed       = seed
    )
  } else {
    # delete-1: auto-detect JK1 (no strata) vs JKn (has strata)
    jk_type <- if (is.null(data@variables$strata)) "JK1" else "JKn"
    .convert_and_call(
      data       = data,
      backend_fn = function(d) {
        survey::as.svrepdesign(d, type = jk_type, mse = mse)
      },
      method     = "jackknife",
      params     = list(type = jk_type, mse = mse)
    )
  }
}
