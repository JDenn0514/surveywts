# R/create_bootstrap_weights.R
#
# create_bootstrap_weights() — bootstrap replicate weights for
# survey_taylor and survey_nonprob designs.

# ============================================================================
# create_bootstrap_weights()
# ============================================================================

#' Generate bootstrap replicate weights
#'
#' Generates bootstrap replicate weights for probability-sample designs via
#' [svrep::as_bootstrap_design()], or quasi-randomization bootstrap replicate
#' weights for non-probability samples (`survey_nonprob`) via an internal
#' resample-reweight algorithm.
#'
#' @param data A `survey_taylor` or `survey_nonprob` design object.
#'   `survey_replicate` and `data.frame` → error. A `survey_nonprob` is
#'   accepted with a probability-sample `type` as well; it is then wrapped
#'   as a simple random sample — see `@details`.
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
#'   (error stub; requires `mass_imputation()`, not yet implemented). See
#'   [svrep::as_bootstrap_design()] for how the five probability-sample
#'   variants differ.
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
#' @returns
#'   - Probability-sample types → `survey_replicate` with `replicates` new
#'     `rep_1...rep_N` columns and a `"replicate_creation"` history entry.
#'     This holds for `survey_nonprob` input too: a `survey_nonprob` with a
#'     probability-sample `type` returns a `survey_replicate`.
#'   - `type = "quasi-randomization"` → `survey_nonprob` with `replicates`
#'     new `repwt_1...repwt_B` columns in `@data`, `@variables$repweights`
#'     populated, and a `"bootstrap_weights"` history entry.
#'
#' @details
#' **When to use.** Choose the bootstrap when you estimate a median or
#' another quantile — the jackknife standard error for a quantile does
#' not improve as the sample grows (Elliott & Valliant 2017) — or when
#' your estimator has no textbook variance formula (Wu 2022). For a
#' non-probability sample with a reference probability sample, use
#' `type = "quasi-randomization"`, which refits the weighting model
#' inside every replicate.
#'
#' A `survey_nonprob` passed with a probability-sample `type` (the default
#' included) is silently wrapped as a simple random sample: the replicates
#' resample rows with the base weights and ignore the propensity-estimation
#' step. To capture that step in the variance, use
#' `type = "quasi-randomization"` instead. The `survey_replicate` returned
#' by the wrapped path cannot be converted back with [as_taylor_design()] —
#' that function refuses an object whose source design was a
#' non-probability sample.
#'
#' @section Algorithm:
#' For probability-sample designs (`survey_taylor`), delegates to
#' [svrep::as_bootstrap_design()] with the specified `type`. The variance
#' estimator for resampling type `"Rao-Wu-Yue-Beaumont"` is:
#' \deqn{\hat{V}_{boot} = \frac{1}{B} \sum_{b=1}^{B}
#'   (\hat{\theta}^{(b)} - \hat{\theta})^2}
#' when `mse = "mse"`, with `B = replicates`.
#'
#' For non-probability samples (`type = "quasi-randomization"`), each
#' bootstrap replicate resamples respondents with replacement (SRSWR),
#' then re-runs the original IPW fitting on the resampled data, producing
#' replicate weights that reflect the variability of the propensity
#' estimation step.
#'
#' @section Limitations:
#' Bootstrap standard errors from `type = "quasi-randomization"` likely
#' understate true sampling variability because SRSWR resampling cannot
#' replicate the original NPS recruitment mechanism (AAPOR 2022, §4). This
#' understatement is not reduced by increasing `replicates`.
#'
#' @references
#'   Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability
#'   samples. *Statistical Science* **32**(2), 249--264.
#'
#'   Wu, C. (2022). Statistical inference with non-probability survey samples.
#'   *Survey Methodology* **48**(2), 283--311.
#'
#'   Chrostowski, L., Chlebicki, P. and Beresewicz, M. nonprobsvy — An R
#'   package for modern methods for non-probability surveys.
#'
#' @examples
#' # default SRSWR bootstrap on a probability survey -----------------------
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' create_bootstrap_weights(gss_svy)
#'
#' # quasi-randomization bootstrap for a calibrated non-probability sample ----
#' targets_a <- list(
#'   sex    = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#' ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#' ns_wave1_cal <- calibrate_rake(ns_wave1_svy, targets = targets_a)
#' create_bootstrap_weights(
#'   ns_wave1_cal,
#'   type       = "quasi-randomization",
#'   replicates = 200L
#' )
#'
#' @seealso [create_jackknife_weights()], [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_sdr_weights()],
#'   [create_replicate_weights()], [as_taylor_design()]
#' @family replicate-weights
#' @export
create_bootstrap_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c(
    "Rao-Wu-Yue-Beaumont",
    "Rao-Wu",
    "Antal-Tille",
    "Preston",
    "Canty-Davison",
    "quasi-randomization",
    "hybrid"
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
  mse <- rlang::arg_match(mse)

  # Resolve NULL replicates
  if (is.null(replicates)) {
    replicates <- if (type %in% c("quasi-randomization", "hybrid")) {
      200L
    } else {
      500L
    }
  }
  replicates <- .validate_replicates_arg(replicates)

  # ---- Dispatch: NPS types vs. probability-sample types -------------------
  # NPS type check runs before .validate_replicate_input() so that
  # non-design inputs get a more informative NPS-specific error.
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
              "non-probability samples."
            ),
            "v" = paste0(
              "Use {.fn ipw} or {.fn calibrate_rake} to create a ",
              "{.cls survey_nonprob}, then call {.fn create_bootstrap_weights}."
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
        data = data,
        replicates = replicates,
        reference_sample = reference_sample,
        mse = mse,
        seed = seed
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
      data = data,
      backend_fn = function(d) {
        svrep::as_bootstrap_design(
          d,
          type = type,
          replicates = replicates,
          mse = mse_logical
        )
      },
      method = "bootstrap",
      params = list(type = type, replicates = replicates, mse = mse_logical),
      seed = seed
    )
  }
}
