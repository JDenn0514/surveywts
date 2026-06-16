# R/create_brr_weights.R
#
# create_brr_weights() — balanced repeated replication (Fay variant) weights.

# ============================================================================
# create_brr_weights()
# ============================================================================

#' Create BRR (Fay) replicate weights
#'
#' Generates balanced repeated replication (BRR) or Fay's BRR replicate weights
#' via [survey::as.svrepdesign()]. Requires a paired-PSU design (exactly 2 PSUs
#' per stratum).
#'
#' @param data A `survey_taylor` with exactly 2 PSUs per stratum.
#' @param ... Must be empty.
#' @param rho `numeric(1)`, default `0`. Fay damping coefficient. `rho = 0`
#'   gives standard BRR; `rho > 0` gives Fay's BRR variant with factors `rho`
#'   and `2 - rho`. Must satisfy `0 <= rho < 1`.
#' @param mse `logical(1)`, default `TRUE`.
#'
#' @return A `survey_replicate` with `@variables$type` of `"BRR"` or `"Fay"`.
#'
#' @family replicate-weights
#' @export
create_brr_weights <- function(data, ..., rho = 0, mse = TRUE) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "BRR requires a paired-PSU design; {.cls survey_nonprob} has no PSU structure.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  if (is.null(data@variables$strata) || is.null(data@variables$ids)) {
    cli::cli_abort(
      c(
        "x" = "BRR requires a design with both strata and PSU IDs.",
        "i" = paste0(
          "Strata: ",
          if (is.null(data@variables$strata)) "missing" else "present",
          "; PSU IDs: ",
          if (is.null(data@variables$ids)) "missing" else "present",
          "."
        ),
        "v" = "Build the design with both {.arg ids} and {.arg strata} in {.fn surveycore::as_survey}."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  psu_col    <- data@variables$ids
  strata_col <- data@variables$strata
  df         <- data@data
  counts     <- tapply(
    df[[psu_col]], df[[strata_col]], function(x) length(unique(x))
  )
  bad <- names(counts)[counts != 2L]
  if (length(bad) > 0L) {
    show   <- utils::head(bad, 5L)
    suffix <- if (length(bad) > 5L) paste0(" ... (", length(bad) - 5L, " more)") else ""
    cli::cli_abort(
      c(
        "x" = "BRR requires exactly 2 PSUs per stratum.",
        "i" = paste0(
          "Stratum/a with wrong PSU count: ",
          paste(show, collapse = ", "), suffix, "."
        ),
        "v" = "Use {.fn create_gen_rep_weights} for designs with unequal PSU counts per stratum."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  if (rho < 0 || rho >= 1) {
    cli::cli_abort(
      c(
        "x" = "{.arg rho} must satisfy 0 <= rho < 1; got {.val {rho}}.",
        "i" = "{.arg rho} = 0 gives standard BRR; {.arg rho} > 0 gives Fay's BRR variant."
      ),
      class = "surveywts_error_brr_rho_invalid"
    )
  }

  if (rho == 0) {
    .convert_and_call(
      data       = data,
      backend_fn = function(d) survey::as.svrepdesign(d, type = "BRR", mse = mse),
      method     = "brr",
      params     = list(rho = 0, mse = mse)
    )
  } else {
    .convert_and_call(
      data       = data,
      backend_fn = function(d) survey::as.svrepdesign(d, type = "Fay", fay.rho = rho, mse = mse),
      method     = "brr",
      params     = list(rho = rho, mse = mse)
    )
  }
}
