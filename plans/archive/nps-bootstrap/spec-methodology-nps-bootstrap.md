# NPS Bootstrap Methods: Quasi-Randomization and Hybrid Bootstrap

**Status:** Methodology-locked v1.1 — 12 issues resolved (2026-05-20).
Pre-spec reference for the formal spec for the NPS bootstrap additions to
`create_bootstrap_weights()`.

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

**Statistical assumption:** Quasi-randomization bootstrap validity requires
bounded pseudo-inclusion probabilities: $0 < \hat{\phi}_i < 1$ for all units.
The `trim` parameter in the `ipw()` call enforces this in practice. When
trimming is disabled, extreme propensities will produce high-variance or
unstable bootstrap estimates.

### Algorithm

There are two levels, selected automatically based on the `targets_from_reference`
flag in the `ipw()` history entry. Both levels require a reference design to be
present (either in the history entry or passed as `reference_sample`).

**Level A — Reference held fixed** (`targets_from_reference = FALSE`)

Applies when calibration targets come from population benchmarks (Census/ACS).
The reference design is used for propensity re-estimation in each draw but is
NOT resampled. Captures adjustment uncertainty (pseudo-sampling variability and
propensity model uncertainty) but does not propagate reference survey variance.

> **Note:** Holding the reference design fixed omits reference survey sampling
> variance from the bootstrap. When the reference sample is small or propensity
> estimates are reference-sample-sensitive, this produces anti-conservative
> (downward-biased) variance estimates. Level B is preferred when calibration
> targets are estimated from the reference survey rather than from population
> registers.

For each draw $b = 1, \ldots, B$:

1. Resample $\mathcal{S}_A^{(b)}$ from the NPS $\mathcal{S}_A$: draw $n_A$
   units with replacement (SRS bootstrap). $\mathcal{S}_A^{(b)}$ is
   represented as a data frame with $n_A$ rows where unit $i$ appears
   $m_i^{(b)}$ times (duplicate rows). Each duplicated row carries the
   original base weight $w_i$.

2. Re-run the full weighting history on $\mathcal{S}_A^{(b)}$ using the
   history entries stored in `@metadata@weighting_history`:
   - Re-run `ipw()` with the fixed (un-resampled) reference design and
     resampled NPS. The propensity model specification (formula, method,
     handling of reference design weights) is owned by the `ipw()` spec;
     the bootstrap calls `ipw()` with the same `formula` and `method` from
     the stored history entry.
   - Re-run `rake()` / `calibrate()` with the original fixed calibration
     targets (population benchmarks are treated as constants).

3. Compute $\hat{\theta}^{(b)}$ on the resampled, re-weighted data.

**Level B — Reference resampled** (`targets_from_reference = TRUE`)

Applies when calibration targets were derived from the reference survey rather
than from population registers. Both the NPS and the reference design are
resampled independently, propagating variance from both sources. This is the
correct approach when raking targets come from another survey (e.g., NPORS)
rather than from population registers.

For each draw $b = 1, \ldots, B$:

1. Resample $\mathcal{S}_A^{(b)}$ as in Level A (SRS with replacement,
   duplicate-row representation with original base weights).

2. Resample $\mathcal{S}_B^{(b)}$ from the reference probability sample
   $\mathcal{S}_B$ according to its own design (using the `survey_taylor`
   stored in the `ipw` history entry, via `svrep::as_bootstrap_design()`
   internally). The two resamples are **independent**.

3. Re-run `ipw()` on $\mathcal{S}_A^{(b)} \cup \mathcal{S}_B^{(b)}$ to
   re-estimate pseudo-inclusion probabilities $\hat{\phi}_i^{(b)}$ from the
   propensity model (same formula and method as in the stored history entry).
   The handling of reference design weights within the propensity model is
   specified in the `ipw()` spec; the bootstrap calls `ipw()` as-specified.

4. Compute IPW weights:
   $$w_i^{(b)} = \frac{1 - \hat{\phi}_i^{(b)}}{\hat{\phi}_i^{(b)}} \quad \text{(Hájek)} \qquad \text{or} \qquad w_i^{(b)} = \frac{1}{\hat{\phi}_i^{(b)}} \quad \text{(HT)}$$
   The type (Hájek vs. HT) is read from the stored `ipw` history entry. The
   Hájek weight stored here is the raw odds ratio $(1 - \hat{\phi}_i)/\hat{\phi}_i$;
   normalization (dividing by sum of weights) is performed within the estimator
   calculation, not in weight storage.

