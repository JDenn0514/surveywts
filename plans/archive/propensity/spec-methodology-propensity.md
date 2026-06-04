## Methodology Review: propensity — Pass 1 (2026-05-18)

### New Issues

#### Lens 1 — Method Validity

**Issue 1: `surveywts_warning_class_near_empty` reused with misleading semantics**
Severity: SUGGESTION
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

§V step 11 says the extreme-adjustment check for `method = "propensity"` reuses the
`surveywts_warning_class_near_empty` class. But "class near empty" is a discrete
weighting-class concept — it means a response class contained very few respondents. For
unit-level continuous propensity scores from logistic regression, there are no discrete
classes. A user who receives `surveywts_warning_class_near_empty` from a propensity call
will be confused: the message template will reference cells or classes that don't apply
to their usage context.

Current spec: "Sparse/extreme-adjustment check: same `surveywts_warning_class_near_empty`
logic as `method = 'weighting-class'`"

Options:
- **[A] Introduce `surveywts_warning_extreme_propensity_adjustment`** — a dedicated warning
  class for the propensity case, with message text about extreme adjustment factors (not
  cells). Effort: low, Risk: low, Impact: cleaner user-facing messages and correct class
  semantics, Maintenance: one additional class to document
- **[B] Reuse the existing class** — accept the semantic mismatch; the check logic is
  identical even if the name is imprecise. Effort: none, Risk: low (won't cause wrong
  answers), Impact: slightly confusing user message, Maintenance: none
- **[C] Do nothing** — same as B; the mismatch persists silently

**Recommendation: A** — the class name forms part of the public API; reusing one with
"class" in the name for a method without discrete classes is a user-facing API inconsistency
that is cheapest to fix now.

---

No other Lens 1 issues found. The quasi-randomization framework setup — pooling NPS (Z=1,
weight=1) with reference (Z=0, weight=design weight) — correctly follows Elliott & Valliant
(2017). Input class constraints are clearly specified. Degenerate-score and extreme-score
validation is appropriately defined.

---

#### Lens 2 — Variance Estimation Validity

No issues found. The spec explicitly documents (in §III Statistical Notes and §V
Statistical Note) that:

- Bootstrap resampling without propensity re-estimation understates variance
- This is standard practice in applied survey weighting
- Propensity model-resampling bootstrap is deferred to a future phase

Both notes are documented in `@note` roxygen sections. The spec's disclosure is adequate
given the deferred-phase structure. Users are not left unwarned about the limitation.

---

#### Lens 3 — Algorithmic Correctness

**Issue 2: Conservation test for `adjust_nonresponse(method = "propensity")` claims exact algebraic equality that does not hold for logistic regression propensity scores**
Severity: BLOCKING
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

§VI test category "Numerical correctness" for `adjust_nonresponse(method = "propensity")`
specifies:

```r
abs(sum(new_wts) - sum(orig_wts)) < 1e-8
```

The tolerance `1e-8` implies this is an exact algebraic identity. It is not. For weighting
class methods, weight conservation IS exact: within each cell c, `sum_respondents(w_i /
rate_c) = sum_all(w_i)` because `rate_c = sum_respondents(w_i) / sum_all(w_i)` by
definition. The algebraic identity holds.

For unit-level logistic regression propensity scores, `score_i` is the model-predicted
P(respond | X_i) and is NOT guaranteed to satisfy
`sum_respondents(w_i / score_i) = sum_all(w_i)`. This equality holds only in expectation
under a correctly specified model and in finite samples is an approximation that depends on
data and model. With log-normally distributed base weights (as `make_surveywts_data()`
produces), the gap will typically be in the range 1e-2 to 1e-1 relative to the total
weight, far exceeding 1e-8 in absolute terms.

A valid implementation of the propensity method will fail this test. The test is wrong.

**Fix (UNAMBIGUOUS):** Replace the exact conservation test with a looser relative
tolerance, or remove the algebraic equality claim entirely and replace with a bounded
relative deviation:

```r
# Option A: relative tolerance
expect_equal(sum(new_wts), sum(orig_wts), tolerance = 0.05)  # 5% is generous

# Option B: remove this test; add a note that IPW conservation is only asymptotic
# and test numerical correctness only via the per-unit weight formula check
```

The per-unit weight formula test (`new_weight_i = original_weight_i / predicted_score_i`
to tolerance `1e-10`) is mathematically exact and should be retained. The sum conservation
test should either be removed or use a tolerance that can actually be achieved (e.g., ≤ 5%
relative error using a known well-specified model on simulated data).

**Recommendation:** Remove the conservation test as stated and add a comment explaining
that weight conservation is only approximately satisfied for the propensity method (unlike
weighting-class, where it is exact). Retain the per-unit weight check.

---

**Issue 3: Spec is silent on whether GLM non-convergence makes scores unreliable in ways not caught by existing validation**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

The spec says (§III step 10 and §V step 6): "GLM convergence warnings from `stats::glm()`
pass through unchanged — do not catch or re-wrap them."

When `stats::glm()` exhausts `maxit = 25` iterations without meeting the `epsilon`
criterion, it emits "glm.fit: algorithm did not converge" and returns coefficients from the
final incomplete iteration. The score validation (step 11, `any(scores <= 0 | scores >= 1)`)
detects only boundary predictions (perfect separation). It does not detect the case where
a non-converged model produces scores in (0, 1) but at the wrong values — producing silently
incorrect IPW weights that pass all downstream checks.

This is distinct from perfect separation: a non-converged model with moderate separation
can produce scores that look plausible but are wrong. The `1e-8` epsilon threshold means
the model must improve by `1e-8` per step — if the last few iterations move the coefficients
a small amount without hitting the threshold, the native GLM warning fires and the scores
are returned anyway.

The spec acknowledges the warning will be visible to the user but does not state whether
that is sufficient.

Options:
- **[A] Document that native GLM convergence warnings indicate unreliable scores and users
  should reduce model complexity or check data** — add this to `@details`. Effort: low,
  Risk: low, Impact: clearer user guidance without changing behavior, Maintenance: none
- **[B] Re-wrap the convergence warning with surveywts-specific messaging** that explicitly
  states the IPW weights from a non-converged model are unreliable. Effort: low, Risk: low,
  Impact: better user experience with a clearer warning message, Maintenance: one new
  warning class (e.g., `surveywts_warning_propensity_glm_convergence`)
- **[C] Do nothing** — rely solely on the native GLM warning; users who know what
  "algorithm did not converge" means will investigate

**Recommendation: A** — `@details` documentation is sufficient for this case. The native
warning is standard R behavior that experienced users recognize. Re-wrapping risks breaking
the "pass through unchanged" design. Adding one sentence to `@details` for both `ipw()` and
`adjust_nonresponse()` closes the gap at near-zero effort.

---

#### Lens 4 — Statistical Assumptions

No new issues found. The spec documents:

- Selection on observables (SOO) assumption with appropriate caveats
- Common support requirement with guidance to use `diagnose_propensity()` (Diagnostics phase)
- MAR conditional on estimated propensity for `adjust_nonresponse(method = "propensity")`
- Variance underestimation from not re-estimating the propensity model during bootstrapping

The key assumptions are stated. The SOO note is honest about the limitation (unmeasured
participation drivers cause residual bias regardless of model complexity). No issues.

---

#### Lens 5 — Formula Integrity

No new issues found. The following formulas are stated explicitly and correctly:

- IPW weight: `w_i = 1/π̂_i` where `π̂_i = P(Z=1 | X_i)`, Z=1 for NPS membership
- Pooled regression weight assignment: NPS units = 1, reference units = design weights
- Fit formula: `stats::glm(.Z ~ covariates, weights = pooled_wts, family = binomial(link))`
- Prediction: `predict(fit, newdata = nps_cols, type = "response")` — NPS-only prediction
- Population size estimator: `N̂ = Σ(1/π̂_i)` — correct Horvitz-Thompson estimator for N
- Nonresponse-adjusted weight: `new_w_i = w_i / score_i` for respondents
- Trimming upper bound: `median(w) + 5 × IQR(w)` — matches `trim_weights()` default

