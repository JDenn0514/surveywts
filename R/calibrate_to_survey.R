# R/calibrate_to_survey.R
#
# calibrate_to_survey() — calibrate a replicate-weight design to
# population totals estimated from a control (reference) survey design,
# using the Opsomer & Erciulescu (2022) replication variance adjustment.

#' Reweight to population totals estimated from a control survey
#'
#' Adjusts the full-sample and replicate weights of `primary_design` so that
#' its estimated totals for `variables` match those estimated from
#' `control_design`. Implements the Opsomer & Erciulescu (2022) replication
#' variance adjustment, which correctly propagates the sampling uncertainty
#' of the control survey's estimates into the calibrated primary design.
#' When `targets` is non-NULL, additional fixed census margins are enforced
#' simultaneously alongside the random margins from the control survey.
#'
#' @param primary_design A `survey_replicate` or `survey_nonprob` object with
#'   replicate weights. The design to be calibrated. Must have replicate
#'   weights and a non-NULL `@variables$scale` replication constant.
#' @param control_design A `survey_replicate` or `survey_nonprob` object with
#'   replicate weights. The reference survey from which random population
#'   totals are estimated. Must have replicate weights and a non-NULL
#'   `@variables$scale`. Does not affect the class of the returned object.
#' @param variables <[`tidy-select`][tidyselect::language]> Bare names of the
#'   random calibration variables in `primary_design@data`. Must be present in
#'   both designs. These are the variables whose totals are estimated from
#'   the control survey and vary per replicate in the Opsomer algorithm.
#' @param targets `NULL` (the default) or a named list of fixed census
#'   margins. Each element's name is a column in `primary_design@data`.
#'   Each element is either a named numeric vector (names are level labels)
#'   or a tibble with the variable column plus `"n"` (count) or `"prop"`
#'   (proportion). Format A (named numeric vector) and Format B (tibble) may
#'   be mixed within the same list. When `NULL`, the Opsomer path runs with
#'   no fixed margins; `type` is matched but unused.
#' @param type `"prop"` (the default) or `"count"`. Controls interpretation
#'   of `targets` values. `"prop"` means proportions summing to 1.0 per
#'   variable (each element must sum to 1.0 within 1e-6); `"count"` means
#'   population counts (positive non-NA values). Ignored when `targets =
#'   NULL`. Matched with [rlang::arg_match()].
#' @param method Calibration method: `"rake"` (the default), `"linear"`, or
#'   `"logit"`. Applied to both the full-sample and per-replicate calibration
#'   steps. Matched with [rlang::arg_match()].
#' @param algorithm Raking algorithm; used only when `method = "rake"`.
#'   `"classic_ipf"` (the default): iterative proportional fitting (Deming
#'   & Stephan 1940) — the algorithm used in Opsomer & Erciulescu (2022).
#'   `"nr"`: Newton-Raphson raking (Deville, Sarndal & Sautory 1993).
#'   Silently ignored when `method != "rake"`. Matched with
#'   [rlang::arg_match()].
#' @param bounds Numeric vector of length 2: `c(lower, upper)`. Bounds on
#'   the calibrated-to-starting-weight ratio. `c(-Inf, Inf)` (default) means
#'   no bounds. Passed to `survey::calibrate()`.
#' @param unit_scale `NULL` or a positive numeric vector of length
#'   `nrow(primary_design@data)`. Per-unit variance scaling passed as the
#'   `variance` argument to `survey::calibrate()`. `NULL` means no scaling.
#' @param reference_design A `survey_taylor` object or `NULL`. Stored in the
#'   history entry for provenance only; not used in computation.
#' @param control Named list of calibration control parameters. Known keys:
#'   - `maxit`: maximum iterations (default `50L`)
#'   - `epsilon`: convergence tolerance (default `1e-10`)
#'
#'   Unknown keys trigger a `surveywts_warning_control_param_ignored`
#'   warning.
#'
#' @returns A calibrated design object whose class matches `primary_design`:
#'   a `survey_nonprob` input returns a `survey_nonprob`; a
#'   `survey_replicate` input returns a `survey_replicate`. Updated
#'   full-sample and replicate weights are written back. A new entry with
#'   `operation = "calibrate_to_survey"` is appended to the weighting
#'   history. The history entry always includes `a_constants` (the Opsomer
#'   perturbation constants, length `R_eff = K * R`) and `K` (the expansion
#'   factor). When `targets` is non-NULL, the entry additionally includes
#'   `targets` (user-supplied fixed margins), `type`, and `fixed_variables`.
#'
#' @details
#' **When to use.** Use [calibrate()] when your targets are fixed
#' census values with no sampling error of their own. Use
#' `calibrate_to_survey()` when the targets come from another survey:
#' the control survey's sampling error then carries into the replicate
#' variance. When you have only published estimates and their
#' variance-covariance matrix — not the control survey's data — use
#' [calibrate_to_estimate()].
#'
#'   Both `primary_design` and `control_design` must carry replicate weights
#'   and non-NULL `@variables$scale` replication constants. The scale
#'   constants are required to compute the Opsomer adjustment constants
#'   `a_r`. Use `create_bootstrap_weights()` or another `create_*_weights()`
#'   function to create designs with scale populated.
#'
#'   When `method = "linear"`, any negative calibrated full-sample weights
#'   are clipped to `.Machine$double.eps` with a warning. Replicate weights
#'   are never clipped.
#'
#' @section Algorithm:
#'   Implements the Opsomer & Erciulescu (2022) replication variance
#'   adjustment for sample-based calibration. The core idea is to
#'   calibrate each primary replicate to a *perturbed* version of the
#'   control-survey totals that incorporates the control survey's replication
#'   structure.
#'
#'   **Notation:**
#'   - \eqn{R} = number of primary replicate columns
#'   - \eqn{R_C} = number of control replicate columns
#'   - \eqn{A} = `primary_design@variables$scale` (scalar replication constant)
#'   - \eqn{A_C} = `control_design@variables$scale`
#'   - \eqn{\hat{t}_{Cx}} = control full-sample estimated totals for `variables`
#'   - \eqn{\hat{t}_{Cx}^{(r)}} = control replicate-\eqn{r} estimated totals
#'   - \eqn{T_{\text{fixed}}} = fixed population margins from `targets`
#'     (empty set when `targets = NULL`)
#'
#'   **Step 1.** Extract \eqn{A}, \eqn{A_C}, \eqn{R}, \eqn{R_C}.
#'
#'   **Step 2.** Compute expansion factor:
#'   when \eqn{R_C > R}, set \eqn{K = \lceil R_C / R \rceil},
#'   \eqn{R_{\text{eff}} = K R}, and \eqn{A_{\text{eff}} = A / K};
#'   otherwise \eqn{K = 1}, \eqn{R_{\text{eff}} = R},
#'   \eqn{A_{\text{eff}} = A}.
#'
#'   **Step 3.** Compute adjustment constants:
#'   \deqn{a_r = \begin{cases}
#'     \sqrt{A_C / A_{\text{eff}}} & r = 1, \ldots, \min(R_{\text{eff}}, R_C) \\
#'     0                           & r > \min(R_{\text{eff}}, R_C)
#'   \end{cases}}
#'   When \eqn{K = 1} this reduces to \eqn{\sqrt{A_C / A}}.
#'
#'   **Step 4.** Compute full-sample control totals \eqn{\hat{t}_{Cx}} and
#'   per-replicate control totals \eqn{\hat{t}_{Cx}^{(r)}} for each variable
#'   in `variables`.
#'
#'   **Step 5.** Draw a random mapping of control replicate columns to
#'   virtual primary replicates. One permutation is drawn per call; use
#'   `set.seed()` before calling to make results reproducible.
#'
#'   **Step 6.** Calibrate the full-sample weights of `primary_design` to
#'   the combined target set \eqn{\{ \hat{t}_{Cx} \}} (random margins) union
#'   \eqn{T_{\text{fixed}}} (fixed margins). This defines \eqn{w_i^*}.
#'
#'   **Step 7.** For each primary replicate \eqn{r = 1, \ldots, R}: for each
#'   virtual replicate \eqn{s} in the \eqn{K} repetitions of replicate
#'   \eqn{r}, compute the perturbed control total:
#'   \deqn{\hat{t}^*_{Cx}(s) =
#'     \hat{t}_{Cx} + a_s \bigl(\hat{t}^{(c_s)}_{Cx} - \hat{t}_{Cx}\bigr)}
#'   where \eqn{c_s} is the mapped control replicate for virtual replicate
#'   \eqn{s}. Calibrate the *original* primary replicate-\eqn{r} weights to
#'   \eqn{\hat{t}^*_{Cx}(s)} (random margins) union \eqn{T_{\text{fixed}}}
#'   (fixed margins). When \eqn{K > 1}, average the \eqn{K} calibrated
#'   weight vectors to obtain output replicate \eqn{r}.
#'
#'   **Step 8.** Write calibrated weights back and append history entry.
#'
#'   **Calibration method and algorithm:**
#'   When `method = "rake"`, `algorithm` selects between `"classic_ipf"`
#'   (iterative proportional fitting, Deming & Stephan 1940 — the algorithm
#'   used by Opsomer & Erciulescu 2022) and `"nr"` (Newton-Raphson raking,
#'   Deville, Sarndal & Sautory 1993). For `method = "linear"` or `"logit"`,
#'   `algorithm` is matched but silently ignored.
#'
#' @section Convergence:
#'   Convergence failure in any `.calibrate_opsomer_single()` or `survey::calibrate()`
#'   call raises `surveywts_error_calibration_not_converged`. A hard error
#'   in calibration raises `surveywts_error_calibration_failed`. Users may
#'   increase `control$maxit` or relax `control$epsilon`. Perturbed margins
#'   that are inconsistent with fixed margins may not converge; verify that
#'   `targets` margins are achievable given the data structure.
#'
#' @section Warnings:
#'   **Unknown control parameters.** Unrecognized keys in `control` are
#'   ignored with a warning. Check spelling before assuming a key has an
#'   effect.
#'
#'   **Replicate scheme mismatch.** When `primary_design` and
#'   `control_design` have different replicate types (e.g., bootstrap vs.
#'   jackknife), a warning is emitted. Results are still returned; the
#'   statistical validity of mixing replicate schemes is the user's
#'   responsibility.
#'
#'   **Negative calibrated weights.** When `method = "linear"` produces
#'   negative calibrated full-sample weights, those weights are clipped to
#'   `.Machine$double.eps` and a warning is emitted. Replicate weights are
#'   never clipped.
#'
#' @section Limitations:
#'   **Independence assumption.** The Opsomer & Erciulescu (2022) consistency
#'   proof assumes `primary_design` and `control_design` are independent
#'   samples from non-overlapping draws. Designs that share respondents
#'   (e.g., panel waves, subsamples of the control, or any linked-sample
#'   design) violate this assumption. The function cannot detect overlap;
#'   users are responsible for verifying the independence condition.
#'   Overlapping samples produce variance estimates that do not account for
#'   the covariance between the two surveys' totals.
#'
#'   **Nonprobability samples.** The Opsomer & Erciulescu (2022) consistency
#'   proof assumes probability samples with design-based replicate variance.
#'   When `survey_nonprob` designs are supplied, the method operates
#'   mechanically but the variance interpretation depends on how the replicate
#'   weights were constructed.
#'
#' @references
#'   Opsomer, J.D. and Erciulescu, A.L. (2022). Replication variance
#'   estimation after sample-based calibration. *Survey Methodology*,
#'   47(2), 265--277.
#'
#'   Fuller, W.A. (1998). Replication variance estimation for two-phase
#'   samples. *Statistica Sinica*, 8, 1153--1164.
#'
#' @examples
#' # calibrate ns_wave1 NPS to NPORS probability survey on age_f3 and sex ----
#' ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#' primary <- create_bootstrap_weights(ns_svy, replicates = 50L)
#' npors_design <- surveycore::as_survey(
#'   npors_2025_clean, weights = weight, strata = stratum
#' )
#' control <- create_bootstrap_weights(npors_design, replicates = 50L)
#' result <- calibrate_to_survey(primary, control, variables = c(age_f3, sex))
#'
#' @seealso [calibrate_to_estimate()]
#' @family sample-calibration
#' @export
calibrate_to_survey <- function(
  primary_design,
  control_design,
  variables,
  targets = NULL,
  type = c("prop", "count"),
  method = c("rake", "linear", "logit"),
  algorithm = c("classic_ipf", "nr"),
  bounds = c(-Inf, Inf),
  unit_scale = NULL,
  reference_design = NULL,
  control = list()
) {
  call_str <- paste0(deparse(match.call()), collapse = " ")
  type <- rlang::arg_match(type)
  method <- rlang::arg_match(method)
  algorithm <- rlang::arg_match(algorithm)

  # ---- 1. primary_design class check ----------------------------------------
  is_nonprob_primary <- S7::S7_inherits(
    primary_design,
    surveycore::survey_nonprob
  )
  if (
    !S7::S7_inherits(primary_design, surveycore::survey_replicate) &&
      !is_nonprob_primary
  ) {
    cls <- class(primary_design)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg primary_design} must be a {.cls survey_replicate} or a ",
          "{.cls survey_nonprob} with replicate weights, got {.cls {cls}}."
        ),
        "i" = paste0(
          "Replicate weights are required to propagate control-survey ",
          "uncertainty."
        ),
        "v" = paste0(
          "Use {.fn create_bootstrap_weights} or another ",
          "{.fn create_*_weights} function to add replicate weights ",
          "before calibrating."
        )
      ),
      class = "surveywts_error_primary_not_replicate"
    )
  }
  if (is_nonprob_primary) {
    rw <- primary_design@variables$repweights
    if (is.null(rw) || length(rw) == 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg primary_design} is a {.cls survey_nonprob} but has ",
            "no replicate weights."
          ),
          "i" = paste0(
            "Replicate weights are required to propagate control-survey ",
            "uncertainty."
          ),
          "v" = paste0(
            "Use {.fn create_bootstrap_weights} or another ",
            "{.fn create_*_weights} function to add replicate weights ",
            "before calibrating."
          )
        ),
        class = "surveywts_error_primary_no_repweights"
      )
    }
  }

  # ---- 2. control_design class check ----------------------------------------
  is_nonprob_control <- S7::S7_inherits(
    control_design,
    surveycore::survey_nonprob
  )
  if (
    !S7::S7_inherits(control_design, surveycore::survey_replicate) &&
      !is_nonprob_control
  ) {
    cls <- class(control_design)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg control_design} must be a {.cls survey_replicate} or a ",
          "{.cls survey_nonprob} with replicate weights, got {.cls {cls}}."
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
  if (is_nonprob_control) {
    rw <- control_design@variables$repweights
    if (is.null(rw) || length(rw) == 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg control_design} is a {.cls survey_nonprob} but has ",
            "no replicate weights."
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
        class = "surveywts_error_control_no_repweights"
      )
    }
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
  unknown <- setdiff(names(control), known_keys)
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

  # Extract control_col_matches (not stored in history). Internal key for
  # deterministic replicate mapping in tests; deliberately absent from the
  # user-facing @param control docs.
  control_col_matches <- control[["control_col_matches"]]

  # Build effective control (without control_col_matches)
  ctrl_defaults <- list(maxit = 50L, epsilon = 1e-10)
  ctrl_clean <- control[intersect(names(control), c("maxit", "epsilon"))]
  ctrl <- utils::modifyList(ctrl_defaults, ctrl_clean)

  # ---- 6. variables tidy-select resolution -----------------------------------
  vars_quo <- rlang::enquo(variables)
  var_pos <- tryCatch(
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
  if (
    !is.null(primary_type) &&
      !is.null(control_type) &&
      primary_type != control_type
  ) {
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

  # ---- 8. Scale constant check ----------------------------------------------
  A <- primary_design@variables$scale
  A_C <- control_design@variables$scale
  if (is.null(A) || is.null(A_C)) {
    which_missing <- character(0)
    if (is.null(A)) {
      which_missing <- c(which_missing, "primary_design")
    }
    if (is.null(A_C)) {
      which_missing <- c(which_missing, "control_design")
    }
    cli::cli_abort(
      c(
        "x" = paste0(
          "Replication scale constant not found in ",
          "{.and {.arg {which_missing}}}."
        ),
        "i" = paste0(
          "`@variables$scale` must be non-NULL to compute ",
          "Opsomer `a_r` adjustment constants."
        ),
        "v" = paste0(
          "Use {.fn create_bootstrap_weights} to create designs ",
          "with `@variables$scale` populated."
        )
      ),
      class = "surveywts_error_scale_not_found"
    )
  }

  # ---- 9. Control level check -----------------------------------------------
  .check_control_levels(primary_design, control_design, var_names)

  # ---- 10. Targets validation (only when targets non-NULL) ------------------
  if (!is.null(targets)) {
    .validate_targets_for_opsomer(targets, type, primary_design)
  }

  # ---- 11. Opsomer algorithm ------------------------------------------------

  # Extract key dimensions
  wt_col_name <- primary_design@variables$weights
  rep_col_names <- primary_design@variables$repweights
  R <- length(rep_col_names)
  R_C <- length(control_design@variables$repweights)

  # Step 2: compute expansion factor K and effective parameters
  if (R_C > R) {
    K <- as.integer(ceiling(R_C / R))
    R_eff <- K * R
    A_eff <- A / K
  } else {
    K <- 1L
    R_eff <- R
    A_eff <- A
  }

  # Step 3: compute a_r constants (length R_eff)
  a_r <- numeric(R_eff)
  n_active <- min(R_eff, R_C)
  if (n_active > 0L) {
    a_r[seq_len(n_active)] <- sqrt(A_C / A_eff)
  }
  # positions n_active+1 .. R_eff stay 0 (already initialised to 0)

  # Step 4: compute control totals (full-sample and per-replicate)
  ctrl_totals <- .compute_control_totals(
    control_design,
    var_names,
    primary_design
  )

  # Step 4b: if type="prop" and targets non-NULL, convert proportions to counts
  # Store original targets for history; work with counts internally
  targets_orig <- targets
  targets_counts <- NULL
  if (!is.null(targets)) {
    # Normalize targets to named numeric vectors
    targets_norm <- .normalize_targets(targets)

    if (type == "prop") {
      N <- sum(primary_design@data[[wt_col_name]])
      targets_counts <- lapply(targets_norm, function(props) props * N)
    } else {
      targets_counts <- targets_norm
    }
  }

  # Step 5: draw (or use supplied) control column mapping.
  # ccm[s] = index of the control replicate that maps to virtual primary
  # replicate s (1-based, length min(R_eff, R_C)).  Virtual primary replicates
  # beyond min(R_eff, R_C) have a_r = 0 and do not use a control replicate.
  #
  # To match svrep::calibrate_to_sample() numerically (same seed), we use
  # svrep's sampling direction: sample R_eff primary-replicate indices of size
  # R_C without replacement, then invert.  When R_eff == R_C this reduces to
  # drawing the same permutation and inverting it.
  if (!is.null(control_col_matches)) {
    # User-supplied: interpret as "control replicate c maps to primary replicate r"
    # (svrep's matched_primary_cols convention).
    mpc <- as.integer(control_col_matches)
    # Build ccm as the inverse: ccm[s] = which control replicate maps to s
    ccm <- integer(R_eff)
    for (ci in seq_along(mpc)) {
      if (!is.na(mpc[ci]) && mpc[ci] >= 1L && mpc[ci] <= R_eff) {
        ccm[mpc[ci]] <- ci
      }
    }
  } else {
    # Random draw in svrep's direction: for each control replicate i,
    # which primary (virtual) replicate does it map to?
    n_match <- min(R_eff, R_C)
    mpc <- sample(seq_len(R_eff), size = n_match, replace = FALSE)
    # Invert to get ccm: ccm[primary_r] = control_i
    ccm <- integer(R_eff)
    for (ci in seq_len(n_match)) {
      ccm[mpc[ci]] <- ci
    }
  }

  # Step 6: calibrate full-sample weights to combined target set
  # Build combined targets: random-margin totals from control + fixed totals
  # When a variable appears in both var_names and targets, fixed takes priority
  fixed_var_names <- if (!is.null(targets_counts)) {
    names(targets_counts)
  } else {
    character(0)
  }
  random_var_names <- setdiff(var_names, fixed_var_names)

  # Combined targets for full-sample calibration (Format A named list)
  fs_combined_targets <- list()
  for (v in random_var_names) {
    fs_combined_targets[[v]] <- ctrl_totals[[v]]$full
  }
  if (!is.null(targets_counts)) {
    for (v in names(targets_counts)) {
      fs_combined_targets[[v]] <- targets_counts[[v]]
    }
  }

  all_cal_vars <- names(fs_combined_targets)
  primary_data <- primary_design@data
  before_weights <- primary_data[[wt_col_name]]
  before_stats <- .compute_weight_stats(before_weights)

  # When fixed margins (targets_counts) are present, force (Intercept) to the
  # sum of the fixed margin totals.  This ensures that treatment-contrast coding
  # exactly recovers each fixed-margin cell total rather than being offset by
  # the difference between the control and primary grand totals.
  # When no fixed margins exist, pass NULL so .calibrate_opsomer_single() falls
  # back to the first control variable's grand total (always consistent).
  fs_intercept_n <- if (!is.null(targets_counts)) {
    sum(targets_counts[[1L]])
  } else {
    NULL
  }

  new_full_weights <- .calibrate_opsomer_single(
    data_df = as.data.frame(primary_data),
    weights_vec = before_weights,
    combined_tgts = fs_combined_targets,
    method = method,
    algorithm = algorithm,
    ctrl = ctrl,
    bounds = bounds,
    unit_scale = unit_scale,
    intercept_n = fs_intercept_n
  )

  # Clip negative full-sample weights for linear method
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

  # Step 7: per-replicate calibration
  # Output will have R replicate columns (same as input)
  out_rep_mat <- matrix(NA_real_, nrow = nrow(primary_data), ncol = R)

  for (r_idx in seq_len(R)) {
    # Original primary replicate-r weights (from INPUT, not calibrated)
    orig_rep_wt <- primary_data[[rep_col_names[[r_idx]]]]

    # Accumulate K calibrated weight vectors for averaging
    k_cal_weights <- vector("list", K)

    for (k_idx in seq_len(K)) {
      s_idx <- (r_idx - 1L) * K + k_idx # virtual replicate index (1-based)

      # Build perturbed totals for random-margin variables
      rep_combined_tgts <- list()

      for (v in random_var_names) {
        full_tot <- ctrl_totals[[v]]$full
        c_s <- if (s_idx <= length(ccm)) ccm[s_idx] else 0L
        if (a_r[s_idx] != 0 && c_s > 0L) {
          rep_tot <- ctrl_totals[[v]]$replicates[, c_s]
          names(rep_tot) <- rownames(ctrl_totals[[v]]$replicates)
          perturbed <- full_tot + a_r[s_idx] * (rep_tot - full_tot)
        } else {
          # a_r = 0 or unmatched virtual replicate: use full-sample total
          perturbed <- full_tot
        }
        rep_combined_tgts[[v]] <- perturbed
      }

      # Add fixed-margin targets (unchanged across all replicates)
      if (!is.null(targets_counts)) {
        for (v in names(targets_counts)) {
          rep_combined_tgts[[v]] <- targets_counts[[v]]
        }
      }

      # Calibrate starting from original (pre-calibration) replicate weights
      k_cal_weights[[k_idx]] <- .calibrate_opsomer_single(
        data_df = as.data.frame(primary_data),
        weights_vec = orig_rep_wt,
        combined_tgts = rep_combined_tgts,
        method = method,
        algorithm = algorithm,
        ctrl = ctrl,
        bounds = bounds,
        unit_scale = unit_scale,
        intercept_n = fs_intercept_n
      )
    }

    # Average K calibrated weight vectors (when K=1 this is just the one vector)
    out_rep_mat[, r_idx] <- Reduce("+", k_cal_weights) / K
  }

  # Step 8: build new data and output object
  after_stats <- .compute_weight_stats(new_full_weights)

  # History parameters
  history_params <- list(
    variables = var_names,
    method = method,
    bounds = bounds,
    unit_scale = unit_scale,
    n_replicates = R,
    control_design_class = class(control_design)[[1L]],
    n_replicates_control = R_C,
    K = K,
    a_constants = a_r,
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
  if (!is.null(targets)) {
    history_params$targets <- targets_orig
    history_params$type <- type
    history_params$fixed_variables <- fixed_var_names
  } else {
    history_params$targets <- NULL
    history_params$type <- NULL
    history_params$fixed_variables <- NULL
  }

  current_history <- primary_design@metadata@weighting_history
  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "calibrate_to_survey",
    weight_col = wt_col_name,
    call_str = call_str,
    parameters = history_params,
    before_stats = before_stats,
    after_stats = after_stats,
    convergence = NULL
  )
  # Promote K and a_constants to top-level fields for direct access.
  # These are the primary outputs of the Opsomer algorithm and are
  # checked by tests and documented in @returns as first-class entry fields.
  history_entry$K <- K
  history_entry$a_constants <- a_r
  if (!is.null(targets)) {
    history_entry$targets <- targets_orig
    history_entry$type <- type
    history_entry$fixed_variables <- fixed_var_names
  }

  # Build updated data frame
  new_data <- primary_data
  new_data[[wt_col_name]] <- new_full_weights
  for (r_idx in seq_len(R)) {
    new_data[[rep_col_names[[r_idx]]]] <- out_rep_mat[, r_idx]
  }

  # Dispatch on primary_design class for output constructor
  if (S7::S7_inherits(primary_design, surveycore::survey_nonprob)) {
    result <- surveycore::survey_nonprob(
      data = new_data,
      variables = primary_design@variables,
      metadata = primary_design@metadata
    )
  } else {
    result <- surveycore::survey_replicate(
      data = new_data,
      variables = primary_design@variables,
      metadata = primary_design@metadata
    )
  }
  meta <- result@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  result@metadata <- meta

  result
}

# ---------------------------------------------------------------------------
# Internal helpers for calibrate_to_survey()
# ---------------------------------------------------------------------------

# Compute full-sample and per-replicate control totals for each variable
# in var_names. Also checks for level mismatches (control level check).
#
# Returns a named list: one entry per variable.
# Each entry has:
#   $full:       named numeric vector (total per level, from control
#                full-sample weights)
#   $replicates: matrix (n_levels x R_C) of per-replicate totals;
#                rownames are levels
#
# Errors with surveywts_error_control_level_missing if any level in the
# primary is absent from the control.
#
# @keywords internal
# @noRd
.compute_control_totals <- function(control_design, var_names, primary_design) {
  R_C <- length(control_design@variables$repweights)
  wt_col <- control_design@variables$weights
  ctrl_data <- control_design@data
  ctrl_full_wt <- ctrl_data[[wt_col]]

  result <- list()
  for (v in var_names) {
    p_levels <- unique(as.character(primary_design@data[[v]]))
    c_levels <- unique(as.character(ctrl_data[[v]]))

    missing <- setdiff(p_levels, c_levels)
    if (length(missing) > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Control survey is missing level(s) of variable {.field {v}}: ",
            "{.and {.val {missing}}}."
          ),
          "i" = paste0(
            "All levels in {.arg primary_design} must also appear in ",
            "{.arg control_design} to estimate control-survey totals."
          ),
          "v" = paste0(
            "Verify that {.arg control_design} covers the same population ",
            "as {.arg primary_design}."
          )
        ),
        class = "surveywts_error_control_level_missing"
      )
    }

    lvls <- p_levels
    c_char <- as.character(ctrl_data[[v]])

    # Full-sample totals
    full_totals <- vapply(
      lvls,
      function(lv) {
        sum(ctrl_full_wt[c_char == lv])
      },
      numeric(1L)
    )
    names(full_totals) <- lvls

    # Per-replicate totals (matrix: n_levels x R_C)
    rep_matrix <- matrix(0, nrow = length(lvls), ncol = R_C)
    rownames(rep_matrix) <- lvls
    rep_col_names <- control_design@variables$repweights
    for (r in seq_len(R_C)) {
      rep_wt_r <- ctrl_data[[rep_col_names[[r]]]]
      for (i_lv in seq_along(lvls)) {
        lv <- lvls[i_lv]
        rep_matrix[i_lv, r] <- sum(rep_wt_r[c_char == lv])
      }
    }

    result[[v]] <- list(full = full_totals, replicates = rep_matrix)
  }
  result
}

