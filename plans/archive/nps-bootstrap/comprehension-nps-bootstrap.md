# Comprehension — nps-bootstrap

## Problem

Non-probability samples (NPS) lack defined inclusion probabilities, so standard
design-based variance estimation is unavailable. The quasi-randomization
bootstrap solves this by using a logistic propensity model — fit on the stacked
NPS plus a reference probability sample — to estimate pseudo-inclusion
probabilities for each NPS unit, and then bootstrapping the entire
propensity-estimation-and-weighting pipeline in each draw. In each replicate,
the NPS is resampled with replacement (SRSWR), propensity scores are
re-estimated on the resampled data (and on a possibly resampled reference, if
Level B), and any downstream calibration (raking) is also re-run so that all
sources of variability are propagated through to the final replicate weight.
The resulting replicate weight columns can then be used to form a variance
estimate around any point estimator of interest. This approach is needed
because NPS data have no fixed sampling design from which to derive analytical
variance formulas, and linearization methods are infeasible without
stratum/cluster identifiers.

---

## Formulas

### Quasi-randomization pseudo-weight

**Combined-sample logistic regression approach (Elliott & Valliant 2017,
Eqs. 3–6; AAPOR 2022, §3):**

$$w_i \propto \frac{1}{\hat{P}(S_i^* = 1 \mid \mathbf{x}_i)} \propto \frac{\hat{P}(Z_i = 0 \mid \mathbf{x}_i)}{\hat{P}(Z_i = 1 \mid \mathbf{x}_i)}$$

When the probability-sample design weights align with covariates (Eq. 6):

$$w_i \propto \tilde{w}_i \cdot \frac{\hat{P}(Z_i = 0 \mid \mathbf{x}_i)}{\hat{P}(Z_i = 1 \mid \mathbf{x}_i)}$$

where $\hat{P}(Z_i = 1 \mid \mathbf{x}_i)$ is the fitted value from a logistic
regression of the combined-sample indicator $Z$ on shared covariates
$\mathbf{x}$.

> **Conflict note:** AAPOR (Formula 2 note) states $w_i = \hat{p}_i /
> (1 - \hat{p}_i)$ where $\hat{p}_i = P(\text{NPS membership})$, which would
> give *higher* weights to units that look more like NPS members — the opposite
> of the correct IPW direction. Elliott & Valliant Eqs. (3)–(6) correctly
> express the weight as the odds of *reference-sample* membership. The E&V
> formula is the theoretically grounded one; `ipw()` follows it. The AAPOR
> formula appears to be a notational ambiguity or extraction artifact.

| Symbol | Meaning | Bound to |
|--------|---------|----------|
| $w_i$ | Pseudo-weight (IPW weight) for NPS unit $i$ | `@data[[data@variables$weights]]` after `ipw()` |
| $S_i^*$ | Indicator: unit $i$ is in the NPS | NPS membership (rows in `data@data`) |
| $Z_i$ | Combined-sample indicator: 1 = NPS, 0 = reference sample | response variable in pooled logistic model inside `ipw()` |
| $\mathbf{x}_i$ | Shared auxiliary covariates | RHS of `selection` formula argument to `ipw()` |
| $\hat{P}(Z_i = 1 \mid \mathbf{x}_i)$ | Fitted propensity (prob. of NPS membership) | internal fitted value in `ipw()` |
| $\tilde{w}_i$ | Design weight for reference-sample unit | `weights(ref_design)` |

---

### Bootstrap variance estimator

**MSE formulation (spec §IV, `mse = TRUE` default):**

$$\hat{V}(\hat{\theta}) = \frac{1}{B} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \hat{\theta}\right)^2$$

**Uncentered formulation (spec `mse = FALSE`):**

$$\hat{V}(\hat{\theta}) = \frac{1}{B-1} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \bar{\theta}^{(B)}\right)^2$$

where $\bar{\theta}^{(B)} = \frac{1}{B} \sum_{b=1}^{B} \hat{\theta}^{(b)}$.

> **Conflict note:** Chrostowski (2025) Eq. 5 uses $\frac{1}{B-1}$ and centers
> on $\hat{\mu}_y$ (the original point estimate). The spec uses $\frac{1}{B}$
> for the MSE form. These differ by $(B-1)/B$. The spec's design choice is
> consistent with standard replicate-weight variance practice. See Conflicts.

