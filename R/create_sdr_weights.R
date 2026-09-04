# R/create_sdr_weights.R
#
# create_sdr_weights() — successive difference replication (SDR) weights.

# ============================================================================
# create_sdr_weights()
# ============================================================================

#' Generate successive difference replication weights
#'
#' Generates successive difference replication weights — a form of
#' replicate weights (sets of perturbed weight columns used to compute
#' standard errors) — via [svrep::as_sdr_design()]. Requires a
#' `survey_taylor` design.
#'
#' @param data A `survey_taylor` design. PSUs should be in systematic
#'   selection order, or use `sort_var`.
#' @param replicates `integer(1)`, default `100L`. Target replicate count
#'   (>= 4). Actual count may be slightly larger due to Hadamard matrix sizing.
#' @param ... Must be empty.
#' @param sort_var <[`tidy-select`][tidyselect::language]> Bare column name
#'   giving the systematic selection order. Required for stratified designs
#'   (svrep >= 0.9.1); for non-stratified designs row order is used as fallback.
#' @param use_normal_hadamard `logical(1)`, default `FALSE`. Selects which
#'   Hadamard orders the replicate count can take. `FALSE` gives orders that
#'   double from 4; `TRUE` gives a finer grid, so the count sits closer to
#'   `replicates`. The two settings give different variance estimates once the
#'   PSU count exceeds the smaller order — see the **Hadamard order and the
#'   column count** part of the Algorithm section.
#' @param mse `logical(1)`, default `TRUE`. Centers each replicate deviation
#'   on the full-sample estimate (`TRUE`; conservative) or on the mean of
#'   the replicate estimates (`FALSE`).
#'
#' @returns A `survey_replicate` with `@variables$type = "successive-difference"`.
#'
#' @details
#' **When to use.** Choose successive difference replication only when
#' the sample was drawn systematically from a sorted list and the rows
#' still carry that order (Ash 2014). The row order is part of the
#' method: re-sorted rows give a different and incorrect answer, and
#' no error is raised. Pass `sort_var` to pin the order.
#'
#' This estimator targets the variance of a systematic random sample when
#' PSUs are in selection order (Ash, 2014; Fay & Train, 1995). See the
#' Algorithm section for when the match is exact.
#'
#' @section Algorithm:
#' Successive difference replication (SDR) pairs adjacent PSUs in
#' systematic selection order. A Hadamard matrix of order \eqn{R} assigns
#' each pair to a half-sample. The SDR variance estimator is:
#' \deqn{\hat{V}_{SDR} = \frac{4}{R} \sum_{r=1}^{R}
#'   (\hat{\theta}^{(r)} - \hat{\theta}_{\text{full}})^2.}
#' The match to SD2 is exact only while the unit count does not exceed
#' \eqn{R}. Above that the row assignment recycles row pairs, so SDR
#' approximates SD2 rather than reproducing it. The bundled `cps_2023` example
#' is in that regime.
#' Delegates to [svrep::as_sdr_design()].
#'
#' **Hadamard order and the column count.** The number of replicate columns is
#' the order of the Hadamard matrix, not `replicates`. `use_normal_hadamard`
#' selects which orders are reachable. At `FALSE`, the default, the order
#' doubles from 4 — 4, 8, 16, 32, 64, 128, 256, 512 and so on — and the
#' smallest such order at or above `replicates` is the one returned. At `TRUE`
#' the order comes from [survey::hadamard()], which supplies a finer grid: 20,
#' 40, 56, 104 and 128 are all reachable, so the count sits closer to
#' `replicates`. A request the finer grid cannot meet still rounds up — 52
#' returns 56. At `TRUE` some replicates may be inactive: all of their
#' replicate factors equal 1, so each equals the full sample. The count of
#' them rises as the PSU count falls relative to the order, and it is not
#' capped. An inactive replicate is valid. It contributes a zero term to the
#' variance sum, and the scale \eqn{4/R} counts it, which is what keeps the
#' estimator unbiased.
#'
#' The check to run is your PSU count against the order you would land on.
#' While the PSU count does not exceed the smaller order, both settings give
#' the same answer and the smaller order is free. Above that the two settings
#' give different variance estimates, and the gap grows with the PSU count.
#' Measured at `replicates = 50` on a design of 480 rows in four strata, the
#' standard error moved by about 2% at 80 PSUs, 5% at 160 and 15% at 480. Both
#' estimates are valid. Keep the default `FALSE` to reproduce existing work.
#'
#' Two further differences. At the same order and `mse = TRUE`, the default,
#' both settings give the same variance for a total, but a mean can differ,
#' because a mean is a ratio whose denominator varies by replicate and the
#' inactive replicates enter it. At `mse = FALSE` the two settings differ even
#' at the same order, for the same reason.
#'
#' @inheritSection create_gen_boot_weights Messages
#'
#' @references
#'   Ash, S. (2014). Using successive difference replication for
#'   estimating variances. *Survey Methodology, Statistics Canada*,
#'   40(1), 47--59.
#'
#'   Fay, R.E. and Train, G.F. (1995). Aspects of survey and model-based
#'   postcensal estimation of income and poverty characteristics for
#'   states and counties. *Joint Statistical Meetings, Proceedings of
#'   the Section on Government Statistics*, 154--159.
#'
#' @examples
#' # apply SDR to a Taylor-linearization design ---------------------------
#' # `cps_2023` carries no strata or PSU columns, so this design has neither.
#' cps_design <- surveycore::as_survey(cps_2023, weights = wtfinl)
#' # `replicates = 50L` returns 64 columns: the count is a Hadamard matrix
#' # order, and the default path doubles from 4 until it reaches 50.
#' sdr_design <- create_sdr_weights(cps_design, replicates = 50L)
#' summarize_weights(sdr_design)
#' # The confidence interval below is computed from the 64 replicate
#' # columns rather than by Taylor linearization.
#' surveycore::get_means(sdr_design, age)
#'
#' # ask for a count closer to `replicates` --------------------------------
#' # The finer grid of Hadamard orders reaches 56, so the same request
#' # returns 56 columns rather than 64.
#' sdr_normal <- create_sdr_weights(
#'   cps_design,
#'   replicates = 50L,
#'   use_normal_hadamard = TRUE
#' )
#' length(sdr_normal@variables$repweights)
#'
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_replicate_weights()], [as_taylor_design()].
#'   For the class system, the standard workflows, and a glossary of terms,
#'   see the [Getting started
#'   article](https://jdenn0514.github.io/surveywts/articles/getting-started.html).
#' @family replicate-weights
#' @export
create_sdr_weights <- function(
  data,
  replicates = 100L,
  ...,
  sort_var = NULL,
  use_normal_hadamard = FALSE,
  mse = TRUE
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_sdr_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by SDR.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  replicates <- .validate_replicates_arg(replicates, min_val = 4L)

  if (
    !is.logical(use_normal_hadamard) ||
      length(use_normal_hadamard) != 1L ||
      is.na(use_normal_hadamard)
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg use_normal_hadamard} must be TRUE or FALSE.",
        "i" = paste0(
          "Got {.cls {class(use_normal_hadamard)}} of ",
          "length {length(use_normal_hadamard)}."
        ),
        "v" = paste0(
          "Set {.code use_normal_hadamard = FALSE} (default) or ",
          "{.code use_normal_hadamard = TRUE}."
        )
      ),
      class = "surveywts_error_use_normal_hadamard_invalid"
    )
  }

  sort_quo <- rlang::enquo(sort_var)
  sort_col <- if (rlang::quo_is_null(sort_quo)) {
    NULL
  } else {
    rlang::as_name(sort_quo)
  }

  if (!is.null(sort_col)) {
    n_na <- sum(is.na(data@data[[sort_col]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = "{.arg sort_var} column {.field {sort_col}} contains {n_na} NA value(s).",
          "v" = "Remove rows with missing sort values before calling {.fn create_sdr_weights}."
        ),
        class = "surveywts_error_sort_var_has_na"
      )
    }
  }

  .convert_and_call(
    data = data,
    backend_fn = function(d) {
      if (is.null(sort_col)) {
        d$variables[[".row_order"]] <- seq_len(nrow(d$variables))
        effective_sort <- ".row_order"
      } else {
        effective_sort <- sort_col
      }
      result <- svrep::as_sdr_design(
        d,
        replicates = replicates,
        sort_variable = effective_sort,
        use_normal_hadamard = use_normal_hadamard,
        mse = mse
      )
      result$variables[[".row_order"]] <- NULL
      result
    },
    method = "successive-difference",
    params = list(
      replicates = replicates,
      sort_var = sort_col,
      mse = mse,
      use_normal_hadamard = use_normal_hadamard
    )
  )
}