# PR 1 validation helper (kept for backward-compat; now also done in
# .compute_control_totals for the Opsomer path)
.check_control_levels <- function(primary, control, var_names) {
  for (v in var_names) {
    p_levels <- unique(as.character(primary@data[[v]]))
    c_levels <- unique(as.character(control@data[[v]]))
    missing <- setdiff(p_levels, c_levels)
    if (length(missing) > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Control survey is missing level(s) of variable {.field {v}}: ",
            "{.and {.val {missing}}}."
          ),
          "i" = paste0(
            "All levels in {.arg primary_design} must also appear in ",
            "{.arg control_design} to estimate control-survey totals."
          ),
          "v" = paste0(
            "Verify that {.arg control_design} covers the same population ",
            "as {.arg primary_design}."
          )
        ),
        class = "surveywts_error_control_level_missing"
      )
    }
  }
  invisible(TRUE)
}

# Validate the targets argument for the Opsomer path.
# Steps 12a-12d from the spec validation order.
.validate_targets_for_opsomer <- function(targets, type, primary_design) {
  # Step 12a: named non-empty list check
  if (!is.list(targets)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg targets} must be a named list, got ",
          "{.cls {class(targets)[[1L]]}}."
        ),
        "i" = "Each element name is a variable in {.arg primary_design}.",
        "v" = paste0(
          "Pass a named list, e.g. ",
          "{.code list(age_group = c('18-34' = 0.30, ...))}."
        )
      ),
      class = "surveywts_error_targets_not_named_list"
    )
  }
  if (length(targets) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg targets} is an empty list.",
        "i" = "Every element of {.arg targets} must be named with a variable name.",
        "v" = paste0(
          "Pass a named list, e.g. ",
          "{.code list(age_group = c('18-34' = 0.30, ...))}."
        )
      ),
      class = "surveywts_error_targets_not_named_list"
    )
  }
  tgt_names_raw <- names(targets)
  if (is.null(tgt_names_raw) || !all(nzchar(tgt_names_raw))) {
    cli::cli_abort(
      c(
        "x" = "{.arg targets} has unnamed element(s).",
        "i" = "Every element of {.arg targets} must be named with a variable name.",
        "v" = paste0(
          "Pass a named list, e.g. ",
          "{.code list(age_group = c('18-34' = 0.30, ...))}."
        )
      ),
      class = "surveywts_error_targets_not_named_list"
    )
  }

  target_names <- names(targets)

  # Step 12b: variable names exist in primary_design@data
  for (nm in target_names) {
    if (!nm %in% names(primary_design@data)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg targets} element {.val {nm}} is not a column in ",
            "{.arg primary_design}."
          ),
          "i" = paste0(
            "Available columns: ",
            "{.and {.field {names(primary_design@data)}}}."
          )
        ),
        class = "surveywts_error_targets_variable_not_found"
      )
    }
  }

  # Step 12c: element format check
  for (nm in target_names) {
    elem <- targets[[nm]]
    valid_vector <- is.numeric(elem) &&
      !is.null(names(elem)) &&
      all(nzchar(names(elem)))
    valid_tibble <- is.data.frame(elem) &&
      nm %in% names(elem) &&
      any(c("n", "prop") %in% names(elem))
    if (!valid_vector && !valid_tibble) {
      cli::cli_abort(
        c(
          "x" = "{.arg targets} element {.val {nm}} is not a valid format.",
          "i" = paste0(
            "Expected a named numeric vector or a tibble with a ",
            "{.field {nm}} column plus {.field n} or {.field prop}."
          ),
          "v" = paste0(
            "E.g. {.code c('18-34' = 0.30, '35-54' = 0.40)} ",
            "or {.code tibble({nm} = ..., prop = ...)}."
          )
        ),
        class = "surveywts_error_targets_element_invalid"
      )
    }
  }

  # Step 12d: totals valid
  for (nm in target_names) {
    elem <- targets[[nm]]
    # Normalize to named numeric vector for validation
    if (is.data.frame(elem)) {
      val_col <- if ("n" %in% names(elem)) "n" else "prop"
      vals <- stats::setNames(elem[[val_col]], as.character(elem[[nm]]))
    } else {
      vals <- elem
    }
    if (type == "count") {
      if (any(is.na(vals)) || any(vals <= 0)) {
        cli::cli_abort(
          c(
            "x" = "{.arg targets} element {.val {nm}} has invalid count(s).",
            "i" = paste0(
              "With {.code type = \"count\"}, all values must be ",
              "positive and non-NA."
            ),
            "v" = "Fix the value(s) in {.code targets[[{.val {nm}}]]}."
          ),
          class = "surveywts_error_targets_totals_invalid"
        )
      }
    } else {
      # type == "prop"
      s <- sum(vals, na.rm = FALSE)
      if (is.na(s) || abs(s - 1.0) > 1e-6) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "{.arg targets} element {.val {nm}} proportions sum to ",
              "{round(s, 8)}, not 1."
            ),
            "i" = paste0(
              "With {.code type = \"prop\"}, values must sum to ",
              "exactly 1 (within 1e-6)."
            ),
            "v" = paste0(
              "Rescale or correct the values in ",
              "{.code targets[[{.val {nm}}]]}."
            )
          ),
          class = "surveywts_error_targets_totals_invalid"
        )
      }
    }
  }

  invisible(TRUE)
}

