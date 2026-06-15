# R/calibrate_to_survey.R
#
# calibrate_to_survey() - calibrate a replicate-weight design to
# population totals estimated from a control (reference) survey design.
# Delegates to svrep::calibrate_to_sample().

#' Calibrate replicate weights to a control survey
#'
#' Adjusts the full-sample and replicate weights of `primary_design` so that
#' its estimated totals for `variables` match those estimated from
#' `control_design`. Variance estimation correctly propagates the sampling
#' uncertainty of the control survey's estimates into the calibrated primary
#' design.
#'
#' @param primary_design A `survey_replicate` object. The design to be
#'   calibrated. Must have replicate weights.
#' @param control_design A `survey_replicate` object. The reference survey
#'   from which population totals are estimated. Must have replicate weights.
#' @param variables <[`tidy-select`][tidyselect::language]> Bare names of the
#'   calibration variables in `primary_design@data`. Must be present in both
#'   `primary_design` and `control_design`.
#' @param method Calibration method. One of `"rake"` (default), `"linear"`,
#'   or `"logit"`. Matched with [rlang::arg_match()].
#' @param bounds Numeric vector of length 2: `c(lower, upper)`. Bounds on
#'   the calibrated-to-starting-weight ratio. Default `c(-Inf, Inf)`.
#'   Note: per-unit `bounds_scale` is not supported; use scalar bounds only.
#' @param unit_scale `NULL` or a positive numeric vector of length
#'   `nrow(primary_design@data)`. Passed to svrep as the `variance` argument
#'   (per-unit variance scaling). `NULL` means no scaling.
#' @param reference_design A `survey_taylor` object or `NULL`. Stored in the
#'   history entry for provenance only; not used in computation.
#' @param control Named list of calibration control parameters. Known keys:
#'   - `maxit`: maximum iterations (default `50L`)
#'   - `epsilon`: convergence tolerance (default `1e-7`)
#'   - `control_col_matches`: passed to svrep for reproducible
#'     primary-to-control replicate matching; not stored in history.
#'   Unknown keys trigger a `surveywts_warning_control_param_ignored` warning.
#'
#' @return A `survey_replicate` object with updated full-sample and replicate
#'   weights. A history entry with `operation = "calibrate_to_survey"` is
#'   appended to `@metadata@weighting_history`.
#'
#' @details
#'   Both `primary_design` and `control_design` must be `survey_replicate`
#'   objects because replicate weights are required to propagate the
#'   uncertainty of the control survey's estimated totals into the variance
#'   of the calibrated design. Taylor-linearization designs are not
#'   sufficient for this purpose.
#'
#'   When `method = "logit"`, finite bounds are required by the algorithm;
#'   the default `c(-Inf, Inf)` is passed through and svrep applies logit
#'   calibration. When `method = "linear"`, any negative full-sample weights
#'   are clipped to `.Machine$double.eps` with a warning, but replicate
#'   weights are not clipped.
#'
#' @references
#'   Fuller, W.A. (1998). Replication variance estimation for two-phase
#'   samples. *Statistica Sinica*, 8, 1153--1164.
#'
#'   Opsomer, J.D. and Erciulescu, A. (2021). Replication variance estimation
#'   after sample-based calibration. *Survey Methodology*, 47, 265--277.
#'
#' @examples
#' data(api, package = "survey")
#'
#' # Build simple designs from apiclus1 and apisrs
#' set.seed(1)
#' d_primary <- survey::svydesign(id = ~1, weights = ~pw, data = apiclus1)
#' d_control <- survey::svydesign(id = ~1, weights = ~pw, data = apisrs)
#'
#' # Create bootstrap replicate weights
#' boot_primary <- svrep::as_bootstrap_design(
#'   d_primary,
#'   type = "Rao-Wu-Yue-Beaumont",
#'   replicates = 20
#' )
#' boot_control <- svrep::as_bootstrap_design(
#'   d_control,
#'   type = "Rao-Wu-Yue-Beaumont",
#'   replicates = 20
#' )
#'
#' # Convert to surveywts survey_replicate objects
#' primary <- surveycore::survey_replicate(
#'   data = cbind(
#'     as.data.frame(boot_primary$variables),
#'     as.data.frame(as.matrix(boot_primary$repweights))
#'   ),
#'   variables = list(
#'     weights    = "pw",
#'     repweights = paste0("V", seq_len(ncol(boot_primary$repweights))),
#'     type       = boot_primary$type,
#'     scale      = boot_primary$scale,
#'     rscales    = boot_primary$rscales,
#'     mse        = isTRUE(boot_primary$mse)
#'   )
#' )
#' control <- surveycore::survey_replicate(
#'   data = cbind(
#'     as.data.frame(boot_control$variables),
#'     as.data.frame(as.matrix(boot_control$repweights))
#'   ),
#'   variables = list(
#'     weights    = "pw",
#'     repweights = paste0("V", seq_len(ncol(boot_control$repweights))),
#'     type       = boot_control$type,
#'     scale      = boot_control$scale,
#'     rscales    = boot_control$rscales,
#'     mse        = isTRUE(boot_control$mse)
#'   )
#' )
#'
#' result <- surveywts::calibrate_to_survey(
#'   primary_design = primary,
#'   control_design = control,
#'   variables      = c(stype)
#' )
#'
#' @family sample-calibration
#' @export
calibrate_to_survey <- function(
  primary_design,
  control_design,
  variables,
  method = c("rake", "linear", "logit"),
  bounds = c(-Inf, Inf),
  unit_scale = NULL,
  reference_design = NULL,
  control = list()
) {
  call_str <- paste0(deparse(match.call()), collapse = " ")
  method   <- rlang::arg_match(method)

  # ---- 1. primary_design class check ----------------------------------------
  if (!S7::S7_inherits(primary_design, surveycore::survey_replicate)) {
    cls <- class(primary_design)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg primary_design} must be a {.cls survey_replicate}, ",
          "got {.cls {cls}}."
        ),
        "i" = paste0(
          "Replicate weights are required to propagate control-survey ",
          "uncertainty."
        ),
        "v" = paste0(
          "Use {.fn create_bootstrap_weights} or another ",
          "{.fn create_*_weights} function to add replicate weights."
        )
      ),
      class = "surveywts_error_primary_not_replicate"
    )
  }

  # ---- 2. control_design class check ----------------------------------------
  if (!S7::S7_inherits(control_design, surveycore::survey_replicate)) {
    cls <- class(control_design)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg control_design} must be a {.cls survey_replicate}, ",
          "got {.cls {cls}}."
        ),
        "i" = paste0(
          "Replicate weights are required to propagate control-survey ",
          "uncertainty."
        ),
        "v" = paste0(
          "Use {.fn create_bootstrap_weights} or another ",
          "{.fn create_*_weights} function to add replicate weights."
        )
      ),
      class = "surveywts_error_control_not_replicate"
    )
  }

  # ---- 3. reference_design check (if non-NULL) ------------------------------
  if (!is.null(reference_design)) {
    if (!S7::S7_inherits(reference_design, surveycore::survey_taylor)) {
      cls <- class(reference_design)[[1L]]
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg reference_design} must be a {.cls survey_taylor} or ",
            "{.code NULL}, got {.cls {cls}}."
          ),
          "i" = "{.arg reference_design} is used for provenance tracking only."
        ),
        class = "surveywts_error_reference_design_not_taylor"
      )
    }
  }

  # ---- 4. unit_scale validation (if non-NULL) --------------------------------
  if (!is.null(unit_scale)) {
    .validate_unit_scale(unit_scale, nrow(primary_design@data))
  }

  # ---- 5. control unknown-key warning + extraction + merge with defaults -----
  known_keys <- c("maxit", "epsilon", "control_col_matches")
  unknown    <- setdiff(names(control), known_keys)
  for (key in unknown) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Unknown {.arg control} parameter {.val {key}} was ignored."
        ),
        "i" = paste0(
          "Known keys for {.fn calibrate_to_survey}: ",
          "{.val maxit}, {.val epsilon}, {.val control_col_matches}."
        )
      ),
      class = "surveywts_warning_control_param_ignored"
    )
  }

  # Extract control_col_matches (not stored in history)
  control_col_matches <- control[["control_col_matches"]]

  # Build effective control (without control_col_matches)
  ctrl_defaults <- list(maxit = 50L, epsilon = 1e-7)
  ctrl_clean    <- control[intersect(names(control), c("maxit", "epsilon"))]
  ctrl          <- utils::modifyList(ctrl_defaults, ctrl_clean)

  # ---- 6. variables tidy-select resolution -----------------------------------
  vars_quo <- rlang::enquo(variables)
  var_pos  <- tryCatch(
    tidyselect::eval_select(vars_quo, data = primary_design@data),
    error = function(e) {
      cli::cli_abort(
        c(
          "x" = "Calibration variables not found in {.arg primary_design}.",
          "i" = "Tidy-select error: {conditionMessage(e)}"
        ),
        class = "surveywts_error_variables_not_found"
      )
    }
  )
  if (length(var_pos) == 0L) {
    cli::cli_abort(
      c(
        "x" = "No calibration variables selected.",
        "i" = "The {.arg variables} selection returned an empty set.",
        "v" = "Provide at least one variable present in {.arg primary_design}."
      ),
      class = "surveywts_error_variables_not_found"
    )
  }
  var_names <- names(var_pos)

  # ---- 7. Replicate-scheme type mismatch warning ----------------------------
  primary_type <- primary_design@variables$type
  control_type <- control_design@variables$type
  if (!is.null(primary_type) && !is.null(control_type) &&
      primary_type != control_type) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Replicate scheme mismatch: primary is {.val {primary_type}}, ",
          "control is {.val {control_type}}."
        ),
        "i" = paste0(
          "Mixing replicate schemes may produce inaccurate variance estimates."
        )
      ),
      class = "surveywts_warning_replicate_scheme_mismatch"
    )
  }

  # ---- 8. Convert to svrep objects and call calibrate_to_sample() -----------
  primary_svyrep  <- .to_svyrep(primary_design)
  control_svyrep  <- .to_svyrep(control_design)

  cal_formula <- stats::reformulate(var_names)
  calfun      <- .method_to_calfun(method)
  svrep_bounds <- list(lower = bounds[[1L]], upper = bounds[[2L]])

  wt_col_name <- primary_design@variables$weights
  before_weights <- primary_design@data[[wt_col_name]]
  before_stats   <- .compute_weight_stats(before_weights)

  cal_args <- list(
    primary_rep_design  = primary_svyrep,
    control_rep_design  = control_svyrep,
    cal_formula         = cal_formula,
    calfun              = calfun,
    bounds              = svrep_bounds,
    maxit               = as.integer(ctrl$maxit),
    epsilon             = ctrl$epsilon,
    variance            = unit_scale
  )
  if (!is.null(control_col_matches)) {
    cal_args$control_col_matches <- control_col_matches
  }

  cal_result <- tryCatch(
    withCallingHandlers(
      do.call(.svrep_calibrate_to_sample, cal_args),
      warning = function(w) {
        msg <- conditionMessage(w)
        if (grepl("converge", msg, ignore.case = TRUE)) {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Sample-based calibration did not converge after ",
                "{ctrl$maxit} iterations."
              ),
              "i" = "svrep::calibrate_to_sample() reported: {msg}",
              "v" = paste0(
                "Increase {.code control$maxit}, relax ",
                "{.code control$epsilon}, or verify that the variables ",
                "are present in both designs."
              )
            ),
            class = "surveywts_error_calibration_not_converged"
          )
        }
        # Muffle non-convergence warnings from svrep (e.g., mse reset)
        tryInvokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      if (inherits(e, "surveywts_error_calibration_not_converged")) {
        stop(e)
      }
      cli::cli_abort(
        c(
          "x" = "svrep::calibrate_to_sample() encountered an error.",
          "i" = "svrep reported: {conditionMessage(e)}"
        ),
        class = "surveywts_error_calibration_failed"
      )
    }
  )

  # ---- 9. Extract new weights and clip negatives (linear only) ---------------
  new_full_weights <- as.numeric(cal_result$pweights)

  if (method == "linear") {
    n_neg <- sum(new_full_weights < 0)
    if (n_neg > 0L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Linear calibration produced {n_neg} negative full-sample ",
            "weight(s)."
          ),
          "i" = paste0(
            "Negative weights have been clipped to ",
            "{.code .Machine$double.eps}."
          ),
          "i" = paste0(
            "Consider using {.code method = \"logit\"} with finite bounds ",
            "to avoid negative weights."
          )
        ),
        class = "surveywts_warning_negative_calibrated_weights"
      )
      new_full_weights[new_full_weights < 0] <- .Machine$double.eps
    }
  }

  # ---- 10. Write weights back, append history --------------------------------
  rep_matrix  <- as.matrix(cal_result$repweights)
  n_rep       <- ncol(rep_matrix)
  rep_names   <- primary_design@variables$repweights

  # If svrep changed the number of replicates, rebuild rep names
  if (n_rep != length(rep_names)) {
    rep_names <- paste0("rep_", seq_len(n_rep))
  }

  after_stats <- .compute_weight_stats(new_full_weights)

  history_params <- list(
    variables          = var_names,
    method             = method,
    bounds             = bounds,
    unit_scale         = unit_scale,
    n_replicates       = length(primary_design@variables$repweights),
    control_design_class = class(control_design)[[1L]],
    n_replicates_control = length(control_design@variables$repweights),
    targets_from_reference = !is.null(reference_design),
    reference_design   = if (!is.null(reference_design)) {
      list(class = class(reference_design)[[1L]],
           n = nrow(reference_design@data))
    } else {
      NULL
    },
    control            = ctrl
  )

  current_history <- primary_design@metadata@weighting_history
  history_entry   <- .make_history_entry(
    step         = length(current_history) + 1L,
    operation    = "calibrate_to_survey",
    weight_col   = wt_col_name,
    call_str     = call_str,
    parameters   = history_params,
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = NULL
  )

  # Build new data frame: update full-sample weights + replicate weight columns
  new_data <- primary_design@data
  new_data[[wt_col_name]] <- new_full_weights
  rep_df <- as.data.frame(rep_matrix)
  names(rep_df) <- rep_names
  for (rn in rep_names) {
    new_data[[rn]] <- rep_df[[rn]]
  }

  result <- surveycore::survey_replicate(
    data      = new_data,
    variables = primary_design@variables,
    metadata  = primary_design@metadata
  )
  meta                   <- result@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  result@metadata        <- meta

  result
}

