# R/ipw.R
#
# Inverse probability weighting for non-probability samples.
#
# Contents:
#   .fit_participation_propensity() - internal Newton-Raphson engine
#   ipw()                           - user-facing IPW constructor

# ============================================================================
# .fit_participation_propensity()
# ============================================================================

#' @keywords internal
#' @noRd
.fit_participation_propensity <- function(
  selection,
  nps_data,
  ref_data,
  ref_weights,
  method,
  estimating_eq,
  maxit,
  epsilon
) {
  sel_vars <- all.vars(selection)

  # Detect "(Missing)" rows in NPS data (produced by missing_method = "separate").
  # When present, the pseudo-likelihood Hessian is singular if "(Missing)" is
  # treated as either a regular dummy (X_ref column all-zeros) or as the reference
  # level (X_ref intercept = sum of other dummies, so X_ref is collinear). The
  # fix: fit the NR score equations on complete-case NPS rows only; predict for
  # ALL NPS rows by substituting "(Missing)" with the reference baseline level.
  sep_mask <- rep(FALSE, nrow(nps_data))
  for (var in sel_vars) {
    if (is.factor(nps_data[[var]]) || is.character(nps_data[[var]])) {
      sep_mask <- sep_mask | (as.character(nps_data[[var]]) == "(Missing)")
    }
  }
  has_sep <- any(sep_mask)

  nps_fit <- if (has_sep) nps_data[!sep_mask, , drop = FALSE] else nps_data
  nps_pred <- nps_data

  # Align factor levels: reference is authoritative.
  for (var in sel_vars) {
    if (is.character(ref_data[[var]]) || is.factor(ref_data[[var]])) {
      ref_levs <- sort(unique(as.character(ref_data[[var]][
        !is.na(ref_data[[var]])
      ])))
      if (has_sep) {
        # Replace "(Missing)" in prediction dataset with the baseline ref level
        pred_col <- as.character(nps_pred[[var]])
        pred_col[pred_col == "(Missing)"] <- ref_levs[1L]
        nps_pred[[var]] <- factor(pred_col, levels = ref_levs)
        nps_fit[[var]] <- factor(
          as.character(nps_fit[[var]]),
          levels = ref_levs
        )
      } else {
        nps_fit[[var]] <- factor(nps_data[[var]], levels = ref_levs)
        nps_pred[[var]] <- nps_fit[[var]]
      }
      ref_data[[var]] <- factor(ref_data[[var]], levels = ref_levs)
    }
  }

  X_nps_fit <- stats::model.matrix(selection, data = nps_fit)
  X_nps_pred <- if (has_sep) {
    stats::model.matrix(selection, data = nps_pred)
  } else {
    X_nps_fit
  }
  X_ref <- stats::model.matrix(selection, data = ref_data)
  d_ref <- ref_weights
  gamma <- rep(0, ncol(X_nps_fit))
  link <- stats::binomial(link = method)$linkinv
  converged <- FALSE
  delta <- rep(Inf, ncol(X_nps_fit))

  # GEE path: reference population covariate totals are constant across NR
  # iterations (do not depend on gamma). Compute once before the loop.
  ref_totals <- colSums(X_ref * d_ref)

  for (iter in seq_len(maxit)) {
    # Guard: detect NPS score saturation on the PREDICTION matrix (all NPS rows).
    # R's link functions cap at 1 - .Machine$double.eps rather than 1.0 exactly.
    # When NPS is heavily overrepresented, gamma diverges and scores hit this float
    # boundary. Returning early here lets ipw() throw
    # surveywts_error_propensity_scores_degenerate with the correct class.
    eps <- .Machine$double.eps
    cur_scores <- link(drop(X_nps_pred %*% gamma))
    if (any(cur_scores <= eps | cur_scores >= 1 - eps)) {
      return(list(
        scores = cur_scores,
        converged = FALSE,
        final_delta = max(abs(delta))
      ))
    }

    if (estimating_eq == "mle") {
      pi_ref <- link(drop(X_ref %*% gamma))
      score <- colSums(X_nps_fit) - drop(t(X_ref) %*% (d_ref * pi_ref))
      hess <- -crossprod(X_ref, X_ref * (d_ref * pi_ref * (1 - pi_ref)))
    } else {
      # GEE path: calibration score that guarantees sum(w * x) = sum(d_ref * x)
      # at convergence. Jacobian sums over NPS rows (not reference rows).
      pi_nps <- link(drop(X_nps_fit %*% gamma))
      # Inner GEE guard: if any NPS propensity hits the float boundary, return
      # early — same converged = FALSE path as the outer saturation guard.
      if (any(pi_nps <= eps)) {
        return(list(
          scores = link(drop(X_nps_pred %*% gamma)),
          converged = FALSE,
          final_delta = max(abs(delta))
        ))
      }
      score <- colSums(X_nps_fit / pi_nps) - ref_totals
      hess <- -crossprod(X_nps_fit, X_nps_fit * ((1 - pi_nps) / pi_nps))
    }
    delta <- tryCatch(
      solve(hess, score),
      error = function(e) {
        cli::cli_abort(
          c(
            "x" = "Propensity Hessian is singular: {e$message}",
            "i" = "Collinear or degenerate covariates in {.arg selection}.",
            "v" = "Simplify {.arg selection} or check for constant covariate columns."
          ),
          class = "surveywts_error_propensity_hessian_singular"
        )
      }
    )
    gamma <- gamma - delta
    if (max(abs(delta)) < epsilon) {
      converged <- TRUE
      break
    }
  }
  list(
    scores = link(drop(X_nps_pred %*% gamma)),
    converged = converged,
    final_delta = max(abs(delta))
  )
}

# ============================================================================
# ipw()
# ============================================================================

