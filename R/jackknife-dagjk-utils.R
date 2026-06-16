# R/jackknife-dagjk-utils.R
#
# Internal engine helpers for create_group_jackknife_weights() (DAGJK).
# Migrated from create_group_jackknife_weights.R in PR 1 of jackknife-merge.

# ============================================================================
# .validate_replicates_dagjk_arg()
# ============================================================================

# Validates the `replicates` argument for DAGJK. Two-phase validation:
#   Phase 1 (combined_n = Inf): validates type, whole-number, and minimum.
#   Phase 2 (combined_n = actual): validates ceiling.
# Returns as.integer(replicates) on success.
#
# Arguments:
#   replicates : the groups/replicates argument passed by the user
#   combined_n : numeric upper bound; Inf skips the ceiling check
.validate_replicates_dagjk_arg <- function(replicates, combined_n = Inf) {
  # Must be a single non-NA numeric value
  if (!is.numeric(replicates) || length(replicates) != 1L || is.na(replicates)) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be a single, non-NA number.",
        "i" = "Got {.cls {class(replicates)}} of length {length(replicates)}.",
        "v" = "Supply a whole number >= 2, e.g. {.code replicates = 50L}."
      ),
      class = "surveywts_error_jackknife_replicates_invalid"
    )
  }
  # Must be a whole number (zero fractional part)
  if (replicates %% 1 != 0) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be a whole number, not {.val {replicates}}.",
        "v" = "Use an integer value, e.g. {.code replicates = {round(replicates)}}."
      ),
      class = "surveywts_error_replicates_not_whole_number"
    )
  }
  # Must be at least 2
  if (replicates < 2) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be >= 2; got {.val {replicates}}.",
        "i" = "The DAGJK formula is degenerate at G = 1 (variance estimate is 0).",
        "v" = "Use at least 2 groups. Valliant (2020) recommends {.code replicates = 50}."
      ),
      class = "surveywts_error_jackknife_replicates_too_small"
    )
  }
  # Must not exceed combined NPS + reference row count
  if (is.finite(combined_n) && replicates > combined_n) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg replicates} ({replicates}) exceeds the combined NPS + reference row ",
          "count ({combined_n})."
        ),
        "i" = paste0(
          "Each group must contain at least 1 unit; groups cannot exceed the ",
          "total number of combined rows."
        ),
        "v" = paste0(
          "Reduce {.arg replicates} to at most {combined_n} ",
          "(combined NPS + reference rows)."
        )
      ),
      class = "surveywts_error_jackknife_replicates_exceeds_n"
    )
  }
  as.integer(replicates)
}

# ============================================================================
# .dagjk_single_replicate()
# ============================================================================

