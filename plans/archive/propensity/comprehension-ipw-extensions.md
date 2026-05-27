# Comprehension — ipw-extensions

## Problem

`ipw()` implements pseudo-likelihood logistic regression to estimate the probability that a
unit belongs to the non-probability sample (NPS) rather than the reference probability sample,
and then assigns each NPS unit an inverse of that probability as its analysis weight. Six papers
audited the implementation and found gaps at four severity levels. The core statistical challenge
is that NPS participation probabilities are unknown — they must be estimated via a reference
sample — and any bias in that estimation propagates directly into the final weights. The gaps
span: a mislabeled estimator type, absent variance documentation, a missing reference weight
correction for large NPS fractions, an undocumented alternative estimating equation (GEE) that
provides covariate balance guarantees the current MLE path lacks, incomplete common support
checks, and a constellation of documentation omissions about model assumptions, limitations,
and recommended follow-on analysis.

---

## Formulas

### 1. Full log-likelihood (infeasible — requires population x_i)

$$
\ell(\boldsymbol{\gamma}) = \sum_{k \in S_A} \log\!\left(\frac{\pi_k^A}{1-\pi_k^A}\right) + \sum_{k \in U} \log(1 - \pi_k^A)
$$

### 2. Pseudo-likelihood (feasible — replaces population sum with weighted reference sum)

$$
\ell^*(\boldsymbol{\gamma}) = \sum_{k \in S_A} \log\!\left(\frac{\pi_k^A}{1-\pi_k^A}\right) + \sum_{k \in S_B} d_k^B \log(1 - \pi_k^A)
$$

Source: Chen (2021) eq. 3.2; Beresewicz (2025) unnumbered above eq. 3.1.

### 3. MLE score equation (current implementation — verified)

$$
\mathbf{U}(\boldsymbol{\gamma}) = \sum_{k \in S_A} \mathbf{x}_k \;-\; \sum_{k \in S_B} d_k^B \, \pi(\mathbf{x}_k;\boldsymbol{\gamma}) \, \mathbf{x}_k = \mathbf{0}
$$

Source: Chen (2021) score equations below eq. 3.2; Beresewicz (2025) eq. 3.1.
Code: `colSums(X_nps_fit) - drop(t(X_ref) %*% (d_ref * pi_ref))` — exact match.

### 4. MLE Hessian (current implementation — verified)

$$
\mathbf{H}(\boldsymbol{\gamma}) = -\sum_{k \in S_B} d_k^B \, \pi_k^B(\boldsymbol{\gamma})(1-\pi_k^B(\boldsymbol{\gamma})) \, \mathbf{x}_k \mathbf{x}_k^T
$$

Code: `-crossprod(X_ref, X_ref * (d_ref * pi_ref * (1 - pi_ref)))` — exact match.

### 5. GEE calibration score equation (NEW — H-6)

When $\mathbf{h}(\mathbf{x}_k; \boldsymbol{\gamma}) = \mathbf{x}_k / \pi(\mathbf{x}_k; \boldsymbol{\gamma})$, the generalized estimating equations become:

$$
\mathbf{G}(\boldsymbol{\gamma}) = \sum_{k \in S_A} \frac{\mathbf{x}_k}{\pi(\mathbf{x}_k;\boldsymbol{\gamma})} \;-\; \sum_{k \in S_B} d_k^B \, \mathbf{x}_k = \mathbf{0}
$$

Source: Beresewicz (2025) eq. 3.3; derivable from eq. 3.2 with the stated h choice.

**Covariate balance guarantee:** At the GEE solution $\hat{\boldsymbol{\gamma}}$, the weighted NPS covariate
totals exactly reproduce the reference-weighted totals:
$\sum_{k \in S_A} \hat{w}_k \mathbf{x}_k = \sum_{k \in S_B} d_k^B \mathbf{x}_k$.
The MLE path does NOT guarantee this (Beresewicz 2025, note after eq. 3.1).

### 6. GEE Jacobian (Hessian of G, NPS-side)

Differentiating $\mathbf{G}(\boldsymbol{\gamma})$ with respect to $\boldsymbol{\gamma}$ under logistic $\pi$:

$$
\mathbf{J}(\boldsymbol{\gamma}) = \frac{\partial \mathbf{G}}{\partial \boldsymbol{\gamma}} = -\sum_{k \in S_A} \mathbf{x}_k \mathbf{x}_k^T \cdot \frac{1 - \pi(\mathbf{x}_k;\boldsymbol{\gamma})}{\pi(\mathbf{x}_k;\boldsymbol{\gamma})}
$$

