## Methodology Review: nonresponse — Pass 1 (2026-05-08)

---

### New Issues

#### Lens 1 — Method Validity

**Issue 1: Weight sum conservation assertion is wrong for `calibrate_to_survey()`**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The §VIII test spec asserts: "Weight totals are conserved: `sum(w_new) ≈ sum(w_original)`." This is statistically incorrect.

When calibrating to a control survey using a formula with an intercept (which is always present in standard R formulas like `~ age_group + sex`), the intercept constraint forces:

```
sum(w_cal × 1) = sum(w_control × 1)
```

So `sum(w_new) ≈ sum(w_control)`, **not** `sum(w_original)`. If the primary and control surveys come from different populations or sampling frames, `sum(w_original) ≠ sum(w_control)` and the assertion will either fail or silently test the wrong property.

The correct assertion is: `sum(w_new) ≈ sum(control full-sample weights)`.

Options:
- **[A]** Change the test to assert `sum(w_new) ≈ sum(control_design@data[[control_design@variables$weights]])` — Effort: low, Risk: low, Impact: test passes and tests correct property, Maintenance: none
- **[B] Do nothing** — test will likely fail if primary and control surveys have different weight totals; or will silently test nothing meaningful if they happen to match

**Recommendation: A** — One-line fix; the test should verify the calibration constraint that was actually imposed.

---

**Issue 2: `surveywts_error_vcov_cholesky_failed` inconsistency across spec sections**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

Three sections of the spec contradict each other about non-PD `vcov_estimate` handling:

- **§IV Behavior Rule 3** says: "Non-positive-definite matrices will cause `svrep::calibrate_to_estimate()` to fail — those errors propagate as-is." (No surveywts wrapping.)
- **§VIII Test** says: "Non-PSD `vcov_estimate` → `surveywts_error_vcov_cholesky_failed`" (Implying a surveywts-wrapped error class exists.)
- **§X Integration** lists new error classes for `calibrate_to_estimate()` but does NOT include `surveywts_error_vcov_cholesky_failed`.

If errors propagate as-is, the test cannot `expect_error(class = "surveywts_error_vcov_cholesky_failed")`. If surveywts wraps the error, the class must be added to §IV's Error Table and §X's integration list.

Additionally, §IV says `vcov_estimate` "Must be symmetric positive semi-definite." A PSD (but not PD) matrix is singular and will cause Cholesky to fail. The spec should say either "positive definite" (the actual numerical requirement) or explicitly document the PSD–vs–PD distinction and the expected behavior for singular covariance matrices.

Options:
- **[A]** Catch Cholesky failure from svrep and re-throw as `surveywts_error_vcov_cholesky_failed`. Add the class to §IV Error Table and §X integration list. Change §IV language to describe `vcov_estimate` as requiring "positive definite" (or "positive semi-definite; singular matrices will cause svrep to fail with `surveywts_error_vcov_cholesky_failed`"). — Effort: low, Risk: low, Impact: consistent spec + test, Maintenance: none
- **[B]** Remove the Cholesky test case from §VIII and let svrep errors propagate as raw errors (no surveywts class). Update §IV to say "positive definite required; non-PD errors propagate from svrep." — Effort: low, Risk: low, Impact: simpler but slightly worse user experience (raw svrep error message), Maintenance: none
- **[C] Do nothing** — three-way inconsistency leads to implementation ambiguity; implementer will have to guess

**Recommendation: A** — Wrapping the Cholesky failure is consistent with the existing pattern for `surveywts_error_calibration_not_converged`. The user deserves a clear surveywts-classed error, not a raw svrep message.

---

**Issue 3: Replicate scheme compatibility between primary and control designs not specified**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

§III Behavior Rule 1 requires both designs to have the same *number* of replicates, but does not state whether the replicate *schemes* must also match (bootstrap vs. JK1 vs. BRR, etc.).

Pairing replicates by index across incompatible schemes is mathematically valid as a mechanics step but may produce variance estimates with non-standard properties. For example, pairing a BRR replicate from the primary design with a bootstrap replicate from the control design would produce scale-factor mismatches that affect the variance of the calibrated estimate.

In practice, svrep's `calibrate_to_sample()` requires a specific pairing assumption. The spec is silent on whether it validates or simply trusts the user.

