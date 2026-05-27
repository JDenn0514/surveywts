# IPW Literature Review: Gaps & Fixes

**Source:** Six-paper methodological audit of `R/nonprob-ipw.R`
**Papers reviewed:**
1. Elliott & Valliant (2017) — *Statistical Science* 32(2):249–264
2. Chen, Li & Wu (2021) — *JASA* 115(532):2011–2021
3. Valliant (2020) — *Survey Methods* 16(1)
4. Yang et al. (2018) — *Stat Methods Med Res* (companion estimation paper)
5. Yang, Kim & Song (2020) — *JRSS-B* 82(2):445–465
6. Beresewicz, Szymkowiak & Chlebicki (2025) — quantile balancing paper

---

## CRITICAL Issues

---

### C-1: `estimator = "ht"` label is wrong

**File:** `R/nonprob-ipw.R`, line 744
```r
estimator  = "ht",  # <-- wrong
```

**Papers:**
- Chen et al. 2021, §3.2, eqs. 3.3–3.4: defines IPW1 (`Σ y_i/π̂_i / N`, known N) vs. IPW2 (`Σ y_i/π̂_i / Σ 1/π̂_i`, estimated N). "IPW2 having smaller MSE for all cases."
- Beresewicz 2025, eq. 3.4: same distinction, labels τ̂_IPW1 vs. τ̂_IPW2.
- Yang 2020, eq. 1: IPW estimator uses known N in denominator (IPW1/HT form).
- Valliant 2020, §2.1: "a mean is estimated as ȳ = Σ w_i y_i / Σ w_i" — ratio estimator (IPW2/Hájek).

**Problem:** The implementation stores `estimated_population_size = sum(w_before_trim)` at line 721 — this is N̂^A, the self-normalizing denominator of IPW2 (Hájek). But the history entry labels this `"ht"`, implying IPW1 which requires known N. When the user calls `svymean()` on the returned `survey_nonprob`, the survey package applies ratio-style (Hájek) normalization — IPW2 behavior. The label and the behavior are in conflict. Chen et al. recommend IPW2 as the preferred estimator.

**Fix — line 744:**
```r
# Change:
estimator  = "ht",
# To:
estimator  = "ipw2",
```

Also update `plans/error-messages.md` to document `estimator = "ipw2"` in the history schema.

---

### C-2: Bootstrap must refit the propensity model at each resample — this is absent from all documentation

**File:** `R/nonprob-ipw.R`, lines 189–191 (`@details` section in roxygen block)
```r
#' **Variance under-estimation:** Naive variance estimates from the resulting
#' `survey_nonprob` object do not account for the uncertainty in the estimated
#' propensity scores. Bootstrap variance estimation is recommended.
```

**Papers:**
- Elliott & Valliant 2017, §3.1, p. 257: "For **each bootstrap or jackknife iteration, the pseudo-weights should be recomputed** as well as the point estimator using the dropped-out or resampled data."
- Elliott & Valliant 2017, §3.1: "For the probability sample, resampling clusters within strata and use of the Rao-Wu bootstrap to accommodate weights can be used."
- Valliant 2020, §2.1.4: "Whether WR or the jackknife is used, the binary regression model for predicting inclusion in the nonprobability sample should be **refitted in every group**."

**Problem:** A user who calls `ipw()` once, attaches the weights, then bootstraps the weighted mean without refitting the propensity model will systematically underestimate variance. The current documentation does not mention this constraint. This is the most operationally important requirement from Elliott & Valliant and is completely absent.

**Fix — replace lines 189–191 with:**
```r
#' **Variance under-estimation:** Naive variance estimates from the returned
#' `survey_nonprob` object treat the propensity scores as fixed and underestimate
#' variance. Correct variance estimation requires a replication approach in which
#' the propensity model is **refit at every replicate** (bootstrap resample or
#' jackknife group) so that score estimation uncertainty is captured.
#'
#' A correct bootstrap procedure:
#' 1. Resample `data` with replacement (simple random, or cluster-aware if the
#'    NPS has a known cluster structure).
#' 2. Resample `reference` using a design-respecting method — for complex
#'    designs use Rao-Wu rescaled bootstrap (`survey::as.svrepdesign()` with
#'    `type = "subbootstrap"`) rather than plain SRS resampling.
#' 3. Call `ipw()` on each resample pair to produce new weights.
#' 4. Compute the estimand from each replicate's weighted sample.
#' 5. Use replicate variance as the variance estimate.
#'
#' Variance estimates that do not refit the propensity model at each replicate
#' will be anti-conservative (Elliott & Valliant, 2017; Valliant, 2020).
```