| Symbol | Meaning | Bound to |
|--------|---------|----------|
| $\hat{V}(\hat{\theta})$ | Bootstrap variance estimate | computed from stored `repwt_1`…`repwt_B` columns |
| $B$ | Number of successful bootstrap draws | `draws_used` in history entry |
| $\hat{\theta}^{(b)}$ | Estimator value in draw $b$ | user applies their estimator to the $b$-th replicate weight column |
| $\hat{\theta}$ | Full-sample point estimate | computed from `data@data[[data@variables$weights]]` |
| $\bar{\theta}^{(B)}$ | Mean of bootstrap estimates | used only when `mse = FALSE` |

---

### Raking update (within each replicate)

**Inner-cycle multiplicative update (Kolenikov 2014, Formula 8):**

$$w_j^{(k,v)} = w_j^{(k,v-1)} \cdot \frac{T(X_v, C_{v,k})}{\displaystyle\sum_{j' \in C_{v,k} \cap S^{(b)}} w_{j'}^{(k,v-1)}}$$

**Level B — perturbed calibration targets from reference resample:**

For proportional margins:
$$t_{j,c}^{(b)} = \frac{\displaystyle\sum_{k \in S_B^{(b)},\, x_{j,k}=c} w_k^B}{\displaystyle\sum_{k \in S_B^{(b)}} w_k^B}$$

For count margins:
$$t_{j,c}^{(b)} = \sum_{k \in S_B^{(b)},\, x_{j,k}=c} w_k^B$$

| Symbol | Meaning | Bound to |
|--------|---------|----------|
| $w_j^{(k,v)}$ | Weight of NPS unit $j$ after outer iteration $k$, inner step $v$ | intermediate weight inside `rake()` per draw |
| $T(X_v, C_{v,k})$ | Target total for level $k$ of margin $v$ | Level A: fixed from `calib_entry$margins`; Level B: perturbed per-draw |
| $S^{(b)}$ | Resampled NPS in draw $b$ | `n_A` rows with replacement from `data@data` |
| $S_B^{(b)}$ | $b$-th reference bootstrap replicate | pre-computed via `svrep::as_bootstrap_design()` |
| $w_k^B$ | Reference replicate weight for unit $k$ | replicate weight vector from `svrep` output |
| $t_{j,c}^{(b)}$ | Perturbed target for margin $j$, level $c$, draw $b$ | passed as `margins` to in-loop `rake()` |

---

## Gotchas

- **Pseudo-weights must be recomputed in every bootstrap draw** (Elliott &
  Valliant §3.1; AAPOR §4) — fixed pseudo-weights across replicates
  understates variance by ignoring variability in propensity estimation. E&V
  describe this as the most commonly violated rule in naive implementations.
  The spec mandates re-running `ipw()` inside each draw. **Multiple papers
  flag this independently.**

- **SRS bootstrap understates variance for NPS** (AAPOR §4; Chrostowski §2.2)
  — because SRSWR cannot replicate the actual (unknown) NPS recruitment
  mechanism, resulting confidence intervals are systematically too narrow.
  AAPOR calls this "likely impossible to avoid" and labels SRSWR the accepted
  practical approximation. **Document as a known limitation in the man page.**

- **All weighting steps must be re-run on each subsample** (AAPOR §4;
  Kolenikov §4.6) — if raking follows IPW in the weighting history, the rake
  must be re-executed inside each draw using within-draw IPW weights, not
  applied once to the final weight column. **Two papers flag independently.**

- **Starting weights for within-draw raking must be pre-IPW base weights, not
  the full-sample calibrated weight** (Kolenikov §4.6 caution) — using the
  full-sample calibrated IPW weight column as the base for within-draw raking
  produces biased variance estimates. The spec's construction using original
  base weights is correct.

- **Near-zero propensities produce extreme pseudo-weights** (Elliott &
  Valliant; AAPOR) — NPS units with $\hat{P}(Z_i = 1 \mid \mathbf{x}_i)
  \approx 1$ get weights tending to infinity, causing degenerate weight
  distributions and potential model failure within draws. The spec's `trim`
  argument to `ipw()` (read from history) handles this.

- **Common support failure within a resampled draw** (Elliott & Valliant) —
  a covariate combination present in the full NPS may vanish from a
  resampled draw, causing the propensity model to extrapolate. This is a
  draw-level failure handled by the spec's `failed_draws` counter.