Options:
- **[A]** Require matching schemes: add a validation error `surveywts_error_replicate_scheme_mismatch` when `primary_design@variables$type ≠ control_design@variables$type`. — Effort: low, Risk: low, Impact: prevents scheme mismatch; may be overly restrictive if svrep handles scheme differences gracefully, Maintenance: none
- **[B]** Allow any schemes but add a warning if types differ, documenting that mismatched schemes may produce non-standard variance estimates. — Effort: low, Risk: low, Impact: permissive but warns, Maintenance: none
- **[C]** Document that scheme matching is user responsibility; no validation or warning. Delegate to svrep to fail or succeed. — Effort: none, Risk: medium (silent wrong variance estimates possible), Maintenance: none

**Recommendation: B** — A warning on scheme mismatch gives users actionable information without being overly restrictive. The user might legitimately have matched designs where the scheme names differ by convention (e.g., "boot" vs. "bootstrap").

---

#### Lens 2 — Variance Estimation Validity

**Issue 4: Multivariate normality assumption for `calibrate_to_estimate()` perturbation not stated**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The perturbation approach in `calibrate_to_estimate()` perturbs the calibration targets for each replicate using `vcov_estimate`. The statistical validity of this approach rests on the assumption that the control totals are approximately multivariate normally distributed (or more precisely, that their sampling distribution can be approximated by a normal with mean `estimate` and covariance `vcov_estimate`).

The spec does not state this assumption anywhere. For large control surveys, the assumption is reasonable via the CLT. For small control samples or non-normal sampling distributions, the perturbation may produce misleading variance estimates.

This is a statistical assumption that belongs in the function's documentation (roxygen `@details` or `@note`) and should be referenced in the spec.

Options:
- **[A]** Add a "Statistical Assumptions" note to §IV stating: "The perturbation approach assumes control totals are approximately multivariate normally distributed. This is satisfied for large control surveys by the CLT; small control samples may violate this assumption." Mirror in the roxygen `@note`. — Effort: low, Risk: none, Impact: user awareness, Maintenance: none
- **[B] Do nothing** — assumption is implicit in the svrep documentation; users who read svrep docs will know

**Recommendation: A** — Survey practitioners expecting a `@note` or `@details` on statistical assumptions will not read the svrep manual. The note is one sentence.

---

**Issue 5: Variance estimation after propensity-cell adjustment does not account for propensity score uncertainty**
Severity: SUGGESTION
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

After `adjust_nonresponse(method = "propensity-cell")`, the adjusted weights are treated as known. The uncertainty from estimating the propensity scores via `glm()` is discarded. This is standard practice for propensity-cell nonresponse adjustment (treating estimated propensity as known is conventional), but it is a known limitation that users should be aware of.

The spec is silent on this. Not flagging it in documentation could mislead users who want correct variance estimates after propensity adjustment.

Options:
- **[A]** Add a one-sentence `@note` in the function spec: "Variance estimates after propensity-cell adjustment treat the estimated propensity scores as known and do not account for uncertainty from model estimation." — Effort: low, Risk: none, Maintenance: none
- **[B] Do nothing** — this limitation is well-known in the nonresponse adjustment literature

**Recommendation: A** — One sentence; worth stating explicitly given the package's emphasis on correct variance estimation throughout.

---

#### Lens 3 — Algorithmic Correctness

**Issue 6: `glm()` non-convergence in propensity-cell not specified**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

§VI says `stats::glm()` is used to fit the propensity model. `glm()` can fail to converge for perfectly separated data (e.g., a covariate that perfectly predicts response), producing a warning and unreliable coefficient estimates with extreme predicted scores.

The spec does not define behavior when glm() warns about non-convergence. `stats::glm()` issues a warning but returns a result (not an error). The spec should specify whether surveywts:
(a) treats glm convergence warnings as errors,
(b) issues a surveywts warning and proceeds with the potentially unreliable scores, or
(c) silently proceeds.