---

### C-3: Reference weight adjustment for non-negligible NPS fraction is missing

**File:** `R/nonprob-ipw.R` — gap is between lines 452–456 (after reference NA handling, before NPS NA handling). No adjustment is applied.

**Paper:** Valliant 2020, §2.1.1, Equation (1):
> `w_i* = w_i × (N̂ − n_NPS) / N̂`
> "If n is a small fraction of N̂, this adjustment is unnecessary."

**Problem:** The pseudo-likelihood treats reference units as representing `N̂ = sum(d_ref)` population units. But this overcounts by `n_NPS` because those NPS units are already counted once on the NPS side of the score equation. When `n_NPS / N̂` is non-trivial (> ~5%), the denominator of the reference-side score contribution is inflated and the resulting propensity estimates are biased upward (too many NPS units appear to be in the population relative to what the reference covers).

**Fix — add after line 454 (after `ref_weights_for_fit <- ref_weights_for_fit[!ref_na_mask]`):**

Add a new argument to `ipw()`:
```r
# Add to function signature after `epsilon`:
adjust_reference = TRUE,
```

Add after reference NA handling block (after line 454), before NPS NA handling:
```r
  # Behavior Rule 9a-ii: Valliant (2020) Eq. (1) reference weight adjustment.
  # When the NPS is a non-negligible fraction of the estimated population,
  # adjust reference weights so the combined sample correctly sums to N_hat.
  # When n_NPS / N_hat < 0.05 the adjustment is essentially 1 and can be skipped.
  n_hat <- sum(ref_weights_for_fit)
  nps_fraction <- nrow(data) / n_hat
  if (adjust_reference && nps_fraction > 0.05) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "NPS has {nrow(data)} units; estimated population size is ",
          "{round(n_hat)}. NPS fraction = {round(nps_fraction * 100, 1)}%."
        ),
        "i" = paste0(
          "Reference weights adjusted by (N_hat - n_NPS) / N_hat = ",
          "{round(1 - nps_fraction, 4)} per Valliant (2020) eq. (1)."
        ),
        "v" = paste0(
          "Set {.code adjust_reference = FALSE} to skip this adjustment if ",
          "the NPS is known to be disjoint from the reference frame."
        )
      ),
      class = "surveywts_warning_ipw_reference_weight_adjusted"
    )
    ref_weights_for_fit <- ref_weights_for_fit * (1 - nps_fraction)
  } else if (!adjust_reference && nps_fraction > 0.05) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "NPS fraction is {round(nps_fraction * 100, 1)}% of the estimated ",
          "population but {.code adjust_reference = FALSE}."
        ),
        "i" = "Valliant (2020) recommends adjusting reference weights when n_NPS / N_hat > 5%.",
        "v" = "Set {.code adjust_reference = TRUE} (the default) to apply the correction."
      ),
      class = "surveywts_warning_ipw_reference_unadjusted_large_nps"
    )
  }
```

Add `adjust_reference` to the roxygen `@param` block and to `plans/error-messages.md`.

---

### C-4: IPW collapse under propensity model misspecification is not communicated

**File:** `R/nonprob-ipw.R`, lines 180–200 (`@note` section in roxygen block)

**Papers:**
- Chen et al. 2021, Table 1, "TF" scenario: pure IPW has ~25% relative bias under misspecified propensity model; doubly robust estimator remains nearly unbiased.
- Yang 2020, §6.2: "The penalized inverse probability of sampling weighting estimator shows largest biases except for scenario (ii)."
- Beresewicz 2025, Scenario IV: standard IPW-MLE RMSE = 499; QBIPW2-GEE RMSE = 14.9 — a 33× difference.
- Valliant 2020, Table 6: IPW typically more biased than calibration/raking estimators.

