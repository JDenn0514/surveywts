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

---

## Methodology Review: nonresponse — Pass 2 (2026-05-12)

---

### Prior Issues (Pass 1)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | Weight sum conservation assertion is wrong for `calibrate_to_survey()` | 1 | ⚠️ Still open |
| 2 | `surveywts_error_vcov_cholesky_failed` inconsistency across spec sections | 1 | ⚠️ Still open |
| 3 | Replicate scheme compatibility between primary and control designs not specified | 1 | ⚠️ Still open |
| 4 | Multivariate normality assumption for `calibrate_to_estimate()` perturbation not stated | 2 | ⚠️ Still open |
| 5 | Variance estimation after propensity-cell adjustment does not account for propensity score uncertainty | 2 | ⚠️ Still open |
| 6 | `glm()` non-convergence in propensity-cell not specified | 3 | ⚠️ Still open |
| 7 | MAR assumption for propensity-cell method not stated | 4 | ⚠️ Still open |
| 8 | Cell definition uses unweighted quantiles — design choice not documented | 4 | ⚠️ Still open |

All 8 prior issues remain open. The spec was not updated between Pass 1 and Pass 2.

---

### New Issues

#### Lens 1 — Method Validity

**Issue 9: `redistribute_weights()` output contract for `survey_taylor` and `survey_nonprob` doesn't specify how zero-weight rows are handled**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

§V Output Contract states: "survey_taylor or survey_nonprob → same class as input." But the redistribution sets `reduce_if` rows to weight 0, and both `survey_taylor` and `survey_nonprob` have S7 validators that enforce strictly positive weights (per `surveywts-conventions.md`: "All values are strictly positive (> 0)").

If a `reduce_if` row has its weight set to 0 and remains in the returned object, the S7 validator will reject the object. If the zero-weight rows are silently filtered out before returning, the spec must say so.

The propensity-cell section (§VI) handles this by referencing the existing weighting-class behavior: "same respondent-only filtering applies as in the weighting-class method (zero weights violate the Taylor validator)." But `redistribute_weights()` has no such language. As a general-purpose primitive, it may be called with `reduce_if` = nonrespondents, but could equally be called with other semantics (e.g., to zero out a group for downweighting).

The issue is more fundamental for `redistribute_weights()` than for `adjust_nonresponse()`: with a general reduce/increase interface, filtering out `reduce_if` rows always may not be the right default — the caller might intend to keep zero-weight rows in the dataset for downstream filtering steps.

Options:
- **[A]** For `survey_taylor` and `survey_nonprob` inputs: filter out `reduce_if` rows from the output (same as the weighting-class method). Document this in §V. — Effort: low, Risk: low, Impact: consistent with Taylor/nonprob constraints; callers lose access to zero-weight rows, Maintenance: none
- **[B]** Disallow `survey_taylor` and `survey_nonprob` as inputs to `redistribute_weights()` (change Input Class Support table to ✗). These classes can't hold zero-weight rows; callers should convert to `weighted_df` first, use `redistribute_weights()`, then reconstruct the survey object. — Effort: low, Risk: low, Impact: narrower API; forces explicit conversion but is honest about the constraint, Maintenance: none
- **[C]** Keep `survey_taylor` and `survey_nonprob` as inputs but error if any `reduce_if` row would result in a zero-weight row being left in a design that can't hold it — i.e., effectively disallowing `reduce_if` for these classes unless all reduce_if rows can be filtered. This is complex to specify. — Effort: high, Risk: medium, Maintenance: ongoing
- **[D] Do nothing** — implementation crashes on S7 validator rejection, or silently filters rows with undocumented behavior

**Recommendation: A** — Filtering `reduce_if` rows from the output for survey objects is the most consistent path. It mirrors the documented behavior of `adjust_nonresponse()` and is the only way to satisfy the S7 validator. The spec must state it explicitly so the behavior is not a surprise.

---

#### Lens 2 — Variance Estimation Validity

No new issues. Lens 2 issues from Pass 1 remain open.

#### Lens 3 — Algorithmic Correctness

No new issues. Lens 3 issues from Pass 1 remain open.

#### Lens 4 — Statistical Assumptions

No new issues. Lens 4 issues from Pass 1 remain open.

#### Lens 5 — Formula Integrity

