# R/replicate-weights.R
#
# create_bootstrap_weights(), create_jackknife_weights(),
# create_brr_weights(), create_gen_boot_weights(),
# create_gen_rep_weights(), create_sdr_weights()
# and all shared internal helpers.

# ============================================================================
# .validate_replicate_input()
# ============================================================================

.validate_replicate_input <- function(data) {
  if (inherits(data, "data.frame") || inherits(data, "weighted_df")) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} is a {.cls {class(data)[[1]]}}, not a survey design.",
        "i" = "This function requires a {.cls survey_taylor} or {.cls survey_nonprob} object.",
        "v" = "Convert with {.fn surveycore::as_survey}."
      ),
      class = "surveywts_error_not_survey_design"
    )
  }
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} is already a {.cls survey_replicate}.",
        "i" = "Replicate weights cannot be created from a design that already has replicates."
      ),
      class = "surveywts_error_already_replicate"
    )
  }
  if (!S7::S7_inherits(data, surveycore::survey_base)) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} is {.cls {cls}}, which is not a supported input class.",
        "i" = "Supported classes: {.cls survey_taylor} and {.cls survey_nonprob}.",
        "v" = "Use {.fn surveycore::as_survey} or {.fn surveycore::survey_nonprob}."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }
  invisible(TRUE)
}

# ============================================================================
# .validate_replicates_arg()
# ============================================================================

# Validates the `replicates` argument: accepts whole numbers, coerces to
# integer. Returns NULL if replicates is NULL (caller handles the NULL case).
# min_val defaults to 2; SDR passes min_val = 4.
.validate_replicates_arg <- function(replicates, min_val = 2L) {
  if (is.null(replicates)) return(NULL)
  if (!is.numeric(replicates) || length(replicates) != 1L || is.na(replicates)) {
    cli::cli_abort(
      c("x" = "{.arg replicates} must be a single number."),
      class = "surveywts_error_replicates_invalid"
    )
  }
  if (replicates %% 1 != 0) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be a whole number, not {.val {replicates}}.",
        "v" = "Use an integer value, e.g. {.code replicates = {round(replicates)}}."
      ),
      class = "surveywts_error_replicates_not_whole_number"
    )
  }
  if (replicates < min_val) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be at least {min_val}, got {.val {replicates}}."
      ),
      class = "surveywts_error_replicates_not_positive"
    )
  }
  as.integer(replicates)
}

# ============================================================================
# .snapshot_variables_for_history()
# ============================================================================

# Captures the full @variables list and a nonprob flag for the
# "replicate_creation" history entry. Used by as_taylor_design() to
# reconstruct the original Taylor design and detect nonprob sources.
# A boolean is used instead of a class string because attr(cls, "package")
# is unreliable for S7 classes and could produce "::survey_nonprob" if NULL.
.snapshot_variables_for_history <- function(data) {
  list(
    variables = data@variables,
    is_nonprob = S7::S7_inherits(data, surveycore::survey_nonprob)
  )
}

# ============================================================================
# .convert_and_call()
# ============================================================================