The formula for `estimated_population_size = sum(w_before_trim)` correctly records N̂
before any trimming, allowing users to compare against an external population estimate.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 1 |
| SUGGESTION | 1 |

**Total issues:** 3

**Overall assessment:** The quasi-randomization IPW framework is correctly specified and
the core formulas are sound. One blocking issue: the `adjust_nonresponse(method =
"propensity")` numerical correctness test incorrectly asserts that logistic regression
propensity weighting produces exact weight conservation (tolerance `1e-8`), which is only
true for weighting-class methods — a valid implementation will fail this test. One required
issue: GLM non-convergence silently produces unreliable scores that the score validation
(`≤ 0 or ≥ 1` check) cannot detect; `@details` needs a sentence about this. One
suggestion: `surveywts_warning_class_near_empty` is semantically misleading when fired from
a continuous propensity method.

---

## Literature Review Addendum — Pass 1 (2026-05-18)

Papers reviewed: `elliott_valliant_2017`, `chen_2021_doubly_robust_inference`,
`chrostowski_2025_nonprobsvy`, `wu_2022_inference_nonprobability_samples`,
`yang_2020_doubly_robust_inference`, `lee_lessler_stuart_2011_weight_trimming_propensity`

---

**Issue 4: Propensity estimation method is inconsistent with Chen (2021) and nonprobsvy — numerical comparison test will fail**
Severity: BLOCKING
Lens: 1 — Method Validity, 5 — Formula Integrity
Resolution type: JUDGMENT CALL

The spec's `.fit_participation_propensity()` uses a plain survey-weighted logistic
regression (step 2):
```r
glm(.Z ~ ., data = pooled, weights = pooled_wts, family = binomial)
```
where `pooled_wts = c(rep(1, n_NPS), ref_design_weights)`.

This is the **weighted GLM approach** (Valliant & Dever 2011, Elliott & Valliant 2017 §3.1).
Its score equation at solution γ̂ is:

Σ_{NPS} (1 − π̂_i) x_i − Σ_{ref} d_i π̂_i x_i = 0

The formally correct approach used by **both Chen et al. (2021) and the `nonprobsvy`
package** maximizes a **pseudo log-likelihood** (Chen eq. 3.2, nonprobsvy eq. 8):

l*(γ) = Σ_{NPS} log{π̂_i/(1−π̂_i)} + Σ_{ref} d_i log(1−π̂_i)

whose score equation is:

Σ_{NPS} x_i − Σ_{ref} d_i π̂_i x_i = 0

**Why they differ:** The weighted GLM has a (1−π̂_i) factor on the NPS term. The pseudo
log-likelihood does not. At the true propensity π^A, Chen's score equation is unbiased
under the joint qp randomization (Wu 2022, Chen et al. 2021 Theorem 1). The weighted GLM
score equation evaluated at the true propensity equals −Σ (π^A_i)² x_i ≠ 0, meaning the
weighted GLM is inconsistent for the true population propensity.

Chen et al. (2021, §2.1) state explicitly: "Existing methods [including the Valliant &
Dever pooling approach] do not provide valid results. The resulting estimators using the
estimated propensity scores P̃_i^A are biased."

**Consequence for the spec's test plan:** The numerical comparison test in §VI specifies:
```r
ipw_mean <- sum(nps_data$y * result@data$ipw_weight) / sum(result@data$ipw_weight)
expect_equal(ipw_mean, nonprobsvy_result$output$mean, tolerance = 1e-6)
```
`nonprobsvy` uses the pseudo log-likelihood (Chen approach). The spec uses the weighted
GLM. Because the two approaches solve different estimating equations, they produce different
propensity scores and different weights. The test will fail regardless of implementation
correctness. The tolerance 1e-6 is far below any reasonable bound on the difference between
the two methods — even with identical data, they won't agree to that precision.

**Options:**