5. Re-run `rake()` / `calibrate()` with perturbed calibration targets
   re-estimated from $\mathcal{S}_B^{(b)}$:
   - For `type = "prop"` (proportion-based) margins:
     $$t_{j,c}^{(b)} = \frac{\sum_{k \in \mathcal{S}_B^{(b)},\, x_{jk}=c} w_k^B}{\sum_{k \in \mathcal{S}_B^{(b)}} w_k^B}$$
     where $w_k^B$ are the reference design weights for unit $k$.
   - For `type = "count"` (count-based) targets: the weighted sum
     $\sum_{k \in \mathcal{S}_B^{(b)},\, x_{jk}=c} w_k^B$ scaled by the
     reference population size.

6. Compute $\hat{\theta}^{(b)}$ on the re-weighted $\mathcal{S}_A^{(b)}$.

### Variance formula

Using the MSE formulation (consistent with `mse = TRUE` throughout
`create_*_weights()`):

$$\hat{V}(\hat{\theta}) = \frac{1}{B} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \hat{\theta}\right)^2$$

where $\hat{\theta}$ is the full-sample estimate. With `mse = FALSE`, use:

$$\hat{V}(\hat{\theta}) = \frac{1}{B - 1} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \bar{\theta}^{(B)}\right)^2$$

**Full-sample estimate:** $\hat{\theta}$ is computed from the original
(pre-bootstrap) NPS data using the final weighting step in
`@metadata@weighting_history` — i.e., the calibrated IPW weights produced by
the last `rake()` or `calibrate()` step, or the raw IPW weights if no
calibration step follows.

### Automatic Level A/B detection

Detection is based on the `targets_from_reference` flag in the `ipw` history
entry: if `targets_from_reference = TRUE`, Level B is used; otherwise Level A.
A reference design must be present regardless of level — if `reference_design`
is `NULL` in the history entry AND `reference_sample` is not provided, the
error `surveywts_error_qr_bootstrap_no_reference` is raised before reaching
the Level A/B branch. The `reference_sample` argument takes precedence over
the stored history entry for the reference design object itself.

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

5. Compute the estimator $\hat{\theta}^{(b)}$ from $\{\hat{y}_i^{(b)}\}$:
   - **Population mean:** $\hat{\theta}^{(b)} = \frac{1}{n_A} \sum_{i \in \mathcal{S}_A^{(b)}} \hat{y}_i^{(b)}$
   - **Population total:** $\hat{\theta}^{(b)} = \frac{N}{n_A} \sum_{i \in \mathcal{S}_A^{(b)}} \hat{y}_i^{(b)}$,
     where $N$ is the population size.
   - **With auxiliary weights $w_i$** (e.g., from quota allocation): multiply
     $\hat{y}_i^{(b)} \cdot w_i$ and normalize accordingly.

### Variance formula

Same MSE formulation as quasi-randomization:

$$\hat{V}(\hat{\theta}) = \frac{1}{B} \sum_{b=1}^{B} \left(\hat{\theta}^{(b)} - \hat{\theta}\right)^2$$

**Full-sample estimate:** $\hat{\theta}$ is computed using the imputation
model $\hat{m}(\mathbf{x})$ fitted on the full (pre-bootstrap) reference
sample $\mathcal{S}_B$, applied to the full original NPS dataset
$\mathcal{S}_A$.

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
  replicates = 500L,          # probability-sample types default
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

**`replicates` default for NPS types:** When `type` is `"quasi-randomization"`
or `"hybrid"`, the default is `replicates = 200L` — lower than the 500L
default for probability-sample types, reflecting the substantially higher
per-replicate cost (each draw re-fits the propensity or imputation model).
Document in the function that `replicates = 500` is recommended for final
published estimates.

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
| `type = "quasi-randomization"`, no reference found anywhere (`reference_design = NULL` in history AND `reference_sample` not provided) | `surveywts_error_qr_bootstrap_no_reference` |
| `type = "hybrid"`, no mass imputation history entry found | `surveywts_error_hybrid_bootstrap_no_imputation_history` |
| `type = "hybrid"`, mass imputation history has no reference design (`reference_design = NULL`) AND `reference_sample` not provided | `surveywts_error_hybrid_bootstrap_no_reference` |
| `reference_sample` is not a `survey_taylor` | `surveywts_error_reference_sample_class` |

**`reference_design = NULL` in the ipw or mass imputation history entry counts
as "no reference found." The error fires whenever `reference_design` is `NULL`
in the history entry AND the `reference_sample` argument is not provided.**

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