# Core conversion pipeline. Converts S7 design to svydesign, calls backend_fn,
# then manually constructs survey_replicate (bypassing from_svydesign() which
# has a bug in surveycore <= 0.8.2 where @variables$repweights is not populated).
#
# Arguments:
#   data          : survey_taylor or survey_nonprob
#   backend_fn    : function(svydesign) -> svyrep.design
#   method        : character(1) -- e.g. "bootstrap", "jackknife"
#   params        : named list of method-specific parameters for the history entry
#   seed          : integer(1) or NULL -- if non-NULL, withr::local_seed() is used
#   type_override : character(1) or NULL -- overrides svyrep_obj$type when set;
#                   used for gen-boot/gen-rep which return type = "other" from svrep
.convert_and_call <- function(data, backend_fn, method, params, seed = NULL,
                               type_override = NULL) {
  if (!is.null(seed)) withr::local_seed(seed)

  # survey_nonprob doesn't support as_svydesign(); build a simple SRS-weighted
  # design from the raw data and base weights so svrep can consume it.
  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    wt_col        <- data@variables$weights
    wt_formula    <- stats::as.formula(paste0("~", wt_col))
    svydesign_obj <- survey::svydesign(ids = ~1, weights = wt_formula, data = data@data)
  } else {
    svydesign_obj <- surveycore::as_svydesign(data)
  }

  svyrep_obj    <- backend_fn(svydesign_obj)

  # Extract replicate weight matrix. Both `matrix` (svrep bootstrap, gen-boot,
  # gen-rep) and `repweights_compressed` (survey JKn/BRR, svrep random-group JK)
  # support as.matrix().
  rep_matrix  <- as.matrix(svyrep_obj$repweights)
  n_rep       <- ncol(rep_matrix)
  rep_names   <- paste0("rep_", seq_len(n_rep))

  base_data   <- as.data.frame(svyrep_obj$variables)
  rep_df      <- as.data.frame(rep_matrix)
  names(rep_df) <- rep_names
  combined    <- cbind(base_data, rep_df)

  variables   <- list(
    weights    = data@variables$weights,
    repweights = rep_names,
    type       = if (!is.null(type_override)) type_override else svyrep_obj$type,
    scale      = svyrep_obj$scale,
    rscales    = svyrep_obj$rscales,
    fpc        = data@variables$fpc,
    fpctype    = if (!is.null(svyrep_obj$fpctype)) svyrep_obj$fpctype else "fraction",
    mse        = isTRUE(svyrep_obj$mse)
  )

  result    <- surveycore::survey_replicate(
    data      = combined,
    variables = variables,
    metadata  = data@metadata
  )

  # Append replicate_creation history entry. Snapshot the full @variables so
  # as_taylor_design() can reconstruct the original Taylor design.
  snapshot  <- .snapshot_variables_for_history(data)
  new_entry <- list(
    step          = length(data@metadata@weighting_history) + 1L,
    operation     = "replicate_creation",
    timestamp     = Sys.time(),
    method        = method,
    parameters    = params,
    source_design = snapshot
  )
  meta                      <- result@metadata
  meta@weighting_history    <- c(meta@weighting_history, list(new_entry))
  result@metadata           <- meta

  result
}

# ============================================================================
# .validate_reference_sample()
# ============================================================================

# Validates that reference_sample is a survey_taylor. Errors with a specific
# message if it is a survey_replicate (common mistake). Returns invisible(TRUE).
.validate_reference_sample <- function(reference_sample) {
  if (!S7::S7_inherits(reference_sample, surveycore::survey_taylor)) {
    cls <- class(reference_sample)[[1L]]
    is_rep <- S7::S7_inherits(reference_sample, surveycore::survey_replicate)
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg reference_sample} must be a {.cls survey_taylor}, ",
          "not {.cls {cls}}."
        ),
        "i" = if (is_rep) {
          paste0(
            "A replicate-weighted reference survey is not supported here. ",
            "Only {.cls survey_taylor} (Taylor-series linearization design) is accepted."
          )
        } else {
          "Only {.cls survey_taylor} (Taylor-series linearization design) is accepted."
        },
        "v" = if (is_rep) {
          paste0(
            "Use {.fn calibrate_to_survey} for the Opsomer-Erciulescu approach ",
            "with a replicate-weighted reference."
          )
        } else {
          paste0(
            "Pass a {.cls survey_taylor} created with {.fn surveycore::as_survey}."
          )
        }
      ),
      class = "surveywts_error_reference_sample_class"
    )
  }
  invisible(TRUE)
}

# ============================================================================
# .quasi_randomization_bootstrap()
# ============================================================================

