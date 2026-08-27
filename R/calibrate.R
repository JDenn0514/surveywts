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

#' Adjust weights to match population totals
#'
#' A thin dispatcher that routes to [calibrate_rake()], [calibrate_linear()],
#' or [calibrate_logit()] based on `method`. All arguments are forwarded
#' unchanged; all validation and error handling occur in the dispatched
#' function.
#'
#' @param data A `survey_nonprob`, `survey_taylor`, or `survey_replicate`.
#'   Forwarded unchanged to the dispatched function. For `survey_replicate`
#'   inputs, calibration is applied to every replicate weight column using the
#'   same `targets`; see the dispatched function for replicate weight handling
#'   details.
#' @param targets Target specification. Forwarded to the dispatched function.
#'   Two formats are accepted:
#'
#'   **Format A — named list** (one element per calibration variable):
#'   ```r
#'   list(
#'     sex   = c("Male" = 0.49, "Female" = 0.51),
#'     age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#'   )
#'   ```
#'
#'   **Format B — long data frame** with columns `variable`, `level`, `target`:
#'   ```r
#'   data.frame(
#'     variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'     level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'     target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#'   )
#'   ```
#'
#'   Format B is auto-detected and converted to Format A before dispatch.
#'   See [calibrate_rake()], [calibrate_linear()], or [calibrate_logit()]
#'   for per-method target validation rules.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column
#'   (bare name). Forwarded to the dispatched function. `NULL` (the default)
#'   auto-detects the weight column from survey object `@variables$weights`.
#' @param wt_name `NULL` (the default) or a `character(1)`. When `NULL`,
#'   calibrated weights overwrite the existing weight column in place. When a
#'   character string, a new column is added and `@variables$weights` updated.
#'   Forwarded to the dispatched function.
#' @param type `character(1)`. `"prop"` (the default): `targets` values are
#'   proportions. `"count"`: `targets` values are population counts. Forwarded
#'   to the dispatched function.
#' @param reference_design A `survey_taylor` or `NULL` (the default). Stored
#'   in the weighting history for provenance. Forwarded to the dispatched
#'   function.
#' @param ... Additional arguments forwarded as-is to the dispatched function.
#'   See [calibrate_rake()], [calibrate_linear()], or [calibrate_logit()]
#'   for available arguments (e.g., `algorithm`, `bounds`, `cap`, `control`).
#' @param method `character(1)`. Calibration method: `"rake"` (the default),
#'   `"linear"`, or `"logit"`. Matched with [rlang::arg_match()].
#'   - `"rake"`: multiplicative raking via [calibrate_rake()]. Weights remain
#'     strictly positive. Two algorithms available via `algorithm` in `...`.
#'   - `"linear"`: GREG estimator via [calibrate_linear()]. Exact in one step;
#'     may produce negative weights for large discrepancies.
#'   - `"logit"`: logit-bounded calibration via [calibrate_logit()]. G-weight
#'     ratios constrained to an open interval `(L, U)` via `bounds` in `...`.
#'
#' @returns An object of the same class as `data`, as returned by the
#'   dispatched function. See [calibrate_rake()], [calibrate_linear()], or
#'   [calibrate_logit()] for class-specific return value details and
#'   weighting history guarantees.
#'
#' @details
#' All three methods implement the Deville-Sarndal calibration framework:
#' each adjusts survey weights so that weighted auxiliary totals match
#' known population totals. The methods share a variance estimator and
#' differ in the weight-ratio function \eqn{F} applied during calibration
#' (Deville & Sarndal 1992; Deville, Sarndal & Sautory 1993).
#'
#' **Raking** (`method = "rake"`, the default) uses the multiplicative
#' function \eqn{F(u) = \exp(u)}, which keeps all calibrated weights
#' strictly positive. For marginal targets, raking reduces to classical
#' iterative proportional fitting (Deville, Sarndal & Sautory 1993). Two
#' algorithms are available via `algorithm` (passed through `...`):
#' `"classic_ipf"` (the default; chi-square variable selection ported
#' from the ANES raking procedure, DeBell & Krosnick 2009) and `"nr"`
#' (Newton-Raphson). The weight ratio \eqn{w_k / d_k} is unbounded above.
#'
#' **Linear** (`method = "linear"`) uses \eqn{F(u) = 1 + u}, equivalent
#' to the generalized regression (GREG) estimator. The solution is exact
#' in a single step — no iteration required — making it the fastest method
#' (Deville & Sarndal 1992). The weight ratio is unbounded in both
#' directions; large sample-to-population discrepancies can produce
#' negative calibrated weights.
#'
#' **Logit** (`method = "logit"`) constrains the weight ratio
#' \eqn{w_k / d_k} to the open interval \eqn{(L, U)} via a logit-bounded
#' \eqn{F} function (Deville & Sarndal 1992; Deville, Sarndal & Sautory
#' 1993). Pass `bounds` via `...` to control the interval (default
#' `c(1e-6, 1e6)`). Note that bounds apply to the ratio of calibrated to
#' design weight, not to calibrated weights directly.
#'
#' For full algorithm documentation, convergence criteria, and
#' replicate-weight handling, see [calibrate_rake()],
#' [calibrate_linear()], and [calibrate_logit()].
#'
#' @references
#'   DeBell, M. and Krosnick, J.A. (2009). Computing Weights for American
#'   National Election Study Survey Data. ANES Technical Report series,
#'   no. nes012427. Ann Arbor, MI, and Palo Alto, CA: American National
#'   Election Studies.
#'
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013--1020.
#'
#'   Kott, P.S. (2003). An overview of calibration weighting. 2003 Joint
#'   Statistical Meetings — Section on Survey Research Methods.
#'
#' @seealso [calibrate_rake()], [calibrate_linear()], [calibrate_logit()],
#'   [poststratify()]
#' @family calibration
#' @export
#'
#' @examples
#' ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#'
#' targets_a <- list(
#'   sex    = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#'
#' # Format A + rake (default) --------------------------------------------
#' calibrate(ns_wave1_svy, targets = targets_a)
#'
#' # Format A + linear ----------------------------------------------------
#' calibrate(ns_wave1_svy, targets = targets_a, method = "linear")
#'
#' # Format A + logit -----------------------------------------------------
#' calibrate(ns_wave1_svy, targets = targets_a, method = "logit")
#'
#' # Format B + rake ------------------------------------------------------
#' targets_b <- data.frame(
#'   variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'   level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'   target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#' )
#' calibrate(ns_wave1_svy, targets = targets_b)
calibrate <- function(
  data,
  targets,
  weights = NULL,
  wt_name = NULL,
  type = c("prop", "count"),
  reference_design = NULL,
  ...,
  method = c("rake", "linear", "logit")
) {
  method <- rlang::arg_match(method)
  weights_quo <- rlang::enquo(weights)

  switch(
    method,
    rake = calibrate_rake(
      data,
      targets = targets,
      weights = !!weights_quo,
      wt_name = wt_name,
      type = type,
      reference_design = reference_design,
      ...
    ),
    linear = calibrate_linear(
      data,
      targets = targets,
      weights = !!weights_quo,
      wt_name = wt_name,
      type = type,
      reference_design = reference_design,
      ...
    ),
    logit = calibrate_logit(
      data,
      targets = targets,
      weights = !!weights_quo,
      wt_name = wt_name,
      type = type,
      reference_design = reference_design,
      ...
    )
  )
}