**Problem:** The `@note` section warns about unmeasured confounders (NMAR / "selection on observables") but says nothing about misspecification of the functional form. Even with the correct variable set, nonlinear selection can cause catastrophic bias in pure IPW. This is the single most important practical limitation of the function.

**Fix — add to `@note` section (after line 197):**
```r
#' **Sensitivity to model misspecification:** IPW estimates can be severely
#' biased when the relationship between covariates and NPS participation is
#' nonlinear and the `selection` formula does not capture this nonlinearity.
#' Chen, Li & Wu (2021, Table 1) demonstrate ~25% relative bias under a
#' misspecified propensity model even when the correct variables are included.
#' Beresewicz et al. (2025) show RMSE increases of 30x or more under nonlinear
#' selection. To mitigate this risk:
#' \itemize{
#'   \item Add interaction terms or polynomial terms to `selection` if
#'     nonlinear selection is suspected.
#'   \item Follow `ipw()` with a doubly robust step that combines the IPW
#'     weights with an outcome regression model (Chen, Li & Wu, 2021;
#'     Yang, Kim & Song, 2020). A doubly robust estimator is consistent if
#'     *either* the propensity model *or* the outcome model is correctly
#'     specified.
#'   \item Use `diagnose_propensity()` (when available) to assess covariate
#'     balance and model calibration before using the weights in analysis.
#' }
```

---

## HIGH Priority Issues

---

### H-1: The unconditional vs. conditional estimator is undocumented

**File:** `R/nonprob-ipw.R`, `@description` and `@details` sections (lines 115–200)

**Paper:** Elliott & Valliant 2017, p. 255–256:
> Two distinct approaches exist. **Conditional (Eq. 5):** pool NPS and reference, code NPS=1/reference=0, run *unweighted* logistic regression on the combined dataset — this estimates P(NPS | in combined sample), not P(NPS | in population). **Unconditional (Valliant & Dever, 2011):** assign NPS units weight=1 and reference units their design weights, run *weighted* logistic regression — this estimates P(NPS | in population) directly. "Whether this method is better or worse than (5) has not been studied."

**Problem:** The implementation uses the unconditional approach (score: `colSums(X_nps_fit) - t(X_ref) %*% (d_ref * pi_ref)`, line 81). A user who has read the paper cannot determine which of the two approaches is implemented. The documentation says only "pseudo-likelihood logistic regression."

**Fix — add to `@details` section:**
```r
#' **Estimating equation:** `ipw()` uses the *unconditional* pseudo-likelihood
#' approach (Valliant & Dever, 2011, as described in Elliott & Valliant, 2017,
#' p. 256). NPS units enter the score equation with implicit weight 1; reference
#' units enter with their design weights `d_i`. This estimates P(NPS | in
#' population) directly, rather than P(NPS | in combined sample). The
#' alternative conditional approach — pooling both samples and treating
#' NPS membership as a binary outcome in an unweighted logistic regression —
#' is *not* used, because it does not account for reference design weights and
#' produces biased propensity estimates (Chen, Li & Wu, 2021, §2.1).
```

---

### H-2: MAR/NMAR terminology does not match the survey statistics literature

**File:** `R/nonprob-ipw.R`, lines 181–184 (first `@note` bullet)
```r
#' **Selection on observables:** IPW adjusts only for observable covariates.
#' If important predictors of NPS participation are unmeasured, the resulting
#' weights may be biased.
```

**Papers:**
- Elliott & Valliant 2017, p. 255: uses "not NMAR" framing
- Chen et al. 2021, Assumption A1: "P(I_B = 1 | X, Y) = P(I_B = 1 | X)" — "non-informative sampling assumption"
- Yang 2020, Assumption 1: "non-informative sampling assumption"
- Valliant 2020, §2.1: "units in U − s are missing at random (MAR) from the sample"

**Problem:** The causal/observational term "selection on observables" is not the terminology used in survey statistics. Users from a survey statistics background will not immediately recognize it as the MAR assumption. More importantly, the complementary case (NMAR — where participation depends on the outcome even after conditioning on X) is not named, which is what the cited papers warn against.

