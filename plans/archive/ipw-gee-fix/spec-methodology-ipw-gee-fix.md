# Spec Methodology Review: ipw-gee-fix — Pass 1 (2026-06-24)

## Scope Assessment

- Does this feature implement, modify, or extend a statistical or mathematical method?
  **Yes.** The GEE calibration estimating equations path is being modified — same
  score/Jacobian formulas, but the iteration strategy changes from bare NR to nleqslv.
- Does it produce numerical quantities with known statistical properties?
  **Yes.** The calibration constraint `sum(w * x) = sum(d * x)` is a numerical
  invariant that must hold at convergence.
- Does it involve iterative algorithms with convergence criteria that must be
  exactly specified?
  **Yes.** nleqslv termination codes 1/2 (converged) vs. 3/>=4 (not converged)
  are the convergence criterion.

All five lenses apply. Lens 6 not applicable (no paper/comprehension.md).

---

### Lens 1 — Method Validity

The GEE score equation `U(γ) = Σ_{NPS} x_i / π_i(γ) − Σ_{ref} d_i · x_i = 0`
and the Jacobian `∂U/∂γ = −X_nps^T diag((1−π)/π) X_nps` are unchanged from the
existing implementation. The fix is a purely algorithmic change: bare NR is
replaced by nleqslv. nleqslv is a well-established globally-convergent nonlinear
system solver with backtracking line search / trust region; it is the same solver
used by the nonprobsvy reference implementation.

The calibration guarantee (`sum(w*x) = sum(d*x)` at convergence) follows from the
GEE score equation being zero at convergence; this remains mathematically unchanged.

The outer saturation guard is moved to the MLE branch only (Rule GEE-2). For GEE
this is correct: nleqslv damps steps and will not drive γ to −∞ in the same way
bare NR does. Any residual degenerate scores after nleqslv returns are caught by
the existing post-fit Rule 15 check.

The inner `pi_nps <= eps` early-return guard is removed from the GEE branch
(Rule GEE-9). This guard was a workaround for NR divergence on the GEE path;
with nleqslv it is no longer needed. Rule 15 in ipw() retains the post-fit
degenerate check, which is the correct place for this safeguard.

**No issues found.**

---

### Lens 2 — Variance Estimation Validity

**Lens 2 not applicable:** this fix changes the GEE propensity solver strategy
only. No variance estimation formula, replicate weight logic, or Taylor
linearization is modified. The existing documentation in `ipw()` about variance
estimation (refit at each replicate) is unchanged. The fix improves the
quality of the point estimate (weights now converge for population-scale
references), which is a prerequisite for variance estimation to be meaningful,
but does not itself affect the variance estimator.

---

### Lens 3 — Algorithmic Correctness

The convergence criterion is delegated to nleqslv:
- `control$xtol = epsilon` — step-size convergence threshold
- `control$ftol = epsilon` — function-norm convergence threshold (sqrt(sum(fn^2)) < ftol)
- Both set to the same `epsilon` (default 1e-8)

Setting both to `epsilon` is sound: the solver may declare convergence on either
the x-step or the function-norm criterion, whichever fires first. For
well-conditioned problems both will fire close together; for ill-conditioned
problems the function-norm criterion may be the tighter binding constraint.

The termcd mapping (Rule GEE-8) is:
- 1 (ftol satisfied) and 2 (xtol satisfied) → converged = TRUE
- 3 (maxit reached) → converged = FALSE → warning
- ≥4 (singular Jacobian or algorithm failure) → converged = FALSE → warning

This is correct per the nleqslv documentation. No algorithmic correctness issues.

One minor observation (SUGGESTION): the non-convergence warning message in
`ipw()` currently reads "max |delta| = {round(fit$final_delta, 6)}". For the
MLE path, `final_delta` is the max step size (|delta|). For the GEE path, the
spec sets `final_delta = max(abs(gee_fit$fvec))` — the maximum score residual.
The label "max |delta|" is misleading for the GEE path but not wrong (it is a
convergence diagnostic). This is a documentation quality issue, not a bug.

**No BLOCKING or REQUIRED issues.**

**Issue M1: Warning message label slightly misleading for GEE path**
Severity: SUGGESTION
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The non-convergence warning in `ipw()` reports `max |delta|` where delta is the
NR step size. For the GEE nleqslv path, `final_delta = max(abs(gee_fit$fvec))`
is a score residual (different quantity). The label is technically inaccurate.

Options:
- **[A]** Update the warning message to be path-aware: for MLE "max step |delta|
  = …", for GEE "max score residual = …". Effort: low, Risk: low.
- **[B]** Use a generic label "convergence diagnostic = …" for both paths.
  Effort: low, Risk: low.
- **[C] Do nothing** — label is wrong for GEE but the value is still informative.

**Recommendation: B** — a single generic label avoids branching in the warning
text and is accurate for both paths.

---

### Lens 4 — Statistical Assumptions

No new statistical assumptions are introduced. The fix does not change:
- The pseudo-likelihood framework for the NPS propensity model
- The GEE calibration constraint interpretation
- The MAR assumption (`P(NPS | X, Y) = P(NPS | X)`)
- The common support assumption
- The assumption that NPS participation decisions are independent given X

The fix makes the algorithm that computes γ actually converge when reference
weights are at population scale; this does not change the statistical properties
of the resulting IPW weights conditional on the propensity scores being correct.

**No issues found.**

---

### Lens 5 — Formula Integrity

Score function (Rule GEE-4):
```
fn(g) = colSums(X_nps_fit / link(X_nps_fit %*% g)) - ref_totals
```
This is `Σ_{NPS} x_i / π_i(g) − Σ_{ref} d_i · x_i` — correct per the GEE
calibration equation.

Jacobian (Rule GEE-5):
```
jac(g) = -crossprod(X_nps_fit, X_nps_fit * ((1 - pi_g) / pi_g))
```
This is `−X_NPS^T diag((1−π)/π) X_NPS` — the derivative of the score with
respect to γ under the logit link (and valid for probit/cloglog by substitution
of the appropriate linkinv). Confirmed correct.

Reference totals (Rule GEE-1):
```
ref_totals = colSums(X_ref * d_ref)
```
This is `Σ_{ref} d_i · x_i` — correct.

All formulas are stated exactly (not in prose). Symbol bindings are clear.
No formula integrity issues.

**No issues found.**

---

### Lens 6 — Literature Cross-Check

**Lens 6 not applicable:** no paper was attached and no `comprehension.md`
exists for this request. The user confirmed literature review is complete; no
new citations are introduced.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 1 |

**Total issues:** 1

**Overall assessment:** The methodology is sound. The score function, Jacobian,
and calibration constraint formulas are unchanged and correct. The nleqslv
convergence criterion mapping is correct. One suggestion (Issue M1) to improve
the convergence-diagnostic label in the non-convergence warning message — worth
fixing but does not block implementation.