---

## Methodology Review: nps-bootstrap — Pass 1 (2026-05-20)

### Scope Assessment

Stage 2 applies in full. This feature implements bootstrap variance estimation
for non-probability samples, defines statistical estimators (IPW Hájek/HT),
involves a multi-step iterative loop with within-draw model re-fitting, states
variance formulas, and rests on the quasi-randomization and hybrid bootstrap
frameworks. All five lenses are active.

---

### New Issues

#### Lens 1 — Method Validity

---

**Issue 1: Level A/B definition is internally contradictory and the detection criterion is wrong**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

The Level A section states: "Applies when calibration targets come from
population benchmarks (Census/ACS) and **no reference design is stored or
passed**." But Level A step 2 then says: "Re-run `ipw()` with the **fixed
reference data** and resampled NPS." These two statements cannot both be true.
If no reference design is stored or passed, there is no reference data with
which to re-run `ipw()`.

The automatic detection reinforces the problem: "If a reference sample is
accessible… Level B is used. Otherwise Level A." Under this rule, Level A is
the no-reference fallback — but then Level A's algorithm (step 2) references
data that doesn't exist.

Root cause: the spec conflates two distinct questions:
1. Is reference data available at all? (availability question)
2. Should the reference data be held fixed or resampled? (resampling question)

The validation table shows `surveywts_error_qr_bootstrap_no_reference` fires
when "no reference found anywhere" — meaning the error catches the no-reference
case, and Level A/B should only be reached when reference IS available.
Therefore Level A cannot mean "no reference available."

Options:
- **[A] Redefine Level A/B based on `targets_from_reference` flag, not reference availability:** Both levels require reference data. Level A = reference held fixed (targets from population benchmarks, propensity model re-run on fixed reference data). Level B = reference resampled (targets from reference survey, both propensities and calibration targets re-estimated). Detection criterion: `targets_from_reference = TRUE` → Level B; `targets_from_reference = FALSE` → Level A. Effort: low (editorial), Risk: low, Impact: makes the spec internally coherent, Maintenance: flag already in Q3.
- **[B] Redefine Level A as a true no-reference bootstrap that does not re-run `ipw()`:** Level A holds the original propensity estimates fixed and applies only NPS resampling variance. This captures "how much would estimates vary if different NPS units were selected, keeping propensities fixed." Level B re-estimates propensities from a resampled reference. Detection: reference available → Level B; reference not available → Level A. Effort: medium (requires specifying how fixed propensities are applied), Risk: medium (statistically inferior, misses adjustment uncertainty), Impact: different estimand than stated.
- **[C] Do nothing** — Step 2 of Level A cannot be implemented as written; the contradiction will surface immediately when ipw() is called on a null reference.

**Recommendation: [A]** — Redefining Level A/B via `targets_from_reference` is the statistically coherent choice and is already prepared by Q3. Option B produces a statistically inferior estimator that doesn't capture adjustment uncertainty, which contradicts the stated goal of the quasi-randomization bootstrap.

---

**Issue 2: `reference_sample` override for hybrid bootstrap conflicts with the validation table**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The API section states: "`reference_sample`: Required for `type = 'hybrid'` if no mass imputation history entry is found with a stored reference design." This implies `reference_sample` can substitute for a missing reference design in the history.

The validation table states: "`type = 'hybrid'`, mass imputation history has no reference design → `surveywts_error_hybrid_bootstrap_no_reference`." This fires unconditionally, with no exception for `reference_sample`.

The quasi-randomization validation row correctly says "no reference found anywhere" (implying both history and argument are checked). The hybrid row does not have this formulation, making the two rules inconsistent with each other.

Options:
- **[A] Update hybrid validation row to match quasi-randomization pattern:** Change to "type = 'hybrid', mass imputation history has no reference design **AND `reference_sample` not provided**" → error. Effort: low (editorial), Risk: low, Impact: closes the conflict.
- **[B] Do nothing** — The API description and validation table will generate conflicting implementations.

**Recommendation: [A]** — A one-line fix in the validation table.

---

**Issue 3: Behavior when `ipw()` history entry exists but `reference_design` field is NULL**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The required ipw() history entry structure includes `reference_design = <survey_taylor>`. But the spec does not state what happens when `ipw()` was called without a reference sample (resulting in `reference_design = NULL`). The error `surveywts_error_qr_bootstrap_no_reference` is defined for "no reference found anywhere" — does a NULL `reference_design` in the history count as "not found"?

