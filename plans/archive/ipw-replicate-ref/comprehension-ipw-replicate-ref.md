# Comprehension — ipw-replicate-ref

## Problem

`ipw()` estimates inverse probability weights for a non-probability sample (NPS)
by fitting a propensity model — a pseudo-likelihood logistic regression — that
uses a probability-based reference sample to approximate the population
contribution to the score equations. The reference sample's only role in
propensity estimation is to supply (a) unit-level covariate records and (b) first-order
design weights `d_i = 1 / pi_i`. All six papers reviewed confirm that these two
quantities are accessed identically whether the reference carries a Taylor
(linearization) design structure or a replicate-weight design structure. The
current implementation restricts `reference` to `survey_taylor`, but
`survey_replicate` objects carry `@variables$weights` (the main weight column
name) and `@data` (the unit-level records) in exactly the same way. Accepting
`survey_replicate` requires only that the Behavior Rule 2 type check be widened;
no changes to the propensity estimation algorithm, the GEE path, the MLE path,
or any downstream computation are needed for point estimation. The one place
where reference design structure beyond first-order weights is statistically
relevant is variance estimation: Wu (2022) §6.2 decomposes IPW asymptotic
variance into V_q (propensity model uncertainty) and V_p (reference design
uncertainty), and notes that replicate weights on the reference sample directly
provide a valid estimator for V_p without requiring second-order inclusion
probabilities — making `survey_replicate` references actually preferable for
variance estimation, not just acceptable.

## Formulas

### Pseudo-likelihood (MLE path) — Chen, Li & Wu (2020), Eq. 3.2; Lenau et al. (2021), Eq. 3.16

$$
l^*(\boldsymbol{\theta}) = \sum_{i \in S_A} \log\!\left\{\frac{\pi(x_i, \boldsymbol{\theta})}{1 - \pi(x_i, \boldsymbol{\theta})}\right\} + \sum_{i \in S_B} d_i^B \log\!\left\{1 - \pi(x_i, \boldsymbol{\theta})\right\}
$$

| Symbol | Bound to |
|--------|----------|
| $S_A$ | `data` (NPS rows) |
| $S_B$ | `reference@data` (reference rows) |
| $\boldsymbol{\theta}$ | Logistic coefficient vector fitted by Newton-Raphson |
| $d_i^B$ | `reference@data[[reference@variables$weights]]` — the first-order design weight |
| $\pi(x_i, \boldsymbol{\theta})$ | `link^{-1}(X %*% theta)` — fitted propensity |

The second term uses only `d_i^B`. Whether that weight came from a Taylor
design or a replicate design object is irrelevant; both expose the same column
via `reference@variables$weights`.

### MLE score equations — Chen, Li & Wu (2020), Eq. 3.2 (score); Lenau et al. (2021), Eq. 3.18

$$
U(\boldsymbol{\theta}) = \sum_{i \in S_A} x_i - \sum_{i \in S_B} d_i^B \pi(x_i, \boldsymbol{\theta}) x_i = 0
$$

Only `d_i^B` and `x_i` from the reference appear here. The reference design
type (Taylor vs. replicate) does not enter these equations.

### GEE calibration equations — current `ipw()` implementation

$$
U_{GEE}(\boldsymbol{\gamma}) = \sum_{k \in NPS} \frac{x_k}{\pi_k(\boldsymbol{\gamma})} - \sum_{k \in ref} d_k x_k = 0
$$

The reference-side quantity is `ref_totals = colSums(X_ref * d_ref)`, computed
once before the solver loop. It depends only on `d_ref` (the main weight
vector) and `X_ref` (the design matrix). Design type is irrelevant.

### IPW weights

$$
w_k = \frac{1}{\hat{\pi}_k(\hat{\boldsymbol{\theta}})}
$$

where `w_k` is written to the `wt_name` column of `@data`. Identical formula
regardless of reference design type.

### Variance decomposition — Wu (2022), §6.2

$$
\text{Var}\{\Phi_n(\boldsymbol{\eta}_0)\} = V_q(\mathbf{A}_1) + V_p(\mathbf{A}_2)
$$

$$
\mathbf{A}_2 = \frac{1}{N} \sum_{i \in S_B} d_i^B \begin{pmatrix} 0 \\ \pi_i^A h(x_i, \boldsymbol{\alpha}) \end{pmatrix}
$$

