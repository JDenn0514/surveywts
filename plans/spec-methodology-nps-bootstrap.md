# NPS Bootstrap Methods: Quasi-Randomization and Hybrid Bootstrap

**Status:** Pre-spec reference — feeds into the formal spec for the NPS
bootstrap additions to `create_bootstrap_weights()`.

**Scope:** Two new `type` options for `create_bootstrap_weights()` that
provide statistically correct variance estimation for non-probability samples.
Both are NPS-only and will error informatively if passed a `survey_taylor`.

---

## Why the Five Existing Types Are Wrong for NPS

The five existing bootstrap types (`Rao-Wu-Yue-Beaumont`, `Rao-Wu`,
`Antal-Tille`, `Preston`, `Canty-Davison`) are probability-sample methods.
When a `survey_nonprob` is passed today, `.convert_and_call()` reduces it to
`survey::svydesign(ids = ~1, ...)` — a bare SRS design using the existing
final weights — and runs the standard bootstrap on that. This produces
replicate weights but treats the final NPS weights as fixed data inputs. The
two sources of NPS variance that this misses:

1. **Adjustment uncertainty.** Every draw should re-run propensity estimation
   and calibration/raking with resampled NPS data, so the spread of replicate
   estimates reflects how much the weights themselves vary due to sampling.

2. **Reference survey uncertainty (when applicable).** When calibration
   targets come from another survey rather than from Census/ACS population
   benchmarks, that survey's own sampling variability propagates into the
   estimates. The reference survey must be resampled in each draw.

---

## Dependency Map

Neither new type can be implemented until upstream functions exist. The
sequencing:

```
ipw()           → quasi-randomization bootstrap
mass_imputation() → hybrid bootstrap
```

Both upstream functions are currently absent from surveywts.

| Upstream function | Status | Release |
|---|---|---|
| `ipw()` | Not yet implemented | Propensity release (planned) |
| `mass_imputation()` (GLM, GAM, k-NN, PMM) | Not yet implemented | TBD |
| `rake()` | Implemented | Calibration release |
| `calibrate()` | Implemented | Calibration release |

The plan below describes both new types fully so the specs for `ipw()` and
`mass_imputation()` can be written with the bootstrap requirements already
known (particularly the history entry structure that the bootstrap will read).

---

## Method 1: Quasi-Randomization Bootstrap

### Conceptual basis

The quasi-randomization framework (Elliott & Valliant 2017; Wu 2022) treats
NPS participation as quasi-random with unknown pseudo-inclusion probabilities
estimated from observed covariates. To justify inference, participation
propensities are estimated from a binary membership model fit on the combined
NPS and a reference probability sample. Variance must capture two sources:
(1) pseudo-sampling variability — which NPS units happened to participate —
and (2) uncertainty in the propensity model itself. Bootstrap is the standard
implementation. Wu (2022) notes that jackknife has known problems in complex
NPS structures; bootstrap does not.

### When to use

Use `type = "quasi-randomization"` when:
- The data are from a non-probability sample (`survey_nonprob` input)
- Weights were constructed via `ipw()` with a reference probability sample,
  optionally followed by `rake()` or `calibrate()` to population margins
- Point estimates use IPW or calibrated-IPW weights

### Algorithm

There are two levels, selected automatically based on whether a reference
sample is available.

**Level A — No reference sample available**

Applies when calibration targets come from population benchmarks (Census/ACS)
and no reference design is stored or passed. Captures adjustment uncertainty
only; does not propagate reference survey variance.

For each draw $b = 1, \ldots, B$:

1. Resample $\mathcal{S}_A^{(b)}$ from the NPS $\mathcal{S}_A$: draw $n_A$
   units with replacement (SRS bootstrap, since no design structure exists).
   The resulting bootstrap count vector $\mathbf{m}^{(b)}$ where $m_i^{(b)}$
   is the number of times unit $i$ appears.