**Fix — replace the "Selection on observables" note bullet:**
```r
#' **Missing at random (MAR) assumption:** IPW is consistent only if NPS
#' participation is independent of the outcome variable given the observed
#' covariates in `selection` — formally, P(I_NPS = 1 | X, Y) = P(I_NPS = 1 | X).
#' This assumption is called "missing at random" (MAR) or "non-informative
#' sampling" in the survey statistics literature. It is not testable from
#' observed data. If participation depends on Y even after conditioning on X
#' (not missing at random, NMAR), IPW weights will be biased regardless of
#' model quality. Common causes of NMAR in online panels include self-selection
#' on health, income, or political engagement when those outcomes are also
#' the study variables.
```

---

### H-3: Reference sample quality requirements are not documented

**File:** `R/nonprob-ipw.R`, lines 126–134 (`@param reference` in roxygen)

**Papers:**
- Elliott & Valliant 2017, p. 200: "A probability sample used as a reference survey ideally must not be subject to coverage or other types of bias... This is an argument for using large, well-controlled samples conducted by central governments."
- Valliant 2020, §2.1.1: "The reference sample must 'represent' the full target population. Those weights should correct all nonresponse and other nonsampling error biases in the reference sample."

**Problem:** The implementation validates only that `reference` is a `survey_taylor` with positive weights — structural requirements. Nothing warns users that a poorly calibrated or high-nonresponse reference survey produces biased propensity estimates regardless of model quality. This is a failure mode every applied user faces.

**Fix — extend `@param reference` documentation:**
```r
#' @param reference A `survey_taylor` object representing the probability-based
#'   reference sample. Must have strictly positive design weights. The reference
#'   sample must itself represent the target population without material coverage
#'   or nonresponse bias — the design weights alone do not correct for an
#'   internally biased reference survey. Elliott & Valliant (2017) recommend
#'   using large, well-controlled probability surveys (e.g., government-conducted
#'   household surveys) as the reference. A biased reference will produce biased
#'   propensity estimates regardless of how well the propensity model is
#'   specified.
```

---

### H-4: Doubly robust estimation should be recommended and linked

**File:** `R/nonprob-ipw.R`, lines 200–215 (`@references` and `@return` sections)

**Papers:**
- Chen et al. 2021: primary paper contribution is DR; pure IPW is the fallback. Table 1: IPW1/IPW2 collapse under "TF" scenario.
- Yang 2020: DR is consistent if either model is correct; penalized IPW shows "largest biases except for scenario (ii)."
- Valliant 2020, conclusion: "Overall, a doubly robust estimator in combination with the jackknife variance estimator was the best combination in this study."
- Beresewicz 2025, Remark 3: QBIPW-GEE is doubly robust.

**Problem:** The `@references` block cites Chen, Li & Wu (2021) and Yang, Kim & Song (2020) — papers whose primary recommendation is to *not* rely on standalone IPW. A user reading the docs would not know the recommended next step after `ipw()`.

**Fix — add to `@details` section:**
```r
#' **Doubly robust estimation (recommended):** The papers cited in
#' `@references` unanimously recommend combining IPW weights with an outcome
#' regression model (mass imputation / prediction) to form a doubly robust
#' (DR) estimator. A DR estimator is consistent if *either* the propensity
#' model *or* the outcome regression model is correctly specified — providing
#' protection against misspecification of either. Valliant (2020) found DR
#' "was the best combination in this study in terms of bias, RMSE, and
#' confidence interval coverage." The weights returned by `ipw()` are the
#' propensity component of such a DR pipeline; the outcome regression step
#' is not yet implemented in `surveywts` but is the recommended follow-on.
```

Also add `@seealso` pointing to future DR function:
```r
#' @seealso [ipw()] for the propensity weighting step. A doubly robust
#'   estimator combining IPW with outcome regression (Chen, Li & Wu, 2021;
#'   Yang, Kim & Song, 2020) is planned for a future release.
```

---

### H-5: Jackknife preferred over bootstrap — and refit requirement must be specified

**File:** `R/nonprob-ipw.R`, lines 175–195 (`@details` section, variance bullet)

**Paper:** Valliant 2020, §2.1.4:
> "The jackknife is generally preferable for variables where point estimators are nearly unbiased since its confidence interval coverage was nearer the nominal level."
> Tables 7–8: jackknife CI coverage is closer to 95% than bootstrap WR across all scenarios.