- **Zero observations in calibration cells within resampled draws** (Kolenikov)
  — SRSWR can produce zero observations in rare covariate combinations,
  causing raking's denominator to be zero. The spec catches this as a draw
  failure.

- **Weight convergence and target convergence are separate checks in raking**
  (Kolenikov §4 explicit) — the raking algorithm may converge in the
  weight-change sense while calibration constraints remain unmet, especially
  with trimming active. The spec delegates to `rake()` which carries this
  dual-check logic.

- **Level B reference resampling requires independent NPS and reference RNG
  sequences** (spec §IV Level B; AAPOR implicit) — a single RNG stream
  driving both resamples introduces within-draw correlation. The spec correctly
  pre-computes all reference replicates before the main loop.

- **Input weights to `svrep::as_bootstrap_design()` must be probability
  (Taylor-series) weights, not calibrated weights** (Kolenikov §4.6) —
  enforced in the spec by the `reference_sample` must-be-`survey_taylor`
  validation.

- **Bootstrap SE does not capture model misspecification bias** (AAPOR §4;
  Elliott & Valliant) — the bootstrap quantifies sampling variability around
  the propensity-weighted estimate. If the propensity model is misspecified,
  the point estimate is biased and the SE does not reflect that bias. Structural
  limitation; document clearly.

- **No deduplication between NPS and reference** (Chrostowski explicit) —
  estimators assume no unit appears in both. The spec makes no deduplication
  check; user must ensure this precondition.

- **Platform inconsistency for MI-NN / MI-PMM** (Chrostowski) — tied distances
  in nearest-neighbor matching produce platform-dependent results. This applies
  to the hybrid path (deferred), not the quasi-randomization path; flagged for
  future reference.

---

## Reference mapping

- Elliott & Valliant §3.1, Eqs. (3)–(6) → Pseudo-weight formula;
  `ipw()` is the implementation in the weighting history
- Elliott & Valliant §3.1, variance paragraph → Mandate to recompute
  pseudo-weights per replicate → spec §IV Level A step 2 / Level B step 3
- Elliott & Valliant §3.1 → Subject-level SRSWR resampling for NPS →
  spec §IV Level A/B step 1
- Kolenikov §4.6 → Replicate-weight calibration: start from probability
  replicate weights, re-rake each replicate independently → spec §IV
  Level B step 2 and Level A/B step 3
- Kolenikov §4.6 caution → Base weight for within-draw raking must be
  pre-IPW weights, not calibrated weights → spec §IV construction of `S_A_b`
- Kolenikov Formula 8 → Inner-cycle multiplicative raking update used by
  `rake()` inside each draw
- Chrostowski §2.2, Eq. 5 → Bootstrap variance formula (divisor conflict
  documented in Conflicts section)
- Chrostowski §2.2 → NPS resampling is SRSWR → spec §IV Level A/B step 1
- AAPOR §4 → All weighting steps must be re-run per replicate → spec §IV
  history replay structure
- AAPOR §4 → SRS bootstrap understates NPS variance → documentation
  requirement for `create_bootstrap_weights()` man page
- AAPOR §3 → Propensity from stacking NPS + reference, logistic regression
  on selection indicator → `ipw()` implementation already in place

---

## Assumptions

- **MAR selection given covariates** — NPS inclusion is conditionally
  independent of the outcome given observed covariates. Central identifying
  assumption of all four papers. Cannot be tested from data; must be
  documented.

- **Small sampling fractions** (Elliott & Valliant, explicit) — the Bayes-rule
  derivation of pseudo-weights requires both NPS and reference to be small
  fractions of the population. The spec does not validate this; it is a
  user-side precondition.

- **Common support / positivity** (all four sources) — every covariate
  combination in the NPS must appear in the reference sample. Violation
  produces undefined or extreme pseudo-weights. The spec relies on `ipw()`
  error handling and the draw-failure mechanism.

- **Reference sample is approximately unbiased** (Elliott & Valliant; AAPOR)
  — treated as a near-probability sample. If the reference has systematic
  nonresponse bias, pseudo-weights inherit it. No validation check in spec.

- **Correctly specified propensity model** (all four sources) — logistic
  model must correctly capture NPS inclusion mechanism. Misspecification
  produces biased pseudo-weights in every draw; bootstrap SE around a biased
  estimate is not a valid confidence interval.