$V_p(\mathbf{A}_2)$ is the design-based variance of a weighted total over $S_B$.
For a Taylor design, estimating $V_p$ requires linearization and second-order
inclusion probabilities $\pi_{ij}^B$ (often unavailable — Yang et al. (2020)
§7 used a Poisson approximation for this reason). For a `survey_replicate`
reference, the pre-computed replicate weight columns provide a direct estimator
of $V_p(\mathbf{A}_2)$ without needing $\pi_{ij}^B$. Wu (2022) §6 preamble
explicitly lists "replication weights as part of the dataset from the reference
probability sample" as the preferred pathway. This is the key new insight that
makes `survey_replicate` not merely acceptable but advantaged for downstream
variance estimation.

## Gotchas

- **Variance estimation still requires propensity model refit per replicate.** Even when the reference is `survey_replicate`, correct variance estimation for the NPS estimator requires re-running `ipw()` at each bootstrap resample or jackknife group, refitting the propensity model from scratch (Elliott & Valliant, 2017, §3.1; Valliant, 2020, §2.1.4). The replicate weights on the reference object provide a V_p estimator (reference-design variance component), not a substitute for propensity model refitting. These are separate operations: the former is available from a `survey_replicate` reference; the latter is the user's responsibility. The `@details` variance section in `ipw()` must make this distinction explicit.

- **The existing `@details` variance section refers to "refitting at each replicate" in the context of the NPS bootstrap/jackknife — that documentation is correct and must be preserved.** The addition for `survey_replicate` is that the reference's own replicate weights can subsequently be used for V_p estimation — a documentation addition, not a replacement of existing variance guidance.

- **Bootstrap for complex multi-stage reference designs.** Wu (2022) §6.3 and Valliant (2020) note that with-replacement bootstrap applied to a complex stratified multi-stage reference introduces complications. Users passing a `survey_replicate` reference with complex BRR or JKn weights should use those pre-computed replicate weights (which were constructed to be design-consistent) rather than resampling from scratch. The spec should document this as a limitation.

- **Small-sampling-fraction assumption.** Elliott & Valliant (2017) and Lenau et al. (2021) both note the pseudo-weight derivation assumes both the NPS and reference have small sampling fractions relative to the population. If the reference is a near-census administrative frame, the Horvitz-Thompson approximation of the population log-likelihood sum is less accurate. This assumption applies identically to Taylor and replicate reference designs.

- **Zero-weight rows in reference.** The existing Behavior Rule 3 checks for non-positive reference weights. For `survey_replicate` objects, the check applies to the main weight column `reference@variables$weights` only. Replicate weight columns may themselves contain zeros (e.g., BRR zeros) — these are not checked and are irrelevant to propensity estimation.

- **Error class name.** The current error `surveywts_error_svydesign_not_taylor` now misstates the contract: it fires when `reference` is neither `survey_taylor` nor `survey_replicate`. Adding a new class `surveywts_error_reference_not_survey_design` alongside the old class (old class retired but kept as an alias via the condition text) is the safest non-breaking option. However, renaming is cleaner: since this feature widens a currently-erroring case, no user currently relying on the `svydesign_not_taylor` class name for `survey_replicate` inputs will break (they could not have caught that error previously without the test failing the `ipw()` call itself). The spec mandates adding a new class and retiring the old one with a strikethrough entry in `plans/error-messages.md`.

- **`reference@reference_sample` slot.** `survey_replicate` does not have a `reference_sample` slot in the same sense as `survey_nonprob`. The `history_entry$reference_design` field currently stores the supplied `reference` object. For `survey_replicate`, this remains the correct behavior — the `reference_design` history field should store whatever object was passed, preserving the replicate weights for downstream variance workflows.

- **Common support and near-zero propensities.** These failure modes (zero propensity scores, extreme weights) are identical for Taylor and replicate reference objects. The existing Limitations section in `ipw()` covers them; no new documentation needed.

## Reference mapping

- Chen, Li & Wu (2020), §2.1, Eq. 3.2 → `d_i^B` from the reference sample enters the pseudo-likelihood only as a scalar weight on the log(1 - pi) terms. Design type is irrelevant to the score equations. Confirms that widening the type check for `reference` requires no algorithm change.

- Chen, Li & Wu (2020), §4.1, `hat_D` formula → Second-order inclusion probabilities `pi_ij^B` needed for design-based variance of the reference contribution. For Taylor designs these may be available from stratum/PSU structure; for replicate designs they are bypassed by the replication formula.

- Wu (2022), §4.1.1 (Eq. 4.2–4.3) → Same pseudo-likelihood and score equation structure as Chen et al. — only `d_i^B` from the reference enters propensity fitting. Design type does not appear.

- Wu (2022), §6.2, $V_p(\mathbf{A}_2)$ → The reference-design variance component of IPW variance. Explicitly states that "replication weights as part of the dataset from the reference probability sample" are a preferred mechanism for estimating $V_p$. This is the primary basis for the documentation addition to `@details` and `@param reference`.

