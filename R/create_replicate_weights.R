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
#'   `"successive-difference"`, `"group-jackknife"`.
#' @param ... Passed as-is to the dispatched function. Invalid arguments for
#'   the selected method produce R's native "unused argument" error.
#'
#' @return
#'   - For most methods: a `survey_replicate`.
#'   - For `method = "group-jackknife"`: a `survey_nonprob` with DAGJK replicate
#'     weight columns, consistent with
#'     `create_bootstrap_weights(type = "quasi-randomization")`.
#'
#' @family replicate-weights
#' @export
create_replicate_weights <- function(
  data,
  method = c(
    "bootstrap", "jackknife", "brr",
    "generalized-bootstrap", "generalized-replicate",
    "successive-difference", "group-jackknife"
  ),
  ...
) {
  method <- rlang::arg_match(method)
  switch(
    method,
    bootstrap                = create_bootstrap_weights(data, ...),
    jackknife                = create_jackknife_weights(data, ...),
    brr                      = create_brr_weights(data, ...),
    "generalized-bootstrap"  = create_gen_boot_weights(data, ...),
    "generalized-replicate"  = create_gen_rep_weights(data, ...),
    "successive-difference"  = create_sdr_weights(data, ...),
    "group-jackknife"        = create_group_jackknife_weights(data, ...)
  )
}