2. Re-run the full weighting history on $\mathcal{S}_A^{(b)}$ using the
   history entries stored in `@metadata@weighting_history`:
   - Re-run `ipw()` with the fixed reference data and resampled NPS
   - Re-run `rake()` / `calibrate()` with original fixed calibration targets

3. Compute $\hat{\theta}^{(b)}$ on the resampled, re-weighted data.

**Level B — Reference sample available**

Applies when a reference design is stored in the `ipw` history entry or
passed as `reference_sample`. In addition to Level A, also propagates
variance from the reference survey itself. This is the correct approach when
raking targets come from another survey (e.g., NPORS) rather than from
population registers.

For each draw $b = 1, \ldots, B$:

1. Resample $\mathcal{S}_A^{(b)}$ as in Level A (SRS with replacement).

2. Resample $\mathcal{S}_B^{(b)}$ from the reference probability sample
   $\mathcal{S}_B$ according to its own design (using the `survey_taylor`
   stored in the `ipw` history entry, via `svrep::as_bootstrap_design()`
   internally). The two resamples are **independent**.

3. Re-run `ipw()` on $\mathcal{S}_A^{(b)} \cup \mathcal{S}_B^{(b)}$ to
   re-estimate pseudo-inclusion probabilities $\hat{\phi}_i^{(b)}$ from the
   propensity model (same formula and method as in the stored history entry).

4. Compute IPW weights:
   $$w_i^{(b)} = \frac{1 - \hat{\phi}_i^{(b)}}{\hat{\phi}_i^{(b)}} \quad \text{(Hájek)} \qquad \text{or} \qquad w_i^{(b)} = \frac{1}{\hat{\phi}_i^{(b)}} \quad \text{(HT)}$$
   The type (Hájek vs. HT) is read from the stored `ipw` history entry.

5. If the history contains a subsequent `rake()` or `calibrate()` step:
   - If targets were derived from the reference survey (flag in history):
     re-estimate the calibration targets from $\mathcal{S}_B^{(b)}$, then
     re-run raking/calibration with the perturbed targets.
   - If targets are population benchmarks: use the original fixed targets.

6. Compute $\hat{\theta}^{(b)}$ on the re-weighted $\mathcal{S}_A^{(b)}$.

### Variance formula

Using the MSE formulation (consistent with `mse = TRUE` throughout
`create_*_weights()`):

$$\hat{V}(\hat{\theta}) = \frac{1}{B} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \hat{\theta}\right)^2$$

where $\hat{\theta}$ is the full-sample estimate. With `mse = FALSE`, use:

$$\hat{V}(\hat{\theta}) = \frac{1}{B - 1} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \bar{\theta}^{(B)}\right)^2$$

### Automatic Level A/B detection

If a reference sample is accessible at bootstrap time — either from the `ipw`
history entry in `@metadata@weighting_history` or from the `reference_sample`
argument — Level B is used. Otherwise Level A. The `reference_sample`
argument takes precedence over the stored history entry.

### Required `ipw()` history entry structure

The bootstrap reads this entry to re-run propensity estimation and detect
whether calibration targets came from the reference survey. The `ipw()` spec
must produce an entry with at least these fields:

```r
list(
  operation             = "ipw",
  step                  = <integer>,
  timestamp             = Sys.time(),
  formula               = <formula>,        # propensity model formula
  method                = "logit",          # or "probit", "cloglog", "ranger" etc.
  estimator             = "hajek",          # or "ht"
  trim                  = c(0.05, 0.95),    # or NULL
  reference_design      = <survey_taylor>,  # stored reference design object
  targets_from_reference = FALSE            # TRUE if rake()/calibrate()
                                            # targets came from this design
)
```

The `targets_from_reference` flag tells the bootstrap whether to re-estimate
calibration targets from the resampled reference (Level B, step 5) or use
fixed targets.

---

## Method 2: Hybrid Bootstrap