**Problem:** The current documentation says "Bootstrap variance estimation is recommended" with no mention of the jackknife as the paper's primary recommendation. (See also C-2 above for the refit requirement.) The recommended update to the variance documentation should mention both jackknife and bootstrap as valid options, clarify that jackknife is the survey-statistics literature's primary recommendation, and state the refit requirement for both.

This fix is part of C-2 above — the extended variance documentation block should replace lines 189–191.

---

### H-6: GEE / calibrated estimating equations are absent

**File:** `R/nonprob-ipw.R` — `.fit_participation_propensity()`, lines 55–105

**Paper:** Beresewicz et al. 2025, eqs. 3.3 and 4.2:
> MLE score (implemented): `U(γ) = Σ_{k∈S_A} x_k − Σ_{k∈S_B} d_k^B π(x_k; γ) x_k = 0`
> GEE score (missing): `G(γ) = Σ_{k∈S_A} x_k / π(x_k; γ) − Σ_{k∈S_B} d_k^B x_k = 0`
> "GEE-based versions generally outperforming their MLE counterparts."

The GEE form guarantees `Σ_{k∈S_A} w_k x_k = Σ_{k∈S_B} d_k^B x_k` (weighted NPS covariate totals reproduce reference population totals). The MLE form does not guarantee this. GEE is also the building block for the doubly robust property (Beresewicz 2025, Remark 3).

**Fix — add `estimating_eq` argument and GEE path to `.fit_participation_propensity()`:**

Add to `ipw()` signature (after `epsilon`):
```r
estimating_eq = c("mle", "gee"),
```

In `.fit_participation_propensity()`, add a `estimating_eq` parameter and branch the score/Hessian:

```r
# MLE path (current):
if (estimating_eq == "mle") {
  score <- colSums(X_nps_fit) - drop(t(X_ref) %*% (d_ref * pi_ref))
  hess  <- -crossprod(X_ref, X_ref * (d_ref * pi_ref * (1 - pi_ref)))
}
# GEE path (new):
if (estimating_eq == "gee") {
  pi_nps <- link(drop(X_nps_fit %*% gamma))
  # Guard: GEE requires NPS scores > 0 (division by pi_nps)
  if (any(pi_nps <= eps)) {
    return(list(scores = pi_nps, converged = FALSE, final_delta = Inf))
  }
  score <- colSums(X_nps_fit / pi_nps) - drop(t(X_ref) %*% d_ref)
  # Jacobian of G w.r.t. gamma: -X_nps^T diag((1-pi)/pi) X_nps
  hess  <- -crossprod(X_nps_fit, X_nps_fit * ((1 - pi_nps) / pi_nps))
}
```

Note: for GEE, the saturation guard at the top of the NR loop must also check `pi_nps` (NPS scores), not just `cur_scores`. The GEE NPS-score check (preventing division by zero) replaces the current reference-side saturation check for the GEE path.

Add `estimating_eq` to the history entry so users can identify which estimating equation was used.

Add to `plans/error-messages.md`:
- `surveywts_warning_ipw_gee_nps_scores_degenerate` — GEE path: NPS scores hit float boundary

---

## MEDIUM Priority Issues

---

### M-1: Common support check is one-directional and misses numeric covariates

**File:** `R/nonprob-ipw.R`, lines 395–424 (Behavior Rule 8)

**Paper:** Valliant 2020, §2.1.2:
> "The requirement ensures that there is sufficient overlap in the characteristics of the units in the nonprobability and the reference samples so that π(i ∈ s | x_i; Φ) can be estimated for every unit in the population."

**Problem:**
1. The check only catches NPS factor/character levels absent from the reference — one direction. It does not check whether reference factor levels are absent from the NPS (reference units in covariate cells the NPS never visits will have propensity scores near 0, producing extreme reference-side score contributions with no diagnostic signal).
2. For numeric covariates, no range check is performed. An NPS unit with `age = 102` when the reference only covers ages 18–85 violates common support but passes all validation.

**Fix — add after line 424, within the Behavior Rule 8 block:**