# Internal helper: quasi-randomization bootstrap for NPS.
# Called from create_bootstrap_weights() when type = "quasi-randomization".
#
# Arguments:
#   data             : survey_nonprob (already validated)
#   replicates       : integer(1) (already validated)
#   reference_sample : survey_taylor or NULL (already validated if non-NULL)
#   mse              : character(1) — "mse", "chrostowski", or "uncentered"
#   seed             : integer(1) or NULL
#
# Returns: survey_nonprob with repwt_* columns + updated @variables$repweights
#   and a "bootstrap_weights" history entry.
.quasi_randomization_bootstrap <- function(
  data, replicates, reference_sample, mse, seed
) {
  # ---- Prerequisites check ------------------------------------------------

  # Find ipw history entry
  ipw_entry <- Filter(
    function(e) identical(e$operation, "ipw"),
    data@metadata@weighting_history
  )
  if (length(ipw_entry) == 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "No {.code ipw()} step found in the weighting history of {.arg data}."
        ),
        "i" = paste0(
          "The quasi-randomization bootstrap requires an {.code ipw()} step ",
          "in the weighting history."
        ),
        "v" = paste0(
          "Call {.fn ipw} on the non-probability sample before calling ",
          "{.fn create_bootstrap_weights}."
        )
      ),
      class = "surveywts_error_qr_bootstrap_no_ipw_history"
    )
  }
  ipw_entry <- ipw_entry[[1L]]

  # Resolve reference design: argument takes precedence over stored entry
  ref_design <- reference_sample %||% ipw_entry$reference_design
  if (is.null(ref_design)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "A reference probability sample is required for ",
          "{.code type = 'quasi-randomization'}."
        ),
        "i" = paste0(
          "No reference design found in the {.code ipw()} history entry ",
          "and {.arg reference_sample} was not supplied."
        ),
        "v" = paste0(
          "Supply the reference design via {.arg reference_sample}, or re-run ",
          "{.fn ipw} with a {.cls survey_taylor} reference."
        )
      ),
      class = "surveywts_error_qr_bootstrap_no_reference"
    )
  }

  # Find last calibration history entry (rake or calibrate)
  calib_entry <- Filter(
    function(e) e$operation %in% c("raking", "calibration"),
    data@metadata@weighting_history
  )
  calib_entry <- if (length(calib_entry) > 0L) {
    calib_entry[[length(calib_entry)]]
  } else {
    NULL
  }

  # ---- Level A / Level B detection ----------------------------------------
  # Level B fires only when rake()/calibrate() was called with reference_design=,
  # which sets parameters$targets_from_reference = TRUE in the history entry.
  # isTRUE(NULL) = FALSE, so ipw-only and Level A workflows get use_level_b = FALSE.
  use_level_b <- isTRUE(calib_entry$parameters$targets_from_reference)

  # ---- Second-call overwrite check ----------------------------------------
  if (!is.null(data@variables$repweights) &&
        length(data@variables$repweights) > 0L) {
    n_old <- length(data@variables$repweights)
    cli::cli_warn(
      c(
        "!" = paste0(
          "Overwriting {n_old} existing replicate weight column(s) in ",
          "{.arg data}."
        ),
        "i" = paste0(
          "A previous call to {.fn create_bootstrap_weights} already produced ",
          "{n_old} replicate column(s). They will be replaced."
        ),
        "v" = "Inspect the previous replicates before overwriting if needed."
      ),
      class = "surveywts_warning_repweights_overwritten"
    )
    # Remove old repwt_* columns from @data
    old_cols <- data@variables$repweights
    data@data <- data@data[, setdiff(names(data@data), old_cols), drop = FALSE]
    data@variables$repweights <- NULL
  }

  B <- replicates

  # ---- Seed and reference size setup ----------------------------------------
  if (!is.null(seed)) set.seed(seed)
  n_ref <- if (use_level_b) nrow(ref_design@data) else 0L

  # ---- Main loop ----------------------------------------------------------
  n_A         <- nrow(data@data)
  failed_draws <- 0L
  repwt_list  <- list()

  for (b in seq_len(B)) {
    draw_ok <- tryCatch({
      # Step 1: SRSWR resample of NPS rows
      idx    <- sample(n_A, size = n_A, replace = TRUE)
      S_A_b  <- data@data[idx, , drop = FALSE]

      # Drop weight column so ipw() doesn't find it
      S_A_b  <- S_A_b[
        , setdiff(names(S_A_b), data@variables$weights),
        drop = FALSE
      ]

      # Revert "(Missing)" if missing_method = "separate"
      if (identical(ipw_entry$missing_method, "separate")) {
        sel_vars <- all.vars(ipw_entry$formula)
        for (var in sel_vars) {
          col <- S_A_b[[var]]
          if (is.factor(col) && "(Missing)" %in% levels(col)) {
            char_col <- as.character(col)
            char_col[char_col == "(Missing)"] <- NA_character_
            existing_levels <- sort(
              unique(char_col[!is.na(char_col)])
            )
            S_A_b[[var]] <- factor(char_col, levels = existing_levels)
          }
        }
      }

      # Step 2 (Level B): SRSWR resample of reference rows.
      # Avoids zero-weight issues (survey_taylor requires all weights > 0).
      # The resampled reference carries original design weights for the
      # selected rows; margins are re-estimated from these resampled weights.
      if (use_level_b) {
        idx_ref    <- sample(n_ref, size = n_ref, replace = TRUE)
        ref_data_b <- ref_design@data[idx_ref, , drop = FALSE]
        ref_b      <- surveycore::survey_taylor(
          data      = ref_data_b,
          variables = ref_design@variables
        )
      } else {
        ref_b      <- ref_design  # fixed reference for Level A
        ref_data_b <- NULL        # unused for Level A
      }

      # Step 3: re-run ipw()
      ipw_result_b <- surveywts::ipw(
        data             = S_A_b,
        reference        = ref_b,
        selection        = ipw_entry$formula,
        method           = ipw_entry$method,
        estimating_eq    = ipw_entry$estimating_eq,
        missing_method   = ipw_entry$missing_method,
        adjust_reference = ipw_entry$adjust_reference,
        trim             = ipw_entry$trim,
        wt_name          = data@variables$weights
      )

      # Step 4: re-run calibration (if in history)
      if (!is.null(calib_entry)) {
        if (calib_entry$operation == "raking") {
          if (use_level_b) {
            # Re-estimate margins from the SRSWR-resampled reference data.
            # ref_data_b carries original design weights for selected rows.
            margins_b <- .reestimate_margins_from_reference(
              calib_entry = calib_entry,
              ref_design  = ref_design,
              ref_data_b  = ref_data_b
            )
          } else {
            margins_b <- calib_entry$parameters$margins
          }
          calib_result_b <- surveywts::rake(
            data    = ipw_result_b,
            margins = margins_b,
            type    = calib_entry$parameters$type,
            method  = calib_entry$parameters$method,
            cap     = calib_entry$parameters$cap,
            control = calib_entry$parameters$control
          )
        } else {
          # operation == "calibration"
          calib_result_b <- surveywts::calibrate(
            data       = ipw_result_b,
            variables  = calib_entry$parameters$variables,
            population = calib_entry$parameters$population,
            method     = calib_entry$parameters$method,
            type       = calib_entry$parameters$type,
            control    = calib_entry$parameters$control
          )
        }
        repwt_list[[length(repwt_list) + 1L]] <-
          calib_result_b@data[[data@variables$weights]]
      } else {
        repwt_list[[length(repwt_list) + 1L]] <-
          ipw_result_b@data[[data@variables$weights]]
      }

      TRUE  # draw succeeded
    }, error = function(e) {
      FALSE  # draw failed
    })

    if (!isTRUE(draw_ok)) {
      failed_draws <- failed_draws + 1L
    }
  }

  # ---- Post-loop checks ---------------------------------------------------
  if (failed_draws > 0.1 * B) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{failed_draws} of {B} bootstrap draws failed and were skipped."
        ),
        "i" = paste0(
          "A draw fails when {.fn ipw} or calibration does not converge ",
          "(e.g., degenerate propensity scores in the resampled data)."
        ),
        "v" = paste0(
          "Increase {.arg replicates} to compensate, or inspect the data for ",
          "extreme covariate imbalance."
        )
      ),
      class = "surveywts_warning_bootstrap_draws_failed"
    )
  }

  draws_used <- B - failed_draws
  if (draws_used == 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "All {B} bootstrap draws failed; no replicate weights could be produced."
        ),
        "i" = paste0(
          "Every resampled draw produced degenerate propensity scores or ",
          "calibration divergence."
        ),
        "v" = paste0(
          "Check the {.arg data} for single-level covariates or extreme ",
          "covariate imbalance with the reference."
        )
      ),
      class = "surveywts_error_bootstrap_all_draws_failed"
    )
  }

  # ---- Assemble output ----------------------------------------------------
  repwt_names <- paste0("repwt_", seq_len(draws_used))
  for (i in seq_len(draws_used)) {
    data@data[[repwt_names[i]]] <- repwt_list[[i]]
  }
  data@variables$repweights <- repwt_names

  # Append bootstrap_weights history entry
  meta <- data@metadata
  meta@weighting_history <- c(
    meta@weighting_history,
    list(list(
      step       = length(meta@weighting_history) + 1L,
      operation  = "bootstrap_weights",
      timestamp  = Sys.time(),
      type       = "quasi-randomization",
      replicates = B,
      draws_used = draws_used,
      level      = if (use_level_b) "B" else "A",
      mse        = mse,
      seed       = seed
    ))
  )
  data@metadata <- meta

  data
}

