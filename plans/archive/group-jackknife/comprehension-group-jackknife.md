# Comprehension — group-jackknife

## Problem

Standard design-based variance estimation assumes that every unit in the
sample had a known, nonzero probability of selection. Non-probability samples
(NPS) — opt-in web panels, convenience samples, volunteer registries — do not
satisfy this requirement. Their inclusion mechanism is unknown and likely
depends on unobserved factors. As a result, the classical jackknife (or any
design-based replication scheme) cannot be applied directly: there is no known
first-stage sampling fraction to form the scaling factor, and dropping a
single unit at a time produces a variance estimate that ignores the estimation
variability in the pseudo-weights themselves.

The delete-a-group jackknife (DAGJK) for NPS addresses this by partitioning
the combined dataset — NPS units plus reference-probability-sample units —
into $G$ mutually exclusive, roughly equal-sized random groups. For each
replicate, one group is removed from the combined dataset, the entire
estimation pipeline is re-run from scratch (binary logistic regression to
estimate pseudo-inclusion probabilities, weight inversion, any subsequent
calibration), and the resulting leave-one-group-out point estimate is recorded.
Variance is then estimated from the spread of these $G$ replicate estimates,
scaled by $(G-1)/G$. This differs from the standard jackknife for probability
samples in three important ways: (1) groups are random rather than design PSUs;
(2) the weight-generating model must be refit in every replicate, not just the
point estimator; and (3) the asymptotic justification rests on analogy to
probability-sample theory (Krewski and Rao 1981) rather than on a formal proof
— no such proof exists in the literature for NPS settings as of 2020.

---

## Formulas

### Core DAGJK formula

$$
v_J(\hat{\theta}) = \frac{G-1}{G} \sum_{g=1}^{G} \left(\hat{\theta}_{(g)} - \hat{\theta}\right)^2
$$

| Symbol | Meaning | Bound to (R) |
|--------|---------|--------------|
| $v_J(\hat{\theta})$ | Grouped jackknife variance estimate of $\hat{\theta}$ | scalar return value |
| $G$ | Number of random deletion groups | function argument `groups` |
| $g$ | Group index, $g = 1, \ldots, G$ | replicate index (loop counter) |
| $\hat{\theta}_{(g)}$ | Point estimate recomputed from all units **not** in group $g$ | computed per replicate |
| $\hat{\theta}$ | Full-sample point estimate | full-sample estimate before deletion |

**Source:** Valliant (2020) Eq. 3, p. 234. Factor is $(G-1)/G$, not $(n-1)/n$.

**Scaling factor resolution (cross-paper tension 1):**
Valliant (2020) writes the factor as $(G-1)/G$ where $G$ is the number of
groups. Valliant (2009) writes the analogous delete-one formula as
$(n-1)/n$ where $n$ is the number of clusters (units deleted one at a time).
These are the same formula applied at different levels of aggregation:
for unit-level deletion with $n$ units, $G = n$; for group-level deletion
with $G$ groups, the scaling factor is $(G-1)/G$. When groups are defined
as sets of NPS+reference units (the NPS application), the correct factor
is always $(G-1)/G$ with $G$ = number of groups. Using $(n-1)/n$ with
$n$ = total sample size would scale variance by approximately $(n-1)/(G-1)$
relative to the correct formula — a severe overestimate for typical values
(e.g., $n=500$, $G=50$ gives a $\approx 10\times$ inflation).

---

### Replicate weight construction

For replicate $g = 1, \ldots, G$:

```
Step 1.  Remove all units assigned to group g from the combined dataset.
         Combined dataset = NPS rows union reference rows.

Step 2.  On the reduced combined dataset (all units NOT in group g):
         a. Adjust reference weights if the NPS fraction is non-negligible
            (Valliant 2020, Eq. 1):
               w_ref_adj[i] = w_ref[i] * (N_hat - n_nps) / N_hat
            where N_hat = sum(w_ref) over all reference units,
            and n_nps = number of NPS units (count, not sum of weights).
         b. Stack adjusted reference rows (Z=0) with NPS rows (Z=1).
         c. Refit the binary logistic model:
               logit(P(Z=1 | x)) ~ predictors
            using reference weights for reference rows and weight 1 for NPS rows.
         d. Predict pseudo-inclusion probability pi_i = P(Z=1 | x_i)
            for each remaining NPS unit.
         e. Compute NPS pseudo-weight for remaining NPS units:
               w_i = 1 / pi_i
            (optionally scaled to reference population size).
         f. If calibration (raking / post-stratification) was applied in the
            full-sample pipeline, repeat that calibration step on the remaining
            NPS units using the replicate pseudo-weights from (e).

Step 3.  Units in group g receive a replicate weight of 0
         (they are excluded from the replicate estimate).

Step 4.  Record hat(theta)_(g) = weighted estimate from remaining NPS units
         using the replicate weights from Step 2.
```

The resulting replicate weight matrix has $G$ columns. Column $g$ contains:
- For NPS units NOT in group $g$: their leave-one-group-out pseudo-weight.
- For NPS units in group $g$: 0 (excluded from replicate $g$).

This structure integrates with the existing `survey_replicate` / `svrep`
infrastructure: `scale = (G-1)/G`, `rscales = rep(1, G)`, `mse = TRUE`
for centered variance estimates.

---

### Estimator-specific notes

**IPW / quasi-randomization (QR) estimator (primary NPS use case):**
The full binary logistic model (step 2c above) must be refit in every
replicate. This is not optional. Fixed pseudo-weights applied across all
replicates underestimate variance by ignoring estimation variability in
$\hat{\pi}_i$. Valliant (2020, §3.2.1, §3.2.2) is unambiguous on this point.
Elliott & Valliant (2017, §3.1) state it directly: "for each bootstrap or
jackknife iteration, the pseudo-weights should be recomputed as well as the
point estimator using the dropped-out or resampled data."

**GREG / model-based prediction estimator ($\hat{t}_{y1}$, $\hat{t}_{y2}$):**
Valliant (2009) derives a computational shortcut for the delete-one-cluster
jackknife that avoids refitting via the within-cluster hat matrix block
$\mathbf{H}_{ii}$:

$$v_J(\hat{T}_r) = \frac{n-1}{n} \left\{ \sum_{i \in s} \left(\mathbf{a}_i' \mathbf{P}_i^{-1} \mathbf{r}_i\right)^2 - \frac{1}{n} \left[\sum_{i \in s} \mathbf{a}_i' \mathbf{P}_i^{-1} \mathbf{r}_i\right]^2 \right\}$$

where $\mathbf{P}_i = \mathbf{I}_{m_i} - \mathbf{H}_{ii}$ and
$\mathbf{H}_{ii} = \mathbf{X}_{si} \mathbf{G} \mathbf{X}_{si}' \mathbf{W}_{si}$.

**This shortcut applies only when the weight-generating model is a BLUP/GREG
linear predictor.** It does NOT apply to logistic-regression-based IPW for
NPS, because the hat matrix block is defined for the OLS/WLS working model,
not for logistic regression. For the group jackknife in the surveywts NPS
context, the shortcut is out of scope — full model refit is required.

**Doubly robust (DR) calibrated estimator:**
When the full pipeline applies both IPW (quasi-randomization) and a subsequent
calibration step, both steps must be repeated in every replicate (Valliant 2020,
§2.4). Repeating only the calibration step while holding pseudo-weights fixed
underestimates variance. Note: the DAGJK is consistently positively biased for
DR estimators (3–5% SE relbias at $n=500$, 2–3% at $n=1000$; Valliant 2020,
Table 8) and this bias does not vanish as $n$ grows — cause is not established
in the literature.

---

## Gotchas

