# R/calibrate_to_estimate.R
#
# calibrate_to_estimate() - calibrate a replicate-weight design to
# externally-supplied population count estimates, with an associated
# variance-covariance matrix. Delegates to svrep::calibrate_to_estimate().

#' Reweight to externally estimated population totals
#'
#' Adjusts the full-sample and replicate weights of `design` so that its
#' estimated totals for the variables named in `targets` match the supplied
#' count totals. The `vcov_estimate` matrix propagates the uncertainty of
#' those external estimates into the calibrated design's variance estimates.
#'
#' @param design A `survey_replicate` or `survey_nonprob` object with
#'   replicate weights. The design to be calibrated. Must have replicate
#'   weights populated.
#' @param targets A named list of population count totals. Each element is
#'   a named numeric vector whose names are the level labels for that variable
#'   in `design@data`. All values must be strictly positive. The list name is
#'   the variable name in `design@data`.
#' @param vcov_estimate A numeric matrix of dimension `k x k`, where
#'   `k = length(unlist(targets))`. The variance-covariance matrix of the
#'   population estimates. Must be symmetric (tolerance `1e-8`) and positive
#'   definite.
#' @param method Calibration method. One of `"rake"` (default), `"linear"`,
#'   or `"logit"`. Matched with [rlang::arg_match()].
#' @param bounds Numeric vector of length 2: `c(lower, upper)`. Bounds on the
#'   calibrated-to-starting-weight ratio. Default `c(-Inf, Inf)`.
#'   Note: per-unit `bounds_scale` is not supported; use scalar bounds only.
#' @param unit_scale `NULL` or a positive numeric vector of length
#'   `nrow(design@data)`. Passed to svrep as the `variance` argument
#'   (per-unit variance scaling). `NULL` means no scaling.
#' @param reference_design A `survey_taylor` object or `NULL`. Stored in the
#'   history entry for provenance only; not used in computation.
#' @param control Named list of calibration control parameters. Known keys:
#'   - `maxit`: maximum iterations (default `50L`)
#'   - `epsilon`: convergence tolerance (default `1e-7`)
#'   - `col_selection`: passed to svrep for reproducible replicate selection;
#'     not stored in history.
#'   Unknown keys trigger a `surveywts_warning_control_param_ignored` warning.
#'
#' @returns A calibrated design object whose class matches the class of
#'   `design`: a `survey_nonprob` input returns a `survey_nonprob`; a
#'   `survey_replicate` input returns a `survey_replicate`. Updated
#'   full-sample and replicate weights are written back. A new entry with
#'   `operation = "calibrate_to_estimate"` is appended to the weighting
#'   history.
#'
#' @details
#'   `design` must carry replicate weights — either as a `survey_replicate`
#'   object or as a `survey_nonprob` object to which replicate weights have
#'   been added. Taylor-linearization designs are not sufficient for this
#'   purpose because replicate weights are required to propagate the
#'   uncertainty of the external estimates (captured in `vcov_estimate`) into
#'   the variance of the calibrated design.
#'
#'   The `targets` list is converted to a named vector via `unlist(targets)`,
#'   and a calibration formula is built from `names(targets)`. Ensure that
#'   the names of each `targets` element exactly match the levels in the
#'   corresponding column of `design@data` (for factor columns: `levels()`;
#'   for character columns: `unique()`).
#'
#'   When `method = "linear"`, any negative full-sample weights are clipped to
#'   `.Machine$double.eps` with a warning; replicate weights are not clipped.
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
#' set.seed(1)
#' d_primary <- survey::svydesign(id = ~1, weights = ~pw, data = apiclus1)
#' boot_primary <- svrep::as_bootstrap_design(
#'   d_primary,
#'   type = "Rao-Wu-Yue-Beaumont",
#'   replicates = 20
#' )
#'
#' # Convert to surveywts survey_replicate object
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
#'
#' # Known population counts by school type
#' targets <- list(
#'   stype = c(E = 4421, H = 755, M = 1018)
#' )
#' vcov_est <- diag(c(10000, 1000, 2000))
#'
#' result <- surveywts::calibrate_to_estimate(
#'   design        = primary,
#'   targets       = targets,
#'   vcov_estimate = vcov_est
#' )
#'
#' @seealso [calibrate_to_survey()]
#' @family sample-calibration
#' @export
calibrate_to_estimate <- function(
  design,
  targets,
  vcov_estimate,
  method = c("rake", "linear", "logit"),
  bounds = c(-Inf, Inf),
  unit_scale = NULL,
  reference_design = NULL,
  control = list()
) {
  call_str <- paste0(deparse(match.call()), collapse = " ")
  method <- rlang::arg_match(method)

  # ---- 1. design class check ------------------------------------------------
  is_nonprob_design <- S7::S7_inherits(design, surveycore::survey_nonprob)
  if (
    !S7::S7_inherits(design, surveycore::survey_replicate) &&
      !is_nonprob_design
  ) {
    cls <- class(design)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg design} must be a {.cls survey_replicate} or a ",
          "{.cls survey_nonprob} with replicate weights, got {.cls {cls}}."
        ),
        "i" = paste0(
          "Replicate weights are required to propagate the uncertainty ",
          "of the external estimates."
        ),
        "v" = paste0(
          "Use {.fn create_bootstrap_weights} or another ",
          "{.fn create_*_weights} function to add replicate weights."
        )
      ),
      class = "surveywts_error_design_not_replicate"
    )
  }
  if (is_nonprob_design) {
    rw <- design@variables$repweights
    if (is.null(rw) || length(rw) == 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg design} is a {.cls survey_nonprob} but has no ",
            "replicate weights."
          ),
          "i" = paste0(
            "Replicate weights are required to propagate the uncertainty ",
            "of the external estimates."
          ),
          "v" = paste0(
            "Use {.fn create_bootstrap_weights} or another ",
            "{.fn create_*_weights} function to add replicate weights ",
            "before calibrating."
          )
        ),
        class = "surveywts_error_design_no_repweights"
      )
    }
  }

  # ---- 2. reference_design check (if non-NULL) ------------------------------
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

  # ---- 3. unit_scale validation (if non-NULL) --------------------------------
  if (!is.null(unit_scale)) {
    .validate_unit_scale(unit_scale, nrow(design@data))
  }

  # ---- 4. control unknown-key warning + extraction + merge with defaults -----
  known_keys <- c("maxit", "epsilon", "col_selection")
  unknown <- setdiff(names(control), known_keys)
  for (key in unknown) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Unknown {.arg control} parameter {.val {key}} was ignored."
        ),
        "i" = paste0(
          "Known keys for {.fn calibrate_to_estimate}: ",
          "{.val maxit}, {.val epsilon}, {.val col_selection}."
        )
      ),
      class = "surveywts_warning_control_param_ignored"
    )
  }

  # Extract col_selection (not stored in history)
  col_selection <- control[["col_selection"]]

  # Build effective control (without col_selection)
  ctrl_defaults <- list(maxit = 50L, epsilon = 1e-7)
  ctrl_clean <- control[intersect(names(control), c("maxit", "epsilon"))]
  ctrl <- utils::modifyList(ctrl_defaults, ctrl_clean)

  # ---- 5. targets named-list check (including empty-list check) -------------
  if (
    !is.list(targets) ||
      is.null(names(targets)) ||
      any(names(targets) == "") ||
      length(targets) == 0L
  ) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg targets} must be a non-empty named list with all ",
          "elements named."
        ),
        "i" = paste0(
          "Each name gives the variable in {.arg design@data}, and each ",
          "element is a named numeric vector of population count totals."
        )
      ),
      class = "surveywts_error_targets_not_named_list"
    )
  }

  # ---- 6. targets element named-numeric check --------------------------------
  for (nm in names(targets)) {
    el <- targets[[nm]]
    if (!is.numeric(el) || is.null(names(el)) || any(names(el) == "")) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg targets${.field {nm}}} must be a named numeric vector."
          ),
          "i" = paste0(
            "Got {.cls {class(el)[[1]]}} with ",
            if (is.null(names(el))) "no names" else "some empty names",
            "."
          ),
          "v" = paste0(
            "Supply count totals as e.g. ",
            "{.code c(level1 = 1000, level2 = 500)}."
          )
        ),
        class = "surveywts_error_targets_element_not_named"
      )
    }
  }

  # ---- 6b. targets element positivity check ----------------------------------
  for (nm in names(targets)) {
    el <- targets[[nm]]
    n_bad <- sum(is.na(el) | el <= 0)
    if (n_bad > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg targets${.field {nm}}} contains {n_bad} value(s) that ",
            "are NA or not strictly positive."
          ),
          "i" = "All population count totals must be > 0."
        ),
        class = "surveywts_error_targets_element_not_positive"
      )
    }
  }

  # ---- 7. targets variable names existence check in design@data -------------
  var_names <- names(targets)
  data_colnames <- names(design@data)
  missing_vars <- setdiff(var_names, data_colnames)
  if (length(missing_vars) > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Calibration variable(s) not found in {.arg design}: ",
          "{.and {.field {missing_vars}}}."
        ),
        "i" = paste0(
          "Available columns: ",
          "{.and {.field {data_colnames}}}."
        )
      ),
      class = "surveywts_error_variables_not_found"
    )
  }

  # ---- 7a. targets level-label mismatch check --------------------------------
  for (nm in names(targets)) {
    col <- design@data[[nm]]
    if (is.factor(col)) {
      data_levels <- levels(col)
    } else {
      data_levels <- sort(unique(as.character(col)))
    }
    target_levels <- sort(names(targets[[nm]]))
    data_levels <- sort(data_levels)

    if (!identical(data_levels, target_levels)) {
      missing_in_tgt <- setdiff(data_levels, target_levels)
      extra_in_tgt <- setdiff(target_levels, data_levels)
      detail <- character(0)
      if (length(missing_in_tgt) > 0L) {
        detail <- c(
          detail,
          paste0(
            "Levels in data but not in targets: ",
            paste(missing_in_tgt, collapse = ", ")
          )
        )
      }
      if (length(extra_in_tgt) > 0L) {
        detail <- c(
          detail,
          paste0(
            "Levels in targets but not in data: ",
            paste(extra_in_tgt, collapse = ", ")
          )
        )
      }
      cli::cli_abort(
        c(
          "x" = paste0(
            "Level labels in {.arg targets${.field {nm}}} do not exactly ",
            "match the levels in {.arg design@data${.field {nm}}}."
          ),
          "i" = paste(detail, collapse = "; ")
        ),
        class = "surveywts_error_targets_levels_mismatch"
      )
    }
  }

  # ---- 8. vcov_estimate NA check --------------------------------------------
  n_na_vcov <- sum(is.na(vcov_estimate))
  if (n_na_vcov > 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg vcov_estimate} contains {n_na_vcov} NA value(s).",
        "i" = "The variance-covariance matrix must be fully observed."
      ),
      class = "surveywts_error_vcov_has_na"
    )
  }

  # ---- 9. vcov_estimate dimension check -------------------------------------
  k <- length(unlist(targets))
  vcov_dim <- dim(vcov_estimate)
  if (is.null(vcov_dim) || !identical(as.integer(vcov_dim), c(k, k))) {
    actual_dim <- if (!is.null(vcov_dim)) {
      paste0(vcov_dim[[1L]], " x ", vcov_dim[[2L]])
    } else {
      "not a matrix"
    }
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg vcov_estimate} must be {k} x {k} ",
          "(one row/column per element of {.code unlist(targets)})."
        ),
        "i" = "Got {actual_dim}."
      ),
      class = "surveywts_error_vcov_dimension_mismatch"
    )
  }

  # ---- 10. vcov_estimate symmetry check (tolerance 1e-8) --------------------
  max_asym <- max(abs(vcov_estimate - t(vcov_estimate)))
  if (max_asym > 1e-8) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg vcov_estimate} is not symmetric: ",
          "max(|V - V^T|) = {max_asym}."
        ),
        "i" = "Symmetry tolerance is 1e-8.",
        "v" = "Symmetrize with {.code (vcov + t(vcov)) / 2}."
      ),
      class = "surveywts_error_vcov_not_symmetric"
    )
  }

  # ---- 11. vcov_estimate PD check (Cholesky) --------------------------------
  chol_result <- tryCatch(
    chol(vcov_estimate),
    error = function(e) e
  )
  if (inherits(chol_result, "error")) {
    cli::cli_abort(
      c(
        "x" = "{.arg vcov_estimate} is not positive definite.",
        "i" = paste0(
          "Cholesky decomposition failed: ",
          "{conditionMessage(chol_result)}"
        ),
        "v" = paste0(
          "Use a valid variance-covariance matrix ",
          "(all eigenvalues > 0)."
        )
      ),
      class = "surveywts_error_vcov_cholesky_failed"
    )
  }

  # ---- 12. Convert to svrep, call calibrate_to_estimate() ------------------
  design_svyrep <- .to_svyrep(design)

  # Build the estimate vector with names in the format expected by svrep:
  # svrep::svytotal(~varname) returns names like "varnameLevel" (concatenated,
  # no dot separator). We replicate that naming convention here.
  estimate <- stats::setNames(
    as.numeric(unlist(targets)),
    unlist(lapply(names(targets), function(nm) {
      paste0(nm, names(targets[[nm]]))
    }))
  )
  cal_formula <- stats::reformulate(var_names)
  calfun <- .method_to_calfun(method)
  svrep_bounds <- list(lower = bounds[[1L]], upper = bounds[[2L]])

  wt_col_name <- design@variables$weights
  before_weights <- design@data[[wt_col_name]]
  before_stats <- .compute_weight_stats(before_weights)

  cal_args <- list(
    rep_design = design_svyrep,
    estimate = estimate,
    vcov_estimate = vcov_estimate,
    cal_formula = cal_formula,
    calfun = calfun,
    bounds = svrep_bounds,
    maxit = as.integer(ctrl$maxit),
    epsilon = ctrl$epsilon,
    variance = unit_scale
  )
  if (!is.null(col_selection)) {
    cal_args$col_selection <- col_selection
  }

  cal_result <- tryCatch(
    withCallingHandlers(
      do.call(.svrep_calibrate_to_estimate, cal_args),
      warning = function(w) {
        msg <- conditionMessage(w)
        if (grepl("converge", msg, ignore.case = TRUE)) {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Calibration to estimate did not converge after ",
                "{ctrl$maxit} iterations."
              ),
              "i" = "svrep::calibrate_to_estimate() reported: {msg}",
              "v" = paste0(
                "Increase {.code control$maxit}, relax ",
                "{.code control$epsilon}, or verify the target counts ",
                "are consistent with the design."
              )
            ),
            class = "surveywts_error_calibration_not_converged"
          )
        }
        # Muffle non-convergence warnings from svrep
        tryInvokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      if (inherits(e, "surveywts_error_calibration_not_converged")) {
        stop(e)
      }
      cli::cli_abort(
        c(
          "x" = "svrep::calibrate_to_estimate() encountered an error.",
          "i" = "svrep reported: {conditionMessage(e)}"
        ),
        class = "surveywts_error_calibration_failed"
      )
    }
  )

  # ---- 13. Extract new weights and clip negatives (linear only) -------------
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

  # ---- 14. Write weights back, append history --------------------------------
  rep_matrix <- as.matrix(cal_result$repweights)
  n_rep <- ncol(rep_matrix)
  rep_names <- design@variables$repweights

  if (n_rep != length(rep_names)) {
    rep_names <- paste0("rep_", seq_len(n_rep))
  }

  after_stats <- .compute_weight_stats(new_full_weights)

  history_params <- list(
    variables = var_names,
    method = method,
    bounds = bounds,
    unit_scale = unit_scale,
    n_replicates = length(design@variables$repweights),
    targets = targets,
    vcov_dim = dim(vcov_estimate),
    targets_from_reference = !is.null(reference_design),
    reference_design = if (!is.null(reference_design)) {
      list(
        class = class(reference_design)[[1L]],
        n = nrow(reference_design@data)
      )
    } else {
      NULL
    },
    control = ctrl
  )

  current_history <- design@metadata@weighting_history
  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "calibrate_to_estimate",
    weight_col = wt_col_name,
    call_str = call_str,
    parameters = history_params,
    before_stats = before_stats,
    after_stats = after_stats,
    convergence = NULL
  )

  # Build new data: update full-sample weights + replicate weight columns
  new_data <- design@data
  new_data[[wt_col_name]] <- new_full_weights
  rep_df <- as.data.frame(rep_matrix)
  names(rep_df) <- rep_names
  for (rn in rep_names) {
    new_data[[rn]] <- rep_df[[rn]]
  }

  # ---- 15. Dispatch on design class for output constructor ------------------
  if (S7::S7_inherits(design, surveycore::survey_nonprob)) {
    result <- surveycore::survey_nonprob(
      data = new_data,
      variables = design@variables,
      metadata = design@metadata
    )
  } else {
    result <- surveycore::survey_replicate(
      data = new_data,
      variables = design@variables,
      metadata = design@metadata
    )
  }
  meta <- result@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  result@metadata <- meta

  result
}

# Thin wrapper around svrep::calibrate_to_estimate().
# Exists as a named function in the surveywts namespace so tests can mock it.
.svrep_calibrate_to_estimate <- function(...) svrep::calibrate_to_estimate(...)
