# Methodology Review: group-jackknife — Pass 1 (2026-05-27)

## Scope Assessment

All Stage 2 trigger conditions are met. The feature:
- Implements a statistical variance estimator (DAGJK) producing replicate
  weights with known statistical properties
- Involves an iterative logistic regression algorithm refit in every replicate
- Produces numerical replicate weight quantities that must be exactly specified

**Lenses applied:** 1, 2, 3, 4, 5, 6 (comprehension.md is present)

---

### New Issues

#### Lens 1 — Method Validity

**Issue 1: Reference weight adjustment formula uses wrong N_hat definition per replicate**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec (§3 "Estimation pipeline per replicate", step 2a) defines:
```
N_hat    = sum(w_ref) over all reference units not in group g
n_nps_g  = number of NPS units not in group g (unweighted count)
w_ref_adj[i] = w_ref[i] * (N_hat - n_nps_g) / N_hat
```

The `N_hat` definition here is **within-replicate**: the sum of reference
weights for units remaining after group deletion. This is correct per the
DAGJK logic (replicate g should use only the reference units that remain in
replicate g). However, this conflicts with the comprehension.md (§Formulas,
step 2a), which defines:

```
w_ref_adj[i] = w_ref[i] * (N_hat - n_nps) / N_hat
where N_hat = sum(w_ref) over all reference units,
and n_nps = number of NPS units (count, not sum of weights).
```

The comprehension.md formula uses `N_hat` = sum over **all** reference units
(full-sample denominator), and `n_nps` = number of NPS units in the **full**
combined dataset — not the within-replicate counts. The spec changes both
quantities to their within-replicate versions without citing a source for this
modification.

Valliant (2020) Eq. 1 gives the adjustment as `w_i* = w_i(N_hat - n) / N_hat`
where `n` is the NPS count and `N_hat = sum(w_ref)` over the full reference
sample. This is the full-sample formula. The spec applies this adjustment
*within each replicate* with replicate-level quantities — which changes the
formula's meaning. The statistical justification for this within-replicate
modification is not stated.

There are two distinct choices, and the spec conflates them:
- **Full-sample N_hat** (Valliant 2020 Eq. 1): N_hat is computed once from
  the full reference sample. n_nps is the full NPS count. Adjustment does not
  vary per replicate.
- **Within-replicate N_hat** (the spec's formula): N_hat and n_nps_g are
  recomputed after group deletion. The adjustment changes per replicate.

The within-replicate approach is arguably more internally consistent with the
DAGJK replication logic (it matches the data actually available in replicate g),
but this is a methodological choice that requires explicit citation or
justification. Without one, an implementer cannot know which formula was
intended, and the two formulas produce different variance estimates.

Options:
- **[A]** Adopt within-replicate N_hat and n_nps_g (as currently written), add
  explicit methodological justification or note that this is an extension of
  Valliant (2020) Eq. 1 applied within-replicate — Effort: low, Risk: low,
  Impact: correct formula, Maintenance: none
- **[B]** Revert to full-sample N_hat and n_nps (matching comprehension.md
  step 2a verbatim) and note that the adjustment does not vary per replicate —
  Effort: low, Risk: low, Impact: matches literature directly, Maintenance: none
- **[C] Do nothing** — Implementers will not know which formula to use; the
  two are silently inconsistent between spec and comprehension.md.

**Recommendation: A** — The within-replicate approach is more principled for
DAGJK (the replicate should reflect the state of the world without group g),
but the spec must state this choice explicitly and note the departure from
the comprehension.md literal formula.

---

**Issue 2: `groups > combined N` edge case allows 0- or 1-unit replicates with no methodological floor**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

The spec (§3 Errors table) requires `groups > combined N` to error with
`surveywts_error_dagjk_groups_exceeds_n`. The rationale given is "cannot form
non-empty groups." This is the correct extreme-bound error. However, the spec
does not address the case where `groups` is large relative to N but less than N
— e.g., `groups = N - 1`, which would produce groups of size 1 or 2. With
single-unit groups, each replicate removes one unit from the combined dataset.
For the logistic model, single-unit deletion groups are equivalent to
leave-one-out jackknife — which the comprehension.md explicitly notes is
problematic (§Gotchas: "degenerate groups / single-unit groups"). The logistic
model can fail with a singleton covariate level removed.

The spec's only safeguard is the per-replicate failure mechanism (if the model
fails to converge, that replicate is skipped). This may result in a large
fraction of replicates failing if `groups` is chosen poorly relative to N.
There is no recommended upper bound on `groups` relative to combined N, and no
warning when groups are very small on average (combined_N / groups < some
threshold).

Options:
- **[A]** Add a `SUGGESTION`-level warning `surveywts_warning_dagjk_small_groups`
  when `floor(combined_N / groups) < some_threshold` (e.g., 5 units per group
  average) to alert users to potential convergence problems — Effort: low,
  Risk: low, Impact: better diagnostics, Maintenance: none
- **[B]** Add a hard upper bound error `surveywts_error_dagjk_groups_too_large`
  when `groups > combined_N / k` for some floor k — Effort: low, Risk: medium
  (the threshold k is arbitrary), Impact: prevents degenerate usage,
  Maintenance: low
- **[C] Do nothing** — Rely on the existing failure-fraction warning
  (`surveywts_warning_dagjk_replicates_failed` at > 10% failure rate) as the
  only signal; users must diagnose the cause.

**Recommendation: A** — A diagnostic warning at a soft threshold is more
helpful than a hard error at an arbitrary bound, and aligns with the
comprehension.md gotcha on group size.

