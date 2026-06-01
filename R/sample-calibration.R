# R/sample-calibration.R
#
# Implements sample-based calibration functions for replicate-weight designs:
#   calibrate_to_survey()  -- calibrate primary to a replicate control survey
#   calibrate_to_estimate() -- calibrate to point estimates + covariance matrix

# ============================================================================
# calibrate_to_survey()
# ============================================================================

#' Calibrate a replicate design to a replicate control survey
#'
#' Adjusts the full-sample and replicate weights of `primary_design` so that
#' weighted totals of the calibration variables match those of `control_design`.
#' Each replicate is calibrated to the corresponding replicate of the control,
#' propagating the variance of the control totals into the variance estimates.
#'
#' @param primary_design A `survey_replicate` design to calibrate.
#' @param control_design A `survey_replicate` design providing control totals.
#'   Must have the same number of replicates as `primary_design`.
#' @param formula A one-sided formula specifying calibration variables,
#'   e.g., `~ age_group + sex`. All variables must exist in both designs.
#' @param method Calibration method: `"raking"` (iterative multiplicative;
#'   always positive weights), `"linear"` (one-step GREG; may produce negative
#'   weights), or `"logit"` (bounded iterative; requires finite `bounds`).
#' @param bounds Named list with `lower` and `upper` weight bounds passed to
#'   svrep. Default: `list(lower = -Inf, upper = Inf)` (unbounded).
#' @param control Named list of convergence parameters, merged with defaults
#'   `list(maxit = 50, epsilon = 1e-7)`. Applied to every calibration call
#'   (full-sample and each replicate).
#'
#' @details
#' `method = "logit"` requires finite `bounds$lower` and `bounds$upper`. With
#' the default infinite bounds, `survey::cal.logit` will fail with a raw survey
#' package error -- this is not wrapped by surveywts.
#'
#' The intercept calibration constraint forces the calibrated weight sum to
#' equal the control survey's weight sum, not the primary design's original
#' weight sum.
#'
#' @return A `survey_replicate` with updated full-sample and replicate weights
#'   and a new `"sample_calibration_replicate"` entry appended to
#'   `@metadata@weighting_history`.
#'
#' @family sample-calibration
#' @export
calibrate_to_survey <- function(
  primary_design,
  control_design,
  formula,
  method = c("raking", "linear", "logit"),
  bounds = list(lower = -Inf, upper = Inf),
  control = list()
) {
  method <- match.arg(method)
  call_str <- deparse(match.call())

  # 1. Validate primary_design
  if (!S7::S7_inherits(primary_design, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg primary_design} must be a {.cls survey_replicate}.",
        "i" = "Got {.cls {class(primary_design)[[1L]]}}."
      ),
      class = "surveywts_error_primary_not_replicate"
    )
  }

  # 2. Validate control_design
  if (!S7::S7_inherits(control_design, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg control_design} must be a {.cls survey_replicate}.",
        "i" = "Got {.cls {class(control_design)[[1L]]}}."
      ),
      class = "surveywts_error_control_not_replicate"
    )
  }

  # 3. Validate replicate count match
  n_rep <- length(primary_design@variables$repweights)
  n_rep_ctrl <- length(control_design@variables$repweights)
  if (n_rep != n_rep_ctrl) {
    cli::cli_abort(
      c(
        "x" = "{.arg primary_design} and {.arg control_design} have different numbers of replicates.",
        "i" = "{.arg primary_design} has {n_rep} replicate(s); {.arg control_design} has {n_rep_ctrl}."
      ),
      class = "surveywts_error_replicate_count_mismatch"
    )
  }

  # 4. Warn if replicate scheme differs
  type_p <- primary_design@variables$type
  type_c <- control_design@variables$type
  if (!identical(type_p, type_c)) {
    cli::cli_warn(
      c(
        "!" = "Replicate schemes differ: {.arg primary_design} uses {.val {type_p}}, {.arg control_design} uses {.val {type_c}}.",
        "i" = "Mismatched schemes may produce non-standard variance estimates due to scale-factor differences."
      ),
      class = "surveywts_warning_replicate_scheme_mismatch"
    )
  }

  # 5-7. Validate formula and variables
  .validate_formula(formula)
  .validate_formula_variables(formula, primary_design@data, "primary_design")
  .validate_formula_variables(formula, control_design@data, "control_design")

  # 8. Merge control defaults
  control <- utils::modifyList(list(maxit = 50L, epsilon = 1e-7), control)

  # 9. Derive calibration function
  calfun <- switch(method,
    raking = survey::cal.raking,
    linear = survey::cal.linear,
    logit  = survey::cal.logit
  )

  # 10. Convert both designs to svyrep.design
  primary_svyrep <- .to_svyrep_design(primary_design)
  control_svyrep <- .to_svyrep_design(control_design)

  # Capture before-calibration weight stats
  wt_col <- primary_design@variables$weights
  before_stats <- .compute_weight_stats(primary_design@data[[wt_col]])

  # 11. Calibrate, catching convergence warnings and errors
  converged <- TRUE
  conv_msg <- NULL
  calibrated <- tryCatch(
    suppressMessages(
      withCallingHandlers(
        svrep::calibrate_to_sample(
          primary_rep_design = primary_svyrep,
          control_rep_design = control_svyrep,
          cal_formula        = formula,
          calfun             = calfun,
          bounds             = bounds,
          maxit              = control$maxit,
          epsilon            = control$epsilon,
          verbose            = FALSE
        ),
        warning = function(w) {
          msg <- conditionMessage(w)
          if (grepl("converge", msg, ignore.case = TRUE)) {
            converged <<- FALSE
            conv_msg  <<- msg
            invokeRestart("muffleWarning")
          }
        }
      )
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "x" = "Calibration failed.",
          "i" = "{conditionMessage(e)}",
          "v" = "Try increasing {.code control$maxit} or relaxing {.code control$epsilon}."
        ),
        class = "surveywts_error_calibration_not_converged"
      )
    }
  )

  if (!converged) {
    cli::cli_abort(
      c(
        "x" = "Calibration did not converge.",
        "i" = "{conv_msg}",
        "v" = "Try increasing {.code control$maxit} or relaxing {.code control$epsilon}."
      ),
      class = "surveywts_error_calibration_not_converged"
    )
  }

  # 12. Extract updated weights
  w_full <- stats::weights(calibrated, type = "sampling")
  w_rep  <- stats::weights(calibrated, type = "analysis")  # n x R matrix

  # 13. Warn on negative full-sample weights (linear only; not per-replicate)
  if (any(w_full < 0)) {
    cli::cli_warn(
      c(
        "!" = "Linear calibration produced {sum(w_full < 0)} negative full-sample weight(s).",
        "i" = "Negative weights arise when the calibration adjustment is very large. Consider {.val raking} instead.",
        "i" = "Negative weights have been clipped to the smallest positive double to preserve design validity."
      ),
      class = "surveywts_warning_negative_calibrated_weights"
    )
    w_full <- pmax(w_full, .Machine$double.eps)
  }

  # 14. Write weights back into primary_design
  repwt_cols <- primary_design@variables$repweights
  updated_data <- primary_design@data
  updated_data[[wt_col]] <- w_full
  for (i in seq_along(repwt_cols)) {
    updated_data[[repwt_cols[[i]]]] <- w_rep[, i]
  }
  primary_design@data <- updated_data

  # 15. Append history entry
  after_stats <- .compute_weight_stats(w_full)
  history_entry <- .make_history_entry(
    step       = length(primary_design@metadata@weighting_history) + 1L,
    operation  = "sample_calibration_replicate",
    weight_col = wt_col,
    call_str   = call_str,
    parameters = list(
      formula              = deparse(formula),
      method               = method,
      n_replicates         = n_rep,
      control_design_class = class(control_design)[[1L]],
      n_replicates_control = n_rep_ctrl
    ),
    before_stats = before_stats,
    after_stats  = after_stats
  )
  meta <- primary_design@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  primary_design@metadata <- meta

  primary_design
}