```r
  # Behavior Rule 8b: check numeric covariate range overlap
  for (var in sel_vars) {
    nps_col <- data[[var]]
    ref_col <- reference@data[[var]]
    if (is.numeric(nps_col) && is.numeric(ref_col)) {
      nps_range <- range(nps_col, na.rm = TRUE)
      ref_range <- range(ref_col, na.rm = TRUE)
      if (nps_range[1] < ref_range[1] || nps_range[2] > ref_range[2]) {
        cli::cli_warn(
          c(
            "!" = paste0(
              "Variable {.field {var}} has a wider range in {.arg data} ",
              "([{nps_range[1]}, {nps_range[2]}]) than in {.arg reference} ",
              "([{ref_range[1]}, {ref_range[2]}])."
            ),
            "i" = paste0(
              "NPS units outside the reference covariate range violate the ",
              "common support assumption and may produce extreme propensity scores."
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

  # Behavior Rule 8c: check reference factor levels absent from NPS (reverse direction)
  for (var in sel_vars) {
    nps_col <- data[[var]]
    ref_col <- reference@data[[var]]
    if (is.character(nps_col) || is.factor(nps_col)) {
      nps_levels <- unique(as.character(nps_col[!is.na(nps_col)]))
      ref_levels <- unique(as.character(ref_col[!is.na(ref_col)]))
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
```

Add both new warning classes to `plans/error-messages.md`.

---

### M-2: probit and cloglog lack documented theoretical grounding

**File:** `R/nonprob-ipw.R`, lines 157–158 (`@param method`)
```r
#' @param method Link function for the propensity model. One of `"logit"`
#'   (default), `"probit"`, or `"cloglog"`. Partial matching is supported.
```

**Papers:**
- Chen et al. 2021, Assumption A2: consistency and asymptotic normality proven specifically for logistic regression.
- Beresewicz 2025, §3.1: "If logistic regression is assumed for π_k^A, then U(γ) is given by..." — all theoretical results are logit-specific.
- Yang 2020, Assumption 2: "the sampling mechanism follows a logistic regression model... our framework can be extended to the case of other models such as the probit model" — extension is claimed but not proven.

**Fix — update `@param method`:**
```r
#' @param method Link function for the propensity model. One of `"logit"`
#'   (default), `"probit"`, or `"cloglog"`. Partial matching is supported.
#'   Asymptotic consistency and normality proofs in the cited literature
#'   (Chen, Li & Wu, 2021; Beresewicz et al., 2025) are derived specifically
#'   for logistic regression. `"probit"` and `"cloglog"` are available as
#'   practical alternatives but have weaker formal backing in the
#'   pseudo-likelihood framework for non-probability samples.
```

---

### M-3: `missing_method = "separate"` lacks theoretical grounding

**File:** `R/nonprob-ipw.R`, lines 137–145 (`@param missing_method`)

**Papers:** None of the six papers address missing NPS covariates. The entire framework assumes complete covariate observations in both samples.

**Problem:** The `"separate"` strategy — fit the NR on complete-case NPS rows (`X_nps_fit`), predict for all NPS rows using the fitted gamma with `"(Missing)"` recoded to the reference baseline — is an ad hoc adaptation. The score equation `colSums(X_nps_fit)` then represents only the `n_complete` complete-case NPS rows, not all `n_NPS` rows, meaning the estimating equations are no longer centered correctly for the full NPS. This is not derived from any of the six referenced papers and has no published theoretical validation.

**Fix — add caveat to `@param missing_method`:**
```r
#'     \item{`"separate"`}{... **Caveat:** The pseudo-likelihood score
#'       equation is fit on complete-case NPS rows only (rows without `"(Missing)"`
#'       values), and propensity scores are predicted for all rows by substituting
#'       `"(Missing)"` with the reference baseline level. This adaptation is
#'       not derived from the pseudo-likelihood framework and has no published
#'       theoretical validation. Use `"impute"` for a more principled approach
#'       to missing data.}
```

---

### M-4: NPS fraction of population is never checked

**File:** `R/nonprob-ipw.R` — gap between reference NA handling (line 454) and NPS NA handling (line 457)

**Papers:**
- Yang 2020, §2.3.1: "The resulting estimator hat_alpha is valid if n_B is relatively small (Valliant and Dever, 2011)."
- Valliant 2020: the Eq. (1) adjustment (see C-3) quantifies what "non-negligible" means.

