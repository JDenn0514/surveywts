# R/create_jackknife_weights.R
#
# create_jackknife_weights() — unified jackknife replicate weights for
# probability and non-probability samples.

# ============================================================================
# create_jackknife_weights()
# ============================================================================

#' Construct jackknife replicate weights
#'
#' Generates jackknife replicate weights for probability samples via the
#' `survey` or `svrep` package, and for non-probability samples via the
#' delete-a-group jackknife (DAGJK) engine. The `type` argument selects the
#' jackknife variant; `survey_nonprob` inputs are restricted to
#' `type = "grouped"`.
#'
#' @param data A `survey_taylor` or `survey_nonprob`. `survey_nonprob` is only
#'   valid with `type = "grouped"`. `data.frame` and `survey_replicate`
#'   inputs all error.
#' @param replicates `integer(1)` or `NULL`. Number of random deletion groups
#'   for `type = "grouped"`. Required when `type = "grouped"` for both
#'   `survey_taylor` and `survey_nonprob` inputs; errors if `NULL`. Silently
#'   ignored for `type = "jkn"` and `type = "jk1"` (those types are
#'   deterministic). For `survey_nonprob` (DAGJK path), must be a whole number
#'   (value >= 2); whole-number doubles (e.g., `50.0`) are coerced to integer. Must
#'   not exceed the combined NPS + reference row count. Documentation advises
#'   `G >= 50` as a practical starting point for CV(SE) <= 10% (Valliant,
#'   Dever & Kreuter 2018 Table 15.2). No default is provided by design —
#'   callers must always supply a value when `type = "grouped"`.
#' @param ... Must be empty. Forces all remaining arguments to be named.
#' @param type `character(1)`. `"jkn"` (the default): stratified delete-one
#'   jackknife, one replicate per PSU across all strata. `"jk1"`: unstratified
#'   delete-one jackknife ignoring stratification — will generally overestimate
#'   variance on multi-stratum designs. `"grouped"`: random-group jackknife
#'   for probability samples (via `svrep`) or DAGJK for non-probability samples.
#'   `"jkn"` and `"jk1"` are valid only for `survey_taylor`.
#' @param mse `logical(1)`, default `TRUE`. Centers each replicate deviation on
#'   the full-sample estimate (`mse = TRUE`, Wolter 2007 v_4 form; conservative)
#'   or on the within-stratum mean of replicate estimates (`mse = FALSE`, v_1
#'   form). For `type = "grouped"` with `survey_nonprob` (DAGJK), `mse = TRUE`
#'   is hardcoded — see the **Algorithm** section. Supplying `mse = FALSE` on
#'   that path emits a warning and is overridden.
#' @param var_strat `character(1)` or `NULL`. Variance stratification variable;
#'   passed to `svrep::as_random_group_jackknife_design()` for `type = "grouped"`
#'   with `survey_taylor`. Silently ignored for `"jkn"` and `"jk1"`. Emits a
#'   warning and is ignored for `survey_nonprob` (DAGJK does not support svrep
#'   variance stratification).
#' @param var_strat_frac `numeric(1)` or `NULL`. Variance stratification
#'   fraction for `svrep`. Same applicability and ignored-path behavior as
#'   `var_strat`.
#' @param sort_var `character(1)` or `NULL`. Sort variable for systematic group
#'   assignment in `svrep`. Same applicability and ignored-path behavior as
#'   `var_strat`. Not applicable to DAGJK because DAGJK uses its own
#'   `sample()` engine across the combined NPS + reference dataset.
#' @param adj_method `character(1)`. `"variance-stratum-psus"` (the default,
#'   matching the svrep default) or `"variance-units"`. Passed to
#'   `svrep::as_random_group_jackknife_design()` for `type = "grouped"` with
#'   `survey_taylor`. Silently ignored for `"jkn"` and `"jk1"`. Emits a warning
#'   when non-default and `data` is `survey_nonprob`.
#' @param scale_method `character(1)`. `"variance-stratum-psus"` (the default)
#'   or `"variance-units"`. Same applicability and ignored-path behavior as
#'   `adj_method`.
#' @param reference_sample `survey_taylor` or `NULL`. Reference probability
#'   sample for the DAGJK path (`type = "grouped"` with `survey_nonprob`).
#'   When non-`NULL`, overrides any reference design stored in the `ipw()`
#'   history entry. When non-`NULL` and not a `survey_taylor`, errors with
#'   `surveywts_error_reference_sample_class`. Silently ignored when `type` is
#'   `"jkn"`, `"jk1"`, or `"grouped"` with `survey_taylor` (documented as
#'   DAGJK-only; no runtime warning emitted on non-DAGJK paths).
#' @param seed `integer(1)` or `NULL`. RNG seed for reproducible random group
#'   assignment. For `type = "grouped"` with `survey_taylor`, passed to
#'   `.convert_and_call()` which calls `withr::local_seed()`. For DAGJK,
#'   `set.seed(seed)` is called once before group assignment; the global RNG
#'   state is not restored. Silently ignored for `"jkn"` and `"jk1"`
#'   (deterministic).
#'
#' @returns
#' **`type = "jkn"`, `type = "jk1"`, or `type = "grouped"` with
#' `survey_taylor`:** A `survey_replicate` with replicate weight columns in
#' `@data` named `rep_1`, `rep_2`, ..., `rep_R`; `@variables$repweights`
#' populated; `@variables$type` set to `"JKn"`, `"JK1"`, or `"random-group"`
#' respectively; `@variables$scale`, `@variables$rscales`, and
#' `@variables$mse` populated from the backend. A new entry with
#' `operation = "replicate_creation"` and `method = "jackknife"` is appended
#' to the weighting history.
#'
#' **`type = "grouped"` with `survey_nonprob`:** A `survey_nonprob` with
#' `G_success` replicate weight columns named `repwt_1` through
#' `repwt_{G_success}`; `@variables$type` set to `"group-jackknife"`;
#' `@variables$scale` set to `(G_success - 1) / G_success`;
#' `@variables$rscales` set to `rep(1, G_success)`; `@variables$mse` set to
#' `TRUE`. A new entry with `operation = "jackknife_weights"` is appended to
#' the weighting history.
#'
#' @section Algorithm:
#'
#' **JKn (stratified delete-one jackknife)**
#'
#' Drops PSU `i` from stratum `h` in turn. Retained units in stratum `h` are
#' scaled by `n_h / (n_h - 1)`; units in other strata are unchanged:
#'
#' \deqn{
#'   w_{k(hi)} = \begin{cases}
#'     0 & \text{if unit } k \text{ is in PSU } i \text{ of stratum } h \\
#'     \dfrac{n_h}{n_h - 1}\, w_k & \text{if unit } k \text{ is in stratum } h,\; k \neq i \\
#'     w_k & \text{if unit } k \text{ is not in stratum } h
#'   \end{cases}
#' }
#'
#' The `mse = TRUE` variance estimator (Wolter 2007 eq. 4.6.4a):
#'
#' \deqn{
#'   v_J(\hat{\theta}) = \sum_{h=1}^{H} \frac{n_h - 1}{n_h}
#'     \sum_{i=1}^{n_h} \left( \hat{\theta}_{(hi)} - \hat{\theta} \right)^2
#' }
#'
#' Total replicates = \eqn{\sum_h n_h} (one per PSU across all strata).
#' Delegated to `survey::as.svrepdesign(type = "JKn", mse = mse)`.
#'
#' **JK1 (unstratified delete-one jackknife)**
#'
#' Special case of JKn treating all PSUs as a single stratum (Valliant, Dever &
#' Kreuter 2018 §15.4.1 "Special Cases"). Scale factor is `(n-1)/n`; total
#' replicates = `n`. JK1 ignores the design stratification and generally
#' overestimates variance when applied to a multi-stratum design. Delegated to
#' `survey::as.svrepdesign(type = "JK1", mse = mse)`.
#'
#' **Grouped jackknife (probability samples)**
#'
#' PSUs are randomly divided into `replicates` groups. Each replicate drops one
#' group and rescales the remaining units' weights. Scale factor =
#' `(G - 1) / G` for equal-sized groups. Delegated to
#' `svrep::as_random_group_jackknife_design()` which handles unequal groups and
#' variance stratification via `var_strat`, `var_strat_frac`, `sort_var`,
#' `adj_method`, and `scale_method`.
#'
#' **Delete-a-group jackknife for non-probability samples (DAGJK)**
#'
#' Randomly partitions the combined NPS + reference dataset into `replicates`
#' groups, then refits the full estimation pipeline (IPW and/or calibration) on
#' the leave-one-group-out subsample for each replicate. The variance estimator
#' (Kott 2001 eq. 1; Valliant 2020 eq. 3):
#'
#' \deqn{
#'   v_J(\hat{\theta}) = \frac{G - 1}{G}
#'     \sum_{g=1}^{G} \left( \hat{\theta}_{(g)} - \hat{\theta} \right)^2
#' }
#'
#' Centering is always on the full-sample estimate \eqn{\hat{\theta}} (`mse =
#' TRUE`); `mse = FALSE` is not valid for this formula.
#'
#' The standard per-stratum weight adjustment (Kott 2001 §1):
#'
#' \deqn{
#'   w_{k(g)} = \begin{cases}
#'     0 & \text{if PSU } j \text{ is in group } g \\
#'     \dfrac{n_h}{n_h - n_{hg}}\, w_k & \text{otherwise}
#'   \end{cases}
#' }
#'
#' When any NPS stratum has \eqn{n_h < G}, the extended formula (Kott 2001 §3
#' eq. 2) is applied per stratum:
#'
#' \deqn{
#'   Z = \sqrt{\frac{G}{(G-1)\, n_h\, (n_h - 1)}}
#' }
#' \deqn{
#'   w_{k(g)}^{(E)} = \begin{cases}
#'     w_k & \text{if no PSU from stratum } h \text{ is in group } g \\
#'     w_k \bigl(1 - (n_h - 1)\, Z\bigr) & \text{if PSU containing } k
#'       \text{ is in group } g \\
#'     w_k (1 + Z) & \text{if PSU is in stratum } h \text{ but not in group } g
#'   \end{cases}
#' }
#'
#' When \eqn{n_h = 2}, the deleted-PSU multiplier \eqn{1 - Z =
#' 1 - \sqrt{G/(G-1)} < 0} for all finite \eqn{G}; the resulting negative
#' replicate weights are retained and reported via a warning (see **Warnings**).
#'
#' @section Limitations:
#'
#' **Jackknife is not consistent for quantile variance.** The jackknife
#' underestimates variance for quantiles and other non-smooth statistics (Elliott
#' & Valliant 2017 §4.1; Valliant, Dever & Kreuter 2018 §15.4.1; Wolter 2007
#' §4.2.4). Use `create_bootstrap_weights()` for quantile variance.
#'
#' **No formal consistency proof for DAGJK on non-probability samples.**
#' Consistency is claimed by analogy to Krewski & Rao (1981); no proof exists
#' for the non-probability sample case (Valliant 2020 §2.4). Variance estimates
#' are asymptotically justified approximations.
#'
#' **DAGJK captures only sample-based estimation variance.** The nonsample
#' variance component (uncertainty about unobserved population units) is not
#' captured. No finite-population correction is applied.
#'
#' **DAGJK standard errors are slightly conservative for doubly-robust
#' estimators.** When the pipeline applies both IPW and downstream calibration,
#' DAGJK standard error estimates are positively biased by approximately 3-5%
#' at n = 500 (Valliant 2020 Table 8). This bias does not vanish as n grows.
#'
#' **JK1 ignores stratification.** Applying `type = "jk1"` to a multi-stratum
#' design treats all PSUs as coming from one stratum and generally overestimates
#' variance. Use `type = "jkn"` for stratified designs.
#'
#' @section Warnings:
#'
#' If existing replicate weight columns are detected on a `survey_nonprob` input
#' (DAGJK path), they are cleared and a warning is emitted before proceeding.
#'
#' If the average DAGJK group size is fewer than 5 units, a warning is emitted.
#' Very small groups cause the propensity model to fail in some replicates.
#' Reduce `replicates` or use a larger combined NPS + reference dataset.
#'
#' If one or more DAGJK replicate weight values are negative after calibration
#' (which can occur with the extended formula when \eqn{n_h = 2}, or with
#' extreme calibration targets), a warning is emitted. Variance estimates
#' using negative replicate weights should be interpreted cautiously.
#'
#' @references
#'   Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability
#'   samples. *Statistical Science* **32**(2), 249--264.
#'   \doi{10.1214/16-STS598}
#'
#'   Kott, P.S. (2001). The delete-a-group jackknife.
#'   *Journal of Official Statistics* **17**(4), 521--526.
#'
#'   Valliant, R. (2020). Comparing alternatives for estimation from
#'   nonprobability samples. *Journal of Survey Statistics and Methodology*
#'   **8**, 231--263. \doi{10.1093/jssam/smz003}
#'
#'   Valliant, R., Brick, J.M. and Dever, J.A. (2008). Weight adjustments
#'   for the grouped jackknife variance estimator.
#'   *Journal of Official Statistics* **24**(3), 469--488.
#'
#'   Valliant, R., Dever, J.A. and Kreuter, F. (2018).
#'   *Practical Tools for Designing and Weighting Survey Samples* (2nd ed.).
#'   Springer.
#'
#'   Wolter, K.M. (2007). *Introduction to Variance Estimation* (2nd ed.).
#'   Springer.
#'
#' @seealso
#'   [create_bootstrap_weights()] for bootstrap replicate weights;
#'   [create_brr_weights()] for balanced repeated replication;
#'   [create_gen_boot_weights()] for generalized bootstrap;
#'   [create_gen_rep_weights()] for generalized replication;
#'   [create_sdr_weights()] for successive difference replication;
#'   [create_replicate_weights()] for the method-dispatch wrapper;
#'   [as_taylor_design()] to recover the Taylor-linearization design from
#'   replicate-weight history.
#'
#' @examples
#' # JKn (stratified delete-one) on a probability sample --------------------
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' jkn_design <- create_jackknife_weights(gss_svy, type = "jkn")
#'
#' # Grouped jackknife on a probability sample -------------------------------
#' grouped_design <- create_jackknife_weights(
#'   gss_svy,
#'   replicates = 2L,
#'   type = "grouped",
#'   seed = 42L
#' )
#'
#' # DAGJK on a calibrated non-probability sample ----------------------------
#' targets_a <- list(
#'   sex    = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#' ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#' ns_wave1_cal <- calibrate_rake(ns_wave1_svy, targets = targets_a)
#' dagjk_design <- create_jackknife_weights(
#'   ns_wave1_cal,
#'   replicates = 50L,
#'   type = "grouped",
#'   seed = 42L
#' )
#'
#' @family replicate-weights
#' @export
create_jackknife_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c("jkn", "jk1", "grouped"),
  mse = TRUE,
  var_strat = NULL,
  var_strat_frac = NULL,
  sort_var = NULL,
  adj_method = c("variance-stratum-psus", "variance-units"),
  scale_method = c("variance-stratum-psus", "variance-units"),
  reference_sample = NULL,
  seed = NULL
) {
  # ---- Steps 1-4: validation on every path ---------------------------------

  # Step 1: dots must be empty
  rlang::check_dots_empty()

  # Step 2: reject data.frame / survey_replicate / unsupported
  .validate_replicate_input(data)

  # Step 3: resolve type
  type <- rlang::arg_match(type)

  # Also resolve adj_method / scale_method (needed for step 13 comparison)
  adj_method   <- rlang::arg_match(adj_method)
  scale_method <- rlang::arg_match(scale_method)

  # Step 4: survey_nonprob + jkn/jk1 is not supported
  if (S7::S7_inherits(data, surveycore::survey_nonprob) &&
        type %in% c("jkn", "jk1")) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.cls survey_nonprob} input is not supported with ",
          "{.code type = \"{type}\"}."
        ),
        "i" = paste0(
          "Only {.code type = \"grouped\"} is supported for non-probability ",
          "designs."
        ),
        "v" = paste0(
          "Use {.code type = \"grouped\"} with {.arg replicates}, or convert ",
          "to {.cls survey_taylor}."
        )
      ),
      class = "surveywts_error_jackknife_type_nonprob_only"
    )
  }

  # ---- Pre-dispatch: grouped + replicates = NULL check (both input classes) -

  if (type == "grouped" && is.null(replicates)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg replicates} is required when {.code type = \"grouped\"}."
        ),
        "v" = "Supply an integer, e.g. {.code replicates = 50L}."
      ),
      class = "surveywts_error_jackknife_replicates_required"
    )
  }

  # ---- JKn / JK1 dispatch --------------------------------------------------

  if (type %in% c("jkn", "jk1")) {
    jk_type <- if (type == "jkn") "JKn" else "JK1"
    return(.convert_and_call(
      data       = data,
      backend_fn = function(d) survey::as.svrepdesign(d, type = jk_type, mse = mse),
      method     = "jackknife",
      params     = list(type = type, mse = mse),
      seed       = NULL
    ))
  }

  # ---- Grouped + survey_taylor dispatch ------------------------------------

  if (!S7::S7_inherits(data, surveycore::survey_nonprob)) {
    replicates <- .validate_replicates_arg(replicates)
    return(.convert_and_call(
      data       = data,
      backend_fn = function(d)
        svrep::as_random_group_jackknife_design(
          d,
          replicates     = replicates,
          mse            = mse,
          var_strat      = var_strat,
          var_strat_frac = var_strat_frac,
          sort_var       = sort_var,
          adj_method     = adj_method,
          scale_method   = scale_method
        ),
      method     = "jackknife",
      params     = list(
        type           = "grouped",
        replicates     = replicates,
        mse            = mse,
        var_strat      = var_strat,
        var_strat_frac = var_strat_frac,
        sort_var       = sort_var,
        adj_method     = adj_method,
        scale_method   = scale_method
      ),
      seed = seed
    ))
  }

  # ---- DAGJK dispatch (survey_nonprob + type = "grouped") ------------------

  # Step 5: validate reference_sample class (if supplied)
  if (!is.null(reference_sample)) {
    .validate_reference_sample(reference_sample)
  }

  # Step 6: already done above (replicates required check)

  # Step 7: Phase 1 validation (type, whole-number, minimum >= 2; no ceiling)
  replicates <- .validate_replicates_dagjk_arg(replicates, combined_n = Inf)

  # Step 8: history routing
  ipw_entries <- Filter(
    function(e) identical(e$operation, "ipw"),
    data@metadata@weighting_history
  )
  ipw_entry <- if (length(ipw_entries) > 0L) {
    ipw_entries[[length(ipw_entries)]]
  } else {
    NULL
  }

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

  if (is.null(ipw_entry) && is.null(calib_entry)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "No IPW or calibration step found in the weighting history of ",
          "{.arg data}."
        ),
        "i" = paste0(
          "{.fn create_jackknife_weights} requires an {.fn ipw} or ",
          "calibration step in the weighting history."
        ),
        "v" = paste0(
          "Call {.fn ipw} or a calibration function on the non-probability ",
          "sample before calling {.fn create_jackknife_weights}."
        )
      ),
      class = "surveywts_error_jackknife_no_history"
    )
  }

  # Step 9: level detection
  use_level_b <- isTRUE(calib_entry$parameters$targets_from_reference)

  # Step 10: reference resolution
  n_nps <- nrow(data@data)

  if (!is.null(ipw_entry)) {
    # IPW path: reference always required
    ref_design <- reference_sample %||% ipw_entry$reference_design
    if (is.null(ref_design)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "A reference probability sample is required for ",
            "{.fn create_jackknife_weights} with a non-probability sample."
          ),
          "i" = paste0(
            "No reference design found in the {.code ipw()} history entry ",
            "and {.arg reference_sample} was not supplied."
          ),
          "v" = paste0(
            "Supply the reference design via {.arg reference_sample}, or ",
            "re-run {.fn ipw} with a {.cls survey_taylor} reference."
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
    # nocov start
    # Defensive: calibrate_rake/linear/logit always stores reference_design in
    # the history entry when called with reference_design != NULL. The only way
    # to reach this branch is if the history entry was manually corrupted.
    if (is.null(ref_design)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "A reference probability sample is required for ",
            "{.fn create_jackknife_weights} with a non-probability sample."
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
    # nocov end
    n_ref      <- nrow(ref_design@data)
    combined_n <- n_nps + n_ref
  } else {
    # Calibration-only Level A: no reference needed
    ref_design <- NULL
    n_ref      <- 0L
    combined_n <- n_nps
  }

  # Step 11: Phase 2 validation (ceiling check now that combined_n is known)
  replicates <- .validate_replicates_dagjk_arg(replicates, combined_n = combined_n)

  # Step 12: mse check — DAGJK requires mse = TRUE
  if (!isTRUE(mse)) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.code mse = FALSE} is not valid for {.code type = \"grouped\"} ",
          "with a non-probability sample. Overriding to {.code mse = TRUE}."
        ),
        "i" = paste0(
          "The DAGJK variance formula (Kott 2001 eq. 1) centers each replicate ",
          "on the full-sample estimate; {.code mse = FALSE} is inconsistent ",
          "with this formula."
        )
      ),
      class = "surveywts_warning_jackknife_mse_overridden"
    )
    mse <- TRUE
  }

  # Step 13: svrep args check — warn once for all non-default values
  svrep_args_non_default <- (
    !is.null(var_strat) ||
      !is.null(var_strat_frac) ||
      !is.null(sort_var) ||
      adj_method != "variance-stratum-psus" ||
      scale_method != "variance-stratum-psus"
  )
  if (svrep_args_non_default) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Arguments {.arg var_strat}, {.arg var_strat_frac}, {.arg sort_var}, ",
          "{.arg adj_method}, and/or {.arg scale_method} do not affect ",
          "non-probability samples and were ignored."
        ),
        "i" = paste0(
          "These arguments control {.pkg svrep} variance stratification for ",
          "probability samples only."
        )
      ),
      class = "surveywts_warning_jackknife_svrep_args_ignored"
    )
  }

  # Step 14: overwrite check
  data <- .handle_repweights_overwrite(
    data,
    fn_name       = "create_jackknife_weights",
    warning_class = "surveywts_warning_jackknife_repweights_overwritten"
  )

  # Step 15: small groups warning
  avg_group_size <- floor(combined_n / replicates)
  if (avg_group_size < 5L) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Average group size is {avg_group_size} unit(s) ",
          "({combined_n} combined / {replicates} groups)."
        ),
        "i" = paste0(
          "Groups with fewer than 5 units may cause the logistic model to fail ",
          "to converge in some replicates."
        ),
        "v" = paste0(
          "Reduce {.arg replicates} or ensure the combined NPS + reference ",
          "dataset is large enough relative to the number of groups."
        )
      ),
      class = "surveywts_warning_jackknife_small_groups"
    )
  }

  # ---- DAGJK engine --------------------------------------------------------

  if (!is.null(seed)) set.seed(seed)
  group_assign <- sample(rep(seq_len(replicates), length.out = combined_n))

  wt_col     <- data@variables$weights
  nps_data   <- data@data
  strata_var <- data@variables$strata  # NULL if no NPS strata variable
  ref_data   <- if (!is.null(ref_design)) ref_design@data else NULL
  ref_wt_col <- if (!is.null(ref_design)) ref_design@variables$weights else NULL

  failed_reps <- 0L
  repwt_list  <- list()

  for (g in seq_len(replicates)) {
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
          wt_col       = wt_col,
          strata_var   = strata_var,
          G            = replicates
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

  # ---- Post-loop checks ----------------------------------------------------

  if (failed_reps > 0.1 * replicates) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{failed_reps} of {replicates} group replicates failed and were skipped."
        ),
        "i" = paste0(
          "A replicate fails when the logistic model does not converge or ",
          "produces degenerate propensity scores in the reduced dataset."
        ),
        "v" = paste0(
          "Reduce {.arg replicates} or inspect the data for extreme covariate ",
          "imbalance."
        )
      ),
      class = "surveywts_warning_jackknife_replicates_failed"
    )
  }

  G_success <- replicates - failed_reps

  if (G_success == 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "All {replicates} group replicates failed; no replicate weights ",
          "could be produced."
        ),
        "i" = paste0(
          "Every replicate produced degenerate propensity scores or ",
          "calibration divergence."
        ),
        "v" = paste0(
          "Check {.arg data} for single-level covariates or extreme covariate ",
          "imbalance with the reference. Consider reducing {.arg replicates}."
        )
      ),
      class = "surveywts_error_jackknife_all_replicates_failed"
    )
  }

  # ---- Assemble output -----------------------------------------------------

  repwt_names <- paste0("repwt_", seq_len(G_success))
  for (i in seq_len(G_success)) {
    data@data[[repwt_names[i]]] <- repwt_list[[i]]
  }

  # Negative weight warning (after assembling all replicate columns)
  rep_mat <- as.matrix(data@data[, repwt_names, drop = FALSE])
  # nocov start
  # This path requires calibrate_linear() with extreme targets on a replicate
  # where the composition deviates sharply from population targets — reliably
  # engineering such a case without also breaking convergence is infeasible.
  if (any(rep_mat < 0, na.rm = TRUE)) {
    cli::cli_warn(
      c(
        "!" = "One or more replicate weight values are negative.",
        "i" = paste0(
          "Negative replicate weights can occur with the extended DAGJK formula ",
          "(when n_h = 2 for some stratum) or after calibration with extreme ",
          "targets. Variance estimates should be interpreted cautiously."
        ),
        "v" = "Review calibration targets or use {.code trim = TRUE} in {.fn ipw}."
      ),
      class = "surveywts_warning_jackknife_negative_replicate_weights"
    )
  }
  # nocov end

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
      step              = length(meta@weighting_history) + 1L,
      operation         = "jackknife_weights",
      timestamp         = Sys.time(),
      parameters        = list(
        type              = "grouped",
        replicates        = as.integer(replicates),
        replicates_used   = as.integer(G_success),
        replicates_failed = as.integer(failed_reps),
        mse               = TRUE,
        scale             = (G_success - 1L) / G_success,
        seed              = seed
      ),
      reference_design  = ref_design,
      source_design     = .snapshot_variables_for_history(data)
    ))
  )
  data@metadata <- meta

  data
}