---

**Issue 3: `reference_sample` restriction to `survey_taylor` excludes valid SRS inputs**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

The spec restricts `reference_sample` to `survey_taylor`, erroring on
`survey_replicate`. The motivating use case is clear: the reference probability
sample must carry design information (weights, strata, PSU). However, many
practitioners store a simple random reference sample as a plain `data.frame`
or `weighted_df` — particularly when every unit has equal probability of
selection and the reference is treated as effectively SRS. The spec explicitly
excludes `data.frame` and `weighted_df` inputs as `data` but does not state
whether they are accepted or rejected as `reference_sample`.

The current argument table says `reference_sample` accepts "`survey_taylor`
or `NULL`". A `data.frame` or `weighted_df` passed as `reference_sample` will
hit an unspecified error path — presumably the existing
`surveywts_error_reference_sample_class` — but the spec does not state this
explicitly, and the error message may be confusing if a user passes a data
frame thinking it will be treated as SRS.

This is distinct from Issue 1: the question here is whether the class
restriction is appropriate, not what formula to apply.

Options:
- **[A]** Explicitly document that `data.frame` / `weighted_df` as
  `reference_sample` errors with `surveywts_error_reference_sample_class`, and
  add an `"i"` bullet in that error explaining how to convert an SRS data
  frame to `survey_taylor` — Effort: low, Risk: low, Impact: clearer user
  guidance, Maintenance: none
- **[B]** Accept `data.frame` as `reference_sample` and internally convert it
  to uniform weights (SRS treatment) — Effort: medium, Risk: medium (implicit
  SRS assumption may be wrong), Maintenance: ongoing
- **[C] Do nothing** — Users hitting this will get a class error without
  actionable guidance.

**Recommendation: A** — The `survey_taylor` restriction is methodologically
defensible (reference design information is needed to construct reference
weights). The gap is in user guidance, not in the restriction itself.

---

#### Lens 2 — Variance Estimation Validity

**Issue 4: Degrees of freedom for downstream inference are unspecified**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec never states the degrees of freedom (df) associated with the DAGJK
variance estimator. The standard result for the grouped jackknife is
`df = G - 1` (Krewski and Rao 1981 analogy). Without an explicit df statement,
users applying the replicate weights for t-tests or confidence intervals via
`survey::svydesign()` / `svrep` will use whatever default df the downstream
package supplies. In `survey`, the default for replicate designs is often
`df = length(repweights) - 1 = G_success - 1`, which is correct — but this
is only coincidentally correct and relies on undocumented behavior in the
downstream package.

The spec should state that df = G_success - 1, where G_success is the number
of successful replicates, consistent with the grouped jackknife formula.

The fix is an addition to the `@details` section and optionally to the Returns
description.

Options:
- **[A]** Add df = G_success - 1 to the `@details` section (alongside the
  other documented limitations) and note it in the Returns description — Effort:
  low, Risk: low, Impact: prevents silent wrong inference, Maintenance: none
- **[C] Do nothing** — Users who check downstream df may get correct results
  by accident, but the spec provides no guarantee.

**Recommendation: A** — Degrees of freedom are a direct property of the
variance estimator and must be stated.

---