Without this being explicit, an implementer may write code that treats `reference_design = NULL` differently from a missing field, or vice versa.

Options:
- **[A] Specify explicitly:** `reference_design = NULL` in the ipw history entry counts as "no reference found." The validation error fires whenever `reference_design` is NULL in the history AND `reference_sample` argument is not provided. Effort: low (editorial), Risk: low, Impact: closes an implementation ambiguity.
- **[B] Do nothing** — risk of divergent implementations.

**Recommendation: [A]**

---

#### Lens 2 — Variance Estimation Validity

---

**Issue 4: Full-sample estimate θ̂ is not defined for either bootstrap type**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The variance formula references θ̂ as "the full-sample estimate" but does not specify what estimator produces it for either bootstrap type:

- For quasi-randomization: θ̂ should be computed using the final IPW (+ calibrated) weights on the full original dataset, not the bootstrap resamples.
- For hybrid: θ̂ should use the mass imputation estimator applied to the full original NPS dataset with the fitted imputation model from the full reference sample.

Without this definition, a user who computes θ̂ using a different weighting scheme (e.g., design weights rather than calibrated IPW weights) will get a wrong centering point in the MSE formula.

Options:
- **[A] Add a "Full-sample estimate" subsection under each method's "Variance formula" section:** For quasi-randomization: "θ̂ is the estimate computed from the original (pre-bootstrap) NPS data using the final weighting step in `@metadata@weighting_history`." For hybrid: "θ̂ is the estimate computed using `m̂(x)` fitted on the full reference sample applied to the full NPS dataset." Effort: low, Risk: low, Impact: eliminates centering ambiguity.
- **[B] Do nothing** — the MSE formula is ambiguous and an implementer may compute the wrong θ̂.

**Recommendation: [A]**

---

**Issue 5: Level A variance understatement when reference survey variance is non-negligible**
Severity: SUGGESTION
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec notes Level A "does not propagate reference survey variance." However it does not warn that Level A will produce **downwardly biased** (anti-conservative) variance estimates in situations where the reference survey's sampling error meaningfully contributes to uncertainty in the propensity estimates. This is most likely when:
- The reference sample is small relative to the NPS
- The propensity model is sensitive to reference sample composition

Users who fall into Level A (under the revised definition from Issue 1 resolution) may not realize their standard errors are understated.

Options:
- **[A] Add a brief note under Level A:** "Note: holding the reference design fixed omits reference survey sampling variance from the bootstrap. When the reference sample is small or propensity estimates are reference-sample-sensitive, this produces anti-conservative (downward-biased) variance estimates. Level B is preferred when the reference survey is available." Effort: low, Risk: low, Impact: user awareness.
- **[B] Do nothing** — the omission is implicit in "does not propagate reference survey variance."

**Recommendation: [A]**

---

#### Lens 3 — Algorithmic Correctness

---

**Issue 6: No formula for re-estimating calibration targets from S_B^(b) in Level B step 5**
Severity: BLOCKING
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

Level B step 5 states: "If targets were derived from the reference survey (flag in history): re-estimate the calibration targets from S_B^(b), then re-run raking/calibration with the perturbed targets." No formula is given.

The implementer needs to know: given the resampled reference survey S_B^(b) with design weights {w_k^B}, what computation produces the perturbed target margins?

For raking (proportion-based margins), the natural formula is:
$$t_{j,c}^{(b)} = \frac{\sum_{k \in \mathcal{S}_B^{(b)},\, x_{jk}=c} w_k^B}{\sum_{k \in \mathcal{S}_B^{(b)}} w_k^B}$$

For calibration (count-based targets), the formula adjusts by the reference population size. Neither case is specified.

This gap cannot be resolved at implementation time without introducing unspecified design choices.

Options:
- **[A] Add target re-estimation formula to Level B step 5:** Specify separately for `type = "prop"` and `type = "count"` targets, referencing the reference design's survey weights as the correct weighting for the estimate. Effort: low, Risk: low, Impact: makes Level B implementable without guessing.
- **[B] Do nothing** — implementer guesses; choices may differ from author intent and from each other.

**Recommendation: [A]**

---

**Issue 7: B default for NPS types is unresolved (Q4)**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

Open question Q4 explicitly defers the B default to "the spec." The current methodology document is that spec — the decision must be made here before handoff to the implementation plan. The within-draw cost of NPS types is O(n_A · model_fit_time) per replicate, which is orders of magnitude higher than the static matrix construction used by probability-sample types.