Code sketch: `-crossprod(X_nps_fit, X_nps_fit * ((1 - pi_nps) / pi_nps))`.

**Critical difference from MLE Hessian:** MLE Hessian is reference-side (sum over $S_B$);
GEE Jacobian is NPS-side (sum over $S_A$). Singularity conditions and numerical behavior differ.

### 7. IPW1 vs. IPW2 (Hájek) — C-1 clarification

$$
\hat{\mu}_\text{IPW1} = \frac{1}{N} \sum_{k \in S_A} \frac{y_k}{\hat{\pi}_k^A} \qquad \text{(requires known } N\text{)}
$$

$$
\hat{\mu}_\text{IPW2} = \frac{1}{\hat{N}_A} \sum_{k \in S_A} \frac{y_k}{\hat{\pi}_k^A}, \quad \hat{N}_A = \sum_{k \in S_A} \frac{1}{\hat{\pi}_k^A}
$$

Source: Chen (2021) eq. 3.3; Beresewicz (2025) eq. 3.4.

The current code sets `estimated_population_size = sum(w_before_trim)` = $\hat{N}_A$ (sum of
inverse propensity scores). When `svymean()` is applied to the `survey_nonprob` output, it
computes $\hat{N}_A^{-1} \sum w_k y_k$ — this is IPW2/Hájek behavior. The history entry
labels this `"ht"`, which is wrong. The label should be `"ipw2"`.

Chen (2021), Table 1: IPW2 has smaller MSE than IPW1 across all scenarios — IPW2 is preferred.

### 8. Valliant (2020) Eq. (1) — reference weight adjustment (C-3)

$$
w_i^* = w_i \cdot \frac{\hat{N} - n_\text{NPS}}{\hat{N}}
$$

where $\hat{N} = \sum_{s_\text{ref}} w_i$ (sum of reference design weights before adjustment)
and $n_\text{NPS}$ = `nrow(data)`.

**Mechanical explanation:** The pseudo-likelihood treats the reference as if it represents
$\hat{N}$ population units. But the NPS $n_\text{NPS}$ units are already being counted on the
NPS side of the score equation — so counting them again in $\hat{N}$ inflates the reference-side
denominator. The adjustment reduces reference weights so the combined weighted sample correctly
sums to $\hat{N}$.

**Threshold:** Valliant (2020) states the adjustment is unnecessary "if $n$ is a small fraction
of $\hat{N}$." The paper does not quantify "small." The gaps document adopts **5%** as an
operational threshold. This is a reasonable engineering choice but is not paper-derived.

### Symbol binding table

| Symbol | Meaning | Bound to |
|--------|---------|----------|
| $\mathbf{x}_k$ | covariate vector for unit $k$ | row of `model.matrix(selection, ...)` |
| $d_k^B$ | reference design weight | `ref_weights_for_fit[k]` |
| $\pi(\mathbf{x}_k; \boldsymbol{\gamma})$ | propensity score | `link(X %*% gamma)` |
| $n_\text{NPS}$ | NPS sample size | `nrow(data)` |
| $\hat{N}$ | estimated population size | `sum(ref_weights_for_fit)` |
| $\hat{N}_A$ | estimated population size from NPS | `sum(w_before_trim)` |
| $\hat{w}_k$ | IPW weight | `1 / hat_pi_k` |
| $\boldsymbol{\gamma}$ | propensity model parameter | `gamma` in `.fit_participation_propensity()` |
| $\mathbf{H}$ | Newton-Raphson Hessian (MLE path) | `hess` in NR loop |
| $\mathbf{J}$ | GEE Jacobian | `hess` in GEE path (same variable, different formula) |
| $S_A$ | non-probability sample | rows of `data` after NA handling |
| $S_B$ | reference probability sample | rows of `ref_data_for_fit` |
| $\pi_k^A$ | true NPS participation probability | estimated as $\pi(\mathbf{x}_k; \hat{\boldsymbol{\gamma}})$ |

---

## Gotchas

### MLE path (current)

- **NPS score saturation** (current guard at line 72): R's `binomial()$linkinv` caps at
  `1 - .Machine$double.eps` rather than exactly 1. Scores at this boundary indicate NR
  divergence. Current guard checks `cur_scores` (NPS predictions on ALL rows) — correct.
- **Hessian singularity**: occurs when covariates are collinear or when a factor level is
  constant in the reference. Current code catches this with `tryCatch(solve(hess, score), ...)`.