**Problem:** When `nrow(data) / sum(ref_weights)` is large, the pseudo-likelihood is misspecified. This is addressed in C-3 (automatic weight adjustment), but even with `adjust_reference = FALSE` the fraction should be reported so the user is aware of the regime they are operating in.

**Fix:** Emit a warning when `nps_fraction > 0.05` and `adjust_reference = FALSE` (already covered in C-3). The `history_entry` should also record `nps_fraction` for diagnostic purposes:
```r
# In the history entry (around line 735):
nps_fraction = nrow(data) / sum(ref_weights_for_fit),
```

---

### M-5: Independence of participation assumption (A3) is undocumented

**File:** `R/nonprob-ipw.R`, lines 181–200 (`@note` section)

**Papers:**
- Chen et al. 2021, Assumption A3: "R_i and R_j are independent given x_i and x_j."
- Beresewicz 2025, Assumption A3: same.

**Problem:** The pseudo-likelihood assumes NPS participation decisions are independent across units. This fails when NPS units are clustered: household panels (all members of a household participate together), snowball-sampled networks, or employer-provided survey panels where a single recruiter controls many respondents. No documentation or warning exists for this case.

**Fix — add to `@note` section:**
```r
#' **Independence of participation:** The pseudo-likelihood assumes that NPS
#' participation decisions are independent across units given the covariates
#' in `selection` (Chen, Li & Wu, 2021, Assumption A3). This assumption fails
#' when NPS units are clustered — for example, household panels where multiple
#' family members participate together, or snowball-recruited samples. In
#' clustered NPS settings the propensity model should include cluster-level
#' covariates, and variance estimation should use cluster-aware resampling.
```

---

### M-6: Model diagnostics recommended by Yang et al. (2018) are absent

**File:** `R/nonprob-ipw.R` — no diagnostic output is returned

**Paper:** Yang et al. 2018, §2.4: "The final model is validated through cross validation and by examining model diagnostic statistics."

**Problem:** No fitted propensity scores (beyond the final weights), model fit statistics (AUC/C-statistic), or cross-validation output are accessible to the user. The function returns only the `survey_nonprob` object; there is no way to inspect propensity model quality.

**Fix:** Return the fitted propensity scores in the history entry so users can compute diagnostics:
```r
# In the history entry (around line 735), add:
propensity_scores = scores,
```

This allows downstream code (and the future `diagnose_propensity()`) to compute:
- AUC / C-statistic for propensity model discrimination
- Calibration plots (predicted vs. observed participation rates by decile)
- Standardized mean differences before and after weighting (covariate balance)

The `diagnose_propensity()` function planned for the Diagnostics phase is the appropriate home for the full implementation.

---

## LOW Priority / Scope Documentation

---

### L-1: LASSO / BART / super learner not mentioned for high-dimensional selection

**File:** `R/nonprob-ipw.R`, lines 120–126 (`@param selection` / `@param predictors`)

**Paper:** Elliott & Valliant 2017, p. 255:
> "P̂(Z_i = z | x_i) can be obtained via logistic regression, or, to reduce model misspecification if x_i is of high dimensionality, via LASSO, BART, or super learner algorithms."

**Fix — add caveat to `@param selection` or `@details`:**
```r
#' For high-dimensional covariate vectors (many predictors relative to sample
#' size), Elliott & Valliant (2017) recommend regularized alternatives such as
#' LASSO-penalized logistic regression, BART, or super learner. `ipw()` uses
#' Newton-Raphson on the full unpenalized model and may overfit in
#' high-dimensional settings. In such cases, fit the propensity model
#' externally, extract the predicted probabilities, and use them directly.
```

---

### L-2: QBIPW workaround via manual quantile dummies not suggested

**File:** `R/nonprob-ipw.R` — `@details` section

**Paper:** Beresewicz 2025, Remark 2:
> "The use of a_k in (4.2) is related to the use of piecewise (constant) regression where variables x_k are split into breaks (e.g. by quartiles or deciles)."

**Problem:** QBIPW is not implemented, but users can approximate it by manually adding quantile-binned indicator variables to the `selection` formula. This workaround is not documented.