# ============================================================================
# .reestimate_margins_from_reference()
# ============================================================================

# Internal helper for Level B: re-estimate calibration margins from the
# b-th resampled reference replicate weights.
#
# Arguments:
#   calib_entry : the "raking" history entry from the original call
#   ref_design  : the original reference survey_taylor
#   ref_wts_b   : numeric vector of the b-th replicate weights
#
# Returns: a named list of named numeric vectors (Format A margins),
#   same structure as calib_entry$parameters$margins.
#
# Arguments:
#   calib_entry : the "raking" history entry from the original call
#   ref_design  : the original reference survey_taylor (for variable structure)
#   ref_data_b  : data.frame — SRSWR-resampled reference rows (includes the
#                 weight column from ref_design@variables$weights)
.reestimate_margins_from_reference <- function(calib_entry, ref_design, ref_data_b) {
  margins_orig <- calib_entry$parameters$margins
  type         <- calib_entry$parameters$type
  wt_col       <- ref_design@variables$weights
  ref_wts_b    <- ref_data_b[[wt_col]]

  lapply(names(margins_orig), function(var) {
    col  <- as.character(ref_data_b[[var]])
    lvls <- names(margins_orig[[var]])
    if (type == "prop") {
      totals <- vapply(lvls, function(lv) {
        sum(ref_wts_b[col == lv], na.rm = TRUE)
      }, numeric(1L))
      total_sum <- sum(ref_wts_b, na.rm = TRUE)
      stats::setNames(totals / total_sum, lvls)
    } else {
      # type == "count"
      totals <- vapply(lvls, function(lv) {
        sum(ref_wts_b[col == lv], na.rm = TRUE)
      }, numeric(1L))
      stats::setNames(totals, lvls)
    }
  }) |> stats::setNames(names(margins_orig))
}