- **Non-convergence**: `maxit` exhausted without `max(abs(delta)) < epsilon`. Currently emits
  `surveywts_warning_propensity_nr_no_convergence`. Scores from last iteration are returned.

### GEE path (NEW — must implement)

- **Division by zero (NPS-side)**: The GEE score computes `x_k / π_k^A`. If any NPS score
  → 0, this blows up. The existing saturation guard checks `cur_scores <= eps` — this is
  exactly the right check, but it uses NPS prediction scores (`X_nps_pred %*% gamma`). For
  GEE, the scores used in the Jacobian are `X_nps_fit %*% gamma` (complete-case only).
  The guard must therefore check `pi_nps` (scores on `X_nps_fit`) before computing GEE
  score/Jacobian, not just the prediction matrix. The check `pi_nps <= eps` is the correct
  guard; returning `converged = FALSE` allows `ipw()` to throw
  `surveywts_error_propensity_scores_degenerate` consistently.
- **GEE Jacobian does NOT involve reference**: Unlike MLE, the GEE Jacobian sums over NPS
  units. This means it can be singular if NPS covariate design matrix is rank-deficient (e.g.,
  perfect collinearity among covariates in the NPS). The existing Hessian singularity check
  still applies.
- **GEE with `missing_method = "separate"`**: GEE score sums over `X_nps_fit` (complete-case
  NPS rows). This means the calibration guarantee `Σ w_k x_k = Σ d_k^B x_k` applies only to
  the complete-case NPS subpopulation, not all NPS rows. This is the same fundamental
  limitation documented in M-3 for the `"separate"` method. This interaction should be
  documented; the GEE path is still valid but the calibration guarantee is partial.
- **GEE convergence is often faster than MLE** in empirical experience (Beresewicz 2025
  simulation results show GEE achieving lower SE than MLE). However, the Jacobian is
  NPS-side, making its condition number sensitive to NPS covariate spread, not reference spread.

### Reference weight adjustment (C-3)

- **Order of operations matters**: The adjustment must happen AFTER reference NA listwise
  deletion (which changes the reference size) but BEFORE the NR fit. If applied before
  deletion, `sum(ref_weights_for_fit)` is inflated by the about-to-be-excluded rows.
- **`n_hat` changes when `nps_fraction` is computed**: The corrected reference weights sum to
  `n_hat - nrow(data)`, not `n_hat`. The history entry should record the pre-adjustment `n_hat`
  and the `nps_fraction` so users can verify.
- **`adjust_reference = FALSE` + `nps_fraction > 0.05`**: Both warnings in the gaps document
  (adjustment applied vs. adjustment skipped) must be distinct warning classes.

### Common support (M-1)

- **Reverse direction (reference levels absent from NPS)**: Reference units with covariate levels
  absent from the NPS have propensity scores near 0. Their term in the MLE score equation
  `Σ d_k^B π(x_k) x_k` is effectively 0 for those levels — they don't contribute. But the
  user has no diagnostic signal. The existing check (NPS levels absent from reference) triggers
  an error. The reverse check (reference levels absent from NPS) produces a warning, not an
  error, because the estimation still proceeds.
- **Numeric covariates**: Range extrapolation (NPS outside reference range) does not cause NR
  failure — the model just extrapolates. No signal exists unless a range check is added.
  The warning should include the actual ranges.
- **Both M-1 checks run even when `estimating_eq = "gee"`**: The GEE path has identical
  common support requirements.

### Estimator label (C-1)

- The history entry at line 744 stores `estimator = "ht"`. This must change to `"ipw2"`.
  The fix is one line. But `"ipw2"` is not a current value in any documented schema — the
  spec must define what values `estimator` can take.

### Variance (C-2 + H-5)

- **Refit requirement**: The propensity model must be refit at EVERY bootstrap replicate or
  jackknife deletion group. This is stated unambiguously in Elliott & Valliant (2017) §3.1
  and Valliant (2020) §2.1.4. The current documentation says only "Bootstrap variance
  estimation is recommended" — no mention of the refit requirement.
- **Jackknife vs. bootstrap**: Valliant (2020) Table 9 shows jackknife coverage consistently
  closer to 95% than bootstrap WR across scenarios. The documentation update should present
  jackknife as the primary recommendation and bootstrap as a valid alternative, not vice versa.