# Internal engine for one DAGJK replicate. Must be called inside tryCatch().
# Throws surveywts_error_jackknife_degenerate_replicate on any failure condition.
#
# Arguments:
#   g               : integer -- the group index being deleted (1..G)
#   group_assign    : integer vector of length (n_nps + n_ref) -- group membership
#   nps_data        : data.frame -- the NPS @data
#   ref_data        : data.frame -- the reference @data
#   ref_wt_col      : character(1) -- name of weight column in ref_data
#   ipw_entry       : list -- the ipw() history entry
#   calib_entry     : list or NULL -- the last calibration history entry
#   n_nps           : integer -- total NPS row count
#   n_ref           : integer -- total reference row count
#   use_level_b     : logical -- TRUE if targets_from_reference
#   ref_design      : survey_taylor -- original reference design
#   wt_col          : character(1) -- name of the weight column in the NPS output
#   strata_var      : character(1) or NULL -- NPS @variables$strata column name,
#                     used for per-stratum extended formula dispatch (Kott 2001 §3)
#   G               : integer -- total number of groups (for extended formula check)
#
# Returns: numeric vector of length n_nps -- replicate pseudo-weights.
#   Entries for group-g NPS units are 0 (assigned by the caller after return).
.dagjk_single_replicate <- function(
  g, group_assign, nps_data, ref_data, ref_wt_col, ipw_entry,
  calib_entry, n_nps, n_ref, use_level_b, ref_design, wt_col,
  strata_var = NULL, G = 0L
) {
  # Indices into the combined sequence: 1..n_nps = NPS, (n_nps+1)..(n_nps+n_ref) = ref
  nps_in_g <- which(group_assign[seq_len(n_nps)] == g)
  ref_in_g <- which(group_assign[(n_nps + 1L):(n_nps + n_ref)] == g)

  # Subset: NPS rows NOT in group g
  nps_keep_idx <- setdiff(seq_len(n_nps), nps_in_g)
  ref_keep_idx <- setdiff(seq_len(n_ref), ref_in_g)

  if (length(nps_keep_idx) == 0L) {
    cli::cli_abort(
      c("x" = "Replicate {g}: no NPS units remain after group deletion."),
      class = "surveywts_error_jackknife_degenerate_replicate"
    )
  }
  if (length(ref_keep_idx) == 0L) {
    cli::cli_abort(
      c("x" = "Replicate {g}: no reference units remain after group deletion."),
      class = "surveywts_error_jackknife_degenerate_replicate"
    )
  }

  nps_g   <- nps_data[nps_keep_idx, , drop = FALSE]
  ref_g   <- ref_data[ref_keep_idx, , drop = FALSE]
  w_ref_g <- ref_g[[ref_wt_col]]

  # Reference weight adjustment (Valliant 2020, Eq. 1):
  #   N_hat_g = sum(w_ref) over reference units NOT in g
  #   n_nps_g = count of NPS units NOT in g
  N_hat_g   <- sum(w_ref_g)
  n_nps_g   <- length(nps_keep_idx)

  if (N_hat_g - n_nps_g < 0) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Replicate {g}: N_hat_g ({round(N_hat_g, 2)}) < n_nps_g ({n_nps_g}). ",
          "Reference weight adjustment produces negative adjusted weights."
        )
      ),
      class = "surveywts_error_jackknife_degenerate_replicate"
    )
  }

  adjust_factor_g <- (N_hat_g - n_nps_g) / N_hat_g
  w_ref_adj_g     <- w_ref_g * adjust_factor_g

  # Drop the original weight column from nps_g before passing to ipw()
  nps_g_no_wt <- nps_g[, setdiff(names(nps_g), wt_col), drop = FALSE]

  # Revert "(Missing)" if missing_method = "separate"
  sel_vars <- all.vars(ipw_entry$formula)
  if (identical(ipw_entry$missing_method, "separate")) {
    for (var in sel_vars) {
      col <- nps_g_no_wt[[var]]
      if (is.factor(col) && "(Missing)" %in% levels(col)) {
        char_col <- as.character(col)
        char_col[char_col == "(Missing)"] <- NA_character_
        existing_levels <- sort(unique(char_col[!is.na(char_col)]))
        nps_g_no_wt[[var]] <- factor(char_col, levels = existing_levels)
      }
    }
  }

  # Build within-replicate reference survey_taylor
  ref_g_design <- surveycore::survey_taylor(
    data      = ref_g,
    variables = ref_design@variables
  )

  # Refit ipw() on reduced combined dataset
  maxit_g   <- ipw_entry$maxit %||% 25L
  epsilon_g <- ipw_entry$epsilon %||% 1e-8

  ipw_result_g <- tryCatch(
    suppressWarnings(surveywts::ipw(
      data             = nps_g_no_wt,
      reference        = ref_g_design,
      selection        = ipw_entry$formula,
      method           = ipw_entry$method,
      estimating_eq    = ipw_entry$estimating_eq,
      missing_method   = ipw_entry$missing_method,
      adjust_reference = FALSE,   # already applied manually above
      trim             = FALSE,   # trimming handled separately below
      maxit            = as.integer(maxit_g),
      epsilon          = epsilon_g,
      wt_name          = wt_col
    )),
    error = function(e) {
      cli::cli_abort(
        c("x" = "Replicate {g}: ipw() failed -- {conditionMessage(e)}"),
        class = "surveywts_error_jackknife_degenerate_replicate"
      )
    }
  )

  # Extract propensity weights (already 1/pi_hat from ipw())
  w_g <- ipw_result_g@data[[wt_col]]

  # Validate: no NA, no non-finite, no non-positive values
  # nocov start
  # Defensive: ipw() validates its own output; this fires only if ipw() produces
  # NA/non-finite/non-positive weights despite passing its own internal checks --
  # not reachable through the public API in practice.
  if (any(is.na(w_g)) || any(!is.finite(w_g)) || any(w_g <= 0)) {
    cli::cli_abort(
      c("x" = "Replicate {g}: degenerate pseudo-weights (NA, non-finite, or <= 0)."),
      class = "surveywts_error_jackknife_degenerate_replicate"
    )
  }
  # nocov end

  # Scale replicate weights per stratum (Kott 2001 §1 standard; §3 eq. 2 extended)
  # When the NPS has an explicit strata variable, apply per-stratum scaling.
  # For each stratum h: n_h = total NPS rows in h; n_hg = rows in group g.
  #   n_hg == 0        : weights unchanged (stratum h has no units in group g)
  #   n_h >= G (std)   : scale factor = n_h / (n_h - n_hg)  (standard formula)
  #   n_h < G (extd)   : Z = sqrt(G / ((G-1)*n_h*(n_h-1))); deleted = 1-(n_h-1)*Z;
  #                       retained stratum-h = 1+Z  (Kott 2001 §3 eq. 2)
  # Note: the kept rows in nps_keep_idx align 1-to-1 with w_g from ipw().
  if (!is.null(strata_var) && strata_var %in% names(nps_data) && G > 0L) {
    # nps_data has ALL rows; nps_keep_idx are the retained (non-group-g) rows
    nps_strata_all <- nps_data[[strata_var]]
    nps_strata_kept <- nps_strata_all[nps_keep_idx]
    nps_strata_g    <- nps_strata_all[nps_in_g]
    strata_levels   <- unique(nps_strata_all)
    scale_vec       <- rep(1, length(w_g))  # default: no scaling

    for (h in strata_levels) {
      h_total     <- sum(nps_strata_all == h)    # n_h total NPS rows in stratum h
      h_in_g      <- sum(nps_strata_g == h)      # n_hg: group-g NPS rows in stratum h
      h_kept_idx  <- which(nps_strata_kept == h) # positions in kept-rows vector

      if (h_in_g == 0L) {
        # No group-g units from this stratum: weights unchanged
        next
      } else if (h_total >= G) {
        # Standard formula: n_h / (n_h - n_hg)
        scale_vec[h_kept_idx] <- h_total / (h_total - h_in_g)
      } else {
        # Extended formula (Kott 2001 §3 eq. 2): n_h < G
        # Note: n_h = 1 produces Inf (single-PSU stratum); this path should not
        # be reached for n_h = 1 because replicates_exceeds_n guards against
        # G > combined_n, but if a stratum has exactly 1 row and G > 1, Inf
        # propagates and is caught by the degenerate check below.
        Z                     <- sqrt(G / ((G - 1L) * h_total * (h_total - 1L)))
        # Deleted units (in group g): these rows are NOT in nps_keep_idx,
        # so they are not in w_g. The caller assigns 0 for deleted units.
        # Retained units in stratum h: apply (1 + Z) factor
        scale_vec[h_kept_idx] <- 1 + Z
      }
    }
    w_g <- w_g * scale_vec
  } else {
    # No strata variable: uniform scaling to N_hat_g (single-stratum treatment)
    w_g <- w_g * (N_hat_g / sum(w_g))
  }

  # Apply trimming if ipw_entry recorded a trim_threshold
  trim_threshold <- ipw_entry$trim_threshold
  if (!is.null(trim_threshold)) {
    w_g <- pmin(w_g, trim_threshold)
  }

  # Reapply calibration if in history
  if (!is.null(calib_entry)) {
    calib_result_g <- tryCatch({
      if (calib_entry$operation %in% c("raking", "calibrate_rake")) {
        if (use_level_b) {
          targets_g <- .reestimate_margins_from_reference(
            calib_entry = calib_entry,
            ref_design  = ref_design,
            ref_data_b  = ref_g
          )
        } else {
          # Old "raking" entries stored targets as `margins`; new ones as `targets`.
          targets_g <- calib_entry$parameters$targets %||%
            calib_entry$parameters$margins
        }
        rake_result <- surveywts::calibrate_rake(
          data      = ipw_result_g,
          targets   = targets_g,
          type      = calib_entry$parameters$type,
          algorithm = calib_entry$parameters$algorithm %||%
            calib_entry$parameters$method,
          cap       = calib_entry$parameters$cap,
          control   = calib_entry$parameters$control
        )
        rake_result@data[[wt_col]]
      } else {
        # operation "calibration" (old), "calibrate_greg" (legacy), or
        # "calibrate_linear" / "calibrate_logit" (current)
        # Old entries stored population + variables; new entries store targets.
        greg_targets <- calib_entry$parameters$targets %||%
          calib_entry$parameters$population
        greg_model <- calib_entry$parameters$model %||%
          calib_entry$parameters$method
        calib_fn <- if (identical(calib_entry$operation, "calibrate_logit") ||
          identical(greg_model, "logit")) {
          surveywts::calibrate_logit
        } else {
          surveywts::calibrate_linear
        }
        if (use_level_b) {
          calib_result <- calib_fn(
            data             = ipw_result_g,
            targets          = greg_targets,
            type             = calib_entry$parameters$type,
            control          = calib_entry$parameters$control,
            reference_design = ref_g_design
          )
        } else {
          calib_result <- calib_fn(
            data    = ipw_result_g,
            targets = greg_targets,
            type    = calib_entry$parameters$type,
            control = calib_entry$parameters$control
          )
        }
        calib_result@data[[wt_col]]
      }
    }, error = function(e) {
      cli::cli_abort(
        c("x" = "Replicate {g}: calibration failed -- {conditionMessage(e)}"),
        class = "surveywts_error_jackknife_degenerate_replicate"
      )
    })
    w_g <- calib_result_g
  }

  # Construct output: full-length vector with 0s for group-g NPS units
  w_full <- numeric(n_nps)
  w_full[nps_keep_idx] <- w_g

  w_full
}