**Issue 5: `mse = TRUE` semantics and centering term consistency with DAGJK formula**
Severity: BLOCKING
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec (§3 "Returns") states `@variables$mse = TRUE` and (§3 "Scaling
constants") states `scale = (G-1)/G`. The `mse = TRUE` flag in the `survey`
/ `svrep` infrastructure controls which centering term is used in the variance
estimator:

- `mse = TRUE`: variance = `scale * sum_g (theta_g - theta_full)^2` where
  `theta_full` is the **full-sample** estimate
- `mse = FALSE`: variance = `scale * sum_g (theta_g - mean(theta_g))^2` where
  the centering is the **mean of replicate estimates**

The DAGJK formula in the spec and comprehension.md is:

$$v_J(\hat\theta) = \frac{G-1}{G} \sum_{g=1}^{G} (\hat\theta_{(g)} - \hat\theta)^2$$

where `\hat\theta` is the full-sample estimate. This matches `mse = TRUE`
semantics — the centering term is the full-sample estimate, not the mean of
replicate estimates.

However, the spec does not state this connection explicitly. It asserts
`mse = TRUE` without explaining *why* `mse = TRUE` is correct for DAGJK.
An implementer who doesn't understand the `mse` flag semantics may set it
incorrectly (or toggle it in a future refactor), producing the wrong centering
and biased variance estimates.

More critically: when `mse = TRUE` and some replicates fail, the remaining
`G_success` replicates compute `(theta_g - theta_full)^2` for each surviving
replicate, and `scale = (G_success - 1) / G_success`. This differs from the
textbook DAGJK formula (which assumes all G replicates succeed). The spec
asserts this adjustment is correct (§3 "Returns": "`@variables$scale` set to
`(G - 1) / G` where G is the number of successful replicates") but provides
no statistical justification. Is dropping failed replicates and adjusting G
to G_success statistically valid? The comprehension.md does not address this.

Options:
- **[A]** Add to `@details`: (1) a sentence explaining why `mse = TRUE` is
  correct for DAGJK (centering on the full-sample estimate matches the DAGJK
  formula), and (2) a sentence acknowledging that the failed-replicate
  adjustment to G_success is a pragmatic approximation without formal
  statistical justification — Effort: low, Risk: low, Impact: documents the
  choice, Maintenance: none
- **[B]** Add a formal justification citation for the G_success adjustment — if
  one exists in the literature — Effort: medium, Risk: low, Impact: stronger
  claim, Maintenance: none
- **[C] Do nothing** — `mse = TRUE` is set correctly but the reasoning is
  opaque to implementers and users.

**Recommendation: A** — The mse flag must be explained, and the failed-replicate
adjustment must be documented as an approximation.

---

**Issue 6: Calibration targets from reference — target re-estimation scope is underspecified**
Severity: BLOCKING
Lens: 2 — Variance Estimation Validity
Resolution type: JUDGMENT CALL

The spec (§3, step 2e) states:

> "If the history entry has `parameters$targets_from_reference = TRUE`,
> re-estimate targets from the reduced reference replicate (consistent with
> Level B in the quasi-randomization bootstrap)."

This is the only case handled. But the spec does not specify what happens
when the calibration targets were **not** derived from the reference sample
— i.e., when `targets_from_reference = FALSE` or is absent from the history
entry. In that case, targets come from an external source (a published
population margin, a Census table, etc.).

The question is: should those fixed external targets be re-used as-is in every
replicate, or should they be perturbed? The standard answer in replicate-weight
theory is: fixed external targets are used as-is (they are population constants,
not estimated from the data). But the spec does not state this. An implementer
who does not know the convention may attempt to re-estimate targets from the
reference even when `targets_from_reference = FALSE`, or may incorrectly drop
the calibration step.

The variance implications are real: if external targets are mistakenly
re-estimated from the reduced reference replicate, the calibration step
absorbs replicate variation that should appear in the variance estimate,
producing downward-biased standard errors.

Additionally: even when `targets_from_reference = TRUE`, removing group-g
reference units changes the estimated population marginals. The spec says to
re-estimate from the reduced reference — but does not specify whether these
re-estimated targets are used as the calibration targets for the NPS replicate,
or as the population total (denominator in proportion-based calibration). If
the calibration is `type = "prop"`, the target proportions do not change with
sample size; if `type = "count"`, the target counts change when the reference
is reduced. The spec does not address this distinction.

Options:
- **[A]** Add to step 2e: "When `targets_from_reference = FALSE` or absent,
  use the fixed targets from the history entry unchanged in every replicate.
  When `targets_from_reference = TRUE`, re-estimate targets from the
  reduced reference replicate; for `type = 'prop'`, re-estimate the target
  proportions; for `type = 'count'`, re-estimate the target counts from the
  reduced reference sum of weights." — Effort: low, Risk: low, Impact: prevents
  silent wrong calibration, Maintenance: none
- **[B]** Always use fixed targets from history regardless of
  `targets_from_reference`, and document this as a conservative simplification
  — Effort: low, Risk: medium (may underestimate variance when targets are
  sample-estimated), Impact: simpler implementation, Maintenance: none
- **[C] Do nothing** — Implementers will infer one of the above; if they
  guess wrong, calibrated replicate estimates will be biased.

**Recommendation: A** — The distinction between fixed and sample-estimated
calibration targets has a direct impact on variance estimates. Both cases
must be specified.

---

#### Lens 3 — Algorithmic Correctness

**Issue 7: Logistic model refit — convergence parameters not specified**
Severity: BLOCKING
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec (§3, step 2b) says to refit the binary logistic model using "the same
`formula`, `method`, `estimating_eq`, and `missing_method` recorded in the
`ipw()` history entry." It does not specify whether `ipw()` records convergence
parameters (`maxit` and `epsilon`) in its history entry, and if so, whether
those parameters are reused in the replicate fits.

From the `ipw()` function signature (surveywts-conventions.md):
```r
ipw(..., maxit = 25L, epsilon = 1e-8, ...)
```

These convergence parameters are part of the estimation algorithm. If they are
not recorded in the `ipw()` history entry, the replicate fits will use whatever
defaults are hardcoded in `glm()` or the relevant solver — which may differ
from what the user specified in the original `ipw()` call. An `epsilon` of
`1e-6` vs `1e-8` can affect whether a borderline replicate converges or is
counted as a failure.

The spec must either:
1. Confirm that `maxit` and `epsilon` are recorded in the `ipw()` history
   entry and are reused in replicate fits, or
2. State what convergence parameters are used when they are not available in
   history (e.g., the same defaults as `ipw()`)

Options:
- **[A]** Specify that the `ipw()` history entry records `maxit` and `epsilon`,
  and that these values are reused for replicate model fits. Update the history
  entry schema in §3.6 of the spec to include these fields. — Effort: low,
  Risk: low, Impact: reproducible replicate fits, Maintenance: requires
  confirming `ipw()` records these params
- **[B]** Use fixed defaults (e.g., `maxit = 25L`, `epsilon = 1e-8`) for all
  replicate fits regardless of the original `ipw()` call, and document this —
  Effort: low, Risk: low (only matters in borderline cases), Maintenance: none
- **[C] Do nothing** — Replicate fits use unpredictable convergence thresholds,
  making DAGJK non-reproducible even with a fixed seed.

**Recommendation: A** — Convergence parameters are part of the algorithm
specification and must be reproduced faithfully. The history entry schema
should include them.

---

**Issue 8: Propensity score clipping for extreme but valid scores not specified**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

The spec (§3 Edge cases) states that degenerate propensity scores
($\hat\pi_i \leq 0$ or $\geq 1$) cause a replicate failure. This handles the
strict boundary cases. It does not address scores close to 0 or 1 (e.g.,
$\hat\pi_i = 0.001$) — which are mathematically valid but produce extreme
pseudo-weights ($w_i = 1000$ in that example).

After group deletion, the covariate distribution of the combined dataset shifts.
A unit that was borderline-extreme in the full-sample fit may receive a very
extreme propensity score in a replicate — without triggering the degenerate
score condition. These extreme pseudo-weights inflate replicate variance
estimates relative to the full-sample estimate, producing conservative
(upward-biased) variance.

The spec is silent on whether any trimming or clipping of propensity scores is
applied inside the DAGJK loop. The full-sample `ipw()` has a `trim` argument;
the DAGJK spec does not mention whether trimming is also applied per replicate,
nor whether the trim threshold from the original `ipw()` call (if any) is
reused.

Options:
- **[A]** Specify that if the original `ipw()` call used `trim`, the same
  trimming is applied to replicate propensity scores. If `trim = FALSE` in the
  original call, no trimming in replicates. This matches the history-reuse
  pattern. — Effort: low, Risk: low, Impact: consistent trim behavior,
  Maintenance: requires `trim` to be recorded in `ipw()` history
- **[B]** Explicitly state that no trimming is applied inside the DAGJK loop
  regardless of the original `ipw()` call, and document that extreme replicate
  weights are possible — Effort: low, Risk: medium (conservative bias if
  extreme weights arise), Maintenance: none
- **[C] Do nothing** — Extreme but valid propensity scores silently inflate
  variance estimates; no user guidance.

**Recommendation: A** — Consistency with the original `ipw()` call is the
principled choice. If the user trimmed in the full-sample fit, trimming in
replicates maintains consistency; the history entry should record whether trim
was applied and the threshold.

---

**Issue 9: Weight conservation — replicate pseudo-weights are not normalized**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec defines replicate pseudo-weights as $w_i^{(g)} = 1 / \hat\pi_i$ for
NPS units not in group g, and 0 for units in group g. It does not state whether
these are normalized to the estimated population total (e.g., scaled so that
`sum(w_i^{(g)})` over surviving NPS units equals `N_hat`).

The full-sample `ipw()` function may or may not normalize the pseudo-weights.
If the full-sample weights are normalized and the replicate weights are not (or
vice versa), the replicate estimates `theta_g` are computed on a different scale
than the full-sample estimate `theta`. Since the DAGJK formula subtracts
`theta_g - theta`, a scale mismatch produces biased variance estimates.

The spec must state explicitly: (a) whether replicate pseudo-weights are
normalized, and (b) whether the normalization matches the full-sample
convention in `ipw()`.

Options:
- **[A]** Add a sentence to step 2d: "The replicate pseudo-weights are scaled
  by the same convention as the full-sample `ipw()` weights — if the full-sample
  weights were normalized to sum to N_hat, replicate weights are normalized
  to sum to the within-replicate N_hat_g." — Effort: low, Risk: low, Impact:
  prevents scale mismatch, Maintenance: none
- **[B]** Explicitly state that replicate weights are NOT normalized (raw
  inverse-probability weights), matching the raw output of the full-sample
  `ipw()` call — Effort: low, Risk: medium (must verify `ipw()` also returns
  raw weights by default), Maintenance: none
- **[C] Do nothing** — Scale mismatch between replicate and full-sample
  estimates silently biases variance estimates.

**Recommendation: A** — Normalization convention must match across full-sample
and replicate estimates for the DAGJK centering term to be correct.

---

#### Lens 4 — Statistical Assumptions

**Issue 10: Non-random group structures (clustered NPS) not addressed**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: JUDGMENT CALL

The spec (§6, Assumption 4) states "Groups must be randomly assigned. Ordered
or systematic assignment may violate the independence assumption." The
comprehension.md (§Assumptions, "Independence across groups") also notes that
within-group cluster structure in the NPS is "typically unnecessary for opt-in
web surveys."

However, Elliott & Valliant (2017, §3.1, citing Brick 2015) explicitly identify
recruiting/hosting websites as natural deletion groups for NPS group jackknife.
If the NPS was recruited via multiple websites or panels, groups defined by
recruitment source are NOT random — they are clustered by recruitment mechanism.
The spec's assumption of random assignment (via the `seed` argument) would be
violated when users substitute natural groups (e.g., panel IDs) for the random
assignment.

The current spec only supports random group assignment (via `seed`). There is
no `groups` argument that accepts a pre-specified group membership vector. This
means users with natural panel/recruitment-source groups cannot use the function
with their preferred grouping — they must randomize, which throws away structure
that would improve the variance estimator.

This is both an assumption gap (random groups required but not verified against
input structure) and a scope question (should natural groups be supported).

Options:
- **[A]** Add a note to §6 (Assumptions) and `@details` stating that this
  implementation supports only random group assignment; users with natural
  cluster structure (recruitment panels, hosting websites) should use random
  groups as an approximation. Document this limitation explicitly. — Effort:
  low, Risk: low, Impact: user awareness, Maintenance: none
- **[B]** Add a `groups` argument overload that accepts a factor/integer vector
  of pre-specified group memberships, in addition to the scalar integer for
  random assignment — Effort: high, Risk: medium (out of scope for this PR?),
  Impact: supports Elliott & Valliant's natural groups use case, Maintenance:
  ongoing
- **[C] Do nothing** — Users with natural cluster groups will randomize anyway
  (the only option the function supports), potentially losing variance
  efficiency.

**Recommendation: A** — The limitation should be documented. Option B is a
genuine future enhancement but is not required for this PR.

---

**Issue 11: Common support violation within replicates not diagnosed**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The spec (§6, Assumption 2) states "Common support: Every population unit must
have positive probability of appearing in either sample. Violations manifest as
extreme pseudo-weights, best diagnosed via `ipw()` before calling this
function."

However, common support can fail *within a replicate* even when it holds in
the full sample. When group g is deleted, the covariate coverage of the
remaining combined dataset may no longer span the full covariate space. A
covariate level present only in group g becomes unobserved in that replicate,
and the logistic model either extrapolates (producing extreme propensity scores)
or fails entirely (if the covariate level creates a structural zero in the model
matrix). The spec's only safeguard is the per-replicate failure mechanism — if
propensity scores are degenerate ($\leq 0$ or $\geq 1$), the replicate fails.

But near-degenerate scores (e.g., $\hat\pi_i = 0.001$) pass the degenerate
check and produce $w_i = 1000$ without triggering any warning. The
`surveywts_warning_ipw_covariate_range_extrapolation` mechanism from `ipw()`
is not applied per replicate (the spec does not mention it).

The assumption text in §6 implies that common support is checked once at the
`ipw()` stage, but does not acknowledge that group deletion changes the
effective common support per replicate.

Options:
- **[A]** Add to §6 (Assumptions): "Common support is assessed at the
  `ipw()` stage on the full combined dataset. Replicate-level common support
  cannot be guaranteed — group deletion may reduce covariate coverage in some
  replicates, producing extreme propensity scores that inflate replicate
  variance. This is expected behavior and is partially captured by the
  negative-replicate-weight warning." — Effort: low, Risk: low, Impact:
  honest documentation, Maintenance: none
- **[B]** Add a per-replicate covariate range check (analogous to the
  `ipw()` extrapolation warning) and emit `surveywts_warning_dagjk_replicates_failed`
  when triggered — Effort: high, Risk: medium, Impact: better diagnostics,
  Maintenance: ongoing
- **[C] Do nothing** — The assumption is stated for the full sample but the
  replicate-level gap is not acknowledged.

**Recommendation: A** — The documentation should acknowledge the replicate-level
common support gap. Option B is a genuine enhancement but beyond this PR's
scope.

---

#### Lens 5 — Formula Integrity

**Issue 12: DAGJK centering term `theta` — full-sample estimate definition missing**
Severity: BLOCKING
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The comprehension.md (§Formulas) shows:

$$v_J(\hat\theta) = \frac{G-1}{G} \sum_{g=1}^{G} (\hat\theta_{(g)} - \hat\theta)^2$$

with the symbol table defining `\hat\theta` as "Full-sample point estimate —
full-sample estimate before deletion." The spec does not define `\hat\theta`
anywhere. The function produces replicate weights — it does not compute
estimates directly. Instead, downstream `survey::svymean()` etc. will use the
replicate weights to compute `theta_g` for each replicate and `theta` for the
full sample.

The question is: what is the full-sample `theta`? Specifically, is it:
(a) The estimate computed using the full-sample pseudo-weights from `ipw()`
    (before any replicate deletion), or
(b) The estimate computed using the final calibrated weights (if calibration
    was applied), or
(c) Implicitly defined by the survey infrastructure from the `@data` weight
    column, whatever that column contains at the time of the function call?

When `mse = TRUE`, the `svrep` / `survey` infrastructure computes
`theta` as the estimate from the survey design object (which uses whatever
weight column is current in `@data`). If the user called `ipw()` and then
`calibrate()` before calling `create_group_jackknife_weights()`, `@data` may
contain calibrated weights — so `theta` would be the calibration-adjusted
estimate, while `theta_g` would be the DAGJK replicate estimates. This is
correct for the DR estimator path but must be stated explicitly.

The spec says nothing about what `theta` is in the context of the downstream
variance computation, creating an ambiguity that is invisible at implementation
time but material for correctness.

Options:
- **[A]** Add to `@details` or `@return`: "The full-sample estimate `theta`
  is taken from the current weight column in `@data` (which reflects all
  weighting steps applied before this call). Replicate estimates `theta_g`
  are computed from replicate weight columns `repwt_g`. With `mse = TRUE`,
  the downstream survey infrastructure uses `theta` (full-sample) as the
  centering term, consistent with the DAGJK formula." — Effort: low, Risk:
  low, Impact: eliminates implementation ambiguity, Maintenance: none
- **[C] Do nothing** — Implementers and users must infer what `theta` is from
  the `mse` flag behavior; this is correct by coincidence but not by contract.

**Recommendation: A** — The centering term is a defining feature of the
variance estimator and must be stated.

---

**Issue 13: Scale factor adjustment for failed replicates — formula stated but not derived**
Severity: REQUIRED
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The spec states `@variables$scale = (G_success - 1) / G_success` when some
replicates fail. This is a substitution of `G_success` for `G` in the DAGJK
formula. The formula in comprehension.md is `(G-1)/G` over all G replicates.

The substitution is plausible — treat the G_success successful replicates as
the effective G — but it is not derived from the literature and has no citation.
When replicates fail at random (which the spec assumes, since failures are due
to numerical issues, not systematic exclusion), the G_success-adjusted formula
is an ad hoc approximation. Its statistical properties (bias, consistency under
random failure) are not established.

The spec should state explicitly that this is an approximation, its conditions
(random, not systematic failure), and that it has no formal justification in
the surveying literature. This is analogous to what the spec already does for
the "no formal consistency proof" assumption (§6, item 5).

Options:
- **[A]** Add a sentence to `@details`: "When fewer than G replicates succeed,
  the scale factor is updated to (G_success - 1) / G_success as a pragmatic
  approximation. This approximation is valid when replicate failures are random
  (due to numerical non-convergence), not systematic. It has no formal
  justification in the jackknife literature; treat the resulting variance
  estimate as approximate." — Effort: low, Risk: low, Impact: honest
  documentation, Maintenance: none
- **[C] Do nothing** — The formula is stated but its approximation status is
  not disclosed, creating an implicit claim of statistical validity.

**Recommendation: A** — Consistent with the spec's existing honesty about the
DAGJK's theoretical limitations.

---

**Issue 14: `n_nps_g` in reference weight adjustment — unweighted count vs. effective count ambiguity**
Severity: REQUIRED
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The spec (step 2a) defines:
```
n_nps_g = number of NPS units not in group g (unweighted count)
```

The comprehension.md (step 2a) defines:
```
n_nps = number of NPS units (count, not sum of weights)
```

Both say "count, not sum of weights" — this is consistent. Good. However,
the Valliant (2020) Eq. 1 formula `w_i* = w_i(N_hat - n) / N_hat` uses `n`
as the NPS count. The spec correctly identifies this as an unweighted count.

The subtle issue: in the within-replicate version adopted by the spec (Issue 1),
`n_nps_g` is the count of NPS units **not** in group g. This is used to compute
the reference weight adjustment for the within-replicate reference sample. The
formula thus becomes:
```
w_ref_adj[i] = w_ref[i] * (N_hat_g - n_nps_g) / N_hat_g
```
where `N_hat_g = sum(w_ref)` over reference units not in group g, and
`n_nps_g = count(NPS units not in group g)`.

This formula can produce a **negative adjustment factor** if `n_nps_g > N_hat_g`.
For example, if the NPS is large relative to the reference sample (e.g.,
n_nps_g = 400, N_hat_g = 300 in a replicate), the factor `(300 - 400) / 300 = -1/3`
would make reference weights negative. The spec does not state what should
happen in this case, nor does it check for it.

This is the "NPS as non-negligible fraction of population" scenario that the
comprehension.md warns about (§Assumptions: "Small NPS sampling fraction").

Options:
- **[A]** Add to step 2a: "If `N_hat_g - n_nps_g < 0` (NPS count exceeds
  estimated population in this replicate), this replicate is counted as failed.
  Error is caught and the replicate is skipped." — Effort: low, Risk: low,
  Impact: prevents negative reference weights, Maintenance: none
- **[B]** Clip the adjustment factor at 0 (set `w_ref_adj = 0` for that
  replicate, effectively treating the reference as having no information) and
  emit a warning — Effort: low, Risk: medium (silent distortion of the
  reference weight), Maintenance: none
- **[C] Do nothing** — Negative reference weights propagate into the logistic
  model, causing model failure (caught by the convergence check) or silent
  distortion.

**Recommendation: A** — Negative adjustment factor should cause replicate
failure explicitly, not rely on downstream model failure to catch it.

---

#### Lens 6 — Literature Cross-Check

**Issue 15: Reference weight adjustment formula — spec diverges from comprehension.md without citation**
Severity: BLOCKING
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

(Overlaps with Issue 1 but from the literature-fidelity angle.)

The comprehension.md (§Formulas, step 2a) gives the reference weight adjustment
as:
```
N_hat = sum(w_ref) over all reference units   [full-sample]
n_nps = number of NPS units                   [full-sample count]
w_ref_adj[i] = w_ref[i] * (N_hat - n_nps) / N_hat
```

The spec changes both `N_hat` and `n_nps` to within-replicate quantities
(`N_hat_g` and `n_nps_g`). Valliant (2020) Eq. 1 is the full-sample formula.
The comprehension.md §Reference mapping entry for this formula is:

> "Valliant (2020) Eq. 1 / §2.1.1 → Reference weight adjustment
> `w_i* = w_i(N_hat - n) / N_hat` when NPS fraction is non-negligible."

There is no citation in either the spec or comprehension.md for the
within-replicate version. The spec must either cite a source for the
within-replicate modification, or acknowledge that it is an unstated extension
of Valliant (2020) Eq. 1.

Options:
- **[A]** Add a footnote or `@details` sentence: "The reference weight
  adjustment follows Valliant (2020) Eq. 1, extended to the within-replicate
  context: N_hat and n_nps are recomputed for each replicate g using only
  units not in group g. This within-replicate extension is not explicit in
  Valliant (2020) but is required for DAGJK internal consistency." — Effort:
  low, Risk: low, Impact: honest about the extension, Maintenance: none
- **[C] Do nothing** — Divergence from the cited formula goes unacknowledged;
  reviewers cannot trace the spec's formula to a source.

**Recommendation: A** — Every departure from cited formulas must be documented.

---

**Issue 16: Gotcha — "recruiting/hosting websites as natural deletion groups" not addressed**
Severity: SUGGESTION
Lens: 6 — Literature Cross-Check
Resolution type: JUDGMENT CALL

Comprehension.md (§Gotchas) does not list this explicitly, but the
§Reference mapping entry for Elliott & Valliant (2017) §3.1 notes:

> "Elliott & Valliant (2017) §3.1 (citing Brick 2015) → Recruiting/hosting
> websites as natural group-deletion units for NPS group jackknife."

This is a real and common use case for DAGJK in web survey practice. The spec
only supports random group assignment via `seed`. It does not mention that
pre-specified groups (e.g., panel IDs) can be used, nor does it say they
cannot be used with this function. This was also raised in Issue 10 under
Lens 4; included here as a Lens 6 issue because the source is the literature.

Options:
- **[A]** Add to `@details`: a note that while Elliott & Valliant (2017) cite
  recruiting/hosting websites as natural deletion groups, this implementation
  uses random groups only. Users with natural group structure should define
  G groups that span their panel membership and use the random assignment
  as an approximation, or wait for a future version with explicit group-vector
  support. — Effort: low, Risk: low, Impact: honest scope statement,
  Maintenance: none
- **[C] Do nothing** — Users familiar with the Elliott & Valliant paper will
  expect panel-based group support; its absence is unexplained.

**Recommendation: A** — A one-sentence scope note in `@details` closes the gap.

---

**Issue 17: Comprehension.md gotcha on "small NPS sampling fraction" assumption not in spec §6**
Severity: SUGGESTION
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

Comprehension.md (§Assumptions) includes:

> "Small NPS sampling fraction — The model-based variance approximations
> assume n/N → 0. For large NPS fractions, the nonsample variance component
> grows and is not captured by DAGJK."

The spec's §6 (Assumptions) lists 6 assumptions. The "small NPS sampling
fraction" assumption is absent. The spec's §3.5 (@details, item 6 "Nonsample
variance component") mentions the nonsample component but does not link it to
the small-fraction assumption. A user with a large NPS fraction may not realize
that the DAGJK variance estimate becomes increasingly incomplete as n/N grows.

Options:
- **[A]** Add a 7th assumption to §6: "Small NPS sampling fraction — The
  DAGJK variance approximation assumes n/N → 0. For NPS surveys covering a
  substantial fraction of the target population, the nonsample variance
  component grows and DAGJK underestimates total uncertainty. The function
  cannot detect this violation." — Effort: low, Risk: low, Impact: complete
  assumption list, Maintenance: none
- **[C] Do nothing** — The assumption is implicit in the nonsample variance
  documentation (§3.5 item 6) but not stated as a verifiable assumption.

**Recommendation: A** — All assumptions from comprehension.md should appear in
§6 or be explicitly marked as out of scope.

---

**Issue 18: Comprehension.md gotcha on "degenerate groups / single-unit groups" — spec coverage incomplete**
Severity: REQUIRED
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

Comprehension.md §Gotchas states:

> "Degenerate groups / single-unit groups — If a deletion group contains
> the only representative of a covariate level, the refitted binary regression
> in that replicate may be degenerate (perfect separation, non-convergence, or
> a covariate level absent from the model matrix). The paper does not address
> this. Implementation must catch convergence failures per replicate and either
> skip or error."

The spec (§3 Edge cases) handles this in two rows:
- "A group deletion leaves no NPS units (all NPS in group g) → That replicate
  is counted as failed"
- "A group deletion leaves only reference units (no NPS remaining) → That
  replicate is counted as failed"

These handle structural depletion (zero NPS or zero reference) but not the
more subtle case: a deletion group contains the **only representative of a
covariate level**. In this case, NPS and reference units remain, the model is
fitted, but the model matrix is rank-deficient or exhibits perfect separation
for the deleted covariate level. The model may "converge" to a pathological
solution (coefficients diverging to ±∞ for the deleted level) or the predict
step may return NA/Inf for units with that level.

The spec catches degenerate propensity scores ($\hat\pi_i \leq 0$ or $\geq 1$)
and NA outputs from the predict step should be handled, but the spec does not
explicitly state that NA propensity scores are treated as degenerate. If
`glm()` / `predict()` returns `NA` for some units (because their covariate
level was not in the model), those units' pseudo-weights would be `1/NA = NA`
— which is not $\leq 0$ or $\geq 1$, so the degenerate check would not catch
it.

Options:
- **[A]** Add to the degenerate propensity score condition: "or any $\hat\pi_i$
  is NA" — i.e., extend the failure condition to `any(is.na(pi_hat) | pi_hat <= 0
  | pi_hat >= 1)`. Add an edge-case row: "Refitted model produces NA propensity
  scores for any unit → replicate is counted as failed." — Effort: low, Risk:
  low, Impact: covers the covariate-depletion case, Maintenance: none
- **[C] Do nothing** — NA propensity scores from covariate level depletion
  propagate as NA pseudo-weights; downstream calibration or estimate computation
  fails silently or with a non-informative error.

**Recommendation: A** — A one-line addition to the failure condition is
sufficient to close this gotcha.

---

**Issue 19: Comprehension.md "single-PSU / single-cluster in a stratum" gotcha — no spec equivalent**
Severity: SUGGESTION
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

Comprehension.md §Gotchas (second-to-last bullet):

> "Single-PSU / single-cluster in a stratum — Elliott & Valliant (2017) §3.1
> note that if a stratum has only one PSU, dropping it leaves zero PSUs and
> makes the stratum contribution undefined. For the NPS group jackknife, the
> analogous problem is a covariate cell with a single unit assigned to one
> group."

This is partially covered by Issue 18 above (degenerate groups). However, the
stratum-contribution problem applies specifically to the **reference sample's**
design structure, not to the logistic model covariates. If the reference
`survey_taylor` has strata with a single PSU, removing reference units in
group g may leave some strata empty in the within-replicate reference design.
This affects the internal `svydesign` variance structure of the reference,
not just the logistic model.

The spec does not address what happens to the reference design's strata
structure after group deletion. The reference weights are used as case weights
in the logistic model (step 2b), not as a design-based estimator, so the
stratum structure of the reference may be irrelevant for model fitting. However,
if `targets_from_reference = TRUE` (step 2e), re-estimating calibration targets
from a truncated reference with empty strata may fail.

Options:
- **[A]** Add to the failed-replicate conditions: "If `targets_from_reference
  = TRUE` and the calibration step fails due to empty reference strata after
  group deletion, the replicate is counted as failed." This is already partially
  covered by "Calibration step throws an error → counted as failed" but the
  stratum-depletion cause should be explicit. — Effort: low, Risk: low,
  Impact: covers this gotcha, Maintenance: none
- **[C] Do nothing** — Empty reference strata after group deletion will cause
  calibration errors that are caught by the existing failure mechanism; the
  cause is not documented.

**Recommendation: A** — A one-sentence addition to the failed-replicate
conditions is sufficient; the generic failure catch already handles it, but
the gotcha should be documented.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 5 |
| REQUIRED | 9 |
| SUGGESTION | 4 |

**Total issues:** 18

| Issue | Title | Lens | Severity | Resolution type |
|---|---|---|---|---|
| 1 | Reference weight adjustment formula — N_hat definition | 1 | BLOCKING | UNAMBIGUOUS |
| 2 | groups > combined N edge case — no upper-density floor | 1 | REQUIRED | JUDGMENT CALL |
| 3 | reference_sample class restriction — data.frame not addressed | 1 | REQUIRED | JUDGMENT CALL |
| 4 | Degrees of freedom unspecified | 2 | REQUIRED | UNAMBIGUOUS |
| 5 | mse = TRUE semantics and failed-replicate centering | 2 | BLOCKING | UNAMBIGUOUS |
| 6 | Calibration targets — fixed vs. sample-estimated not specified | 2 | BLOCKING | JUDGMENT CALL |
| 7 | Logistic model convergence parameters not in history | 3 | BLOCKING | UNAMBIGUOUS |
| 8 | Propensity score clipping for extreme values | 3 | REQUIRED | JUDGMENT CALL |
| 9 | Weight normalization convention unspecified | 3 | REQUIRED | UNAMBIGUOUS |
| 10 | Non-random group structures (clustered NPS) not addressed | 4 | REQUIRED | JUDGMENT CALL |
| 11 | Common support within replicates not diagnosed | 4 | REQUIRED | UNAMBIGUOUS |
| 12 | DAGJK centering term theta — full-sample definition missing | 5 | BLOCKING | UNAMBIGUOUS |
| 13 | Scale factor for failed replicates — derivation absent | 5 | REQUIRED | UNAMBIGUOUS |
| 14 | n_nps_g — negative adjustment factor case unhandled | 5 | REQUIRED | UNAMBIGUOUS |
| 15 | Reference weight formula diverges from comprehension.md | 6 | BLOCKING | UNAMBIGUOUS |
| 16 | Natural deletion groups (recruiting websites) not addressed | 6 | SUGGESTION | JUDGMENT CALL |
| 17 | Small NPS sampling fraction assumption absent from §6 | 6 | SUGGESTION | UNAMBIGUOUS |
| 18 | NA propensity scores not in failure condition | 6 | REQUIRED | UNAMBIGUOUS |
| 19 | Single-PSU/single-cluster stratum depletion gotcha | 6 | SUGGESTION | UNAMBIGUOUS |

**Verdict: BLOCK**

The spec has 5 BLOCKING issues. Three are independent: (1) the reference weight
adjustment formula diverges from the literature without justification, (2) the
`mse = TRUE` centering semantics and the failed-replicate scale adjustment are
asserted without derivation, and (3) the DAGJK centering term `theta` is never
defined. Two more BLOCKING issues — the missing convergence parameter
specification for replicate model fits, and the underspecified calibration
target re-estimation logic — would allow an implementation that produces
statistically wrong variance estimates while passing all behavioral tests.
Resolve all BLOCKING issues, then address REQUIRED issues, before proceeding
to Stage 3.

---

### Mini-Pass 1 (2026-05-27)

**Issue 1 / Issue 15: Reference weight adjustment formula — within-replicate N_hat justification + negative factor case**
✅ RESOLVED — Step 2a now contains an explicit paragraph stating that the within-replicate extension of Valliant (2020) Eq. 1 is required for DAGJK internal consistency and is not explicit in the original paper; it also specifies that `N_hat_g - n_nps_g < 0` causes that replicate to be counted as failed.

**Issue 5: `mse = TRUE` semantics and failed-replicate scale adjustment**
✅ RESOLVED — The `@details` section (item 8) now explains that `mse = TRUE` is correct because it centers on the full-sample estimate matching the DAGJK formula, and explicitly states that the G_success scale adjustment is a pragmatic approximation with no formal justification in the jackknife literature.

**Issue 6: Calibration targets — fixed vs. sample-estimated**
✅ RESOLVED — Step 2e now specifies both cases: when `targets_from_reference = FALSE` or absent, fixed external targets are reused unchanged in every replicate; when `targets_from_reference = TRUE`, targets are re-estimated from the reduced reference with type-specific logic distinguishing `'prop'` (re-estimate proportions) from `'count'` (re-estimate sums of reference weights).

**Issue 7: Logistic model convergence parameters**
✅ RESOLVED — Step 2b now specifies that `maxit` and `epsilon` are taken from the `ipw()` history entry; `R/nonprob-ipw.R` is added to the Modified files table with a note that it must be modified to record these fields; the history entry note in §3.6 also documents this dependency.

**Issue 12: DAGJK centering term theta — full-sample definition**
✅ RESOLVED — The `@details` section (item 9) now defines `theta` as the estimate computed from the current weight column in `@data` (reflecting all weighting steps before the call), including the case where `ipw()` was followed by `calibrate()`, and states that `mse = TRUE` enforces this centering in the downstream survey infrastructure.

**Mini-pass verdict: PASS** — all 5 blocking issues resolved.