- **Refit the model in every replicate, not just reweight** — The binary
  logistic regression (and any downstream calibration) must be refit from
  scratch within each jackknife group. An implementation that only drops group
  $g$ and recomputes a weighted mean using the full-sample pseudo-weights will
  underestimate variance by ignoring estimation variance of the pseudo-
  probabilities. This is the single most common implementation error per all
  three papers.

- **Scaling factor is $(G-1)/G$, not $(n-1)/n$** — Using total sample size
  $n$ instead of group count $G$ in the scaling factor inflates variance
  estimates by $(n-1)/(G-1)$. For typical values ($n=500$, $G=50$) this is a
  $\approx 10\times$ error. Always use $G$ (number of groups).

- **Minimum $G$** — The formula is degenerate at $G = 1$ (factor equals 0,
  variance estimate is 0). The function must require $G \geq 2$. Valliant
  (2020) uses $G = 50$ for $n \in \{500, 1000\}$; no formal guidance exists
  for how $G$ should scale with $n$. The spec should recommend $G = 50$ as
  a default and enforce $G \geq 2$ as a hard floor.

- **$G$ choice and group size** — Groups must be roughly equal in size. With
  $G = 50$ and $n = 500$ NPS units, each group has $\approx 10$ units. If the
  combined NPS+reference dataset is small relative to $G$, groups may be so
  small that the logistic model fails to converge in some replicates. The paper
  provides no fallback for this failure mode.

- **Degenerate groups / single-unit groups** — If a deletion group contains
  the only representative of a covariate level, the refitted binary regression
  in that replicate may be degenerate (perfect separation, non-convergence, or
  a covariate level absent from the model matrix). The paper does not address
  this. Implementation must catch convergence failures per replicate and either
  skip or error.

- **Non-convergence of logistic regression in a replicate** — With small groups
  or sparse covariate coverage, the logistic model may fail to converge in some
  replicates. The paper provides no fallback strategy. Mirroring the existing
  QR bootstrap pattern (`surveywts_warning_bootstrap_draws_failed` for >10%
  failure rate) is appropriate.

- **Groups span the combined NPS + reference dataset** — Groups are formed
  across the full combined dataset (NPS units + reference units), not within
  each dataset separately. When group $g$ is deleted, both NPS units and
  reference units assigned to group $g$ are removed before refitting the
  logistic model (Valliant 2020, §2.1.4). This is a non-obvious implementation
  detail with real impact: removing only NPS units from group $g$ while
  retaining reference units in group $g$ would misspecify the replicate.

- **Reference weight adjustment** — When the NPS is a non-negligible fraction
  of the estimated population size (Valliant 2020 suggests > 5%, though no
  threshold is stated explicitly), reference weights should be adjusted by
  $(1 - n/\hat{N})$ before fitting the binary regression. This adjustment must
  also be applied inside each replicate using the count of NPS units remaining
  after group deletion. Failing to do so introduces a systematic bias into
  replicate estimates.

- **Negative replicate weights** — Model-based weights ($w_{1i}$, $w_{2i}$)
  from GREG-type estimators can be negative (Valliant 2020, §2.2). For IPW-
  based pseudo-weights, negative values should not occur (inverse of a
  probability in $(0,1)$), but they can arise after downstream calibration.
  The function should warn (not error) on negative replicate weights, consistent
  with `surveywts_warning_negative_calibrated_weights` for calibration.

- **Nonsample variance component** — Valliant (2009, §5) notes that the full
  prediction MSE includes a component from the unobserved nonsample:
  $\sum_r \psi_i$. Standard DAGJK for NPS captures only the sample-based
  estimation variance; the nonsample component (representing uncertainty about
  unobserved population units) is not captured. For probability samples the
  nonsample component is handled by the finite population correction; for NPS
  there is no equivalent mechanism. The spec should document this limitation
  rather than attempt to implement it — it requires model assumptions far beyond
  the DAGJK scope.

- **No formal consistency proof for NPS** — Valliant (2020, §2.4) explicitly
  acknowledges that "a formal proof of the consistency of such a replication
  estimator does not appear to exist in the literature for a nonprobability
  sample." Consistency is claimed by analogy to Krewski and Rao (1981). The
  spec should document this theoretical limitation in its assumptions section
  and in user-facing documentation.

