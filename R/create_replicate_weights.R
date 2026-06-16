# R/create_replicate_weights.R
#
# create_replicate_weights() — dispatcher to the appropriate create_*_weights()
# function based on the method argument.

# ============================================================================
# create_replicate_weights()
# ============================================================================

#' Create replicate weights (dispatcher)
#'
#' Dispatches to the appropriate `create_*_weights()` function based on
#' `method`. All validation, defaults, and error messages are handled by the
#' dispatched function; this function only resolves the method name.
#'
#' @param data A `survey_taylor` or `survey_nonprob` design.
#' @param method `character(1)`. One of `"bootstrap"`, `"jackknife"`, `"brr"`,
#'   `"generalized-bootstrap"`, `"generalized-replicate"`,
#'   `"successive-difference"`. For delete-a-group jackknife on a
#'   `survey_nonprob`, use `method = "jackknife"` with `type = "grouped"`.
#' @param ... Passed as-is to the dispatched function. Invalid arguments for
#'   the selected method produce R's native "unused argument" error.
#'
#' @returns A `survey_replicate` for most methods, or a `survey_nonprob`
#'   when `method = "jackknife"` and `type = "grouped"` is passed via `...`
#'   for DAGJK on a non-probability sample.
#'
#' @family replicate-weights
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_sdr_weights()]
#' @export
create_replicate_weights <- function(
  data,
  method = c(
    "bootstrap", "jackknife", "brr",
    "generalized-bootstrap", "generalized-replicate",
    "successive-difference"
  ),
  ...
) {
  method <- rlang::arg_match(method)
  switch(
    method,
    bootstrap               = create_bootstrap_weights(data, ...),
    jackknife               = create_jackknife_weights(data, ...),
    brr                     = create_brr_weights(data, ...),
    "generalized-bootstrap" = create_gen_boot_weights(data, ...),
    "generalized-replicate" = create_gen_rep_weights(data, ...),
    "successive-difference" = create_sdr_weights(data, ...)
  )
}