- **[A] Change the spec to use the pseudo log-likelihood (Chen 2021 / nonprobsvy
  approach)** — Implement the pseudo score equation Σ_{NPS} x_i = Σ_{ref} d_i π̂_i x_i via
  Newton-Raphson. This cannot be done with a plain `stats::glm()` call; it requires either
  a custom optimizer or a GLM-based trick. The numerical test against `nonprobsvy` would
  then be valid and should pass to 1e-6. Effort: medium (custom solver needed); Risk: low
  (well-established estimating equation); Impact: spec implements the method that the
  primary reference (Chen 2021) and the comparison package (nonprobsvy) both use; makes
  the `nonprobsvy` comparison test valid. Maintenance: custom solver is a few lines of
  Newton-Raphson.
- **[B] Keep the weighted GLM; remove or replace the `nonprobsvy` comparison test** —
  Document explicitly that `ipw()` implements the Valliant & Dever (2011) / Elliott &
  Valliant (2017, §3.1) weighted GLM approach, which differs from the Chen (2021)
  pseudo-likelihood. Remove or change the numerical test to compare only against a manual
  re-fit of the same weighted GLM (not against `nonprobsvy`). Add a note to `@details` and
  the spec documenting the methodological difference and its known bias properties. Effort:
  low; Risk: medium (implements a method explicitly called biased by the primary reference);
  Impact: spec's method is self-consistent but diverges from nonprobsvy and from the
  formal theoretical literature; Maintenance: ongoing confusion if users compare results.
- **[C] Do nothing** — implement as written; the `nonprobsvy` comparison test fails; users
  discover the discrepancy on their own.

**Recommendation: A** — The pseudo log-likelihood is directly derivable from the true
population log-likelihood by substituting a Horvitz-Thompson estimator for the population
sum. It is implemented in nonprobsvy, derived in Chen (2021) and Wu (2022), and is the
method the spec already plans to cross-validate against. The Newton-Raphson implementation
is compact (one loop, ~10 lines) and `stats::glm.control()` convergence parameters
(`maxit`, `epsilon`) can still govern the outer loop. Choosing Option B requires either
removing the nonprobsvy comparison entirely (losing an important validity check) or
explaining in the spec why the spec diverges from the established framework it claims to
implement.

---

**Issue 5: Hájek vs HT estimator distinction not resolved in output contract**
Severity: SUGGESTION
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec mentions both interpretations without resolving which the package commits to:
- §III Output Contract: "The sum Σ w_i = Σ (1/π̂_i) estimates the population size N̂" 
- §III Statistical Notes: "For analysis of means and proportions, this estimate of N̂
  cancels in the ratio, producing Hájek-type estimates."

The HT estimator is μ̂_HT = (1/N) Σ y_i w_i (requires known N).  
The Hájek estimator is μ̂_Hájek = Σ y_i w_i / Σ w_i (uses N̂ = Σ w_i as denominator).

The spec returns a `survey_nonprob` object with IPW weights. How `survey_nonprob` computes
means — HT or Hájek — depends on the print method and downstream estimation functions.
This is not specified in the propensity spec (it may be governed by the Calibration phase
spec), but the distinction matters for interpreting `estimated_population_size` in the
history entry.

**Fix (UNAMBIGUOUS):** Add one sentence to `@note` clarifying that `ipw()` produces
unnormalized weights suitable for Hájek-type (ratio) estimation; for HT-type total
estimation the user must supply an external population size estimate N. This is already
partly present in the statistical notes but should be stated as a single explicit
design commitment.

---

## Updated Summary

| Severity | Count |
|---|---|
| BLOCKING | 2 (Issues 2, 4) |
| REQUIRED | 1 (Issue 3) |
| SUGGESTION | 2 (Issues 1, 5) |

**Total issues:** 5

**Updated overall assessment:** Two blocking issues: (1) the nonresponse weight
conservation test claims exact equality that doesn't hold for logistic regression, and (2)
the propensity estimation method (weighted GLM) is inconsistent with both the theoretical
literature (Chen 2021) and the cross-validation package (nonprobsvy) — the numerical
comparison test will fail by design for any correct implementation of the spec. Resolving
issue 4 requires either switching to the pseudo log-likelihood (correct, but requires a
custom solver) or removing the nonprobsvy comparison and documenting the limitation.
Resolving issue 2 requires removing or weakening the conservation test tolerance.