- **Variance formula complexity**: The correct analytical variance for IPW2 (Chen 2021 Theorem
  1, eq. 3.5) involves a term for estimation uncertainty in $\hat{\boldsymbol{\gamma}}$
  (via the $\mathbf{b}_2^T \mathbf{D} \mathbf{b}_2$ term). Replication-based variance
  estimators (jackknife/bootstrap with model refitting) implicitly capture this without
  requiring the analytical formula.

---

## Reference mapping

| Paper | Section/Equation | Design decision |
|-------|-----------------|-----------------|
| Chen (2021) | §3.1, eq. 3.2 | Pseudo-likelihood — replaces population sum with HT-weighted reference |
| Chen (2021) | §3.1, score equations below 3.2 | Current MLE score and Hessian — verified exact match to code |
| Chen (2021) | §3.2, eq. 3.3 | IPW1 vs. IPW2 distinction; IPW2 (Hájek) preferred; current label "ht" is wrong |
| Chen (2021) | Theorem 1, eqs. 3.4–3.5 | Asymptotic variance of IPW1 and IPW2; $\mathbf{b}_2^T\mathbf{D}\mathbf{b}_2$ term is the cost of estimating γ |
| Chen (2021) | Table 1 ("TF" scenario) | IPW collapse under propensity misspecification — basis for C-4 |
| Chen (2021) | §2.1 | Existing pooling approach (Tilde-R method) estimates wrong quantity — justifies unconditional approach |
| Chen (2021) | Assumptions A1–A3 | MAR (A1), positivity (A2), independence (A3) — basis for H-2, M-5 |
| Beresewicz (2025) | eq. 3.1 | MLE score equation — confirmed identical to current code |
| Beresewicz (2025) | eq. 3.2 | General estimating equations framework — h arbitrary |
| Beresewicz (2025) | eq. 3.3 | GEE calibration score (h = x/π) — basis for H-6 |
| Beresewicz (2025) | eq. 3.4 | IPW1 vs. IPW2 — same distinction as Chen (2021) |
| Beresewicz (2025) | Remark 3 | GEE solution is doubly robust |
| Beresewicz (2025) | Table 5.2, Scenario IV | IPW MLE RMSE = 499, QBIPW2-GEE RMSE = 14.9 — basis for C-4 |
| Valliant (2020) | §2.1.1, Eq. (1) | Reference weight adjustment: $w_i^* = w_i((\hat{N}-n)/\hat{N})$ |
| Valliant (2020) | §2.1.2 | Common support: full covariate range required in both directions |
| Valliant (2020) | §2.1.3 | Measurement equivalence: same question wording and categories required |
| Valliant (2020) | §2.1.4, eqs. (2)–(3) | Jackknife preferred over bootstrap WR; grouped JK with model refit |
| Valliant (2020) | §2.1.4 | "The binary regression model should be refitted in every group" — refit requirement |
| Valliant (2020) | Table 9 | JK CI coverage nearer 95% than bootstrap WR across all scenarios |
| Valliant (2020) | Conclusion | "Doubly robust in combination with jackknife was the best combination" — basis for H-4 |
| Elliott & Valliant (2017) | p. 255–256 | Conditional vs. unconditional estimating equation — basis for H-1 |
| Elliott & Valliant (2017) | §3.1 | "Pseudo-weights should be recomputed" at each bootstrap/jackknife iteration |
| Elliott & Valliant (2017) | p. 255 | LASSO/BART/super learner for high-dimensional selection — basis for L-1 |
| Yang et al. (2020) | Assumptions | Non-informative sampling = MAR; bootstrap variance with model refit |
| Yang et al. (2020) | §6 / conclusion | DR substantially outperforms IPW-only under misspecification — basis for H-4 |
| Yang et al. (2018) | §2.4 | Model diagnostics (AUC, cross-validation) — basis for M-6 |
| Beresewicz (2025) | Remark 2 | Quantile binning approximation — basis for L-2 |
| Valliant (2020) | §2.1.1 | "Reference weights should correct all nonresponse and other nonsampling bias" — basis for H-3 |

---

## Assumptions

- **MAR (non-informative sampling):** P(R_i=1 | x_i, y_i) = P(R_i=1 | x_i). NPS participation
  is independent of the outcome variable given covariates. Cannot be tested from observed data.
  Survey statistics term is "non-informative sampling" (Chen 2021, A1; Beresewicz 2025, A1).

- **Positivity:** Every population unit has π_k^A > 0 (Chen 2021, A2; Beresewicz 2025, A2).
  Violated when entire population subgroups are structurally excluded from the NPS.