# ============================================================================
# create_bootstrap_weights()
# ============================================================================

#' Create bootstrap replicate weights
#'
#' Generates bootstrap replicate weights for probability-sample designs via
#' [svrep::as_bootstrap_design()], or quasi-randomization bootstrap replicate
#' weights for non-probability samples (`survey_nonprob`) via an internal
#' resample-reweight algorithm.
#'
#' @param data A `survey_taylor` or `survey_nonprob` design object.
#'   `survey_replicate`, `data.frame`, and `weighted_df` → error.
#' @param replicates `integer(1)` or `NULL`. Number of bootstrap replicates.
#'   Default `NULL` resolves to `200L` for `type = "quasi-randomization"` and
#'   `type = "hybrid"`, and `500L` for all probability-sample types. Must be
#'   at least 2. Whole-number doubles are coerced to integer silently.
#' @param ... Must be empty. Forces all subsequent arguments to be named.
#' @param type `character(1)`. Bootstrap variant. For probability-sample
#'   designs: `"Rao-Wu-Yue-Beaumont"` (default), `"Rao-Wu"`, `"Antal-Tille"`,
#'   `"Preston"`, or `"Canty-Davison"` — passed to
#'   [svrep::as_bootstrap_design()]. For non-probability samples:
#'   `"quasi-randomization"` (resample-reweight bootstrap) or `"hybrid"`
#'   (error stub; requires `mass_imputation()`, not yet implemented).
#' @param reference_sample `survey_taylor` or `NULL`. Reference probability
#'   sample for NPS types. When non-`NULL`, takes precedence over any
#'   reference design stored in `@metadata@weighting_history`. Ignored (with
#'   a warning) when `type` is a probability-sample type. `survey_replicate`
#'   → error.
#' @param mse `character(1)`. Variance formula for bootstrap variance.
#'   `"mse"` (default): mean squared deviation from the full-sample estimate,
#'   \eqn{(1/B) \sum (\hat{\theta}^{(b)} - \hat{\theta})^2}.
#'   `"chrostowski"`: \eqn{(1/(B-1)) \sum (\hat{\theta}^{(b)} - \hat{\theta})^2}
#'   (NPS types only; errors for probability-sample types). `"uncentered"`:
#'   standard Bessel-corrected variance centered on the bootstrap mean.
#'   For probability-sample types, `"mse"` maps to `TRUE` and `"uncentered"`
#'   maps to `FALSE` in the `svrep` call.
#'   **Legacy note:** `mse = TRUE` or `mse = FALSE` (logical) is no longer
#'   accepted and emits `surveywts_error_mse_not_character`.
#' @param seed `integer(1)` or `NULL`. RNG seed. For NPS types,
#'   `set.seed()` is called once immediately before the bootstrap loop (or
#'   before the `svrep` pre-computation for Level B). The caller's global RNG
#'   state is **not** restored. For probability-sample types, the seed is
#'   applied via `withr::local_seed()` and the caller's state is restored.
#'
#' @return
#'   - Probability-sample types → `survey_replicate` with `replicates` new
#'     `rep_1...rep_N` columns and a `"replicate_creation"` history entry.
#'   - `type = "quasi-randomization"` → `survey_nonprob` with `replicates`
#'     new `repwt_1...repwt_B` columns in `@data`, `@variables$repweights`
#'     populated, and a `"bootstrap_weights"` history entry.
#'
#' @details
#'   **SRSWR understatement:** Bootstrap standard errors from
#'   `type = "quasi-randomization"` likely understate true sampling
#'   variability because SRSWR resampling cannot replicate the original NPS
#'   recruitment mechanism (AAPOR 2022, §4). This understatement is not
#'   reduced by increasing `replicates`.
#'
#' @references
#'   Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability
#'   samples. *Statistical Science* **32**(2), 249--264.
#'
#'   Wu, C. (2022). Statistical inference with non-probability survey samples.
#'   *Survey Methodology* **48**(2), 283--311.
#'
#'   Chrostowski, M.J., Guzman, C.A. and Malm, L. (2025). Variance estimation
#'   for non-probability surveys. *Journal of Survey Statistics and
#'   Methodology* (forthcoming).
#'
#'   Kolenikov, S. (2014). Calibrating variance estimation with proxy
#'   variables. *Survey Methodology* **40**(1), 21--38.
#'
#' @family replicate-weights
#' @export
create_bootstrap_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c(
    "Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
    "Preston", "Canty-Davison",
    "quasi-randomization", "hybrid"
  ),
  reference_sample = NULL,
  mse = c("mse", "chrostowski", "uncentered"),
  seed = NULL
) {
  # mse must be character, not logical (legacy boolean API rejected)
  if (is.logical(mse)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg mse} must be a character string, not {.cls logical}."
        ),
        "i" = paste0(
          "{.code mse = TRUE} and {.code mse = FALSE} are no longer accepted."
        ),
        "v" = paste0(
          "Use {.code mse = \"mse\"} (replaces {.code TRUE}) or ",
          "{.code mse = \"uncentered\"} (replaces {.code FALSE})."
        )
      ),
      class = "surveywts_error_mse_not_character"
    )
  }

  type <- rlang::arg_match(type)
  mse  <- rlang::arg_match(mse)

  # Resolve NULL replicates
  if (is.null(replicates)) {
    replicates <- if (type %in% c("quasi-randomization", "hybrid")) 200L else 500L
  }
  replicates <- .validate_replicates_arg(replicates)

  # ---- Dispatch: NPS types vs. probability-sample types -------------------
  # NPS type check runs before .validate_replicate_input() so that weighted_df
  # and other non-design inputs get a more informative NPS-specific error.
  if (type %in% c("quasi-randomization", "hybrid")) {
    if (!S7::S7_inherits(data, surveycore::survey_nonprob)) {
      cls <- class(data)[[1L]]
      if (type == "quasi-randomization") {
        cli::cli_abort(
          c(
            "x" = paste0(
              "{.code type = 'quasi-randomization'} requires a ",
              "{.cls survey_nonprob}; got {.cls {cls}}."
            ),
            "i" = paste0(
              "The quasi-randomization bootstrap is designed for ",
              "non-probability samples with IPW history."
            ),
            "v" = paste0(
              "Use {.fn ipw} to create a {.cls survey_nonprob}, then call ",
              "{.fn create_bootstrap_weights}."
            )
          ),
          class = "surveywts_error_qr_bootstrap_requires_nonprob"
        )
      } else {
        cli::cli_abort(
          c(
            "x" = paste0(
              "{.code type = 'hybrid'} requires a {.cls survey_nonprob}; ",
              "got {.cls {cls}}."
            ),
            "i" = paste0(
              "The hybrid bootstrap is designed for non-probability samples."
            ),
            "v" = paste0(
              "Use {.fn ipw} to create a {.cls survey_nonprob}, then call ",
              "{.fn create_bootstrap_weights}."
            )
          ),
          class = "surveywts_error_hybrid_bootstrap_requires_nonprob"
        )
      }
    }

    if (!is.null(reference_sample)) {
      .validate_reference_sample(reference_sample)
    }

    if (type == "quasi-randomization") {
      .quasi_randomization_bootstrap(
        data             = data,
        replicates       = replicates,
        reference_sample = reference_sample,
        mse              = mse,
        seed             = seed
      )
    } else {
      # type == "hybrid": error stub until mass_imputation() is implemented
      cli::cli_abort(
        c(
          "x" = "{.code type = \"hybrid\"} is not yet available.",
          "i" = paste0(
            "The hybrid bootstrap requires {.fn mass_imputation}, which is ",
            "not yet implemented."
          ),
          "v" = paste0(
            "Use {.code type = \"quasi-randomization\"} for IPW-weighted ",
            "non-probability samples."
          )
        ),
        class = "surveywts_error_hybrid_bootstrap_not_implemented"
      )
    }
  } else {
    # ---- Probability-sample path -------------------------------------------
    .validate_replicate_input(data)

    if (mse == "chrostowski") {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.code mse = \"chrostowski\"} is only available for NPS types ",
            "({.code type = \"quasi-randomization\"})."
          ),
          "i" = paste0(
            "{.code mse = \"chrostowski\"} is the Chrostowski et al. (2025) ",
            "formula for NPS variance. It cannot be applied to probability-",
            "sample designs."
          ),
          "v" = paste0(
            "Use {.code mse = \"mse\"} or {.code mse = \"uncentered\"} for ",
            "probability-sample types."
          )
        ),
        class = "surveywts_error_chrostowski_prob_sample"
      )
    }

    if (!is.null(reference_sample)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.arg reference_sample} is ignored for {.code type = '{type}'}."
          ),
          "i" = paste0(
            "{.arg reference_sample} is only used for NPS bootstrap types: ",
            "{.code \"quasi-randomization\"} and {.code \"hybrid\"}."
          ),
          "v" = paste0(
            "Remove {.arg reference_sample} when using probability-sample ",
            "bootstrap types."
          )
        ),
        class = "surveywts_warning_reference_sample_ignored"
      )
    }

    mse_logical <- (mse == "mse")
    .convert_and_call(
      data       = data,
      backend_fn = function(d) {
        svrep::as_bootstrap_design(
          d, type = type, replicates = replicates, mse = mse_logical
        )
      },
      method     = "bootstrap",
      params     = list(type = type, replicates = replicates, mse = mse_logical),
      seed       = seed
    )
  }
}

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