Options:
- **[A] Set default B = 200 for NPS types:** Lower than the 500 default for probability-sample types, reflecting the computational cost. Document that B = 500 is recommended for final estimates. Effort: low, Risk: low (users can always increase B), Impact: acceptable trade-off between variance estimation precision and runtime for exploratory use.
- **[B] Set default B = 500 (same as probability-sample types):** Consistent API surface, but may make exploratory use prohibitively slow when propensity model or imputation model fit is expensive. Effort: low, Risk: medium (user friction), Impact: slower default experience.
- **[C] Set default B = NULL and require the user to specify:** Forces awareness of the computational cost, but breaks the no-required-argument convention of all other `create_*_weights()` functions.

**Recommendation: [A]** — B = 200 with a note that larger B improves precision. Matches the pattern used by other packages (e.g., `svrep` recommends 200–500; the expensive re-fitting makes 200 the right floor).

---

**Issue 8: How S_A^(b) is represented when passed to rake() / calibrate() is unspecified**
Severity: SUGGESTION
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The bootstrap loop draws n_A units with replacement from the NPS data. This produces a bootstrap sample where some rows appear multiple times. But `rake()` and `calibrate()` accept a data frame where each row is one unit. The spec does not state whether:
- The resampled data frame has n_A rows with duplicates (units appearing m_i^(b) times have m_i^(b) rows), or
- The original n_A rows are passed with a bootstrap weight multiplier (w_i · m_i^(b)), or
- Some other representation

The choice affects how `rake()` and `calibrate()` converge within the draw: raking treats each row as one unit, so duplicate rows will appear as multiple observations with equal base weight. Whether this produces the correct bootstrap weights depends on the approach.

Options:
- **[A] Specify the n_A-row duplicate-row representation:** "Within each draw, S_A^(b) is constructed as a data frame with n_A rows, where unit i appears m_i^(b) times. The base weight for each row in S_A^(b) is the original base weight w_i." Effort: low, Risk: low.
- **[B] Do nothing** — the open question Q2 defers this to engineering, but Q2 asks about whether `rake()` can handle in-loop objects, not about the representation format. Both questions need answering.

**Recommendation: [A]**

---

#### Lens 4 — Statistical Assumptions

---

**Issue 9: Positivity assumption for quasi-randomization bootstrap is unstated**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The quasi-randomization framework (Elliott & Valliant 2017; Wu 2022) requires bounded pseudo-inclusion probabilities: 0 < φ_i < 1 for all units. When φ_i → 0 or φ_i → 1, IPW weights become extreme and bootstrap variance estimates become unstable or undefined. The spec mentions a `trim` parameter in the ipw history entry but does not state positivity as a requirement for bootstrap validity.

Options:
- **[A] Add a brief assumption statement:** "Quasi-randomization bootstrap validity requires bounded pseudo-inclusion probabilities: 0 < φ_i < 1 for all units. The `trim` parameter in the `ipw()` call imposes this in practice. When trimming is disabled, extreme propensities will produce high-variance or unstable bootstrap estimates." Effort: low, Risk: low.
- **[B] Do nothing** — implicit in the `trim` field of the history entry.

**Recommendation: [A]**

---

**Issue 10: How reference survey design weights are used in the combined-dataset propensity model (Level B, step 3) is unspecified**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: JUDGMENT CALL

Level B step 3: "Re-run `ipw()` on S_A^(b) ∪ S_B^(b) to re-estimate pseudo-inclusion probabilities from the propensity model."

The propensity model is a binary membership model (indicator: 1 = reference sample, 0 = NPS). When combining S_A^(b) and S_B^(b), the reference units have design weights from their probability sample. The spec does not state whether these design weights are used in the propensity model:

- If they are **not** used: each reference unit gets equal weight 1, which underweights reference units from oversampled strata and overweights those from undersampled strata. This produces biased propensity estimates.
- If they are **used**: the logistic regression is fitted with weights equal to the reference design weights for reference units and 1 for NPS units (or some normalization thereof).

The statistical literature (Elliott & Valliant 2017, Wu 2022) typically uses the design-weighted version for reference units. This must be specified to ensure implementers do not inadvertently use the unweighted version.