### Conceptual basis

Mass imputation estimators (Kim & Wang 2021; Yang et al. 2021) fit an outcome
model $\hat{m}(\mathbf{x}) = \hat{E}[Y|\mathbf{x}]$ on a reference
probability sample and use it to predict outcomes for NPS units. Variance has
two sources: (1) uncertainty in which NPS units were in the sample, and (2)
uncertainty in the fitted imputation model from the reference sample. Chen,
Yang & Kim (2022) distinguish by imputer type:

- **Parametric (GLM):** Standard linearization variance or parametric
  bootstrap is tractable.
- **Kernel regression:** A modified linearization variance is available, but
  hybrid bootstrap is simpler.
- **GAM:** Linearization is analytically intractable due to the smoothing
  structure. Hybrid bootstrap or approximate Bayesian approach required.
- **PMM (A or B):** Chlebicki et al. (2024) derive closed-form analytic
  variance. Hybrid bootstrap is optional.
- **k-NN:** No closed-form analytic variance; hybrid bootstrap applies.

The "hybrid" name comes from independently resampling two sources — the NPS
and the reference sample — rather than jointly resampling a combined dataset.
This independence is structurally required because the imputation model is fit
on the reference sample alone, not on the combined data.

### When to use

Use `type = "hybrid"` when:
- The data are from a non-probability sample (`survey_nonprob` input)
- Weights/estimates were constructed via a mass imputation function
  (GLM, GAM, k-NN, PMM), which stores a history entry of `operation = "mass_imputation"`
- Point estimates come from applying the imputation model to NPS units

### Algorithm

For each draw $b = 1, \ldots, B$:

1. Resample $\mathcal{S}_A^{(b)}$ from the NPS $\mathcal{S}_A$: draw $n_A$
   units with replacement (SRS bootstrap).

2. Independently resample $\mathcal{S}_B^{(b)}$ from the reference
   probability sample $\mathcal{S}_B$ according to its own design. The two
   resamples are **independent** (unlike Level B above, where they were also
   independent, but here the independence is more fundamental — the model is
   fit on $\mathcal{S}_B$ alone).

3. Re-fit the imputation model $\hat{m}^{(b)}$ on $\mathcal{S}_B^{(b)}$
   using the same specification stored in the mass imputation history entry:
   same formula, same method, same hyperparameters.

4. Apply $\hat{m}^{(b)}$ to $\mathcal{S}_A^{(b)}$: for each unit
   $i \in \mathcal{S}_A^{(b)}$, compute $\hat{y}_i^{(b)} = \hat{m}^{(b)}(\mathbf{x}_i)$.

5. Compute the estimator $\hat{\theta}^{(b)}$ from $\{\hat{y}_i^{(b)}\}$,
   applying any design weights from $\mathcal{S}_A^{(b)}$ as appropriate.

### Variance formula

Same MSE formulation as quasi-randomization:

$$\hat{V}(\hat{\theta}) = \frac{1}{B} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \hat{\theta}\right)^2$$

### PMM note

For PMM-A ($\hat{y}$-$\hat{y}$ matching) and PMM-B ($\hat{y}$-$y$ matching),
Chlebicki et al. (2024) derive closed-form analytic variance that does not
require bootstrap. The hybrid bootstrap remains valid and can be used as a
check, but the analytic formula is available and faster. The implementation
should note this in the `?create_bootstrap_weights` documentation for
`type = "hybrid"`.

### Required `mass_imputation()` history entry structure

The bootstrap reads this entry to re-fit the model in each draw. The
`mass_imputation()` spec must produce an entry with at least:

```r
list(
  operation        = "mass_imputation",
  step             = <integer>,
  timestamp        = Sys.time(),
  formula          = <formula>,          # outcome model formula (y ~ x1 + x2)
  method           = "glm",             # "gam", "knn", "pmm_a", "pmm_b"
  family           = "gaussian",        # for GLM/GAM
  parameters       = list(...),         # method-specific: k for kNN, etc.
  reference_design = <survey_taylor>    # stored reference design object
)
```