# ============================================================================
# create_gen_boot_weights()
# ============================================================================

#' Create generalized bootstrap replicate weights
#'
#' Generates generalized bootstrap replicate weights via
#' [svrep::as_gen_boot_design()]. Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design.
#' @param replicates `integer(1)`, default `500L`. Number of bootstrap replicates.
#' @param ... Must be empty.
#' @param variance_estimator `character(1)`. Target variance estimator. One of
#'   `"SD1"` (default), `"SD2"`, `"Horvitz-Thompson"`, `"Yates-Grundy"`,
#'   `"Poisson Horvitz-Thompson"`, `"Stratified Multistage SRS"`,
#'   `"Ultimate Cluster"`, `"Deville-1"`, `"Deville-2"`, `"Deville-Tille"`,
#'   `"BOSB"`, or `"Beaumont-Emond"`.
#' @param tau `numeric(1)` or `"auto"`, default `1`. Rescaling constant to
#'   prevent negative replicate weights.
#' @param aux_var_names <[`tidy-select`][tidyselect::language]> or `NULL`.
#'   Auxiliary variable columns. Required when
#'   `variance_estimator = "Deville-Tille"`.
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed.
#'
#' @return A `survey_replicate` with `@variables$type = "bootstrap"`.
#'
#' @family replicate-weights
#' @export
create_gen_boot_weights <- function(
  data,
  replicates = 500L,
  ...,
  variance_estimator = "SD1",
  tau = 1,
  aux_var_names = NULL,
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_gen_boot_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by this method.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  replicates         <- .validate_replicates_arg(replicates)
  variance_estimator <- rlang::arg_match(variance_estimator, c(
    "SD1", "SD2", "Horvitz-Thompson", "Yates-Grundy",
    "Poisson Horvitz-Thompson", "Stratified Multistage SRS",
    "Ultimate Cluster", "Deville-1", "Deville-2", "Deville-Tille",
    "BOSB", "Beaumont-Emond"
  ))

  aux_quo <- rlang::enquo(aux_var_names)

  if (identical(variance_estimator, "Deville-Tille") && rlang::quo_is_null(aux_quo)) {
    cli::cli_abort(
      c(
        "x" = "{.code variance_estimator = \"Deville-Tille\"} requires {.arg aux_var_names}.",
        "v" = "Pass column names, e.g. {.code aux_var_names = c(x1, x2)}."
      ),
      class = "surveywts_error_variance_estimator_requires_aux"
    )
  }

  resolved_aux <- if (rlang::quo_is_null(aux_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(aux_quo, data = data@data))
  }

  .convert_and_call(
    data          = data,
    backend_fn    = function(d) {
      svrep::as_gen_boot_design(
        d,
        variance_estimator = variance_estimator,
        replicates         = replicates,
        tau                = tau,
        aux_var_names      = resolved_aux,
        mse                = mse
      )
    },
    method        = "generalized-bootstrap",
    params        = list(
      variance_estimator = variance_estimator,
      replicates         = replicates,
      tau                = tau,
      mse                = mse
    ),
    seed          = seed,
    type_override = "bootstrap"
  )
}

