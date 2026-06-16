# R/create_group_jackknife_weights.R
#
# create_group_jackknife_weights() -- delete-a-group jackknife (DAGJK) replicate
# weights for non-probability samples (NPS).
# Engine helpers are in R/jackknife-dagjk-utils.R.

# ============================================================================
# create_group_jackknife_weights()
# ============================================================================

#' Create group jackknife replicate weights for non-probability samples
#'
#' Generates delete-a-group jackknife (DAGJK) replicate weights for a
#' non-probability sample (NPS) by randomly partitioning the combined
#' NPS + reference dataset into `groups` deletion groups, then refitting
#' the full estimation pipeline (binary logistic IPW model and any downstream
#' calibration) on the reduced dataset for each group replicate.
#'
#' @param data A `survey_nonprob` object. Must have an `operation = "ipw"`
#'   entry in `@metadata@weighting_history`. `data.frame`, `weighted_df`,
#'   `survey_taylor`, and `survey_replicate` all error.
#' @param groups `integer(1)`. Number of random deletion groups G. Must be a
#'   whole number >= 2. Whole-number doubles (e.g., `50.0`) are coerced to
#'   integer silently. Default `50L` follows Valliant (2020) simulation
#'   validation. Must be <= combined NPS + reference row count.
#' @param ... Must be empty. Forces all remaining arguments to be named.
#' @param reference_sample `survey_taylor` or `NULL`. Reference probability
#'   sample. When non-`NULL`, overrides any reference design stored in the
#'   `ipw()` history entry. `survey_replicate` and `data.frame` inputs error
#'   with `surveywts_error_reference_sample_class`.
#' @param seed `integer(1)` or `NULL`. RNG seed for reproducible group
#'   assignment. When non-`NULL`, `set.seed(seed)` is called once immediately
#'   before group assignment. The caller's global RNG state is not restored.
#'
#' @return A `survey_nonprob` with:
#'   - G new replicate weight columns added to `@data`, named `repwt_1`,
#'     `repwt_2`, ..., `repwt_G`. If any replicates fail, successful replicates
#'     are numbered sequentially from 1.
#'   - `@variables$repweights` populated with the replicate column names.
#'   - `@variables$scale` set to `(G_success - 1) / G_success`.
#'   - `@variables$rscales` set to `rep(1, G_success)`.
#'   - `@variables$mse` set to `TRUE`.
#'   - `@variables$type` set to `"group-jackknife"`.
#'   - A new history entry appended to `@metadata@weighting_history` with
#'     `operation = "group_jackknife_weights"`.
#'
#' @details
#' **Model refit requirement:** The binary logistic model (and any downstream
#' calibration) is refit from scratch in every replicate. Applying full-sample
#' pseudo-weights without refitting underestimates variance by ignoring
#' estimation uncertainty in the propensity parameters (Elliott and Valliant
#' 2017, §3.1; Valliant 2020, §3.2.1).
#'
#' **Scaling factor:** Always `(G-1)/G` where `G` is the number of groups.
#' Using total sample size n in place of G would inflate variance estimates
#' by approximately (n-1)/(G-1) -- a severe overestimate at typical values
#' (e.g., n=500, G=50 gives approximately 10x inflation).
#'
#' **Groups span both samples:** Random groups are formed across the full
#' combined NPS + reference dataset. Dropping only NPS units from group g
#' while retaining reference units in group g would misspecify the replicate.
#'
#' **DR estimator bias:** When the pipeline applies both IPW (quasi-
#' randomization) and a subsequent calibration step (a doubly robust estimator),
#' DAGJK standard error estimates are slightly conservative (positively biased
#' by approximately 3-5% at n=500 and 2-3% at n=1000; Valliant 2020, Table 8).
#' This bias does not vanish as n grows; its cause is not established in the
#' literature. No runtime warning is emitted.
#'
#' **No formal consistency proof:** A formal proof of the consistency of the
#' DAGJK for non-probability samples does not exist in the literature (Valliant
#' 2020, §2.4). Consistency is claimed by analogy to Krewski and Rao (1981).
#' Variance estimates should be treated as asymptotically justified
#' approximations, not guaranteed-consistent estimators.
#'
#' **Nonsample variance component:** DAGJK captures only the sample-based
#' estimation variance. The nonsample component (uncertainty about unobserved
#' population units) is not captured. For probability samples this is handled
#' by finite population corrections; no equivalent mechanism exists for NPS.
#'
#' **Jackknife vs. bootstrap:** The group jackknife is on firmer theoretical
#' ground than the bootstrap for NPS variance estimation (Elliott and Valliant
#' 2017, §4), though neither has a complete asymptotic theory.
#'
#' **`mse = TRUE` and centering:** `mse = TRUE` centers each replicate
#' estimate on the full-sample estimate, matching the DAGJK formula
#' `v_J = (G-1)/G * sum((theta_g - theta)^2)`. Setting `mse = FALSE` would
#' produce a different variance estimator not justified by the DAGJK literature.
#' When fewer than G replicates succeed, the scale is updated to
#' `(G_success - 1) / G_success` -- a pragmatic approximation that treats the
#' G_success successful replicates as the effective G.
#'
#' **Full-sample estimate `theta`:** The full-sample estimate `theta` in the
#' DAGJK formula is the estimate computed using the weight column currently in
#' `@data` -- which reflects all weighting steps applied before calling this
#' function. The downstream survey infrastructure uses `mse = TRUE` to enforce
#' this centering.
#'
#' **Degrees of freedom:** The DAGJK variance estimator has degrees of freedom
#' `df = G_success - 1`, where `G_success` is the number of successful
#' replicates. Downstream inference functions that require degrees of freedom
#' should use `df = G_success - 1`, consistent with the standard grouped
#' jackknife result (Krewski and Rao 1981 analogy).
#'
#' **Natural group structures:** Elliott & Valliant (2017, §3.1) identify
#' recruiting/hosting websites as natural deletion groups for NPS group
#' jackknife. This implementation assigns units to groups randomly (via
#' `seed`). Users with panel or hosting-website cluster structure should use
#' random group assignment as an approximation.
#'
#' **Reference sample precedence:** When `reference_sample` is supplied and
#' the `ipw()` history also stores a reference design, the `reference_sample`
#' argument takes precedence silently. Verify that the supplied reference
#' matches the one used in `ipw()` -- using a different reference for the
#' replicate loop than for the full-sample model produces methodologically
#' inconsistent variance estimates.
#'
#' **Return type and `@variables$type`:** This function returns a
#' `survey_nonprob`, not a `survey_replicate`, because DAGJK replicate weights
#' are NPS pseudo-weights that must remain associated with the IPW weighting
#' pipeline. This is consistent with
#' `create_bootstrap_weights(type = "quasi-randomization")`. The
#' `@variables$type` field is set to `"group-jackknife"`, a surveywts-specific
#' value. Downstream `survey`-package functions expecting a standard type
#' (e.g., `"JKn"`, `"BRR"`) will not recognize this value.
#'
#' @references
#'   Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability
#'   samples. *Statistical Science* **32**(2), 249--264.
#'   \doi{10.1214/16-STS598}
#'
#'   Valliant, R. (2020). Comparing alternatives for estimation from
#'   nonprobability samples. *Journal of Survey Statistics and Methodology*
#'   **8**, 231--263. \doi{10.1093/jssam/smz003}
#'
#'   Valliant, R. (2009). Model-based prediction of finite population totals.
#'   In D. Pfeffermann and C.R. Rao (Eds.), *Handbook of Statistics, Sample
#'   Surveys: Inference and Analysis* (Vol. 29B). Elsevier.
#'   \doi{10.1016/S0169-7161(09)00223-5}
#'
#' @family replicate-weights
#' @export
create_group_jackknife_weights <- function(
  data,
  groups = 50L,
  ...,
  reference_sample = NULL,
  seed = NULL
) {
  rlang::check_dots_empty()

  # ---- Validation order (strict per spec §3.4) ----------------------------

  # 1. data class: common replicate input check
  .validate_replicate_input(data)

  # 1b. DAGJK-specific: data must be survey_nonprob (not survey_taylor)
  if (!S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.fn create_group_jackknife_weights} requires a ",
          "{.cls survey_nonprob}; got {.cls {cls}}."
        ),
        "i" = paste0(
          "The DAGJK requires a weighting history attached to a ",
          "{.cls survey_nonprob} object."
        ),
        "v" = paste0(
          "Use {.fn ipw} or a calibration function to create a ",
          "{.cls survey_nonprob}, then call ",
          "{.fn create_group_jackknife_weights}."
        )
      ),
      class = "surveywts_error_unsupported_class"
    )
  }

  # 2. reference_sample class (if non-NULL)
  if (!is.null(reference_sample)) {
    .validate_reference_sample(reference_sample)
  }

  # 3. groups: type / whole-number / minimum (ceiling check deferred to after
  #    reference resolution when we know combined_n)
  groups <- .validate_replicates_dagjk_arg(groups, combined_n = Inf)

  # 4. History routing: find IPW entry and last calibration entry
  ipw_entries <- Filter(
    function(e) identical(e$operation, "ipw"),
    data@metadata@weighting_history
  )
  ipw_entry <- if (length(ipw_entries) > 0L) ipw_entries[[length(ipw_entries)]] else NULL

  calib_entries <- Filter(
    function(e) e$operation %in% c(
      "calibrate_rake", "calibrate_linear", "calibrate_logit",
      "poststratify", "raking",
      # Legacy operation names from pre-v0.4 history entries:
      "calibration", "calibrate_greg"
    ),
    data@metadata@weighting_history
  )
  calib_entry <- if (length(calib_entries) > 0L) {
    calib_entries[[length(calib_entries)]]
  } else {
    NULL
  }

  # If neither IPW nor calibration entry: error
  if (is.null(ipw_entry) && is.null(calib_entry)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "No IPW or calibration step found in the weighting history of ",
          "{.arg data}."
        ),
        "i" = paste0(
          "{.fn create_group_jackknife_weights} requires an {.fn ipw} or ",
          "calibration step in the weighting history."
        ),
        "v" = paste0(
          "Call {.fn ipw} or a calibration function on the non-probability ",
          "sample before calling {.fn create_group_jackknife_weights}."
        )
      ),
      class = "surveywts_error_jackknife_no_history"
    )
  }

  use_level_b <- isTRUE(calib_entry$parameters$targets_from_reference)

  # 5. Reference resolution: conditional on path and level
  n_nps <- nrow(data@data)

  if (!is.null(ipw_entry)) {
    # IPW path: reference always required
    ref_design <- reference_sample %||% ipw_entry$reference_design
    if (is.null(ref_design)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "A reference probability sample is required for ",
            "{.fn create_group_jackknife_weights}."
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
        class = "surveywts_error_jackknife_no_reference"
      )
    }
    n_ref      <- nrow(ref_design@data)
    combined_n <- n_nps + n_ref
  } else if (use_level_b) {
    # Calibration-only Level B: reference required
    ref_design <- reference_sample %||%
      calib_entry$parameters$reference_design
    if (is.null(ref_design)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "A reference probability sample is required for ",
            "{.fn create_group_jackknife_weights}."
          ),
          "i" = paste0(
            "No reference design found in the calibration history entry ",
            "and {.arg reference_sample} was not supplied."
          ),
          "v" = paste0(
            "Supply the reference design via {.arg reference_sample}, or ",
            "re-run the calibration with a {.cls survey_taylor} reference."
          )
        ),
        class = "surveywts_error_jackknife_no_reference"
      )
    }
    n_ref      <- nrow(ref_design@data)
    combined_n <- n_nps + n_ref
  } else {
    # Calibration-only Level A: no reference needed
    ref_design <- NULL
    n_ref      <- 0L
    combined_n <- n_nps
  }

  # 5b. Ceiling check (now that combined_n is known)
  .validate_replicates_dagjk_arg(groups, combined_n = combined_n)

  # ---- Second-call overwrite check ----------------------------------------
  data <- .handle_repweights_overwrite(
    data,
    fn_name       = "create_group_jackknife_weights",
    warning_class = "surveywts_warning_jackknife_repweights_overwritten"
  )

  # ---- Small groups warning (before loop) ---------------------------------
  avg_group_size <- floor(combined_n / groups)
  if (avg_group_size < 5L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Average group size is {avg_group_size} unit(s) ",
          "({combined_n} combined / {groups} groups)."
        ),
        "i" = paste0(
          "Groups with fewer than 5 units may cause the logistic model to fail ",
          "to converge in some replicates."
        ),
        "v" = paste0(
          "Reduce {.arg groups} or ensure the combined NPS + reference dataset ",
          "is large enough relative to the number of groups."
        )
      ),
      class = "surveywts_warning_jackknife_small_groups"
    )
  }

  # ---- Group assignment ---------------------------------------------------
  # For Level A calibration-only: assign only n_A rows (no reference)
  # For all other paths: assign n_A + n_ref rows
  if (!is.null(seed)) set.seed(seed)
  group_assign <- sample(
    rep(seq_len(groups), length.out = combined_n)
  )

  # ---- Main loop ----------------------------------------------------------
  wt_col   <- data@variables$weights
  nps_data <- data@data

  # Only set ref_data / ref_wt_col for paths that have a reference
  ref_data   <- if (!is.null(ref_design)) ref_design@data else NULL
  ref_wt_col <- if (!is.null(ref_design)) ref_design@variables$weights else NULL

  failed_reps <- 0L
  repwt_list  <- list()

  for (g in seq_len(groups)) {
    rep_ok <- tryCatch({
      if (!is.null(ipw_entry)) {
        # IPW path (and doubly-robust)
        w_rep <- .dagjk_single_replicate(
          g            = g,
          group_assign = group_assign,
          nps_data     = nps_data,
          ref_data     = ref_data,
          ref_wt_col   = ref_wt_col,
          ipw_entry    = ipw_entry,
          calib_entry  = calib_entry,
          n_nps        = n_nps,
          n_ref        = n_ref,
          use_level_b  = use_level_b,
          ref_design   = ref_design,
          wt_col       = wt_col
        )
      } else {
        # Calibration-only path
        w_rep <- .dagjk_single_replicate_calib(
          g            = g,
          group_assign = group_assign,
          nps_data     = nps_data,
          ref_data     = ref_data,
          ref_wt_col   = ref_wt_col,
          calib_entry  = calib_entry,
          n_nps        = n_nps,
          n_ref        = n_ref,
          use_level_b  = use_level_b,
          ref_design   = ref_design,
          wt_col       = wt_col
        )
      }
      repwt_list[[length(repwt_list) + 1L]] <- w_rep
      TRUE
    }, error = function(e) {
      FALSE
    })
    if (!isTRUE(rep_ok)) {
      failed_reps <- failed_reps + 1L
    }
  }

  # ---- Post-loop checks --------------------------------------------------
  if (failed_reps > 0.1 * groups) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{failed_reps} of {groups} group replicates failed and were skipped."
        ),
        "i" = paste0(
          "A replicate fails when the logistic model does not converge or ",
          "produces degenerate propensity scores in the reduced dataset."
        ),
        "v" = paste0(
          "Reduce {.arg groups} or inspect the data for extreme covariate ",
          "imbalance."
        )
      ),
      class = "surveywts_warning_jackknife_replicates_failed"
    )
  }

  G_success <- groups - failed_reps

  if (G_success == 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "All {groups} group replicates failed; no replicate weights could ",
          "be produced."
        ),
        "i" = paste0(
          "Every replicate produced degenerate propensity scores or ",
          "calibration divergence."
        ),
        "v" = paste0(
          "Check {.arg data} for single-level covariates or extreme covariate ",
          "imbalance with the reference. Consider reducing {.arg groups}."
        )
      ),
      class = "surveywts_error_jackknife_all_replicates_failed"
    )
  }

  # ---- Assemble output ---------------------------------------------------
  repwt_names <- paste0("repwt_", seq_len(G_success))
  for (i in seq_len(G_success)) {
    data@data[[repwt_names[i]]] <- repwt_list[[i]]
  }

  # Negative weight warning (after assembling all replicate columns)
  rep_mat <- as.matrix(data@data[, repwt_names, drop = FALSE])
  if (any(rep_mat < 0, na.rm = TRUE)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "One or more replicate weight values are negative."
        ),
        "i" = paste0(
          "Negative replicate weights can occur after downstream calibration. ",
          "Variance estimates using these replicates should be interpreted ",
          "cautiously."
        ),
        "v" = "Review calibration targets or use {.code trim = TRUE} in {.fn ipw}."
      ),
      class = "surveywts_warning_jackknife_negative_replicate_weights"
    )
  }

  data@variables$repweights <- repwt_names
  data@variables$scale      <- (G_success - 1L) / G_success
  data@variables$rscales    <- rep(1, G_success)
  data@variables$mse        <- TRUE
  data@variables$type       <- "group-jackknife"

  # Append history entry
  meta <- data@metadata
  meta@weighting_history <- c(
    meta@weighting_history,
    list(list(
      step             = length(meta@weighting_history) + 1L,
      operation        = "group_jackknife_weights",
      timestamp        = Sys.time(),
      groups           = as.integer(groups),
      groups_used      = as.integer(G_success),
      groups_failed    = as.integer(failed_reps),
      seed             = seed,
      scale            = (G_success - 1L) / G_success,
      reference_design = ref_design,   # NULL for calibration-only Level A
      source_design    = .snapshot_variables_for_history(data)
    ))
  )
  data@metadata <- meta

  data
}