- **Independence of participation:** R_i and R_j are independent given covariates (Chen 2021,
  A3; Beresewicz 2025, A3). Fails for clustered NPS (household panels, snowball recruitment).

- **Logistic model:** Formal asymptotic theory (Chen 2021 Theorem 1; Beresewicz 2025) is proven
  specifically for logistic regression. Probit and cloglog are extensions "in principle" (Yang
  2020) but lack formal proof. They remain valid link functions computationally; their asymptotic
  behavior in the pseudo-likelihood framework is not established in any of the six papers.

- **Reference quality:** The reference sample must represent the target population with correct
  coverage and calibrated weights. A biased reference propagates directly into propensity
  estimates (Valliant 2020, §2.1.1).

- **Measurement equivalence:** Shared covariates must be measured with the same question
  wording, response options, and measurement period in both samples (Valliant 2020, §2.1.3).

- **Common support (both directions):** Every covariate combination in the NPS must appear in
  the reference, AND every reference factor level must appear in the NPS. For continuous
  covariates, the NPS range must lie within the reference range.

- **NPS fraction of population:** The pseudo-likelihood is correctly specified only when
  n_NPS / N̂ is small (Yang 2020, §2.3.1 citing Valliant & Dever 2011). The reference weight
  adjustment (Valliant 2020, Eq. 1) corrects for non-negligible NPS fractions.

- **NPS and reference do not overlap:** If units appear in both samples, the 0/1 coding for
  NPS membership is ambiguous. The implementation does not check for this; it is assumed to
  be handled by the caller (Valliant 2020, §2.1.2 notes duplicates should be removed).

---

## Open questions

- **5% threshold for C-3 (adjust_reference):** Valliant (2020) says "small fraction" without
  quantifying it. The gaps document proposes 5% (`nps_fraction > 0.05`) as the operational
  threshold for both the adjustment and the warning. This is a defensible engineering choice but
  is not paper-derived. The spec must decide whether to expose this threshold as an argument
  (e.g., `adjust_reference_threshold = 0.05`) or hardcode it.

- **GEE + missing_method = "separate" interaction:** When `has_sep = TRUE`, `X_nps_fit` covers
  only complete-case NPS rows. The GEE score sums `x_k / π_k` over those rows only — the
  calibration guarantee does not extend to all NPS units. The spec must decide: (a) warn the
  user of this limitation and allow GEE + separate, or (b) error out with
  `surveywts_error_gee_incompatible_with_separate`, or (c) upgrade the behavior so GEE
  calibrates on all NPS rows (would require a different fit strategy). Option (a) is simplest
  and consistent with how M-3 handles the theoretical gap in "separate."

- **GEE new warning class needed or reuse existing?** The gaps document specifies
  `surveywts_warning_ipw_gee_nps_scores_degenerate` for when NPS scores hit the float boundary
  on the GEE path. The existing `surveywts_error_propensity_scores_degenerate` is an error (not
  a warning) and is thrown by `ipw()` after `.fit_participation_propensity()` returns
  `converged = FALSE`. The spec must decide whether GEE score degeneration is a warning (return
  last-iteration result) or triggers the existing error path. The gaps document sketches
  returning `converged = FALSE` from the fit function — this is consistent with the existing
  pattern and means `ipw()` will abort via the existing error class. If so, the separate warning
  class `surveywts_warning_ipw_gee_nps_scores_degenerate` is not actually needed.

- **L-4 (population_size argument) + GEE interaction:** GEE naturally produces IPW2-type
  weights (calibrated to reference totals, self-normalizing). Supplying a known population
  N would shift to IPW1 semantics. With GEE, the estimating equations would need modification
  to incorporate N. The spec should either prohibit `population_size` with `estimating_eq = "gee"`
  or document that `population_size` only affects the history entry (not the estimation).

- **`estimating_eq` added to history entry:** The gaps document calls for recording
  `estimating_eq` in the history. The spec must define the full updated schema for the history
  entry including all new fields (C-1: `estimator = "ipw2"`, C-3: `nps_fraction`,
  H-6: `estimating_eq`, M-4: `nps_fraction` in history, M-6: `propensity_scores`).

- **M-6 (propensity_scores in history):** Storing all propensity scores in the history entry
  creates a potentially large object — for n_NPS = 10,000, this is a numeric vector of 10,000
  elements stored in the metadata list. The spec should address whether this is acceptable or
  whether only summary statistics (min, max, deciles) should be stored.