No new issues.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 (new) + 2 (prior open) = 3 total open |
| REQUIRED | 4 (prior open) |
| SUGGESTION | 2 (prior open) |

**New issues this pass:** 1 (Issue 9, BLOCKING)
**Total open issues:** 9

**Overall assessment:** No prior issues were resolved. One new BLOCKING issue was found: `redistribute_weights()` promises to accept `survey_taylor` and `survey_nonprob` inputs but the output contract is silent on how zero-weight rows are handled — both classes enforce strictly positive weights via their S7 validators, so the current spec will produce either a crash or undocumented silent filtering. This must be resolved alongside the two prior BLOCKING issues before implementation begins.

---

## Methodology Review: nonresponse — Pass 3 (2026-05-12)

---

### Prior Issues (Pass 1 + Pass 2)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | Weight sum conservation assertion is wrong for `calibrate_to_survey()` | 1 | ✅ Resolved |
| 2 | `surveywts_error_vcov_cholesky_failed` inconsistency across spec sections | 1 | ✅ Resolved |
| 3 | Replicate scheme compatibility between primary and control designs not specified | 1 | ✅ Resolved |
| 4 | Multivariate normality assumption for `calibrate_to_estimate()` perturbation not stated | 2 | ✅ Resolved |
| 5 | Variance estimation after propensity-cell adjustment does not account for propensity score uncertainty | 2 | ✅ Resolved |
| 6 | `glm()` non-convergence in propensity-cell not specified | 3 | ✅ Resolved |
| 7 | MAR assumption for propensity-cell method not stated | 4 | ✅ Resolved |
| 8 | Cell definition uses unweighted quantiles — design choice not documented | 4 | ✅ Resolved |
| 9 | `redistribute_weights()` output contract for `survey_taylor` and `survey_nonprob` doesn't specify how zero-weight rows are handled | 1 | ✅ Resolved |

All 9 prior issues resolved. Notes on each:
- Issues 1 & 2 (BLOCKING): §III Output Contract now documents the intercept-forces-control-total behavior; §IV Behavior Rule 3 now catches Cholesky failure and re-throws as `surveywts_error_vcov_cholesky_failed`; §IV Error Table and §X integration list now include this class; PSD vs PD language corrected.
- Issue 3 (REQUIRED): §III Behavior Rule 2 now warns with `surveywts_warning_replicate_scheme_mismatch` on type mismatch and proceeds.
- Issues 4, 5, 7, 8 (REQUIRED/SUGGESTION): Statistical assumptions sections added to §IV and §VI; MAR stated, propensity-as-known stated, unweighted quantile convention documented with citation.
- Issue 6 (REQUIRED): §VI Behavior Notes now documents that glm convergence warnings pass through unchanged.
- Issue 9 (BLOCKING): §V Output Contract now states `reduce_if` rows are filtered out for `survey_taylor` and `survey_nonprob`.

---

### New Issues

#### Lens 1 — Method Validity

No new issues.

#### Lens 2 — Variance Estimation Validity

No new issues.

#### Lens 3 — Algorithmic Correctness

No new issues.

#### Lens 4 — Statistical Assumptions

No new issues.

#### Lens 5 — Formula Integrity

**Issue 10: `vcov_estimate` NA values produce a misleading or unhandled error**
Severity: REQUIRED
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

§IV Behavior Rule 3 says `vcov_estimate` must have "No NAs." The symmetry check is specified as `abs(vcov - t(vcov)) < 1e-8`. In R, `all(abs(vcov - t(vcov)) < 1e-8)` when `vcov` contains `NA` values evaluates to `NA`, not `FALSE`. An `if (NA)` then throws an unhandled R error ("missing value where TRUE/FALSE needed"), not a clean surveywts class. Alternatively, if the check is written with `isTRUE(all(...))`, it silently falls through to the Cholesky step, which then fails and throws `surveywts_error_vcov_cholesky_failed` — the wrong class for what is actually an NA input error.

Neither outcome is correct. The spec does not include a `surveywts_error_vcov_has_na` class, does not list an NA test case for `vcov_estimate` in §VIII, and does not include the class in §X's integration list.

Fix: add an explicit NA check on `vcov_estimate` before the symmetry check, with a dedicated error class. This is the same pattern used for `estimate` (which has `surveywts_error_estimate_has_na`).

