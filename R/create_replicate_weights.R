# R/create_replicate_weights.R
#
# create_replicate_weights() — dispatcher to the appropriate create_*_weights()
# function based on the method argument.

# ============================================================================
# create_replicate_weights()
# ============================================================================

#' Generate replicate weights for a survey design
#'
#' Dispatches to the appropriate `create_*_weights()` function based on
#' `method`. All validation, defaults, and error messages are handled by the
#' dispatched function; this function only resolves the method name.
#'
#' @param data A `survey_taylor` or `survey_nonprob` design.
#' @param method `character(1)`. One of `"bootstrap"`, `"jackknife"`, `"brr"`,
#'   `"generalized-bootstrap"`, `"generalized-replicate"`,
#'   `"successive-difference"`. For delete-a-group jackknife on a
#'   `survey_nonprob`, use `method = "jackknife"` with `type = "grouped"`.
#' @param ... Passed as-is to the dispatched function. Invalid arguments for
#'   the selected method produce R's native "unused argument" error.
#'
#' @returns A `survey_replicate` for most methods, or a `survey_nonprob`
#'   when `method = "jackknife"` and `type = "grouped"` is passed via `...`
#'   for DAGJK on a non-probability sample.
#'
#'   Every replicate weight column holds a finished weight, on the same
#'   scale as the base weight column, not a factor to apply to the base
#'   weight. This matches the replicate columns in the bundled `cps_2023`
#'   dataset and the convention `survey` calls combined weights.
#'
#' @details
#' All six methods estimate variance by rebuilding the estimate on many
#' perturbed copies of the weights — replicate weights (sets of
#' perturbed weight columns used to compute standard errors) — then
#' measuring the spread across those copies. They differ in how the
#' perturbation is built, and each one assumes something about the
#' sample design. Replication avoids the derivatives that Taylor
#' linearization needs, which makes variance available for complex
#' statistics (Dippo, Fay & Morganstein 1984).
#'
#' **Bootstrap** (`method = "bootstrap"`) resamples with replacement and
#' recomputes the estimate. It is the only method here that is consistent
#' for quantiles (Elliott & Valliant 2017), and the practical choice when
#' an estimator has no closed-form variance (Wu 2022). On a
#' non-probability sample with `type = "quasi-randomization"`, the
#' pseudo-weight model refits inside every replicate. Note that `mse` is
#' a string here, not a logical.
#'
#' **Jackknife** (`method = "jackknife"`) drops one PSU (a primary
#' sampling unit: the first unit the design selects, such as a county
#' or school) at a time and reweights the rest of its stratum (Valliant,
#' Dever & Kreuter 2018, Section 15.4). Use `type = "jk1"` for a simple
#' random sample and `type = "jkn"` for a stratified or multi-stage
#' design; the replicate count follows from the design. No jackknife
#' variant converges to the correct variance for a quantile. For DAGJK
#' (delete-a-group jackknife) on a `survey_nonprob` design, use
#' `type = "grouped"` and set `replicates` (Valliant 2020).
#'
#' **BRR (balanced repeated replication)** (`method = "brr"`) needs
#' exactly two PSUs per stratum, and uses a Hadamard matrix (a +1/-1
#' grid whose rows agree in exactly half their positions) to keep the
#' half-samples balanced across strata (Fay 1984). Unlike the jackknife, it is
#' proven for nonlinear estimators and quantiles. The default `rho = 0`
#' gives classic BRR, which zeroes one PSU per stratum in each
#' replicate; set `rho > 0` for Fay's variant, which keeps every weight
#' positive and so keeps ratio statistics defined (Dippo, Fay &
#' Morganstein 1984).
#'
#' **Generalized bootstrap** (`method = "generalized-bootstrap"`) draws
#' random weight multipliers that reproduce a target variance estimator
#' you name through `variance_estimator` (Beaumont & Patak 2012). It is
#' the general-purpose choice for designs the named methods do not fit,
#' and the documented approach for Poisson sampling. Use `tau` to clear
#' negative multipliers; the variance then carries a matching \eqn{\tau^2}
#' correction. Beaumont & Patak recommend at least 750 replicates.
#'
#' **Generalized replication** (`method = "generalized-replicate"`) is
#' the deterministic counterpart. It decomposes the same target variance
#' matrix into components and turns each into a weight perturbation
#' (Fay 1989). Its balanced construction extends BRR's logic beyond the
#' two-PSU case. There is no `replicates` argument; use `max_replicates`.
#'
#' **Successive difference replication**
#' (`method = "successive-difference"`) estimates variance by comparing
#' each unit with its neighbour in sort order, which is the right
#' comparison for a systematic sample (Fay & Train 1995; Ash 2014). The
#' row order of the data is part of the method: re-sorted rows give a
#' different and incorrect answer, with no error raised.
#'
#' For full algorithm documentation, parameter behavior, and
#' replicate-weight handling, see [create_bootstrap_weights()],
#' [create_jackknife_weights()], [create_brr_weights()],
#' [create_gen_boot_weights()], [create_gen_rep_weights()], and
#' [create_sdr_weights()].
#'
#' @section Messages:
#'
#' When the design carries a calibration, the replay re-runs it inside every
#' replicate. Replicates that already meet their margins are counted and
#' reported in one summary line, not announced one by one. A count close to
#' `replicates` means the replay changed little, so the variance estimate
#' may be near zero and deserves a look.
#'
#' @inheritSection create_gen_boot_weights Messages
#'
#' @references
#'   Ash, S. (2014). Using successive difference replication for estimating
#'   variances. *Survey Methodology*, 40(1), 47--59.
#'
#'   Beaumont, J.-F. and Patak, Z. (2012). On the generalized bootstrap for
#'   sample surveys with special attention to Poisson sampling.
#'   *International Statistical Review*, 80(1), 127--148.
#'
#'   Dippo, C., Fay, R.E. and Morganstein, D. (1984). Computing variances
#'   from complex samples with replicate weights. *Proceedings of the
#'   Section on Survey Research Methods, American Statistical Association*,
#'   489--494.
#'
#'   Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability
#'   samples. *Statistical Science*, 32(2), 249--264.
#'
#'   Fay, R.E. (1984). Some properties of estimates of variance based on
#'   replication methods. *Proceedings of the Section on Survey Research
#'   Methods, American Statistical Association*, 495--500.
#'
#'   Fay, R.E. (1989). Theory and application of replicate weighting for
#'   variance calculations. *Proceedings of the Section on Survey Research
#'   Methods, American Statistical Association*.
#'
#'   Fay, R.E. and Train, G.F. (1995). Aspects of survey and model-based
#'   postcensal estimation of income and poverty characteristics for states
#'   and counties. *Joint Statistical Meetings, Proceedings of the Section
#'   on Government Statistics*, 154--159.
#'
#'   Valliant, R. (2020). Comparing alternatives for estimation from
#'   nonprobability samples. *Journal of Survey Statistics and Methodology*,
#'   8, 231--263.
#'
#'   Valliant, R., Dever, J. and Kreuter, F. (2018). *Practical Tools for
#'   Designing and Weighting Survey Samples*, 2nd edition. New York:
#'   Springer.
#'
#'   Wu, C. (2022). Statistical inference with non-probability survey
#'   samples. *Survey Methodology*, 48(2), 283--311.
#'
#' @examples
#' # bootstrap (default: Rao-Wu-Yue-Beaumont) ------------------------------
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' # Real analyses use more replicates; 100 keeps `R CMD check` fast.
#' boot_rep <- create_replicate_weights(
#'   gss_svy, method = "bootstrap", replicates = 100L, seed = 1L
#' )
#' summarize_weights(boot_rep)
#' # The confidence interval below is computed from the 100 replicate
#' # columns, which is what the replicate weights are for.
#' surveycore::get_means(boot_rep, age)
#'
#' # jackknife ----------------------------------------------------------------
#' # the design fixes the replicate count, so there is no `replicates` to set
#' jack_rep <- create_replicate_weights(gss_svy, method = "jackknife")
#' summarize_weights(jack_rep)
#'
#' # delete-a-group jackknife for a non-probability sample ------------------
#' targets_a <- list(
#'   sex    = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#' ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#' ns_wave1_cal <- calibrate_rake(ns_wave1_svy, targets = targets_a)
#' # This path replays the calibration inside every replicate. Replicates that
#' # already met their margins are named in one summary line. Real analyses use
#' # more replicates; 25 keeps `R CMD check` fast.
#' dagjk_rep <- create_replicate_weights(
#'   ns_wave1_cal, method = "jackknife", type = "grouped",
#'   replicates = 25L, seed = 42L
#' )
#' summarize_weights(dagjk_rep)
#'
#' @family replicate-weights
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_sdr_weights()], [as_taylor_design()].
#'   For the class system, the standard workflows, and a glossary of terms,
#'   see the [Getting started
#'   article](https://jdenn0514.github.io/surveywts/articles/getting-started.html).
#' @export
create_replicate_weights <- function(
  data,
  method = c(
    "bootstrap",
    "jackknife",
    "brr",
    "generalized-bootstrap",
    "generalized-replicate",
    "successive-difference"
  ),
  ...
) {
  method <- rlang::arg_match(method)
  switch(
    method,
    bootstrap = create_bootstrap_weights(data, ...),
    jackknife = create_jackknife_weights(data, ...),
    brr = create_brr_weights(data, ...),
    "generalized-bootstrap" = create_gen_boot_weights(data, ...),
    "generalized-replicate" = create_gen_rep_weights(data, ...),
    "successive-difference" = create_sdr_weights(data, ...)
  )
}