# ---------------------------------------------------------------------------
# Internal helpers used by calibrate_to_survey() and calibrate_to_estimate()
# ---------------------------------------------------------------------------

# Convert a survey_replicate S7 object to a survey package svyrep.design
# object that svrep can consume.
.to_svyrep <- function(design) {
  wt_col   <- design@variables$weights
  rep_cols <- design@variables$repweights
  data_df  <- as.data.frame(design@data)

  pweights <- data_df[[wt_col]]
  repwts   <- as.matrix(data_df[, rep_cols, drop = FALSE])

  svy_obj <- survey::svydesign(ids = ~1, weights = ~1, data = data_df)

  # Build a svyrep.design object manually. Suppress the "combined weights"
  # warning that fires when mean(repweights) << mean(sampling weights) --
  # this is expected for bootstrap designs with large sampling weights.
  result <- suppressWarnings(
    survey::svrepdesign(
      data       = data_df,
      repweights = repwts,
      weights    = pweights,
      type       = design@variables$type %||% "bootstrap",
      scale      = design@variables$scale,
      rscales    = design@variables$rscales,
      mse        = isTRUE(design@variables$mse)
    )
  )
  result
}

# Thin wrapper around svrep::calibrate_to_sample().
# Exists as a named function in the surveywts namespace so tests can mock it.
.svrep_calibrate_to_sample <- function(...) svrep::calibrate_to_sample(...)

# Map method string to survey calfun object
.method_to_calfun <- function(method) {
  switch(
    method,
    "rake"   = survey::cal.raking,
    "linear" = survey::cal.linear,
    "logit"  = survey::cal.logit,
    survey::cal.raking  # default
  )
}