Options:
- **[A]** Add `surveywts_error_vcov_has_na` class: check `anyNA(vcov_estimate)` before the symmetry check; throw `surveywts_error_vcov_has_na` if TRUE. Add the class to §IV Error Table, §VIII test plan, and §X integration list. — Effort: low, Risk: low, Impact: user gets a clear actionable error instead of an internal R exception or wrong class, Maintenance: none
- **[B]** Handle NAs inside the symmetry check: treat any NA in `vcov_estimate` as a symmetry violation and throw `surveywts_error_vcov_not_symmetric`. Document in the error message that NA values were detected. — Effort: low, Risk: low, Impact: slightly imprecise error class but user is informed; avoids adding a new class, Maintenance: none
- **[C] Do nothing** — implementer will likely add the check instinctively, but without a spec entry there's no test and no error class; behavior remains undefined

**Recommendation: A** — Mirrors the `surveywts_error_estimate_has_na` pattern already in this spec. Consistent, low effort, and gives the user the most informative message.

---

**Issue 11: `method = "logit"` with default infinite bounds is undocumented as an error condition**
Severity: SUGGESTION
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

§III and §IV specify `bounds = list(lower = -Inf, upper = Inf)` as the default. The argument description notes: "For `method = 'logit'`, set finite bounds to constrain calibrated weights within a specified range." However, the spec does not state what happens when a user calls `calibrate_to_survey()` or `calibrate_to_estimate()` with `method = "logit"` and the default infinite bounds — specifically, whether this is an error, a warning, or silently delegated to svrep/survey (which would then fail with a non-surveywts error from `survey::cal.logit`).

`survey::cal.logit` requires finite bounds. Passing infinite bounds will produce an error from the survey package, not a surveywts-classed error. There is no `surveywts_error_logit_bounds_required` class specified.

This is a SUGGESTION rather than REQUIRED because: (a) the svrep/survey error message will be visible and informative to most users, and (b) the argument description does tell users to set bounds for logit.

Options:
- **[A]** Add a pre-flight check: if `method = "logit"` and either `bounds$lower == -Inf` or `bounds$upper == Inf`, throw `surveywts_error_logit_bounds_required`. Add to error table and §X. — Effort: low, Risk: low, Impact: user gets a surveywts-classed error with a clear message, Maintenance: none
- **[B]** Add a `@details` note in the function documentation only: "When `method = 'logit'`, both `bounds$lower` and `bounds$upper` must be finite; the default infinite bounds will cause `survey::cal.logit` to fail." No new error class. — Effort: low, Risk: none, Impact: user is informed but only via documentation; runtime error is a raw survey package message, Maintenance: none
- **[C] Do nothing** — current argument description is a soft hint; raw survey error propagates

**Recommendation: B** — The documentation note is sufficient. Adding a surveywts pre-flight check is low-effort but adds a new error class and test without proportionate user benefit; the survey package error is clear.

---

### Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 (Issue 10) |
| SUGGESTION | 1 (Issue 11) |

**New issues this pass:** 2
**Total open issues:** 2

**Overall assessment:** All 9 prior issues have been resolved and the spec is in strong methodological shape. One REQUIRED issue remains: `vcov_estimate` NA inputs are unspecified — the current symmetry check logic will produce an unhandled R exception or the wrong surveywts error class. This is a one-line fix with a new error class. One SUGGESTION: document that `method = "logit"` requires finite `bounds` in `@details`. No blocking methodology issues remain; the spec is ready to advance to Stage 3 after Issue 10 is resolved.

---

## Stage 2 Resolve — Methodology Lock (2026-05-12)

Issues 10 and 11 resolved (both unambiguous). No judgment calls; no decisions log entry.

| # | Title | Resolution |
|---|---|---|
| 10 | `vcov_estimate` NA values produce unhandled error | Added `surveywts_error_vcov_has_na`: explicit `anyNA()` check before symmetry check added to §IV Behavior Rule 3, Error Table, §VIII test plan, §X integration list |
| 11 | `method = "logit"` with infinite bounds undocumented | Added `@details` note to §III bounds argument description |

**Spec version:** 0.4 — Methodology Locked. All 11 issues across 3 passes resolved.