---

## Key Structural Difference from Existing Bootstrap Types

The five probability-sample bootstrap types follow a static pattern:

```
design → svrep::as_bootstrap_design() → static replicate weight matrix
```

Analysis functions then apply those fixed weights. The NPS types cannot
follow this pattern because the weights themselves must be re-estimated in
each draw. The structure is instead:

```
for b in 1..B:
  resample NPS (+ reference if Level B/hybrid)
  re-run ipw() / mass_imputation() on resampled data
  re-run rake() / calibrate() if in history
  compute estimate → store as one replicate
collapse B estimates → variance
```

This means the new types will need a different internal implementation path in
`create_bootstrap_weights()` — separate from the `svrep` backend path used
by the probability-sample types.

---

## `create_bootstrap_weights()` API Changes

New `type` options and one new argument:

```r
create_bootstrap_weights <- function(
  data,
  replicates = 500L,
  ...,
  type = c(
    # Probability-sample types (existing):
    "Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
    "Preston", "Canty-Davison",
    # NPS types (new):
    "quasi-randomization", "hybrid"
  ),
  reference_sample = NULL,  # NEW: survey_taylor or NULL
  mse = TRUE,
  seed = NULL
)
```

**`reference_sample`:** A `survey_taylor` object. When supplied, takes
precedence over any reference design stored in `@metadata@weighting_history`.
Required for `type = "hybrid"` if no mass imputation history entry is found
with a stored reference design. Optional for `type = "quasi-randomization"`
if the `ipw()` history entry already holds the reference design.

`survey_replicate` is not supported as a `reference_sample`. A reference
survey that already has replicate weights should be handled via
`calibrate_to_survey()` (the Opsomer & Erciulescu approach), not by passing
it here.

### Return type for NPS types

Both `"quasi-randomization"` and `"hybrid"` require `survey_nonprob` input and
return `survey_nonprob` — same class as the input, with repweight columns
(`repwt_1`…`repwt_R`) added to `@data` and `@calibration` populated. The
returned object is immediately ready for analysis without an additional
`as_survey_nonprob()` call.

`weighted_df` input produces an informative error for both NPS types — users
must promote to `survey_nonprob` via `as_survey_nonprob()` first. The NPS
bootstrap types require the weighting history in `@metadata@weighting_history`
(to replay `ipw()` and `rake()`/`calibrate()` on each draw), which `weighted_df`
does not carry.

### Validation rules for new types

| Check | Error class |
|---|---|
| `type = "quasi-randomization"` with `survey_taylor` input | `surveywts_error_qr_bootstrap_requires_nonprob` |
| `type = "quasi-randomization"` with `weighted_df` input | `surveywts_error_qr_bootstrap_requires_nonprob` |
| `type = "hybrid"` with `survey_taylor` input | `surveywts_error_hybrid_bootstrap_requires_nonprob` |
| `type = "hybrid"` with `weighted_df` input | `surveywts_error_hybrid_bootstrap_requires_nonprob` |
| `type = "quasi-randomization"`, no reference found anywhere | `surveywts_error_qr_bootstrap_no_reference` |
| `type = "hybrid"`, no mass imputation history entry found | `surveywts_error_hybrid_bootstrap_no_imputation_history` |
| `type = "hybrid"`, mass imputation history has no reference design | `surveywts_error_hybrid_bootstrap_no_reference` |
| `reference_sample` is not a `survey_taylor` | `surveywts_error_reference_sample_class` |

---

## Source File Map