# Normalize targets to a named list of named numeric vectors.
# Handles both Format A (named numeric vector) and Format B (tibble with
# variable column + "n" or "prop" column).
#
# @keywords internal
# @noRd
.normalize_targets <- function(targets) {
  lapply(seq_along(targets), function(i) {
    nm <- names(targets)[[i]]
    elem <- targets[[i]]
    if (is.data.frame(elem)) {
      val_col <- if ("n" %in% names(elem)) "n" else "prop"
      stats::setNames(as.double(elem[[val_col]]), as.character(elem[[nm]]))
    } else {
      stats::setNames(as.double(unname(elem)), names(elem))
    }
  }) |>
    stats::setNames(names(targets))
}

# Calibrate a single set of weights to combined targets using the
# appropriate method (rake/linear/logit via survey::calibrate()).
#
# Arguments:
#   data_df       : data.frame with calibration variable columns
#   weights_vec   : numeric vector of starting weights
#   combined_tgts : named list of named numeric vectors (count-scale totals)
#   method        : "rake", "linear", or "logit"
#   algorithm     : "classic_ipf" or "nr" (only used when method = "rake")
#   ctrl          : list with maxit and epsilon
#   bounds        : numeric length-2 c(lower, upper)
#   unit_scale    : NULL or numeric vector length nrow(data_df)
#
# Returns: numeric vector of calibrated weights
#
# Errors:
#   surveywts_error_calibration_not_converged — convergence failure
#   surveywts_error_calibration_failed        — hard error
#
# @keywords internal
# @noRd
.calibrate_opsomer_single <- function(
  data_df,
  weights_vec,
  combined_tgts,
  method,
  algorithm,
  ctrl,
  bounds,
  unit_scale,
  intercept_n = NULL
) {
  cal_vars <- names(combined_tgts)
  if (length(cal_vars) == 0L) {
    # No calibration variables: return weights unchanged
    return(weights_vec)
  }

  # All methods (rake, linear, logit) use survey::calibrate() via a temporary
  # svydesign object.  The Opsomer algorithm requires calibration to absolute
  # count-scale totals; anesrake normalises to proportions and is therefore
  # not used here.  When method = "rake", survey::cal.raking (Newton–Raphson
  # raking) is used — this is the GREG formulation used by svrep internally
  # and is numerically equivalent for balanced marginal calibration.
  # The `algorithm` argument is matched but silently ignored in this path.
  data_df$.opsomer_wt_tmp <- weights_vec

  # Convert calibration variables to factors for model.matrix
  for (v in cal_vars) {
    lvls <- names(combined_tgts[[v]])
    data_df[[v]] <- factor(as.character(data_df[[v]]), levels = lvls)
  }

  # Build formula and population totals vector (treatment contrasts)
  multi_level_vars <- cal_vars[vapply(
    combined_tgts,
    function(tgt) {
      length(tgt) >= 2L
    },
    logical(1L)
  )]

  if (length(multi_level_vars) == 0L) {
    # All single-level: trivially calibrated — return weights unchanged
    return(weights_vec)
  }

  fml <- stats::as.formula(
    paste("~", paste(multi_level_vars, collapse = " + "))
  )
  mm <- stats::model.matrix(fml, data = data_df)
  n_cols <- ncol(mm)

  # Population totals in treatment-contrast parameterization.
  # Intercept = the common grand total for all calibration constraints.
  # When intercept_n is supplied (e.g., from the fixed-margin caller, using the
  # primary's weight sum N), use it directly.  Otherwise default to the sum of
  # the first variable's marginal totals (all control-only cases are consistent).
  if (is.null(intercept_n)) {
    intercept_n <- sum(combined_tgts[[cal_vars[[1L]]]])
  }
  pop_totals <- stats::setNames(numeric(n_cols), colnames(mm))
  pop_totals["(Intercept)"] <- intercept_n

  for (v in cal_vars) {
    if (length(combined_tgts[[v]]) < 2L) {
      next
    }
    lvls <- names(combined_tgts[[v]])
    for (lev in lvls[-1L]) {
      col_nm <- paste0(v, lev)
      if (col_nm %in% names(pop_totals)) {
        pop_totals[col_nm] <- combined_tgts[[v]][[lev]]
      }
    }
  }

  svy_tmp <- survey::svydesign(
    ids = ~1,
    weights = ~.opsomer_wt_tmp,
    data = data_df
  )

  calfun <- .method_to_calfun(method)

  cal_args <- list(
    design = svy_tmp,
    formula = fml,
    population = pop_totals,
    calfun = calfun,
    maxit = as.integer(ctrl$maxit),
    epsilon = ctrl$epsilon
  )
  if (!is.null(unit_scale)) {
    cal_args$variance <- unit_scale
  }
  # For logit: bounds must be finite; use wide defaults if not specified
  if (method == "logit") {
    lower <- if (is.finite(bounds[[1L]])) bounds[[1L]] else 1e-6
    upper <- if (is.finite(bounds[[2L]])) bounds[[2L]] else 1e6
    cal_args$bounds <- c(lower, upper)
  } else if (
    method == "linear" &&
      (is.finite(bounds[[1L]]) || is.finite(bounds[[2L]]))
  ) {
    cal_args$bounds <- bounds
  }

  # Use an explicit environment to capture any convergence warning message
  # from inside the withCallingHandlers() closure without <<-.
  conv_env <- new.env(parent = emptyenv())
  conv_env$msg <- NULL

  cal_result <- tryCatch(
    withCallingHandlers(
      do.call(survey::calibrate, cal_args),
      warning = function(w) {
        msg <- conditionMessage(w)
        if (grepl("converge", msg, ignore.case = TRUE)) {
          # Record the convergence message; re-signal as calibration_not_converged
          # inside the error handler if survey::calibrate() subsequently errors.
          conv_env$msg <- msg
          invokeRestart("muffleWarning")
        } else {
          tryInvokeRestart("muffleWarning")
        }
      }
    ),
    error = function(e) {
      # If we already saw a convergence warning, this error is a downstream
      # consequence — surface it as not_converged, not calibration_failed.
      if (!is.null(conv_env$msg)) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "Calibration did not converge after {ctrl$maxit} iterations."
            ),
            "i" = "survey::calibrate() reported: {conv_env$msg}",
            "v" = paste0(
              "Increase {.code control$maxit}, relax ",
              "{.code control$epsilon}, or verify margin totals."
            )
          ),
          class = "surveywts_error_calibration_not_converged"
        )
      }
      cli::cli_abort(
        c(
          "x" = "Calibration failed during Opsomer step.",
          "i" = "survey::calibrate() reported: {conditionMessage(e)}"
        ),
        class = "surveywts_error_calibration_failed"
      )
    }
  )

  # Re-signal convergence failure when survey::calibrate() returned normally
  # despite not fully converging (some calfun implementations only warn).
  if (!is.null(conv_env$msg)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Calibration did not converge after {ctrl$maxit} iterations."
        ),
        "i" = "survey::calibrate() reported: {conv_env$msg}",
        "v" = paste0(
          "Increase {.code control$maxit}, relax ",
          "{.code control$epsilon}, or verify margin totals."
        )
      ),
      class = "surveywts_error_calibration_not_converged"
    )
  }

  as.numeric(stats::weights(cal_result))
}

# Test hook — mockable binding so tests can assert this function is NOT called.
# Not called in production code; retained as a named symbol for test mocking only.
# nocov start
.svrep_calibrate_to_sample <- function(...) svrep::calibrate_to_sample(...)
# nocov end