- **Single-PSU / single-cluster in a stratum** — Elliott & Valliant (2017,
  §3.1) note that if a stratum has only one PSU, dropping it leaves zero PSUs
  and makes the stratum contribution undefined. For the NPS group jackknife,
  the analogous problem is a covariate cell with a single unit assigned to one
  group. The function must handle this gracefully (skip the replicate or error
  with a clear message).

- **Bootstrap theory gap** — Elliott & Valliant (2017, §4) explicitly state
  that "finite population, model-based theory has not been worked-out for the
  bootstrap." The jackknife is on firmer (though still incomplete) theoretical
  ground for NPS variance estimation. This distinction should appear in the
  function's documentation.

---

## Reference mapping

- Valliant (2020) §2.1.4 / Eq. 3 → Core DAGJK formula with $(G-1)/G$ scaling
  factor; groups are random equal-sized partitions of the combined sample.
- Valliant (2020) §3.2.1 → Refit binary regression in every replicate;
  $G = 50$ as the simulation-validated default group count.
- Valliant (2020) §2.4 → For doubly robust estimators, both the QR step and
  the calibration step must be repeated per replicate.
- Valliant (2020) Eq. 1 / §2.1.1 → Reference weight adjustment
  $w_i^* = w_i(\hat{N} - n) / \hat{N}$ when NPS fraction is non-negligible.
- Valliant (2020) §3.3 / Table 8 → Positive SE relbias of JK for DR
  estimators; informs documentation of known limitations.
- Valliant (2009) §5 / Eq. 22 → Computational delete-one-cluster jackknife
  shortcut via $\mathbf{H}_{ii}$ block; establishes that shortcut applies to
  BLUP/GREG only, not to logistic-IPW pipeline.
- Valliant (2009) §5 → Delete-one jackknife $\approx$ HC2-adjusted sandwich;
  establishes model-based equivalence anchor.
- Elliott & Valliant (2017) §3.1 → "Pseudo-weights should be recomputed" in
  every replicate; key justification for refit requirement.
- Elliott & Valliant (2017) §3.1 (citing Brick 2015) → Recruiting/hosting
  websites as natural group-deletion units for NPS group jackknife.
- Elliott & Valliant (2017) §4 → Bootstrap theory gap for NPS; jackknife
  preferred over bootstrap for superpopulation estimators.

---

## Assumptions

- **MAR given covariates** — The quasi-randomization approach requires that
  pseudo-inclusion probability depends only on observed covariates, not on the
  analysis variable. This is untestable in most applications. The function
  cannot verify this; it must be stated as a design constraint in documentation.

- **Common support** — Every population unit must have positive probability of
  appearing in either the NPS or the reference sample. Violations manifest as
  extreme or undefined weights rather than computation errors. Common support
  should be diagnosed via the existing `surveywts_warning_ipw_covariate_range_extrapolation`
  mechanism at the `ipw()` stage.

- **Reference sample quality** — The reference sample must represent the full
  target population without coverage bias. If the reference has coverage error,
  pseudo-weights inherit that bias. The function cannot detect this; it is a
  design input constraint.

- **Correct model specification (or double robustness)** — Consistency of the
  QR estimator requires correct specification of the binary inclusion model.
  The doubly robust variant (QR + calibration) relaxes this to require only one
  of the two models to be correct. The refit-per-replicate requirement ensures
  that model estimation variability is captured regardless.