- Wu (2022), §6 preamble → "either suitable variance approximation formulas or replication weights as part of the dataset from the reference probability sample" — direct justification for accepting `survey_replicate` as preferred for variance workflows.

- Valliant (2020), §2.1.1 → Reference sample cases receive their probability survey weight in the binary propensity regression. Only the main weight is used. Replicate weights are not mentioned in the propensity step.

- Valliant (2020), §2.1.4, Eq. 3 → Jackknife variance requires refitting the propensity model in every group. This applies regardless of reference design type.

- Elliott & Valliant (2017), §3.1 → Pseudo-weights must be recomputed at every bootstrap/jackknife replicate. Pre-computed replicate weights on the reference describe reference-design variance (V_p), not NPS propensity variance (V_q). They serve different purposes and must not be confused.

- Lenau et al. (2021), §3.4.6.1, Eq. 3.18 → Only point weights `w_i` enter the score equations. Replicate weights would enter only for variance estimation of the coefficient vector.

- Yang et al. (2020), §5, Remark 4 → For high-entropy designs, asymptotic properties are determined solely by first-order inclusion probabilities. Design type (Taylor vs. replicate) does not affect the propensity score estimation step.

- Yang et al. (2020), §5, Eq. 24 → $\hat{V}_1$ requires second-order inclusion probabilities, often unavailable. `survey_replicate` reference sidesteps this via the replication variance formula.

## Assumptions

- **MAR / ignorability.** NPS participation is independent of the outcome given observed covariates. Unverifiable from data. Applies identically regardless of reference design type.

- **Positivity.** All population units have positive propensity. Violated units produce extreme weights. Identical across reference design types.

- **Independence of NPS and reference.** No unit appears in both `data` and `reference`. If a `survey_replicate` reference was itself drawn from a panel that overlaps with the NPS, the pseudo-likelihood label coding is inconsistent. User responsibility; `ipw()` cannot check overlap.

- **Reference weights are interpretable as first-order design weights.** The pseudo-likelihood's Horvitz-Thompson approximation is valid when `d_i^B = 1/pi_i^B` (raw design weights). Both `survey_taylor` and `survey_replicate` objects may carry calibrated or post-stratified weights rather than raw design weights. This is a limitation of the method generally, not specific to replicate designs.

- **Reference unit-level records are available.** The score equations require `x_i` for each reference unit, not just population totals. Both `survey_taylor` and `survey_replicate` carry unit-level data in `@data`. No new assumption for `survey_replicate`.

## Citations

**Chen, Y.; Li, P.; Wu, C.**
Year: 2020
Title: Doubly Robust Inference with Non-probability Survey Samples
Journal: Journal of the American Statistical Association
Volume/Issue/Pages: Vol. 115, No. 532, pp. 2011–2021
DOI: [NOT FOUND in source document — listed as JASA but exact DOI unavailable]

**Wu, C.**
Year: 2022
Title: Statistical inference with non-probability survey samples
Journal: Survey Methodology
Volume/Issue/Pages: Vol. 48, No. 2, pp. 283–311
URL: Statistics Canada, Catalogue No. 12-001-X

**Valliant, R.**
Year: 2020
Title: Comparing Alternatives for Estimation from Nonprobability Samples
Journal: Journal of Survey Statistics and Methodology
Volume/Issue/Pages: Vol. 8, pp. 231–263
DOI: 10.1093/jssam/smz003

**Elliott, M.R.; Valliant, R.**
Year: 2017
Title: Inference for Nonprobability Samples
Journal: Statistical Science
Volume/Issue/Pages: Vol. 32, No. 2, pp. 249–264
DOI: 10.1214/16-STS598

**Lenau, S.; Marchetti, S.; Münich, R.; Pratesi, M.; Salvati, N.; Shlomo, N.; Schirripa Spagnolo, F.; Zhang, L.-C.**
Year: 2021
Title: Methods for Sampling and Inference with Non-Probability Samples
Journal: InGRID-2 Project Deliverable D11.8
Volume/Issue/Pages: [NOT FOUND]
URL: http://www.inclusivegrowth.eu

**Yang, S.; Kim, J.K.; Song, R.**
Year: 2020
Title: Doubly Robust Inference when Combining Probability and Non-Probability Samples with High Dimensional Data
Journal: Journal of the Royal Statistical Society: Series B (Statistical Methodology)
Volume/Issue/Pages: Vol. 82, Part 2, pp. 445–465
DOI: https://doi.org/10.1111/rssb.12354 [DOI inferred from journal imprint — verify before citing]