# ============================================================================
# calibrate_to_estimate()
# ============================================================================

#' Calibrate a replicate design to control totals with uncertainty
#'
#' Adjusts the weights of `design` to match control totals specified as a
#' point estimate vector and an associated variance-covariance matrix.
#' Replicate weights are calibrated to perturbed versions of the estimate,
#' propagating the uncertainty in the control totals into the variance
#' estimates.
#'
#' @param design A `survey_replicate` design to calibrate.
#' @param formula A one-sided formula specifying calibration variables,
#'   e.g., `~ age_group + sex`. All variables must exist in `design`.
#' @param estimate Named numeric vector of control totals. Names must match
#'   the column names returned by
#'   `survey::svytotal(formula, .to_svyrep_design(design))`.
#' @param vcov_estimate Numeric matrix. Variance-covariance of `estimate`.
#'   Must be symmetric positive definite with dimensions
#'   `length(estimate) x length(estimate)`.
#' @param method Calibration method: `"raking"`, `"linear"`, or `"logit"`.
#'   Same semantics as [calibrate_to_survey()].
#' @param bounds Named list with `lower` and `upper` weight bounds.
#'   Default: `list(lower = -Inf, upper = Inf)`.
#' @param control Named list of convergence parameters, merged with defaults
#'   `list(maxit = 50, epsilon = 1e-7)`.
#'
#' @details
#' `method = "logit"` requires finite bounds. See [calibrate_to_survey()]
#' for details.
#'
#' @note
#' This function assumes the control totals are approximately multivariate
#' normally distributed (i.e., the sampling distribution of `estimate` is
#' well-approximated by a multivariate normal with mean `estimate` and
#' covariance `vcov_estimate`). This assumption is satisfied by the CLT for
#' large control surveys. For small control samples or strongly non-normal
#' sampling distributions, the resulting variance estimates may be misleading.
#' Additionally, the function treats `estimate` as if the true population
#' totals were known; estimation error in the control survey is incorporated
#' only through `vcov_estimate`, not through any model of the data-generating
#' process.
#'
#' @return A `survey_replicate` with updated full-sample and replicate weights
#'   and a new `"sample_calibration_estimate"` entry appended to
#'   `@metadata@weighting_history`.
#'
#' @family sample-calibration
#' @export
calibrate_to_estimate <- function(
  design,
  formula,
  estimate,
  vcov_estimate,
  method = c("raking", "linear", "logit"),
  bounds = list(lower = -Inf, upper = Inf),
  control = list()
) {
  method <- match.arg(method)
  call_str <- deparse(match.call())

  # 1. Validate design
  if (!S7::S7_inherits(design, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg design} must be a {.cls survey_replicate}.",
        "i" = "Got {.cls {class(design)[[1L]]}}."
      ),
      class = "surveywts_error_primary_not_replicate"
    )
  }

  # 2-3. Validate formula
  .validate_formula(formula)
  .validate_formula_variables(formula, design@data, "design")

  # 4. Compute expected estimate names via svytotal on the converted design
  design_svyrep <- .to_svyrep_design(design)
  withCallingHandlers(
    {
      ref_tot <- survey::svytotal(formula, design_svyrep)
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  expected_names <- names(stats::coef(ref_tot))
  expected_len <- length(expected_names)

  # 5a. Named check
  if (is.null(names(estimate))) {
    cli::cli_abort(
      c(
        "x" = "{.arg estimate} must be a named numeric vector.",
        "i" = "Provide names matching {.fn survey::svytotal} output for {.code {deparse(formula)}}: {.val {expected_names}}."
      ),
      class = "surveywts_error_estimate_not_named"
    )
  }

  # 5b. NA check
  if (anyNA(estimate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg estimate} contains {sum(is.na(estimate))} NA value(s).",
        "i" = "All control total estimates must be non-missing."
      ),
      class = "surveywts_error_estimate_has_na"
    )
  }

  # 5c. Length check
  if (length(estimate) != expected_len) {
    cli::cli_abort(
      c(
        "x" = "{.arg estimate} has {length(estimate)} element(s); expected {expected_len}.",
        "i" = "Expected names: {.val {expected_names}}."
      ),
      class = "surveywts_error_estimate_length_mismatch"
    )
  }

  # 5d. Names check (order-independent)
  if (!setequal(names(estimate), expected_names)) {
    cli::cli_abort(
      c(
        "x" = "Names of {.arg estimate} do not match expected calibration variable names.",
        "i" = "Got: {.val {names(estimate)}}.",
        "i" = "Expected: {.val {expected_names}}."
      ),
      class = "surveywts_error_estimate_names_mismatch"
    )
  }

  # 6a. vcov NA check first (per spec sectionIV Rule 3)
  if (anyNA(vcov_estimate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg vcov_estimate} contains {sum(is.na(vcov_estimate))} NA value(s).",
        "i" = "The variance-covariance matrix must be fully observed."
      ),
      class = "surveywts_error_vcov_has_na"
    )
  }

  # 6b. Dimension check
  if (!identical(dim(vcov_estimate), c(expected_len, expected_len))) {
    cli::cli_abort(
      c(
        "x" = "{.arg vcov_estimate} must be a {expected_len} x {expected_len} matrix.",
        "i" = "Got dimensions {nrow(vcov_estimate)} x {ncol(vcov_estimate)}."
      ),
      class = "surveywts_error_vcov_dimension_mismatch"
    )
  }

  # 6c. Symmetry check (tolerance 1e-8)
  max_asym <- max(abs(vcov_estimate - t(vcov_estimate)))
  if (max_asym > 1e-8) {
    cli::cli_abort(
      c(
        "x" = "{.arg vcov_estimate} is not symmetric (max asymmetry = {signif(max_asym, 3)}).",
        "i" = "The symmetry tolerance is 1e-8.",
        "v" = "Use {.code (vcov_estimate + t(vcov_estimate)) / 2} to symmetrize."
      ),
      class = "surveywts_error_vcov_not_symmetric"
    )
  }

  # 6d. Cholesky (positive-definiteness) check
  tryCatch(
    chol(vcov_estimate),
    error = function(e) {
      cli::cli_abort(
        c(
          "x" = "{.arg vcov_estimate} is not positive definite (Cholesky factorization failed).",
          "i" = "Singular or indefinite matrices are not valid variance-covariance matrices.",
          "v" = "Ensure all eigenvalues are strictly positive."
        ),
        class = "surveywts_error_vcov_cholesky_failed"
      )
    }
  )

  # 7. Merge control defaults
  control <- utils::modifyList(list(maxit = 50L, epsilon = 1e-7), control)

  # 8. Derive calibration function
  calfun <- switch(method,
    raking = survey::cal.raking,
    linear = survey::cal.linear,
    logit  = survey::cal.logit
  )

  # 9. Capture before stats
  wt_col <- design@variables$weights
  before_stats <- .compute_weight_stats(design@data[[wt_col]])

  # 10. Calibrate, catching convergence warnings and errors
  converged <- TRUE
  conv_msg <- NULL
  calibrated <- tryCatch(
    suppressMessages(
      withCallingHandlers(
        svrep::calibrate_to_estimate(
          rep_design    = design_svyrep,
          estimate      = estimate,
          vcov_estimate = vcov_estimate,
          cal_formula   = formula,
          calfun        = calfun,
          bounds        = bounds,
          maxit         = control$maxit,
          epsilon       = control$epsilon,
          verbose       = FALSE
        ),
        warning = function(w) {
          msg <- conditionMessage(w)
          if (grepl("converge", msg, ignore.case = TRUE)) {
            converged <<- FALSE
            conv_msg  <<- msg
            invokeRestart("muffleWarning")
          }
        }
      )
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "x" = "Calibration failed.",
          "i" = "{conditionMessage(e)}",
          "v" = "Try increasing {.code control$maxit} or relaxing {.code control$epsilon}."
        ),
        class = "surveywts_error_calibration_not_converged"
      )
    }
  )

  if (!converged) {
    cli::cli_abort(
      c(
        "x" = "Calibration did not converge.",
        "i" = "{conv_msg}",
        "v" = "Try increasing {.code control$maxit} or relaxing {.code control$epsilon}."
      ),
      class = "surveywts_error_calibration_not_converged"
    )
  }

  # 11. Extract updated weights
  w_full <- stats::weights(calibrated, type = "sampling")
  w_rep  <- stats::weights(calibrated, type = "analysis")  # n x R matrix

  # 12. Warn on negative full-sample weights
  if (any(w_full < 0)) {
    cli::cli_warn(
      c(
        "!" = "Linear calibration produced {sum(w_full < 0)} negative full-sample weight(s).",
        "i" = "Negative weights arise when the calibration adjustment is very large. Consider {.val raking} instead.",
        "i" = "Negative weights have been clipped to the smallest positive double to preserve design validity."
      ),
      class = "surveywts_warning_negative_calibrated_weights"
    )
    w_full <- pmax(w_full, .Machine$double.eps)
  }

  # 13. Write weights back into design
  repwt_cols <- design@variables$repweights
  n_rep <- length(repwt_cols)
  updated_data <- design@data
  updated_data[[wt_col]] <- w_full
  for (i in seq_along(repwt_cols)) {
    updated_data[[repwt_cols[[i]]]] <- w_rep[, i]
  }
  design@data <- updated_data

  # 14. Append history entry
  after_stats <- .compute_weight_stats(w_full)
  history_entry <- .make_history_entry(
    step       = length(design@metadata@weighting_history) + 1L,
    operation  = "sample_calibration_estimate",
    weight_col = wt_col,
    call_str   = call_str,
    parameters = list(
      formula        = deparse(formula),
      method         = method,
      n_replicates   = n_rep,
      estimate_names = names(estimate),
      vcov_dim       = dim(vcov_estimate)
    ),
    before_stats = before_stats,
    after_stats  = after_stats
  )
  meta <- design@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  design@metadata <- meta

  design
}