# ============================================================================
# create_gen_rep_weights()
# ============================================================================

#' Create generalized replication replicate weights
#'
#' Generates Fay's generalized replication weights via
#' [svrep::as_fays_gen_rep_design()]. Produces deterministic replicate weights
#' (no randomness). Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design.
#' @param ... Must be empty.
#' @param variance_estimator `character(1)`. Target variance estimator. Same
#'   options as [create_gen_boot_weights()]. Default `"SD2"`.
#' @param max_replicates `numeric(1)`, default `Inf`. Maximum number of
#'   replicates; `Inf` uses the natural count.
#' @param balanced `logical(1)`, default `TRUE`. Equal contribution of
#'   replicates to variance estimates.
#' @param aux_var_names `<tidy-select>` or `NULL`. Required for
#'   `"Deville-Tille"`.
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed for reproducibility.
#'
#' @return A `survey_replicate` with generalized replication weights.
#'
#' @family replicate-weights
#' @export
create_gen_rep_weights <- function(
  data,
  ...,
  variance_estimator = "SD2",
  max_replicates = Inf,
  balanced = TRUE,
  aux_var_names = NULL,
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_gen_rep_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by this method.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  variance_estimator <- rlang::arg_match(variance_estimator, c(
    "SD1", "SD2", "Horvitz-Thompson", "Yates-Grundy",
    "Poisson Horvitz-Thompson", "Stratified Multistage SRS",
    "Ultimate Cluster", "Deville-1", "Deville-2", "Deville-Tille",
    "BOSB", "Beaumont-Emond"
  ))

  aux_quo <- rlang::enquo(aux_var_names)

  if (identical(variance_estimator, "Deville-Tille") && rlang::quo_is_null(aux_quo)) {
    cli::cli_abort(
      c(
        "x" = "{.code variance_estimator = \"Deville-Tille\"} requires {.arg aux_var_names}.",
        "v" = "Pass column names, e.g. {.code aux_var_names = c(x1, x2)}."
      ),
      class = "surveywts_error_variance_estimator_requires_aux"
    )
  }

  resolved_aux <- if (rlang::quo_is_null(aux_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(aux_quo, data = data@data))
  }

  .convert_and_call(
    data       = data,
    backend_fn = function(d) {
      svrep::as_fays_gen_rep_design(
        d,
        variance_estimator = variance_estimator,
        max_replicates     = max_replicates,
        balanced           = balanced,
        aux_var_names      = resolved_aux,
        mse                = mse
      )
    },
    method     = "generalized-replicate",
    params     = list(
      variance_estimator = variance_estimator,
      max_replicates     = max_replicates,
      balanced           = balanced,
      mse                = mse
    ),
    seed       = seed
  )
}