Options:
- **[A]** Catch glm convergence warnings (via `withCallingHandlers`) and re-issue as `surveywts_warning_propensity_model_not_converged`. — Effort: medium, Risk: low, Impact: user is informed; adds a new warning class to §X integration, Maintenance: none
- **[B]** Document in `@details` that glm convergence warnings from perfect separation or sparse data pass through unchanged. No re-wrapping. — Effort: low, Risk: low, Impact: user sees glm's warning but may not understand its implication for the weights, Maintenance: none
- **[C] Do nothing** — silence on convergence

**Recommendation: B** — Re-wrapping glm warnings adds complexity; the glm warning message is informative enough. Documenting the pass-through behavior is sufficient.

---

#### Lens 4 — Statistical Assumptions

**Issue 7: MAR assumption for propensity-cell method not stated**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The propensity-cell method (like weighting-class adjustment) assumes nonresponse is Missing at Random (MAR) conditional on the propensity score — i.e., within each propensity score cell, respondents and nonrespondents are exchangeable for survey outcome variables.

The existing spec states this assumption for weighting-class adjustment (context from the broader `adjust_nonresponse()` design) but the propensity-cell section (§VI) does not state it. This is the core assumption of the method; without it, the adjustment may increase rather than decrease nonresponse bias.

Options:
- **[A]** Add a "Assumptions" note to §VI: "The propensity-cell method assumes nonresponse is Missing at Random (MAR) conditional on the propensity score. Bias reduction depends on how well the propensity model covariates predict both response propensity and survey outcomes." — Effort: low, Risk: none, Maintenance: none
- **[B] Do nothing** — assumption inherited from adjust_nonresponse() documentation

**Recommendation: A** — Each method section should be self-contained on its statistical requirements. The propensity-cell method is a distinct algorithm that warrants its own MAR statement.

---

**Issue 8: Cell definition uses unweighted quantiles — design choice not documented**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: JUDGMENT CALL

§VI Step 3 says: "Define cell cutpoints: `quantile(predicted_scores, probs = seq(0, 1, 1/n_cells))`." This computes unweighted quantiles — each cell contains approximately the same **number** of units, not the same **weighted count**.

An alternative is to use weighted quantiles (using the design weights), so each cell contains approximately the same weighted sum. Weighted quantiles give cells that represent equal fractions of the survey population, which may produce more balanced adjustment factors.

The spec does not state which approach is taken or why. This is a methodological choice that practitioners may have opinions about.

Options:
- **[A]** Keep unweighted quantiles (current spec) and add a note: "Cell boundaries are defined by unweighted quantiles of the predicted scores, so each cell contains approximately the same number of sampled units. This is the conventional implementation of the propensity-cell method." — Effort: low, Risk: none, Maintenance: none
- **[B]** Switch to weighted quantiles and update §VI accordingly. — Effort: medium, Risk: low, Impact: cells represent equal population fractions; deviation from conventional textbook implementation, Maintenance: none
- **[C] Do nothing** — the choice is implicit in the formula

**Recommendation: A** — Unweighted quantiles are the conventional approach (Rosenbaum & Rubin 1984; Little 1986). Documenting the choice as deliberate prevents implementers from "improving" it to weighted quantiles.

---

#### Lens 5 — Formula Integrity

No additional issues beyond those already flagged under Lens 1. The formulas in the spec are:

- **Redistribution formula** (§V): `new_weight_i = weight_i × (W_total / W_increase)` for `increase_if` rows. This is correct: sum of new weights for `increase_if` rows = W_increase × (W_total / W_increase) = W_total = W_reduce + W_increase. ✓
- **Propensity-cell formula** (§VI): `new_weight_i = weight_i × (W_cell / W_cell_resp)` for respondents. Sum = W_cell_resp × (W_cell / W_cell_resp) = W_cell. ✓ Weight conservation within each cell verified.
- **Equivalence of redistribute_weights() and weighting-class**: verified algebraically. ✓
- **Calibration formulas** delegated to svrep — acceptable given the reference implementation is well-tested.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 8

**Overall assessment:** The calibration and redistribution formulas are correct. Two BLOCKING issues must be resolved before implementation: a wrong test assertion (weight sum conservation) and a three-way inconsistency around `surveywts_error_vcov_cholesky_failed`. The four REQUIRED issues address unstated statistical assumptions (MAR, multivariate normality, replicate scheme compatibility, glm non-convergence) that will either produce user confusion or silent wrong behavior.