| File | Role |
|---|---|
| `R/replicate-weights.R` | `create_bootstrap_weights()` — new types go here, in new internal helpers called from the existing function body |
| `R/replicate-dispatch.R` | No changes needed (dispatcher passes through to `create_bootstrap_weights()`) |
| `R/rake.R` | Called within each draw for quasi-randomization; no changes to the function itself, but must be callable with a data frame input from within the bootstrap loop |
| `R/calibrate.R` | Same as rake.R |
| `R/sample-calibration.R` | Reference pattern for two-design (primary + control) bootstrap logic; see `calibrate_to_survey()` |
| `R/nonprob-ipw.R` | Does not yet exist — the Propensity release will create it; the quasi-randomization bootstrap reads its history entries |
| `R/mass-imputation.R` | Does not yet exist — the hybrid bootstrap reads its history entries |

---

## Knowledge Base References

| File | Relevance |
|---|---|
| `knowledge/wiki/concepts/nonprob_variance_estimation.md` | Primary synthesis; covers both bootstrap types, estimand coverage, the two implementation requirements |
| `knowledge/wiki/methods/wu_2022_inference_nonprobability_samples.md` | Formal A1-A4 framework; quasi-randomization bootstrap; jackknife limitations for NPS |
| `knowledge/wiki/methods/chen_yang_kim_2022_nonparametric_mass_imputation.md` | Hybrid bootstrap derivation for GAM; approximate Bayesian alternative |
| `knowledge/wiki/methods/chen_2021_doubly_robust_inference.md` | Formal doubly robust variance; propensity estimation uncertainty in bootstrap |
| `knowledge/wiki/methods/chlebicki_beresewicz_2024_pmm_nonprob_integration.md` | Analytic variance for PMM-A and PMM-B; hybrid bootstrap optional for PMM |
| `knowledge/wiki/methods/opsomer_erciulescu_2022_replication_variance_calibration.md` | Level B rationale: propagating reference survey variance when calibration targets are estimated, not fixed |
| `knowledge/wiki/methods/elliott_valliant_2017_inference_nonprobability.md` | Foundational quasi-randomization and superpopulation framework definitions |

---

## Open Design Questions

**Q1: Where in `replicate-weights.R` do the new types live?**
Option A: Two new private helpers (`.quasi_randomization_bootstrap()` and
`.hybrid_bootstrap()`) called from within the `"quasi-randomization"` and
`"hybrid"` branches of `create_bootstrap_weights()`. These bypass
`.convert_and_call()` entirely since they don't go through `svrep`.
Option B: An entirely separate internal dispatch that `create_bootstrap_weights()`
routes to when the type is NPS-specific.
Recommendation: Option A — keep the function body as the single entry point
and hide the complexity in private helpers, consistent with how the existing
code uses `.validate_replicate_input()` and `.convert_and_call()`.

**Q2: How are the within-draw calls to `rake()` / `calibrate()` structured?**
The existing `rake()` and `calibrate()` functions accept a `survey_nonprob`
or `survey_taylor` as input and return an updated design. Within the bootstrap
loop, the input will be a temporary design built from the resampled rows.
Confirm that `rake()` and `calibrate()` can accept a bare `survey_nonprob`
constructed in-loop without issues (particularly around history and metadata
initialization).

**Q3: `targets_from_reference` flag implementation**
The automatic Level A/B detection requires knowing whether the calibration
targets in the history were derived from the reference survey or from
population benchmarks. This flag must be set by `rake()` / `calibrate()` when
those functions are called after `ipw()` and the user supplies targets
estimated from the reference design. The spec for `rake()` / `calibrate()`
may need a small addition to record this. Alternatively, the bootstrap can
inspect the history entry's `population` field and compare it to estimates
from the reference — but the explicit flag is simpler and more reliable.

**Q4: B (replicates) for the NPS types**
The within-draw re-estimation is substantially more expensive than the static
weight matrix construction used by the probability-sample types. The default
of 500 is probably too high for routine use; 200 may be a more practical
default for `type = "quasi-randomization"` and `type = "hybrid"`. This is a
UX decision for the spec.