- **No overlap between NPS and reference** (Chrostowski, explicit) — no unit
  in both samples. No deduplication in spec; user precondition.

- **No clustering in NPS selection** (Chrostowski) — conditional independence
  of NPS selection given covariates. Violated for panel-recruited NPS data;
  SRSWR bootstrap ignores cluster structure and understates variance further.

- **Taylor-series input to `svrep::as_bootstrap_design()`** (Kolenikov §4.6)
  — enforced by spec's `reference_sample` must-be-`survey_taylor` rule.

- **Calibration targets are consistent across margins** (Kolenikov) — all
  raking margins must sum to the same population total. Inconsistent targets
  produce draw failures. The spec relies on existing `rake()` validation,
  not a pre-loop check.

---

## Conflicts across sources

- **Variance formula divisor ($B$ vs. $B-1$)** — Chrostowski (2025) Eq. 5
  uses $\frac{1}{B-1}$ centered on $\hat{\mu}_y$. The spec uses $\frac{1}{B}$
  for the MSE form and $\frac{1}{B-1}$ for the uncentered form. These agree on
  which formula centers on the original estimate but disagree on the divisor.
  **Resolved in the spec** by a deliberate design choice consistent with
  standard replicate-weight variance practice; the `mse` argument controls
  which form is used.

- **Pseudo-weight direction (AAPOR vs. Elliott & Valliant)** — AAPOR Formula
  2 note writes $w_i = \hat{p}_i / (1 - \hat{p}_i)$ where $\hat{p}_i$ is the
  NPS propensity, which gives *higher* weights to NPS-looking units — opposite
  of the correct IPW direction. Elliott & Valliant correctly express the weight
  as the odds of reference-sample membership. The E&V formula is theoretically
  grounded. **Unresolved** at the literature level; the `ipw()` implementation
  follows E&V.

- **Fixed vs. perturbed calibration targets** — Kolenikov §4.6 supports
  Level A (fixed targets, re-rake per replicate) as a valid approach. AAPOR
  §4's recommendation to re-run weighting "as though independently selected"
  implies targets should also be perturbed (closer to Level B). **Partially
  resolved** by the spec's dual-level design; Level A is the default when
  `targets_from_reference = FALSE`.

- **Theoretical guarantee for quasi-randomization bootstrap** — Elliott &
  Valliant explicitly state that "finite population, model-based theory has
  not been worked out for the bootstrap" in the superpopulation path. The
  spec's quasi-randomization approach straddles design-based and model-based
  paths. **Unresolved** theoretical gap acknowledged by E&V; the bootstrap
  is the accepted practical approach despite incomplete theory.

---

## Citations

### Kolenikov (2014)
Authors: Kolenikov, S.
Year: 2014
Title: Calibrating survey data using iterative proportional fitting (raking)
Journal/Venue: The Stata Journal
Volume/Issue/Pages: 14, Number 1, pp. 22–59
DOI/URL: [NOT FOUND]

### Chrostowski et al. (2025)
Authors: Chrostowski, Ł.; Chlebicki, P.; Beręsewicz, M.
Year: 2025
Title: nonprobsvy — An R package for modern methods for non-probability surveys
Journal/Venue: [NOT FOUND — likely Journal of Statistical Software by format; not confirmed in document]
Volume/Issue/Pages: [NOT FOUND]
DOI/URL: https://github.com/ncn-foreigners/nonprobsvy (package version 0.2.3)

### Elliott & Valliant (2017)
Authors: Elliott, M.R.; Valliant, R.
Year: 2017
Title: Inference for Nonprobability Samples
Journal/Venue: Statistical Science
Volume/Issue/Pages: Vol. 32, No. 2, pp. 249–264
DOI/URL: 10.1214/16-STS598

### AAPOR (2022)
Authors: McPhee, C. (Chair); Barlas, F.; Brigham, N.; Darling, J.; Dutwin, D.; Jackson, C.; Jackson, M.; Kirzinger, A.; Little, R.; Lorenz, E.; Marlar, J.; Mercer, A.; Scanlon, P.J.; Weiss, S.; Wronski, L.
Year: 2022
Title: Data Quality Metrics for Online Samples: Considerations for Study Design and Analysis
Journal/Venue: American Association for Public Opinion Research (AAPOR) Task Force Report
Volume/Issue/Pages: [NOT FOUND]
DOI/URL: [NOT FOUND]