- **Independence across groups** — The DAGJK analogy to Krewski and Rao (1981)
  requires that groups are mutually independent. Within-group cluster structure
  in the NPS is typically not modeled (Valliant 2020: "typically unnecessary
  for opt-in web surveys"). Random group assignment is required; ordered or
  systematic assignment may violate this.

- **Small NPS sampling fraction** — The model-based variance approximations
  assume $n/N \to 0$. For large NPS fractions, the nonsample variance component
  grows and is not captured by DAGJK. The reference weight adjustment (Eq. 1)
  partially corrects for this at the point estimate level but does not resolve
  the variance gap.

- **No formal consistency proof** — The DAGJK for NPS is consistent by analogy
  only. Implementers and users should treat variance estimates as asymptotically
  justified approximations, not guaranteed-consistent estimators.

- **$G \geq 2$** — The formula is undefined for $G = 1$ (zero variance). Hard
  floor enforced by the function.

- **Groups span both samples** — Random groups are formed across the full
  combined NPS+reference dataset. The logistic regression is refit on the
  combined dataset minus one group per replicate. Groups formed within each
  sample separately (then combined) would be incorrect.

---

## Cross-paper conflicts

- **Scaling factor notation: $(G-1)/G$ vs. $(n-1)/n$** — Valliant (2020) uses
  $(G-1)/G$ (groups); Valliant (2009) uses $(n-1)/n$ (units or clusters).
  **Resolution:** These are the same formula at different aggregation levels.
  For the NPS group jackknife, the correct factor is always $(G-1)/G$ where
  $G$ = number of deletion groups. Bind to function argument `groups`.

- **Computational shortcut (hat matrix) vs. full refit** — Valliant (2009)
  provides a computational shortcut via $\mathbf{H}_{ii}$ that avoids refitting
  the model. Valliant (2020) and Elliott & Valliant (2017) require full model
  refit in every replicate.
  **Resolution:** The shortcut applies to BLUP/GREG linear models where the hat
  matrix is well-defined for the OLS/WLS working model. For logistic-regression-
  based IPW on NPS — the primary use case in surveywts — the hat matrix block
  is not defined in the same way, and full refit is required. The shortcut is
  out of scope for this feature.

- **NPS asymptotic basis: firmer ground for jackknife vs. no formal proof** —
  Elliott & Valliant (2017) state jackknife is on "firmer ground" than bootstrap
  for NPS. Valliant (2020) states explicitly that "a formal proof of the
  consistency of such a replication estimator does not appear to exist in the
  literature for a nonprobability sample."
  **Resolution:** Both statements are correct and non-contradictory. "Firmer
  ground" relative to bootstrap (which has no formal theory at all for NPS) is
  not the same as a formal consistency proof. Document the gap honestly in the
  spec and in user-facing documentation: jackknife is preferred over bootstrap
  for NPS, but neither has a complete asymptotic theory.

- **DR estimator JK bias — cause unknown** — Valliant (2020) Table 8 shows the
  DAGJK is consistently positively biased for doubly robust estimators (3–5%
  relbias), and this bias does not converge to zero with sample size. The cause
  is not discussed in any of the three papers.
  **Resolution:** [UNRESOLVED — HOLD]. Document as a known empirical limitation.
  The spec should note that DAGJK variance estimates for DR estimators should
  be interpreted cautiously (slightly conservative).

---

## Citations

Authors: Elliott, M.R.; Valliant, R.
Year: 2017
Title: Inference for Nonprobability Samples
Journal/Venue: Statistical Science
Volume/Issue/Pages: Vol. 32, No. 2, pp. 249–264
DOI/URL: 10.1214/16-STS598

Authors: Valliant, R.
Year: 2020
Title: Comparing Alternatives for Estimation from Nonprobability Samples
Journal/Venue: Journal of Survey Statistics and Methodology
Volume/Issue/Pages: 8, 231–263
DOI/URL: doi: 10.1093/jssam/smz003

Authors: Valliant, R.
Year: 2009
Title: Model-based Prediction of Finite Population Totals
Journal/Venue: Handbook of Statistics, Sample Surveys: Inference and Analysis, Vol. 29B (Elsevier)
Volume/Issue/Pages: Vol. 29B, Chapter 26 (pages not individually numbered in this document; chapter is 44 pages)
DOI/URL: 10.1016/S0169-7161(09)00223-5