#' Inverse probability weighting for non-probability samples
#'
#' @title Inverse Probability Weighting (IPW) for Non-Probability Samples
#'
#' @description
#' Constructs inverse probability weights for a non-probability sample (NPS)
#' by estimating participation propensity via pseudo-likelihood logistic
#' regression. The weights adjust for selection bias by upweighting NPS units
#' that are underrepresented relative to a probability-based reference sample.
#'
#' @param data A `data.frame` containing the non-probability sample.
#' @param reference A `survey_taylor` object representing the probability-based
#'   reference sample. Must have strictly positive design weights. The reference
#'   sample must itself represent the target population without material coverage
#'   or nonresponse bias — design weights alone do not correct for an internally
#'   biased reference survey. Elliott & Valliant (2017) recommend using large,
#'   well-controlled probability surveys (e.g., government-conducted household
#'   surveys) as the reference; a biased reference will produce biased propensity
#'   estimates regardless of model specification. Shared covariates must be
#'   measured with the same question wording, response options, and measurement
#'   period in both samples — category differences (e.g., 4-point vs. 5-point
#'   scales) produce spurious covariate imbalance that the propensity model
#'   cannot correct (Valliant, 2020).
#' @param selection A one-sided formula (e.g., `~ age + sex`) specifying
#'   the covariates used to model participation propensity. Exactly one of
#'   `selection` and `predictors` must be supplied.
#' @param predictors A character vector of covariate names (e.g.,
#'   `c("age", "sex")`), used as an alternative to `selection`. Exactly one
#'   of `selection` and `predictors` must be supplied. Suitable for
#'   programmatic use (e.g., `lapply()`).
#' @param missing_method How to handle `NA` values in `selection` variables in
#'   `data`. One of:
#'   \describe{
#'     \item{`"omit"` (default)}{Rows with any NA in a selection variable are
#'       dropped before fitting and excluded from `@data`; a warning reports
#'       the count and which variables.}
#'     \item{`"separate"`}{NA values in **factor and character** selection
#'       variables are recoded to an explicit `"(Missing)"` baseline category
#'       so those units still enter the propensity model and receive weights.
#'       **Numeric selection variables with NA values are not supported** —
#'       `ipw()` errors with `surveywts_error_separate_numeric_na`. Convert
#'       the variable to a factor (e.g. with `cut()`) or use
#'       `missing_method = "impute"` instead.
#'       **Caveat:** The pseudo-likelihood is fitted on complete-case NPS
#'       rows only; propensity scores are predicted for all rows by
#'       substituting `"(Missing)"` with the reference baseline level.
#'       This adaptation is not derived from the pseudo-likelihood framework
#'       and has no published theoretical validation. Use
#'       `missing_method = "impute"` for a more principled missing data
#'       approach.}
#'     \item{`"impute"`}{Missing values are imputed via a single iteration of
#'       predictive mean matching using `mice::mice()` (requires the `mice`
#'       package). All NPS units receive weights.}
#'   }
#'   Regardless of `missing_method`, NA values in `reference@data` selection
#'   variables are always handled by listwise deletion with a warning.
#' @param mice_args Named list of additional arguments forwarded to
#'   `mice::mice()` when `missing_method = "impute"`. The argument `m` is
#'   fixed at `1` and cannot be overridden — attempting to do so triggers
#'   `surveywts_warning_ipw_mice_m_ignored`. Ignored when `missing_method` is
#'   not `"impute"`.
#' @param method Link function for the propensity model. One of `"logit"`
#'   (default), `"probit"`, or `"cloglog"`. Partial matching is supported.
#'   Asymptotic consistency and normality results in the cited literature
#'   (Chen, Li & Wu, 2020; Beresewicz et al., 2025) are derived specifically
#'   for logistic regression. `"probit"` and `"cloglog"` are computationally
#'   valid alternatives but have weaker formal backing in the pseudo-likelihood
#'   framework for non-probability samples.
#' @param estimating_eq Estimating equation for the propensity model. One of
#'   `"mle"` (default) or `"gee"`. Partial matching is supported.
#'
#'   - `"mle"` uses the pseudo-likelihood score equation
#'     (Chen, Li & Wu, 2020; Beresewicz et al., 2025, eq. 3.1). Weights
#'     reproduce the reference-weighted covariate totals in expectation
#'     but not exactly.
#'   - `"gee"` uses the calibration estimating equations
#'     (Beresewicz et al., 2025, eq. 3.3). At convergence, the weighted
#'     NPS covariate totals exactly reproduce the reference-weighted
#'     totals: `sum(w_k * x_k) = sum(d_k * x_k)`. When
#'     `adjust_reference = TRUE` and `nps_fraction > 0.05`, the
#'     calibration target is the Valliant-adjusted reference totals
#'     `sum(adjust_factor * d_k * x_k)` (where
#'     `adjust_factor = 1 - nps_fraction`), not the original
#'     design-weight totals. This covariate balance guarantee makes
#'     `"gee"` the building block for doubly robust estimation.
#'     When `missing_method = "separate"`, the guarantee applies only
#'     to complete-case NPS rows.
#'
#'   Beresewicz et al. (2025) show GEE-based methods generally outperform
#'   MLE in simulation. For most applications `"gee"` is preferred.
#' @param maxit Maximum number of Newton-Raphson iterations. Must be >= 1.
#'   Default `25L`.
#' @param epsilon Convergence threshold on the maximum absolute step size.
#'   Must be > 0. Default `1e-8`.
#' @param adjust_reference Logical (default `TRUE`). Whether to apply Valliant
#'   (2020) Eq. (1) reference weight adjustment when the NPS is a non-negligible
#'   fraction of the estimated population. When `nps_fraction = nrow(data) /
#'   sum(d)` (where `d` are the reference design weights after excluding rows
#'   with `NA` in any selection variable) exceeds 0.05, the reference weights
#'   are multiplied by `(N_hat - n_NPS) / N_hat` to prevent the reference-side
#'   score denominator from being inflated by NPS units already counted on the
#'   NPS side. When `nps_fraction <= 0.05`, no adjustment is applied regardless
#'   of this argument. Set `adjust_reference = FALSE` to skip the adjustment
#'   when the NPS and reference frames are known to be disjoint and the
#'   correction is inappropriate.
#' @param trim Logical. If `TRUE`, IPW weights are trimmed at
#'   `median(w) + 5 * IQR(w)` after estimation. Default `FALSE`.
#' @param population_size Optional positive numeric scalar. If the population
#'   size N is known from a census or frame, supply it here. When provided,
#'   `estimated_population_size` in the history entry records this known value
#'   and `population_size_known` is set to `TRUE`. This value is stored for
#'   reference only and does not affect the returned weights or any downstream
#'   `svymean()` call (which always uses the Hájek/IPW2 estimator). To compute
#'   an IPW1-style mean manually: `sum(result@data[[wt_name]] * y) /
#'   population_size`. When `NULL` (default), `population_size_known = FALSE`
#'   and the self-normalizing estimate `N_hat = sum(1 / pi_hat)` is recorded
#'   (IPW2/Hájek). If `population_size < nrow(data)`, the recorded value will
#'   be smaller than the sample size — this indicates a user error (N < n is
#'   impossible). Verify that `population_size` is the total population count N,
#'   not a subsample or domain size.
#' @param wt_name Name for the output weight column in `@data`. Must be a
#'   non-empty character scalar that does not already exist in `data`.
#'   Default `"ipw_weight"`.
#'
#' @return A `survey_nonprob` object. The `@data` slot contains all original
#'   columns from `data` plus a new column named `wt_name` holding the
#'   (possibly trimmed) IPW weights. When `missing_method = "omit"`, rows with
#'   NA in any selection variable are excluded from `@data`. The
#'   `@reference_sample` slot holds the supplied `reference` design. A history
#'   entry is appended to `@metadata@weighting_history`.
#'
#' @details
#' **Newton-Raphson non-convergence:** If the algorithm does not converge
#' within `maxit` iterations, a `surveywts_warning_propensity_nr_no_convergence`
#' warning is issued and the result from the last iteration is returned.
#' Inspect the data for extreme covariate imbalance or increase `maxit`.
#'
#' **Variance estimation — refit required:** Naive variance estimates from
#' the returned `survey_nonprob` object treat the propensity scores as fixed
#' and underestimate variance. Correct variance estimation requires a
#' replication approach in which the propensity model is **refit at every
#' replicate** (bootstrap resample or jackknife group) so that estimation
#' uncertainty in the propensity parameters is captured (Elliott & Valliant,
#' 2017; Valliant, 2020).
#'
#' Jackknife is generally preferred over bootstrap when point estimates are
#' nearly unbiased: Valliant (2020, Table 9) shows jackknife confidence
#' interval coverage consistently nearer the 95% nominal level than bootstrap
#' with replacement. Both require refitting the propensity model at each
#' replicate.
#'
#' A correct jackknife procedure (preferred):
#' 1. Partition `data` into G groups (G = 20 is a standard choice;
#'    Valliant (2020, §2.1.4) uses G = 20 in simulations).
#' 2. For each group g (1..G), omit group g from `data` and call `ipw()` on
#'    the reduced NPS dataset and the full `reference`.
#' 3. Compute the estimand from each of the G replicate weighted samples.
#' 4. Compute jackknife variance:
#'    `V_JK = ((G - 1) / G) * sum((theta_g - mean(theta_g))^2)`.
#'
#' A correct bootstrap procedure (valid alternative):
#' 1. Resample `data` with replacement (simple random, or cluster-aware if
#'    the NPS has a known cluster structure).
#' 2. Resample `reference` using a design-respecting method — for complex
#'    designs, use Rao-Wu rescaled bootstrap
#'    (`survey::as.svrepdesign(type = "subbootstrap")`) rather than plain
#'    SRS resampling.
#' 3. Call `ipw()` on each resample pair to produce new weights.
#' 4. Compute the estimand from each replicate's weighted sample.
#' 5. Use replicate variance as the variance estimate.
#'
#' Both procedures apply equally when `estimating_eq = "gee"`. Variance
#' estimates that do not refit the propensity model at each replicate will
#' be anti-conservative.
#'
#' **Estimating equation:** `ipw()` uses the *unconditional* pseudo-likelihood
#' approach (Valliant & Dever, 2011, as described in Elliott & Valliant, 2017,
#' p. 256). NPS units enter the score equation with implicit weight 1;
#' reference units enter with their design weights. This estimates
#' P(NPS | in population) directly, rather than P(NPS | in combined sample).
#' The alternative *conditional* approach — pooling both samples and running an
#' unweighted logistic regression with NPS membership as the outcome — is not
#' used because it does not account for reference design weights and estimates
#' a different quantity (Chen, Li & Wu, 2020, §2.1).
#'
#' **Doubly robust estimation (recommended):** The papers in `@references`
#' unanimously recommend combining IPW weights with an outcome regression model
#' to form a doubly robust (DR) estimator. A DR estimator is consistent if
#' *either* the propensity model *or* the outcome regression model is correctly
#' specified — providing protection against misspecification of either.
#' Valliant (2020) found DR "was the best combination in this study in terms
#' of bias, RMSE, and confidence interval coverage"; Yang et al. (2020) show
#' that DR substantially outperforms IPW-only under propensity
#' misspecification. The weights returned by `ipw()` are the propensity
#' component of such a DR pipeline; the outcome regression step is planned
#' for a future release.
#'
#' **Sensitivity to propensity model misspecification:** IPW estimates can be
#' severely biased when selection is nonlinear and the `selection` formula does
#' not capture this nonlinearity. Chen, Li & Wu (2020, Table 1) demonstrate
#' ~25% relative bias under a misspecified propensity model even when the
#' correct variables are included. Beresewicz et al. (2025) show RMSE
#' increases of 30x or more under nonlinear selection. To mitigate this risk:
#' add interaction or polynomial terms to `selection` if nonlinear selection
#' is suspected; follow `ipw()` with a doubly robust step; or use
#' `diagnose_propensity()` (planned) to assess covariate balance.
#'
#' **High-dimensional selection:** For large covariate vectors, Elliott &
#' Valliant (2017) recommend regularized alternatives such as LASSO-penalized
#' logistic regression, BART, or super learner. `ipw()` uses Newton-Raphson
#' on the full unpenalized model and may overfit in high-dimensional settings.
#' In such cases, fit the propensity model externally, extract predicted
#' probabilities, and use them directly.
#'
#' **Quantile balancing approximation:** Beresewicz et al. (2025) show that
#' augmenting the propensity model with quantile-indicator variables for
#' continuous covariates substantially reduces bias under nonlinear selection
#' ("quantile balancing IPW"). Users can approximate this by adding cut-point
#' indicators to `selection`:
#' ```r
#' nps$age_q <- cut(
#'   nps$age,
#'   quantile(nps$age, c(0, .25, .5, .75, 1)),
#'   include.lowest = TRUE
#' )
#' ipw(nps, ref, selection = ~age_q + sex)
#' ```
#' Native QBIPW support (Beresewicz et al., 2025, eqs. 4.1--4.2) is planned
#' for a future release.
#'
#' @note
#' **Missing at random (MAR) assumption:** `ipw()` is consistent only if NPS
#' participation is independent of the outcome variable given the observed
#' covariates in `selection` — formally, P(I_NPS = 1 | X, Y) = P(I_NPS = 1 |
#' X). This is called "missing at random" (MAR) or "non-informative sampling"
#' in the survey statistics literature (Chen, Li & Wu, 2020, Assumption A1;
#' Valliant, 2020). It is not testable from observed data. If participation
#' depends on Y even after conditioning on X (not missing at random, NMAR),
#' IPW weights will be biased regardless of model quality. Common causes of
#' NMAR in opt-in panels include self-selection on health, income, or political
#' engagement when those outcomes are also the study variables.
#'
#' **Common support:** IPW requires that every covariate combination observed
#' in the NPS is also present in the reference. If not, scores approach 1 and
#' weights become uninformative.
#'
#' **Variance under-estimation:** Naive variance estimates from the resulting
#' `survey_nonprob` object do not account for the uncertainty in the estimated
#' propensity scores. Bootstrap variance estimation is recommended.
#'
#' **Weight interpretation:** The IPW weight for unit `i` is
#' `w_i = 1 / P(in NPS | x_i)`. The sum of weights estimates the population
#' size (`N_hat` in the history entry reflects the pre-trim total).
#'
#' **Pre-trim population size:** `estimated_population_size` in the history
#' entry always equals `sum(w)` before trimming, regardless of `trim`.
#'
#' **Independence of participation:** The pseudo-likelihood assumes NPS
#' participation decisions are independent across units given the covariates
#' in `selection` (Chen, Li & Wu, 2020, Assumption A3). This assumption fails
#' when NPS units are clustered — for example, household panels where multiple
#' family members participate together, or snowball-recruited samples. In
#' clustered NPS settings the propensity model should include cluster-level
#' covariates, and variance estimation should use cluster-aware resampling.
#'
#' **Non-overlapping samples:** The pseudo-likelihood codes NPS units as
#' members (1) and reference units as non-members (0). If the same individual
#' appears in both `data` and `reference`, the coding is inconsistent and
#' propensity estimates will be biased. Remove any units present in both
#' samples from `reference` before calling `ipw()` (Valliant, 2020, §2.1.2).
#'
#' @seealso
#'   [adjust_nonresponse()] for unit nonresponse adjustment via weighting
#'   class methods, which can serve as the IPW step in a doubly robust pipeline
#'   when the nonresponse mechanism is modeled.
#'
#'   [calibrate_to_survey()] for post-stratification and raking calibration
#'   that can be applied after `ipw()` as the regression correction step of a
#'   doubly robust estimator.
#'
#'   `diagnose_propensity()` (planned) for propensity score diagnostics
#'   including AUC, covariate balance plots, and standardized mean differences.
#'   Uses the `propensity_scores` stored in the history entry returned by
#'   `ipw()` without refitting the model.
#'
#' @family propensity
#' @export
#'
#' @references
#' Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability samples.
#' *Statistical Science* **32**(2), 249--264.
#'
#' Chen, Y., Li, P. and Wu, C. (2020). Doubly robust inference with
#' nonprobability survey samples. *Journal of the American Statistical
#' Association* **115**(532), 2011--2021.
#'
#' Lenau, S., Marchetti, S., Munnich, R., Pratesi, M., Salvati, N., Shlomo,
#' N., Schirripa Spagnolo, F. and Zhang, L.-C. (2021). Methods for sampling
#' and inference with non-probability samples. Deliverable D11.8,
#' InGRID-2 project 730998 -- H2020.
#'
#' Valliant, R. and Dever, J.A. (2011). Estimating propensity adjustments
#' for volunteer web surveys. *Sociological Methods & Research*
#' **40**(1), 105--137.
#'
#' Valliant, R. (2020). Comparing alternatives for estimation from
#' nonprobability samples. *Survey Methods: Insights from the Field*
#' **16**(1). \doi{10.13094/SMIF-2020-00011}
#'
#' Yang, S., Kim, J.K. and Song, R. (2020). Doubly robust inference when
#' combining probability and non-probability samples with high dimensional
#' data. *Journal of the Royal Statistical Society: Series B* **82**(2),
#' 445--465.
#'
#' Beresewicz, M., Szymkowiak, M. and Chlebicki, P. (2025). Quantile
#' balancing inverse probability weighting for non-probability samples.
#' *arXiv preprint* arXiv:2403.09028.
#'
#' @examples
#' data(ns_wave1)
#'
#' # --- GSS 2024 as probability reference ---
#' # Construct a Taylor reference design from the gss_2024 tibble using wt_pop.
#' data(gss_2024)
#' gss_ref <- surveycore::as_survey(
#'   gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#'
#' # Formula interface
#' result1 <- ipw(ns_wave1, gss_ref, selection = ~sex + age_f3)
#'
#' # Programmatic interface — suitable for lapply()
#' result2 <- ipw(
#'   ns_wave1,
#'   gss_ref,
#'   predictors = c("sex", "age_f3")
#' )
#'
#' # Inspect weight quality before analysis
#' effective_sample_size(result1)
#' weight_variability(result1)
#'
#' # --- ACS PUMS Wyoming as probability reference ---
#' # acs_wy_2022_svy is survey_replicate; ipw() needs survey_taylor.
#' # Construct a plain Taylor design from the tibble.
#' data(acs_wy_2022)
#' acs_ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
#' result_acs <- ipw(
#'   ns_wave1,
#'   acs_ref,
#'   selection = ~sex + age_f3 + race_f4 + edu_f3,
#'   missing_method = "omit"
#' )
#'
#' # --- Pew NPORS 2025 as probability reference ---
#' # ns_wave1 has ~120 NA values in race_f4; missing_method controls handling.
#' # Use npors_2025_clean to avoid reference-NA listwise-deletion warnings.
#' data(npors_2025_clean)
#' npors_ref <- surveycore::as_survey(npors_2025_clean, weights = wt_pop)
#'
#' # missing_method = "omit" (default): rows with NA in race_f4 are dropped
#' result_omit <- ipw(
#'   ns_wave1,
#'   npors_ref,
#'   selection = ~sex + age_f3 + race_f4 + edu_f3,
#'   missing_method = "omit"
#' )
#'
#' # missing_method = "separate": NA recoded to "(Missing)" level; all rows kept
#' result_sep <- ipw(
#'   ns_wave1,
#'   npors_ref,
#'   selection = ~sex + age_f3 + race_f4 + edu_f3,
#'   missing_method = "separate"
#' )
#'
#' # missing_method = "impute": NA imputed via mice::mice() (requires mice)
#' if (requireNamespace("mice", quietly = TRUE)) {
#'   result_imp <- ipw(
#'     ns_wave1,
#'     npors_ref,
#'     selection = ~sex + age_f3 + race_f4 + edu_f3,
#'     missing_method = "impute"
#'   )
#' }
#'
#' # --- GEE estimating equation ---
#' # GEE guarantees sum(w * x) = sum(d * x) at convergence;
#' # generally preferred over the default MLE when covariate balance matters.
#' # GEE converges best when NPS and reference are similar in size;
#' # use balanced synthetic data here to illustrate the API.
#' set.seed(42L)
#' nps_gee <- data.frame(
#'   age_group = sample(c("18-34", "35-54", "55+"), 200L, replace = TRUE),
#'   sex       = sample(c("M", "F"), 200L, replace = TRUE),
#'   stringsAsFactors = FALSE
#' )
#' ref_gee_df <- data.frame(
#'   age_group   = sample(c("18-34", "35-54", "55+"), 500L,
#'                        replace = TRUE, prob = c(0.3, 0.4, 0.3)),
#'   sex         = sample(c("M", "F"), 500L, replace = TRUE),
#'   base_weight = 1,
#'   stringsAsFactors = FALSE
#' )
#' ref_gee <- surveycore::survey_taylor(
#'   ref_gee_df,
#'   variables = list(weights = "base_weight")
#' )
#' result_gee <- ipw(
#'   nps_gee,
#'   ref_gee,
#'   selection      = ~age_group + sex,
#'   estimating_eq  = "gee",
#'   adjust_reference = FALSE
#' )
#'
#' # --- Known population size ---
#' # Supply N from a census frame to record it in the history entry.
#' # The returned weights are unchanged; N enables manual IPW1 means:
#' #   sum(result@data[["ipw_weight"]] * y) / population_size
#' result_known_n <- ipw(
#'   ns_wave1,
#'   gss_ref,
#'   selection = ~sex + age_f3,
#'   population_size = 258000000L
#' )
#' result_known_n@metadata@weighting_history[[1]]$population_size_known
ipw <- function(
  data,
  reference,
  selection = NULL,
  predictors = NULL,
  missing_method = c("omit", "separate", "impute"),
  mice_args = list(),
  method = "logit",
  estimating_eq = c("mle", "gee"),
  maxit = 25L,
  epsilon = 1e-8,
  adjust_reference = TRUE,
  trim = FALSE,
  population_size = NULL,
  wt_name = "ipw_weight"
) {
  # Behavior Rule 0: partial-match method
  method <- match.arg(method, c("logit", "probit", "cloglog"))

  # Behavior Rule 0d: partial-match estimating_eq
  estimating_eq <- match.arg(estimating_eq, c("mle", "gee"))

  # Behavior Rule 0e: validate adjust_reference
  if (
    !is.logical(adjust_reference) ||
      length(adjust_reference) != 1L ||
      is.na(adjust_reference)
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg adjust_reference} must be TRUE or FALSE.",
        "i" = paste0(
          "Got {.cls {class(adjust_reference)}} of ",
          "length {length(adjust_reference)}."
        ),
        "v" = paste0(
          "Set {.code adjust_reference = TRUE} (default) or ",
          "{.code adjust_reference = FALSE}."
        )
      ),
      class = "surveywts_error_adjust_reference_invalid"
    )
  }

  # Behavior Rule 0f: validate population_size
  if (!is.null(population_size)) {
    if (
      !is.numeric(population_size) ||
        length(population_size) != 1L ||
        is.na(population_size) ||
        !is.finite(population_size) ||
        population_size <= 0
    ) {
      cli::cli_abort(
        c(
          "x" = "{.arg population_size} must be a positive finite number.",
          "i" = "Got {.val {population_size}}.",
          "v" = paste0(
            "Supply a known census population count or leave ",
            "{.arg population_size = NULL} to use the self-normalizing estimate."
          )
        ),
        class = "surveywts_error_population_size_invalid"
      )
    }
  }

  # Behavior Rule 0a: conflict check
  if (!is.null(selection) && !is.null(predictors)) {
    cli::cli_abort(
      c(
        "x" = "Only one of {.arg selection} and {.arg predictors} may be supplied.",
        "i" = "Both were non-NULL.",
        "v" = "Use {.arg selection} for a formula or {.arg predictors} for a character vector."
      ),
      class = "surveywts_error_selection_conflict"
    )
  }

  # Behavior Rule 0b: missing check
  if (is.null(selection) && is.null(predictors)) {
    cli::cli_abort(
      c(
        "x" = "One of {.arg selection} or {.arg predictors} must be supplied.",
        "i" = "Both were NULL.",
        "v" = paste0(
          "Provide a formula via {.arg selection} ",
          "(e.g., {.code selection = ~age + sex}) or a character vector via ",
          "{.arg predictors} (e.g., {.code predictors = c(\"age\", \"sex\")})."
        )
      ),
      class = "surveywts_error_selection_missing"
    )
  }

  # Behavior Rule 0c: build selection from predictors
  if (!is.null(predictors)) {
    selection <- stats::reformulate(predictors)
    environment(selection) <- baseenv()
  }

  # Behavior Rule 1: validate data is data.frame
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} must be a {.cls data.frame}.",
        "i" = "Got {.cls {class(data)[[1L]]}}.",
        "v" = "Pass a plain {.cls data.frame} as the non-probability sample."
      ),
      class = "surveywts_error_not_data_frame"
    )
  }

  # Behavior Rule 2: validate reference is survey_taylor
  if (!S7::S7_inherits(reference, surveycore::survey_taylor)) {
    cli::cli_abort(
      c(
        "x" = "{.arg reference} must be a {.cls survey_taylor} object.",
        "i" = "Got {.cls {class(reference)[[1L]]}}.",
        "v" = paste0(
          "Pass a probability-based {.cls survey_taylor} design as the reference. ",
          "Use {.fn surveycore::as_survey} to construct one from a data frame."
        )
      ),
      class = "surveywts_error_svydesign_not_taylor"
    )
  }

  # Behavior Rule 3: extract reference weights and validate > 0
  ref_wt_col <- reference@variables$weights
  ref_weights <- reference@data[[ref_wt_col]]
  n_nonpos <- sum(ref_weights <= 0, na.rm = TRUE)
  if (n_nonpos > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg reference} weight column {.field {ref_wt_col}} contains ",
          "{n_nonpos} non-positive value(s)."
        ),
        "i" = "All reference design weights must be strictly positive (> 0).",
        "v" = "Remove or replace non-positive weights in the reference design."
      ),
      class = "surveywts_error_reference_weights_nonpositive"
    )
  }

  # Behavior Rule 4: validate nrow(data) > 0
  if (nrow(data) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} has 0 rows.",
        "i" = "The non-probability sample must have at least one row.",
        "v" = "Check that {.arg data} contains the intended sample."
      ),
      class = "surveywts_error_empty_data"
    )
  }

  # Behavior Rule 5: validate selection formula
  .validate_formula(selection)

  # Behavior Rule 6: validate selection variables exist in data
  .validate_formula_variables(selection, data, "data")

  # Behavior Rule 7: validate selection variables exist in reference@data
  .validate_formula_variables(
    selection,
    reference@data,
    "reference",
    error_class = "surveywts_error_formula_variable_not_in_reference"
  )

  # Behavior Rule 8: factor/character level alignment
  sel_vars <- all.vars(selection)
  for (var in sel_vars) {
    nps_col <- data[[var]]
    ref_col <- reference@data[[var]]
    if (is.character(nps_col) || is.factor(nps_col)) {
      nps_levels <- unique(as.character(nps_col[!is.na(nps_col)]))
      ref_levels <- unique(as.character(ref_col[!is.na(ref_col)]))
      orphaned <- setdiff(nps_levels, ref_levels)
      if (length(orphaned) > 0L) {
        lev <- orphaned[[1L]]
        cli::cli_abort(
          c(
            "x" = paste0(
              "Level {.val {lev}} of variable {.field {var}} is present in ",
              "{.arg data} but not in {.arg reference}."
            ),
            "i" = paste0(
              "Propensity estimation requires all NPS covariate levels ",
              "to appear in the reference design."
            ),
            "v" = paste0(
              "Remove NPS rows with {.field {var}} = {.val {lev}}, or add ",
              "reference units with that level."
            )
          ),
          class = "surveywts_error_propensity_level_not_in_reference"
        )
      }
    }
  }

  # Behavior Rule 9: coerce missing_method
  missing_method <- match.arg(missing_method)

  # Behavior Rule 9a: Reference NA handling (always listwise regardless of missing_method)
  ref_data_for_fit <- reference@data
  ref_weights_for_fit <- ref_weights
  ref_na_mask <- Reduce(
    "|",
    lapply(sel_vars, function(v) is.na(ref_data_for_fit[[v]]))
  )
  if (any(ref_na_mask)) {
    n_na_ref <- sum(ref_na_mask)
    na_vars_ref <- sel_vars[
      vapply(
        sel_vars,
        function(v) any(is.na(ref_data_for_fit[[v]])),
        logical(1L)
      )
    ]
    cli::cli_warn(
      c(
        "!" = paste0(
          "{n_na_ref} reference row(s) excluded from model fitting: NA in ",
          "{.and {.field {na_vars_ref}}}."
        ),
        "i" = "Reference NAs are always removed by listwise deletion regardless of {.arg missing_method}.",
        "v" = paste0(
          "Remove or impute NA values in {.arg reference} before calling ",
          "{.fn ipw} to avoid this warning."
        )
      ),
      class = "surveywts_warning_ipw_reference_na_omitted"
    )
    ref_data_for_fit <- ref_data_for_fit[!ref_na_mask, , drop = FALSE]
    ref_weights_for_fit <- ref_weights_for_fit[!ref_na_mask]
  }

  # Behavior Rule 9a-ii: Reference weight adjustment (Valliant 2020, Eq. 1)
  # n_hat from post-NA-deletion reference weights; nps_fraction from full NPS.
  n_hat <- sum(ref_weights_for_fit)
  nps_fraction <- nrow(data) / n_hat
  if (adjust_reference && nps_fraction > 0.05) {
    adjust_factor <- 1 - nps_fraction
    ref_weights_for_fit <- ref_weights_for_fit * adjust_factor
    cli::cli_warn(
      c(
        "!" = paste0(
          "NPS ({nrow(data)} units) is ",
          "{round(nps_fraction * 100, 1)}% of the estimated population ",
          "(N_hat = {round(n_hat)})."
        ),
        "i" = paste0(
          "Reference weights adjusted by factor {round(adjust_factor, 4)} per ",
          "Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat."
        ),
        "v" = paste0(
          "Set {.code adjust_reference = FALSE} to skip this adjustment if the ",
          "NPS is known to be disjoint from the reference frame."
        )
      ),
      class = "surveywts_warning_ipw_reference_weight_adjusted"
    )
  } else if (!adjust_reference && nps_fraction > 0.05) {
    adjust_factor <- 1
    cli::cli_warn(
      c(
        "!" = paste0(
          "NPS fraction is {round(nps_fraction * 100, 1)}% of the estimated ",
          "population but {.code adjust_reference = FALSE}."
        ),
        "i" = paste0(
          "Valliant (2020) recommends adjusting reference weights when ",
          "n_NPS / N_hat > 5%."
        ),
        "v" = paste0(
          "Set {.code adjust_reference = TRUE} (the default) to apply the ",
          "correction."
        )
      ),
      class = "surveywts_warning_ipw_reference_unadjusted_large_nps"
    )
  } else {
    adjust_factor <- 1
  }

  # Behavior Rule 8b: numeric covariate range check (M-1)
  # Uses ref_data_for_fit (post-NA-deletion), NOT reference@data.
  # Fires once per variable whose NPS range exceeds the reference range.
  for (var in sel_vars) {
    if (is.numeric(data[[var]]) && is.numeric(ref_data_for_fit[[var]])) {
      nps_range <- range(data[[var]], na.rm = TRUE)
      ref_range <- range(ref_data_for_fit[[var]], na.rm = TRUE)
      if (nps_range[1L] < ref_range[1L] || nps_range[2L] > ref_range[2L]) {
        cli::cli_warn(
          c(
            "!" = paste0(
              "Variable {.field {var}} has a wider range in {.arg data} ",
              "([{nps_range[1]}, {nps_range[2]}]) than in {.arg reference} ",
              "([{ref_range[1]}, {ref_range[2]}])."
            ),
            "i" = paste0(
              "NPS units outside the reference covariate range violate the ",
              "common support assumption and may produce extreme propensity ",
              "scores."
            ),
            "v" = paste0(
              "Consider removing NPS units with {.field {var}} values outside ",
              "[{ref_range[1]}, {ref_range[2]}], or trimming with ",
              "{.code trim = TRUE}."
            )
          ),
          class = "surveywts_warning_ipw_covariate_range_extrapolation"
        )
      }
    }
  }

  # Behavior Rule 8c: reference factor levels absent from NPS (M-1)
  # Uses ref_data_for_fit (post-NA-deletion), NOT reference@data.
  # Warns when reference has a level absent from NPS (inverse of Rule 8 which
  # errors on NPS levels absent from reference).
  for (var in sel_vars) {
    if (is.character(data[[var]]) || is.factor(data[[var]])) {
      nps_levels <- unique(
        as.character(data[[var]][!is.na(data[[var]])])
      )
      ref_levels <- unique(
        as.character(ref_data_for_fit[[var]][!is.na(ref_data_for_fit[[var]])])
      )
      absent_in_nps <- setdiff(ref_levels, nps_levels)
      if (length(absent_in_nps) > 0L) {
        cli::cli_warn(
          c(
            "!" = paste0(
              "{length(absent_in_nps)} level(s) of variable {.field {var}} ",
              "are present in {.arg reference} but not in {.arg data}: ",
              "{.and {.val {absent_in_nps}}}."
            ),
            "i" = paste0(
              "Reference units in these cells have no NPS analog. Their ",
              "propensity scores will be near 0, contributing extreme weights ",
              "to the score equation."
            ),
            "v" = paste0(
              "Review whether {.field {var}} is measured equivalently in ",
              "both samples."
            )
          ),
          class = "surveywts_warning_ipw_reference_levels_absent_from_nps"
        )
      }
    }
  }

  # Behavior Rules 9b / 9c / 9d: NPS NA handling
  if (missing_method == "omit") {
    # Rule 9b: drop rows with any NA in any selection variable
    nps_na_mask <- Reduce("|", lapply(sel_vars, function(v) is.na(data[[v]])))
    if (any(nps_na_mask)) {
      n_na_nps <- sum(nps_na_mask)
      na_vars_nps <- sel_vars[
        vapply(sel_vars, function(v) any(is.na(data[[v]])), logical(1L))
      ]
      cli::cli_warn(
        c(
          "!" = paste0(
            "{n_na_nps} row(s) in {.arg data} dropped: NA in ",
            "{.and {.field {na_vars_nps}}}."
          ),
          "i" = paste0(
            "Rows with any NA in a {.arg selection} variable are excluded when ",
            "{.code missing_method = \"omit\"}."
          ),
          "v" = paste0(
            "Use {.code missing_method = \"separate\"} or ",
            "{.code missing_method = \"impute\"} to retain rows with NA."
          )
        ),
        class = "surveywts_warning_ipw_data_na_omitted"
      )
      data <- data[!nps_na_mask, , drop = FALSE]
    }
  } else if (missing_method == "separate") {
    # Rule 9c: recode factor/character NA → "(Missing)" baseline; error on numeric NA
    for (var in sel_vars) {
      col <- data[[var]]
      if (any(is.na(col))) {
        if (is.numeric(col)) {
          n_na <- sum(is.na(col))
          cli::cli_abort(
            c(
              "x" = paste0(
                "{.code missing_method = \"separate\"} cannot handle numeric ",
                "selection variables with NA values."
              ),
              "i" = paste0(
                "Variable {.field {var}} is {.cls numeric} and has ",
                "{n_na} NA value(s)."
              ),
              "v" = paste0(
                "Convert {.field {var}} to a factor (e.g., with {.fn cut}) or ",
                "use {.code missing_method = \"impute\"} instead."
              )
            ),
            class = "surveywts_error_separate_numeric_na"
          )
        }
        # Factor or character: recode NA → "(Missing)" so the caller can track
        # which rows had missing data. The helper handles these rows separately
        # (fitting on complete-case NPS rows only, predicting for all).
        char_col <- as.character(col)
        char_col[is.na(char_col)] <- "(Missing)"
        existing_levels <- sort(unique(char_col[char_col != "(Missing)"]))
        data[[var]] <- factor(
          char_col,
          levels = c("(Missing)", existing_levels)
        )
      }
    }
  } else {
    # Rule 9d: missing_method == "impute" — single-iteration PMM via mice
    if (!.has_package("mice")) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Package {.pkg mice} is required for ",
            "{.code missing_method = \"impute\"}."
          ),
          "i" = "{.pkg mice} is not installed.",
          "v" = paste0(
            "Install it with {.code install.packages(\"mice\")} then re-run ",
            "{.fn ipw}."
          )
        ),
        class = "surveywts_error_mice_not_installed"
      )
    }
    na_vars_nps <- sel_vars[
      vapply(sel_vars, function(v) any(is.na(data[[v]])), logical(1L))
    ]
    if (length(na_vars_nps) > 0L) {
      if ("m" %in% names(mice_args)) {
        cli::cli_warn(
          c(
            "!" = paste0(
              "{.arg m} in {.arg mice_args} is ignored: ",
              "{.fn mice::mice} is always called with {.code m = 1L}."
            ),
            "i" = "Single imputation ({.code m = 1}) is used for propensity model fitting.",
            "v" = "Remove {.arg m} from {.arg mice_args} to suppress this warning."
          ),
          class = "surveywts_warning_ipw_mice_m_ignored"
        )
        mice_args[["m"]] <- NULL
      }
      impute_df <- data[, sel_vars, drop = FALSE]
      # mice requires factor type for categorical variables. Convert character
      # columns to factor so mice can properly impute NA values; convert back
      # after completing the imputed dataset.
      original_char_vars <- sel_vars[
        vapply(sel_vars, function(v) is.character(impute_df[[v]]), logical(1L))
      ]
      for (v in original_char_vars) {
        impute_df[[v]] <- factor(impute_df[[v]])
      }
      imp <- do.call(
        mice::mice,
        c(
          list(data = impute_df, m = 1L, method = "pmm", printFlag = FALSE),
          mice_args
        )
      )
      completed <- mice::complete(imp, 1L)
      for (v in na_vars_nps) {
        if (v %in% original_char_vars) {
          data[[v]] <- as.character(completed[[v]])
        } else {
          data[[v]] <- completed[[v]]
        }
      }
    }
  }

  # Behavior Rule 10: validate wt_name
  .validate_wt_name(wt_name)

  # Behavior Rule 11: check wt_name conflict with existing columns
  if (wt_name %in% names(data)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg wt_name} {.val {wt_name}} already exists as a column in ",
          "{.arg data}."
        ),
        "i" = "The output weight column must be distinct from all input columns.",
        "v" = "Choose a different {.arg wt_name}."
      ),
      class = "surveywts_error_wt_name_conflict"
    )
  }

  # Behavior Rule 12: validate maxit >= 1L
  if (
    !is.numeric(maxit) ||
      length(maxit) != 1L ||
      is.na(maxit) ||
      as.integer(maxit) < 1L
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg maxit} must be a whole number >= 1.",
        "i" = "Got {.val {maxit}}.",
        "v" = "Set {.arg maxit} to a positive integer (e.g., {.code maxit = 25L})."
      ),
      class = "surveywts_error_propensity_invalid_maxit"
    )
  }

  # Behavior Rule 13: validate epsilon > 0
  if (
    !is.numeric(epsilon) ||
      length(epsilon) != 1L ||
      is.na(epsilon) ||
      epsilon <= 0
  ) {
    cli::cli_abort(
      c(
        "x" = "{.arg epsilon} must be a positive number.",
        "i" = "Got {.val {epsilon}}.",
        "v" = "Set {.arg epsilon} to a small positive value (e.g., {.code epsilon = 1e-8})."
      ),
      class = "surveywts_error_propensity_invalid_epsilon"
    )
  }

  # Behavior Rule 14: fit propensity model; check convergence
  fit <- .fit_participation_propensity(
    selection = selection,
    nps_data = data,
    ref_data = ref_data_for_fit,
    ref_weights = ref_weights_for_fit,
    method = method,
    estimating_eq = estimating_eq,
    maxit = as.integer(maxit),
    epsilon = epsilon
  )
  if (!fit$converged) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Newton-Raphson did not converge after {maxit} iterations ",
          "(max |delta| = {round(fit$final_delta, 6)})."
        ),
        "i" = "Propensity scores from the last iteration are returned.",
        "v" = paste0(
          "Increase {.arg maxit}, relax {.arg epsilon}, or check for ",
          "extreme covariate imbalance between {.arg data} and {.arg reference}."
        )
      ),
      class = "surveywts_warning_propensity_nr_no_convergence"
    )
  }

  # Behavior Rule 15: validate scores - none at the float boundary of (0, 1).
  # R link functions (logit, probit, cloglog) cap at 1 - .Machine$double.eps
  # rather than returning exactly 1. A score at that boundary indicates the
  # linear predictor overflowed, which happens when the NR has diverged due to
  # extreme NPS/reference imbalance.
  scores <- fit$scores
  .eps <- .Machine$double.eps
  if (any(scores <= .eps | scores >= 1 - .eps)) {
    n_degen <- sum(scores <= .eps | scores >= 1 - .eps)
    cli::cli_abort(
      c(
        "x" = paste0(
          "{n_degen} propensity score(s) saturate at the floating-point ",
          "boundary of (0, 1)."
        ),
        "i" = paste0(
          "Scores at or beyond the float boundary indicate that the ",
          "Newton-Raphson has diverged due to extreme NPS/reference imbalance: ",
          "the NPS is so overrepresented in some covariate cells that no ",
          "valid participation propensity exists."
        ),
        "v" = paste0(
          "Review covariate distributions in {.arg data} and {.arg reference}. ",
          "Consider trimming extreme NPS units or using a simpler {.arg selection}."
        )
      ),
      class = "surveywts_error_propensity_scores_degenerate"
    )
  }

  # Behavior Rule 17: compute weights
  w <- 1 / scores

  # Behavior Rule 18: optionally trim; record n_trimmed
  w_before_trim <- w
  n_trimmed <- 0L
  trim_threshold <- NULL
  if (trim) {
    trim_threshold <- stats::median(w) + 5 * stats::IQR(w)
    trim_result <- .trim_weights_internal(
      weights = w,
      lower = -Inf,
      upper = trim_threshold,
      has_trimmed = rep(FALSE, length(w))
    )
    w <- trim_result$weights
    n_trimmed <- sum(trim_result$has_trimmed)
  }

  # Behavior Rule 19: record estimated population size (pre-trim)
  estimated_population_size <- sum(w_before_trim)

  # Behavior Rule 20: construct survey_nonprob and append history

  # Step 1 - construct the object (NSE injection for wt_name)
  out_df <- data
  out_df[[wt_name]] <- w
  result <- surveycore::as_survey_nonprob(
    data = out_df,
    weights = !!rlang::sym(wt_name),
    reference_sample = reference
  )

  # Step 2 - build history entry and append
  history_entry <- list(
    step = length(.get_history(result)) + 1L,
    timestamp = Sys.time(),
    operation = "ipw",
    formula = selection,
    method = method,
    estimating_eq = estimating_eq,
    missing_method = missing_method,
    estimator = "ipw2",
    adjust_reference = adjust_reference,
    nps_fraction = nps_fraction,
    adjust_factor = adjust_factor,
    maxit = as.integer(maxit),
    epsilon = epsilon,
    trim = trim,
    trim_threshold = trim_threshold,
    n_nps = nrow(data),
    n_reference = nrow(ref_data_for_fit),
    estimated_population_size = if (!is.null(population_size)) {
      population_size
    } else {
      estimated_population_size
    },
    population_size_known = !is.null(population_size),
    n_trimmed = as.integer(n_trimmed),
    reference_design = reference,
    targets_from_reference = FALSE,
    propensity_scores = scores
  )
  meta <- result@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  result@metadata <- meta

  result
}
