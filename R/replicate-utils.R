# R/replicate-utils.R
#
# Internal helpers shared by create_bootstrap_weights(), create_jackknife_weights(),
# create_brr_weights(), create_gen_boot_weights(), create_gen_rep_weights(),
# create_sdr_weights(), and create_group_jackknife_weights().
#
# .validate_replicate_input()        — class/type guard for all create_*_weights()
# .validate_replicates_arg()         — coerce & validate the replicates integer arg
# .snapshot_variables_for_history()  — capture source design structure for history
# .convert_and_call()                — core S7-to-svydesign conversion pipeline
# .validate_reference_sample()       — check reference_sample is survey_taylor
# .handle_repweights_overwrite()     — detect/clear existing replicate weights
# .quasi_randomization_bootstrap()   — QR bootstrap implementation for NPS
# .reestimate_margins_from_reference() — re-derive margins from a replicate control

# ============================================================================
# .validate_replicate_input()
# ============================================================================

.validate_replicate_input <- function(data) {
  if (inherits(data, "data.frame")) {
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
# message if it is a survey_replicate (common mistake) or a data.frame
# (also a common mistake — user forgot to wrap in survey_taylor). Returns
# invisible(TRUE) on success.
.validate_reference_sample <- function(reference_sample) {
  if (!S7::S7_inherits(reference_sample, surveycore::survey_taylor)) {
    cls <- class(reference_sample)[[1L]]
    is_rep <- S7::S7_inherits(reference_sample, surveycore::survey_replicate)
    is_df  <- inherits(reference_sample, "data.frame")
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
        } else if (is_df) {
          paste0(
            "Use {.fn survey::svydesign} to convert an SRS data frame to a ",
            "{.cls survey_taylor} object."
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
# .handle_repweights_overwrite()
# ============================================================================

# Internal helper: detect and clear existing replicate weights, emitting a
# typed warning when overwriting is required.
#
# Arguments:
#   data          : survey_nonprob (already validated)
#   fn_name       : character(1) — name of the calling public function
#   warning_class : character(1) — warning class to attach to cli_warn()
#
# Returns: `data` unchanged when @variables$repweights is NULL; otherwise
#   returns `data` with old replicate columns removed from @data and
#   @variables$repweights cleared to NULL.
.handle_repweights_overwrite <- function(data, fn_name, warning_class) {
  if (is.null(data@variables$repweights) ||
        length(data@variables$repweights) == 0L) {
    return(data)
  }
  n_old <- length(data@variables$repweights)
  cli::cli_warn(
    c(
      "!" = paste0(
        "Overwriting {n_old} existing replicate weight column(s) in ",
        "{.arg data}."
      ),
      "i" = paste0(
        "A previous call to {.fn {fn_name}} already produced ",
        "{n_old} replicate column(s). They will be replaced."
      ),
      "v" = "Inspect the previous replicates before overwriting if needed."
    ),
    class = warning_class
  )
  old_cols <- data@variables$repweights
  # Clear @variables$repweights first so the S7 validator does not require
  # the replicate columns to still be present in @data when we remove them.
  data@variables$repweights <- NULL
  data@data <- data@data[, setdiff(names(data@data), old_cols), drop = FALSE]
  data
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
  history <- data@metadata@weighting_history

  # ---- Prerequisites check: routing by history content --------------------
  # Find the last IPW entry
  ipw_entries <- Filter(function(e) identical(e$operation, "ipw"), history)
  ipw_entry <- if (length(ipw_entries) > 0L) {
    ipw_entries[[length(ipw_entries)]]
  } else {
    NULL
  }

  # Calibration operations that qualify as a "calibration entry"
  .calib_ops <- c(
    "calibrate_rake", "calibrate_linear", "calibrate_logit",
    "poststratify", "raking"
  )

  # Find the last calibration entry
  calib_entries <- Filter(
    function(e) e$operation %in% .calib_ops,
    history
  )
  calib_entry <- if (length(calib_entries) > 0L) {
    calib_entries[[length(calib_entries)]]
  } else {
    NULL
  }

  # If neither IPW nor calibration entry found, error
  if (is.null(ipw_entry) && is.null(calib_entry)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "No {.fn ipw} or calibration step found in the weighting history ",
          "of {.arg data}."
        ),
        "i" = paste0(
          "The quasi-randomization bootstrap requires either an {.fn ipw} step ",
          "or a calibration step (e.g., {.fn calibrate_rake}, {.fn poststratify}) ",
          "in the weighting history."
        ),
        "v" = paste0(
          "Call {.fn ipw} or a calibration function on the non-probability ",
          "sample before calling {.fn create_bootstrap_weights}."
        )
      ),
      class = "surveywts_error_qr_bootstrap_no_history"
    )
  }

  # ---- Level A / Level B detection ----------------------------------------
  # Level B fires when the calibration entry was called with reference_design=,
  # which stores targets_from_reference = TRUE in the history entry.
  # isTRUE(NULL) = FALSE, so IPW-only and Level A get use_level_b = FALSE.
  use_level_b <- isTRUE(calib_entry$parameters$targets_from_reference)

  # ---- Second-call overwrite check ----------------------------------------
  data <- .handle_repweights_overwrite(
    data,
    fn_name       = "create_bootstrap_weights",
    warning_class = "surveywts_warning_repweights_overwritten"
  )

  B <- replicates

  # ---- Route to the appropriate path ----------------------------------------
  if (!is.null(ipw_entry)) {
    # ---- IPW path (doubly-robust or IPW-only) --------------------------------
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
            "No reference design found in the {.fn ipw} history entry ",
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

    if (!is.null(seed)) set.seed(seed)
    n_ref <- if (use_level_b) nrow(ref_design@data) else 0L
    n_A   <- nrow(data@data)
    failed_draws <- 0L
    repwt_list  <- list()

    for (b in seq_len(B)) {
      draw_ok <- tryCatch({
        # Step 1: SRSWR resample of NPS rows
        idx   <- sample(n_A, size = n_A, replace = TRUE)
        S_A_b <- data@data[idx, , drop = FALSE]

        # Drop weight column so ipw() doesn't find it
        S_A_b <- S_A_b[
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
              existing_levels <- sort(unique(char_col[!is.na(char_col)]))
              S_A_b[[var]] <- factor(char_col, levels = existing_levels)
            }
          }
        }

        # Step 2 (Level B): SRSWR resample of reference rows.
        if (use_level_b) {
          idx_ref    <- sample(n_ref, size = n_ref, replace = TRUE)
          ref_data_b <- ref_design@data[idx_ref, , drop = FALSE]
          ref_b      <- surveycore::survey_taylor(
            data      = ref_data_b,
            variables = ref_design@variables
          )
        } else {
          ref_b      <- ref_design
          ref_data_b <- NULL
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

        # Step 4: re-run calibration (if calibration entry present)
        if (!is.null(calib_entry)) {
          calib_result_b <- .dispatch_calibration_replay(
            data         = ipw_result_b,
            calib_entry  = calib_entry,
            ref_design   = ref_design,
            ref_data_b   = ref_data_b,
            use_level_b  = use_level_b
          )
          w_b <- .extract_weight_vec(calib_result_b, data@variables$weights)
        } else {
          w_b <- ipw_result_b@data[[data@variables$weights]]
        }

        repwt_list[[length(repwt_list) + 1L]] <- w_b
        TRUE
      }, error = function(e) FALSE)

      if (!isTRUE(draw_ok)) failed_draws <- failed_draws + 1L
    }
  } else {
    # ---- Calibration-only path (no IPW entry) --------------------------------

    # Reference resolution (only needed for Level B)
    if (use_level_b) {
      ref_design <- reference_sample %||%
        calib_entry$parameters$reference_design
      if (is.null(ref_design)) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "A reference probability sample is required for ",
              "{.code type = 'quasi-randomization'} with Level B calibration."
            ),
            "i" = paste0(
              "The calibration history entry has ",
              "{.code targets_from_reference = TRUE} but no reference design ",
              "was found in the entry and {.arg reference_sample} was not supplied."
            ),
            "v" = paste0(
              "Supply the reference design via {.arg reference_sample}, or ",
              "re-run the calibration with a {.cls survey_taylor} reference."
            )
          ),
          class = "surveywts_error_qr_bootstrap_no_reference"
        )
      }
      n_ref <- nrow(ref_design@data)
    } else {
      ref_design <- NULL
      n_ref      <- 0L
    }

    if (!is.null(seed)) set.seed(seed)
    n_A          <- nrow(data@data)
    wt_col       <- data@variables$weights
    failed_draws <- 0L
    repwt_list   <- list()

    for (b in seq_len(B)) {
      draw_ok <- tryCatch({
        # Step 1: SRSWR resample of NPS rows
        idx   <- sample(n_A, size = n_A, replace = TRUE)
        S_A_b <- data@data[idx, , drop = FALSE]

        # Step 3 (calibration-only): assign equal initial weight = 1.
        # SRSWR gives each NPS unit equal selection probability per replicate;
        # carrying forward the original calibrated weights would double-count.
        S_A_b[[wt_col]] <- 1

        # Wrap as survey_nonprob for dispatch
        nps_b <- surveycore::survey_nonprob(
          data      = S_A_b,
          variables = list(weights = wt_col),
          metadata  = surveycore::survey_metadata()
        )

        # Level B: SRSWR resample of reference rows
        ref_data_b <- if (use_level_b) {
          idx_ref <- sample(n_ref, size = n_ref, replace = TRUE)
          ref_design@data[idx_ref, , drop = FALSE]
        } else {
          NULL
        }

        # Step 4: calibration replay
        calib_result_b <- .dispatch_calibration_replay(
          data        = nps_b,
          calib_entry = calib_entry,
          ref_design  = ref_design,
          ref_data_b  = ref_data_b,
          use_level_b = use_level_b
        )

        w_b <- .extract_weight_vec(calib_result_b, wt_col)

        # A draw fails if any calibrated weight is <= 0 (e.g., calibrate_linear
        # with bounds = NULL can produce negative weights that pass the engine
        # but violate the survey_nonprob validator)
        # nocov start
        # Requires calibrate_linear() to produce a negative weight on a bootstrap
        # subsample — reliably engineering such extreme conditions without
        # also causing convergence failure is not feasible in unit tests.
        if (any(w_b <= 0, na.rm = TRUE)) stop("non-positive calibrated weight")
        # nocov end

        repwt_list[[length(repwt_list) + 1L]] <- w_b
        TRUE
      }, error = function(e) FALSE)

      if (!isTRUE(draw_ok)) failed_draws <- failed_draws + 1L
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
          "A draw fails when calibration or IPW re-estimation does not ",
          "converge (e.g., degenerate inputs in the resampled data)."
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
  data@variables$scale      <- 1 / draws_used
  data@variables$rscales    <- rep(1, draws_used)
  data@variables$type       <- "bootstrap"
  data@variables$mse        <- (mse == "mse")

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
# .dispatch_calibration_replay()
# ============================================================================

# Dispatch table for calibration replay in the QR bootstrap and DAGJK
# calibration-only paths. Selects the correct calibration function based on
# calib_entry$operation and forwards the stored parameters.
#
# Arguments:
#   data        : survey_nonprob or data.frame with the weight column already set
#   calib_entry : the calibration history entry from @metadata@weighting_history
#   ref_design  : survey_taylor or NULL (needed for Level B reference resolution)
#   ref_data_b  : data.frame of SRSWR-resampled reference rows (Level B only);
#                 NULL for Level A
#   use_level_b : logical; TRUE = re-estimate targets from ref_data_b
#
# Returns: a survey_nonprob with calibrated weights
.dispatch_calibration_replay <- function(
  data, calib_entry, ref_design, ref_data_b, use_level_b
) {
  op <- calib_entry$operation
  p  <- calib_entry$parameters

  if (op %in% c("calibrate_rake", "raking")) {
    if (use_level_b) {
      targets_b <- .reestimate_margins_from_reference(
        calib_entry = calib_entry,
        ref_design  = ref_design,
        ref_data_b  = ref_data_b
      )
    } else {
      # "raking" legacy entries stored targets as `margins`; new as `targets`
      targets_b <- p$targets %||% p$margins
    }
    surveywts::calibrate_rake(
      data      = data,
      targets   = targets_b,
      type      = p$type,
      algorithm = p$algorithm %||% p$method,
      cap       = p$cap,
      control   = p$control
    )
  } else if (op == "calibrate_linear") {
    if (use_level_b) {
      targets_b <- .reestimate_margins_from_reference(
        calib_entry = calib_entry,
        ref_design  = ref_design,
        ref_data_b  = ref_data_b
      )
    } else {
      targets_b <- p$targets
    }
    # bounds_scale stored as NULL when bounds = NULL (function default applies).
    # Do not pass NULL to arg_match — omit the arg and let the default be used.
    args_linear <- list(
      data       = data,
      targets    = targets_b,
      type       = p$type,
      bounds     = p$bounds,
      unit_scale = p$unit_scale,
      control    = p$control
    )
    if (!is.null(p$bounds_scale)) {
      args_linear$bounds_scale <- p$bounds_scale
    }
    do.call(surveywts::calibrate_linear, args_linear)
  } else if (op == "calibrate_logit") {
    if (use_level_b) {
      targets_b <- .reestimate_margins_from_reference(
        calib_entry = calib_entry,
        ref_design  = ref_design,
        ref_data_b  = ref_data_b
      )
    } else {
      targets_b <- p$targets
    }
    # bounds_scale stored as NULL when bounds defaults applied — same pattern.
    args_logit <- list(
      data       = data,
      targets    = targets_b,
      type       = p$type,
      bounds     = p$bounds,
      unit_scale = p$unit_scale,
      control    = p$control
    )
    if (!is.null(p$bounds_scale)) {
      args_logit$bounds_scale <- p$bounds_scale
    }
    do.call(surveywts::calibrate_logit, args_logit)
  } else if (op == "poststratify") {
    # poststratify does not accept algorithm, cap, control, or bounds
    surveywts::poststratify(
      data    = data,
      targets = p$targets,
      type    = p$type
    )
  } else {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Unsupported calibration operation {.val {op}} in weighting history."
        ),
        "i" = paste0(
          "The quasi-randomization bootstrap supports replay of ",
          "{.val calibrate_rake}, {.val calibrate_linear}, ",
          "{.val calibrate_logit}, and {.val poststratify} only."
        )
      ),
      class = "surveywts_error_unsupported_calibration_op"
    )
  }
}

# ============================================================================
# .extract_weight_vec()
# ============================================================================

# Extract the weight column from a calibration result.
#
# Arguments:
#   result  : the output of a calibration function call (survey_nonprob)
#   wt_col  : character(1) — name of the weight column
#
# Returns: numeric vector of calibrated weights
.extract_weight_vec <- function(result, wt_col) {
  result@data[[result@variables$weights]]
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
  # Old "raking" entries stored targets as `margins`; new ones as `targets`.
  margins_orig <- calib_entry$parameters$targets %||%
    calib_entry$parameters$margins
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