# ============================================================================
# .dagjk_single_replicate_calib()
# ============================================================================

# Internal engine for one DAGJK calibration-only replicate.
# Must be called inside tryCatch(). Throws
# surveywts_error_jackknife_degenerate_replicate on any failure condition.
#
# Algorithm (spec §3.4, "Calibration-only DAGJK algorithm"):
#   1. Find NPS row indices in group g (and reference row indices if Level B).
#   2. Form reduced NPS: S_A_minus_g = NPS rows NOT in group g.
#   3. Scale factor: a_g = n_A / (n_A - n_Ag)
#   4. Apply: w_i_adj = w_i * a_g (CURRENT weights, NOT equal weights).
#   5. Dispatch calibration replay via .dispatch_calibration_replay().
#   6. Extract replicate weight vector; zeros inserted for group-g NPS units.
#
# Arguments:
#   g               : integer -- the group index being deleted (1..G)
#   group_assign    : integer vector of length combined_n -- group membership.
#                     For Level A: length n_nps. For Level B: length n_nps+n_ref.
#   nps_data        : data.frame -- the NPS @data
#   ref_data        : data.frame or NULL -- the reference @data (NULL for Level A)
#   ref_wt_col      : character(1) or NULL -- weight column in ref_data
#   calib_entry     : list -- the last calibration history entry
#   n_nps           : integer -- total NPS row count
#   n_ref           : integer -- total reference row count (0 for Level A)
#   use_level_b     : logical -- TRUE if targets_from_reference
#   ref_design      : survey_taylor or NULL
#   wt_col          : character(1) -- weight column name in nps_data
#
# Returns: numeric vector of length n_nps -- replicate pseudo-weights.
#   Entries for group-g NPS units are 0 (inserted by this function).
.dagjk_single_replicate_calib <- function(
  g, group_assign, nps_data, ref_data, ref_wt_col,
  calib_entry, n_nps, n_ref, use_level_b, ref_design, wt_col
) {
  # Indices into the group assignment vector (length combined_n = n_nps [+ n_ref])
  nps_in_g <- which(group_assign[seq_len(n_nps)] == g)

  nps_keep_idx <- setdiff(seq_len(n_nps), nps_in_g)
  n_Ag         <- length(nps_in_g)

  if (length(nps_keep_idx) == 0L) {
    cli::cli_abort(
      c("x" = "Replicate {g}: no NPS units remain after group deletion."),
      class = "surveywts_error_jackknife_degenerate_replicate"
    )
  }

  # Scale factor: a_g = n_A / (n_A - n_Ag)
  a_g <- n_nps / (n_nps - n_Ag)

  # Reduced NPS data with scaled current weights
  nps_g      <- nps_data[nps_keep_idx, , drop = FALSE]
  nps_g[[wt_col]] <- nps_g[[wt_col]] * a_g

  # Build survey_nonprob from reduced NPS for dispatch function
  nps_g_obj <- surveycore::survey_nonprob(
    data      = nps_g,
    variables = list(weights = wt_col),
    metadata  = surveycore::survey_metadata()
  )

  # Level B: form reduced reference data
  ref_data_b <- NULL
  if (use_level_b && !is.null(ref_data)) {
    ref_in_g     <- which(
      group_assign[(n_nps + 1L):(n_nps + n_ref)] == g
    )
    ref_keep_idx <- setdiff(seq_len(n_ref), ref_in_g)
    if (length(ref_keep_idx) == 0L) {
      cli::cli_abort(
        c("x" = "Replicate {g}: no reference units remain after group deletion."),
        class = "surveywts_error_jackknife_degenerate_replicate"
      )
    }
    ref_data_b <- ref_data[ref_keep_idx, , drop = FALSE]
  }

  # Dispatch calibration replay
  calib_result_g <- tryCatch(
    .dispatch_calibration_replay(
      data        = nps_g_obj,
      calib_entry = calib_entry,
      ref_design  = ref_design,
      ref_data_b  = ref_data_b,
      use_level_b = use_level_b
    ),
    error = function(e) {
      cli::cli_abort(
        c("x" = "Replicate {g}: calibration failed -- {conditionMessage(e)}"),
        class = "surveywts_error_jackknife_degenerate_replicate"
      )
    }
  )

  # Extract calibrated weight vector
  w_g <- .extract_weight_vec(calib_result_g, wt_col)

  # Validate: no NA, no non-finite, no non-positive values among retained units
  # nocov start
  # Defensive: dispatched calibration functions validate their own output.
  # This fires only if they return NA/non-finite/non-positive despite internal checks.
  if (any(is.na(w_g)) || any(!is.finite(w_g)) || any(w_g <= 0)) {
    cli::cli_abort(
      c("x" = "Replicate {g}: degenerate calibration weights (NA, non-finite, or <= 0)."),
      class = "surveywts_error_jackknife_degenerate_replicate"
    )
  }
  # nocov end

  # Construct full-length output: 0 for group-g units, calibrated weights for rest
  w_full <- numeric(n_nps)
  w_full[nps_keep_idx] <- w_g

  w_full
}