# ============================================================================
# create_sdr_weights()
# ============================================================================

#' Create successive difference replication (SDR) weights
#'
#' Generates successive difference replication weights via
#' [svrep::as_sdr_design()]. Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design. PSUs should be in systematic
#'   selection order, or use `sort_var`.
#' @param replicates `integer(1)`, default `100L`. Target replicate count
#'   (>= 4). Actual count may be slightly larger due to Hadamard matrix sizing.
#' @param ... Must be empty.
#' @param sort_var <[`tidy-select`][tidyselect::language]> Bare column name
#'   giving the systematic selection order. Required for stratified designs
#'   (svrep >= 0.9.1); for non-stratified designs row order is used as fallback.
#' @param mse `logical(1)`, default `TRUE`.
#'
#' @return A `survey_replicate` with `@variables$type = "successive-difference"`.
#'
#' @family replicate-weights
#' @export
create_sdr_weights <- function(
  data,
  replicates = 100L,
  ...,
  sort_var = NULL,
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

  sort_quo <- rlang::enquo(sort_var)
  sort_col <- if (rlang::quo_is_null(sort_quo)) NULL else rlang::as_name(sort_quo)

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
    data       = data,
    backend_fn = function(d) {
      if (is.null(sort_col)) {
        d$variables[[".row_order"]] <- seq_len(nrow(d$variables))
        effective_sort <- ".row_order"
      } else {
        effective_sort <- sort_col
      }
      result <- svrep::as_sdr_design(
        d,
        replicates    = replicates,
        sort_variable = effective_sort,
        mse           = mse
      )
      result$variables[[".row_order"]] <- NULL
      result
    },
    method     = "successive-difference",
    params     = list(replicates = replicates, sort_var = sort_col, mse = mse)
  )
}