Options:
- **[A] Specify that reference survey design weights are used in the propensity model:** "In the propensity model for ipw(), reference sample units are weighted by their survey design weights w_k^B (from the `survey_taylor` reference design). NPS units are unweighted (or equivalently, given weight 1). This is required to produce design-consistent pseudo-inclusion probabilities." Effort: low (editorial), Risk: low, Impact: ensures design-consistent propensity estimation.
- **[B] Defer to the `ipw()` spec:** The propensity model specification belongs in the `ipw()` spec; the bootstrap just calls `ipw()` as specified there. The quasi-randomization bootstrap spec only needs to confirm it uses the same `formula` and `method` from the history entry. Effort: low, Risk: medium (ipw() spec may not yet exist when bootstrap is implemented), Impact: creates a dependency.
- **[C] Do nothing** — risk of non-design-consistent propensity estimation.

**Recommendation: [B]** — The ipw() spec owns the propensity model specification. The bootstrap spec should note that it calls ipw() with the same formula and method from the history entry and that design weights are handled by ipw(). This defers correctly to the propensity release without duplicating the specification.

---

#### Lens 5 — Formula Integrity

---

**Issue 11: Within-draw estimator formula for hybrid bootstrap is absent**
Severity: REQUIRED
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

Hybrid bootstrap step 5: "Compute the estimator θ̂^(b) from {ŷ_i^(b)}, applying any design weights from S_A^(b) as appropriate." No formula is given.

For a mass imputation estimator of a population mean:
$$\hat{\theta}^{(b)} = \frac{\sum_{i \in \mathcal{S}_A^{(b)}} \hat{y}_i^{(b)}}{\left|\mathcal{S}_A^{(b)}\right|}$$

(unweighted, since NPS units have no design weights). For a ratio estimator involving auxiliary weights, the formula differs. The phrase "as appropriate" is not a formula — an implementer cannot determine from this what to compute.

This must be specified before implementation, or implementers in different parts of the codebase will produce incompatible definitions of θ̂^(b) and θ̂.

Options:
- **[A] Specify the hybrid bootstrap estimator formula explicitly:** "θ̂^(b) = (1/n_A) Σ_{i ∈ S_A^(b)} ŷ_i^(b) for a population mean, or Σ_{i ∈ S_A^(b)} ŷ_i^(b) for a population total (scaled by N/n_A where N is the population size). If NPS units carry auxiliary weights w_i (e.g., from a quota allocation), multiply ŷ_i^(b) · w_i and normalize accordingly." Effort: low, Risk: low, Impact: closes the formula gap.
- **[B] Do nothing** — formula gap left to implementation; inconsistencies likely.

**Recommendation: [A]**

---

**Issue 12: Hájek vs HT formula notation needs a denominator clarification**
Severity: SUGGESTION
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The spec gives the Hájek weight as:
$$w_i^{(b)} = \frac{1 - \hat{\phi}_i^{(b)}}{\hat{\phi}_i^{(b)}}$$

This is correct for the odds-based Hájek IPW weight used in the quasi-randomization framework. However, the standard Hájek estimator for a mean uses a normalized version of this weight:
$$\bar{Y}_{HAJ} = \frac{\sum_{i \in S_A} w_i \hat{Y}_i}{\sum_{i \in S_A} w_i}$$

The spec does not state whether the stored Hájek weight is the raw odds (1 − φ̂_i)/φ̂_i or a normalized version (divided by sum of weights to calibrate to n or N). This matters because the MSE formula must use a consistent weight definition across the full-sample θ̂ and each replicate θ̂^(b).

Options:
- **[A] Add a sentence clarifying the weight normalization:** "The Hájek weight stored in the history entry and re-computed in each bootstrap draw is the raw odds ratio (1 − φ̂_i)/φ̂_i; normalization (dividing by sum of weights) is performed within the estimator calculation, not in the weight storage." Effort: low, Risk: low.
- **[B] Do nothing** — the normalization is implicit in standard IPW practice, and the formula is formally correct as stated.

**Recommendation: [A]** — The interaction between stored weights and the bootstrap re-computation is a potential source of implementer error that a single clarifying sentence removes.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 5 |
| SUGGESTION | 5 |

**Total issues:** 12

**Overall assessment:** The quasi-randomization and hybrid bootstrap algorithms are grounded in the correct statistical literature and the high-level design is sound, but two blocking structural problems — the self-contradictory Level A/B definition and the missing target re-estimation formula for Level B — will prevent correct implementation without resolution. The five required issues (undefined θ̂, undefined θ̂^(b) for hybrid, unresolved B default, validation table conflict, and propensity model weights) are straightforward to fix editorially. None of the issues indicate a fundamental error in the chosen methods; they are specification gaps, not method errors.