**Fix — add to `@details`:**
```r
#' **Quantile balancing approximation:** Beresewicz et al. (2025) show that
#' augmenting the propensity model with quantile-indicator variables for
#' continuous covariates ("quantile balancing IPW") substantially reduces
#' bias under nonlinear selection. Users can approximate this by adding
#' cut-point indicators to `selection`:
#' ```r
#' nps$age_q <- cut(nps$age, quantile(nps$age, c(0, .25, .5, .75, 1)),
#'                  include.lowest = TRUE)
#' ipw(nps, ref, selection = ~age_q + sex)
#' ```
#' Native QBIPW support (the GEE estimating equations with quantile constraints
#' per Beresewicz et al.) is planned for a future release.
```

---

### L-3: Measurement equivalence of covariates not documented

**File:** `R/nonprob-ipw.R`, lines 130–134 (`@param reference`)

**Paper:** Valliant 2020, §2.1.3:
> "Another important requirement is that the reference survey and the nonprobability sample both collect the same set of covariates." (Same question wording, same categories, same measurement period.)

**Fix — add to `@param reference` or `@note`:**
```r
#' **Covariate measurement equivalence:** Propensity estimation requires that
#' shared covariates are measured identically in `data` and `reference` —
#' same question wording, same response categories, and compatible measurement
#' periods (Valliant, 2020). Category recoding differences (e.g., age reported
#' in years vs. age groups) or response option differences (e.g., 4-point vs.
#' 5-point education scales) will produce spurious covariate imbalance that
#' the propensity model cannot correct.
```

---

### L-4: Known population size N not supported

**File:** `R/nonprob-ipw.R` — function signature

**Paper:** Yang 2020, §2.1: "N is known" — all estimators use N in the denominator. Yang's `hat_mu_IPW1 = (1/N) Σ y_i/π̂_i` requires the population count.

**Problem:** When N is known from a census frame, users cannot supply it. The function always uses `sum(w)` as an estimate of N, which introduces additional variance. For IPW1-style estimation where N is externally known, this is unnecessary.

**Fix — add optional argument to `ipw()`:**
```r
# In function signature:
population_size = NULL,

# In history entry:
population_size_known = !is.null(population_size),
estimated_population_size = if (!is.null(population_size)) population_size
                            else sum(w_before_trim),
```

If `population_size` is supplied, validate it is a positive scalar and record it in the history. Downstream analysis can use it to implement exact IPW1/HT estimation.

---

## Error / Warning Class Additions Required

Add all new classes to `plans/error-messages.md`:

| Class | Type | Trigger |
|---|---|---|
| `surveywts_warning_ipw_reference_weight_adjusted` | warning | NPS fraction > 5%; Valliant eq. (1) applied |
| `surveywts_warning_ipw_reference_unadjusted_large_nps` | warning | NPS fraction > 5% and `adjust_reference = FALSE` |
| `surveywts_warning_ipw_covariate_range_extrapolation` | warning | NPS numeric covariate outside reference range |
| `surveywts_warning_ipw_reference_levels_absent_from_nps` | warning | Reference factor level not present in NPS |
| `surveywts_warning_ipw_gee_nps_scores_degenerate` | warning | GEE path: NPS scores hit float boundary |

---

## New Argument Summary

Arguments added by the above fixes:

| Argument | Default | Fix | Paper |
|---|---|---|---|
| `adjust_reference` | `TRUE` | C-3 | Valliant 2020, eq. (1) |
| `estimating_eq` | `"mle"` | H-6 | Beresewicz 2025, eqs. 3.3/4.2 |
| `population_size` | `NULL` | L-4 | Yang 2020 |

---

## Implementation Priority Order

1. **C-1** — one-line fix, highest visibility
2. **C-4** — documentation only, highest user impact
3. **C-2 + H-5** — combined variance documentation rewrite
4. **C-3** — new argument + runtime check; correctness impact
5. **H-6** — new `estimating_eq = "gee"` path; largest implementation
6. **H-1, H-2, H-3, H-4** — documentation only, high-value
7. **M-1** — new common support warnings; medium effort
8. **M-4, M-5, M-6** — small additions to history entry and docs
9. **M-2, M-3** — parameter documentation updates
10. **L-1, L-2, L-3, L-4** — low-effort documentation polish
