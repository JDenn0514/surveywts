## Methodology Review: sample-calibration-api — Pass 1 (2026-06-11)

### Scope Assessment

This spec covers an API redesign of `calibrate_to_survey()` and
`calibrate_to_estimate()`. The actual calibration algorithms are delegated to
svrep. However, the spec does contain methodologically significant content:

- Replicate-based variance propagation (the entire statistical justification for
  requiring `survey_replicate` inputs)
- `unit_scale` parameter wiring (a variance-model parameter that enters the
  calibration estimator)
- `vcov_estimate` handling and target perturbation mechanism (how target
  uncertainty propagates into replicate weights)
- Convergence error detection (affects whether partial results are exposed)
- Negative weight clipping behavior (affects whether calibration constraints are
  preserved)

All five lenses apply.

---

### New Issues — Pass 1

#### Lens 1 — Method Validity

**Issue 1: `unit_scale` applicability is not stated per method**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec defines `unit_scale` as "per-observation scaling factors passed to
svrep's `variance` argument" and says "NULL is equivalent to all-ones." For
`method = "linear"` (GREG), the `q_k` variance parameters clearly enter the
calibration estimator. For `method = "rake"` (IPF), the variance model has
no standard interpretation — the spec does not state whether svrep accepts
or ignores `variance` for raking. For `method = "logit"` the situation is
similarly ambiguous.

If svrep silently ignores `unit_scale` for `"rake"` or `"logit"`, users who
pass non-NULL `unit_scale` with those methods will not get the effect they
expect — and no warning is emitted. The spec must state, for each method,
whether `unit_scale` has an effect.

Fix: Add a method-specific note to the `unit_scale` `@param` and to
`@details`: "`unit_scale` enters the calibration estimator as the `q_k`
variance parameters in linear GREG. For `method = \"rake\"` and
`method = \"logit\"`, svrep's behaviour with a non-NULL `variance` argument
must be verified; if ignored, surveywts should warn when `unit_scale` is
non-NULL and method is not `\"linear\"`."

Options:
- **[A]** Verify svrep behavior for each method; document exactly which
  methods use `unit_scale` and warn when it is set for a method that ignores
  it — Effort: low, Risk: low, Impact: prevents silent no-ops, Maintenance: low
- **[B]** Document that `unit_scale` is passed to svrep for all methods and
  leave svrep behavior as the authority — Effort: very low, Risk: medium
  (silent wrong use), Impact: users may be misled
- **[C] Do nothing** — Users who pass `unit_scale` with `"rake"` get silently
  incorrect (or silently ignored) results.

**Recommendation: A** — Verify once; document and warn. The effort is low and
the alternative is a silent no-op that affects real analyses.

---

**Issue 2: Non-determinism when `control_col_matches` / `col_selection` is NULL is undocumented**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec says that when `control_col_matches` is absent from `control` in
`calibrate_to_survey()`, "svrep uses random matching." Similarly, when
`col_selection` is absent from `control` in `calibrate_to_estimate()`,
"svrep uses random draws." This means two calls with identical inputs
(same seed state aside) can produce different calibrated weights. This is a
material property for any user who expects reproducible results.

Neither the `@param` docs nor `@details` mentions non-determinism. A user who
calls `calibrate_to_survey(primary, control, variables = c(sex))` twice and
gets different weights will have no explanation.

Fix: Add a sentence to the `control` `@param` and to `@details` noting that
results are non-deterministic when `control_col_matches` / `col_selection`
is absent, and that setting these to a fixed value ensures reproducibility.

Options:
- **[A]** Add non-determinism note to `@param control` and `@details` for
  both functions — Effort: low, Risk: low, Impact: users can make informed
  reproducibility decisions, Maintenance: none
- **[B]** Do nothing — Effort: zero, Risk: medium (user confusion, bug reports
  attributing randomness to a code bug)

**Recommendation: A** — One sentence in each doc prevents user confusion.

---

#### Lens 2 — Variance Estimation Validity

**Issue 3: Target perturbation mechanism in `calibrate_to_estimate()` is ambiguous for the builder**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec says `vcov_estimate` is validated (NA, dimension, symmetry, PD) and
then the function "Call[s] svrep." What svrep does with `vcov_estimate` —
generate Cholesky-based normal perturbations for each replicate's targets —
is not stated anywhere. The spec describes *what* is validated but not *where
the validated matrix goes after validation* or *which svrep call receives it*.

A builder reading this spec would know to validate `vcov_estimate` but would
not know whether to:
(a) Pass it to svrep as-is and let svrep generate the perturbed targets, or
(b) Generate the perturbed targets themselves (Cholesky sampling) and pass
    the perturbed targets to svrep.

These are two very different implementations. If the builder chooses (b) when
the answer is (a), variance propagation will be wrong.

Fix: Add to the body of `calibrate_to_estimate()`: "After validation, pass
`vcov_estimate` directly to `svrep::calibrate_to_estimate()` as its
`vcov_estimate` argument. Svrep generates the replicate-level perturbed
targets internally using the Cholesky factor of `vcov_estimate`. Do not
implement perturbation sampling in surveywts."

Options:
- **[A]** Add one sentence to the function contract making the delegation to
  svrep explicit — Effort: very low, Risk: low, Impact: eliminates builder
  ambiguity, Maintenance: none
- **[B]** Do nothing — Risk: high (builder implements perturbation sampling
  in surveywts, doubling the variance or using wrong draws)

**Recommendation: A** — One sentence eliminates a fork in implementation.

---

**Issue 4: Replicate duplication understates control-survey variance — undocumented**
Severity: SUGGESTION
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec states: "If `primary_design` has more replicates than
`control_design`, svrep duplicates control replicates to fill." Duplicate
control replicates reduce the effective number of control variance estimates —
if the same control replicate is matched to multiple primary replicates, the
contribution of control-survey variance to the total variance estimate is
understated. The user is not informed of this trade-off.

Fix: Add a note to `@details` or the `@param control_design` in
`calibrate_to_survey()`: "When `primary_design` has more replicates than
`control_design`, svrep duplicates control replicates. This approximation
understates the control-survey variance contribution; users who require
precise variance propagation should construct designs with matched replicate
counts."

Options:
- **[A]** Add one-sentence limitation note to docs — Effort: low, Risk: low
- **[B]** Do nothing — Risk: low (behavior is svrep-delegated and documented
  in svrep; the statistical consequence is minor in practice)

**Recommendation: A** — Worth one sentence in `@details` given the function's
stated goal is correct variance propagation.

---

#### Lens 3 — Algorithmic Correctness

**Issue 5: Convergence detection via string matching on svrep warning message is fragile**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

The spec says `surveywts_error_calibration_not_converged` is triggered when
"svrep emits a warning containing 'converge'". This depends on svrep's
internal warning message text not changing. If svrep updates its message from
(e.g.) "Algorithm did not converge" to "Calibration failed to reach
convergence tolerance", the check may or may not match depending on the exact
grep pattern used.

Additionally, when svrep emits a convergence warning, it still returns a
result (partially converged weights). The spec converts this to a hard error,
discarding the partial result. This is an opinionated design choice (user
gets a hard failure rather than a partial result with a warning) that should
be documented.

Options:
- **[A]** Keep string matching on "converge" but document the fragility in a
  code comment; add a note in `@details` that partial convergence results are
  discarded — Effort: low, Risk: low-medium (works until svrep changes
  message), Impact: acceptable, Maintenance: low
- **[B]** Use `withCallingHandlers()` to intercept all warnings from svrep and
  inspect the `rlang_message_class` if svrep uses classed warnings; fall back
  to string matching — Effort: medium, Risk: low, Impact: more robust
- **[C] Do nothing** — Risk: if svrep changes warning text, convergence errors
  pass silently as "calibration_failed" instead of "not_converged", giving
  wrong error class to users

**Recommendation: A** — The string matching approach is pragmatic given svrep
doesn't expose a typed convergence warning class. Document the approach in a
code comment and test with a snapshot so a svrep message change is caught by
CI.

---

**Issue 6: Negative weight clipping breaks calibration constraint — undocumented**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

The spec states: "Negative full-sample weights are clipped to
`.Machine$double.eps` after the warning is emitted; replicate weights are
not clipped."

Linear calibration (GREG) guarantees that the calibrated weight sum equals the
control survey's weight sum (or the sum of targets for `calibrate_to_estimate`).
Clipping negative weights to `.Machine$double.eps` increases the weight sum
above the intended total. After clipping:

  Σ clipped_weights > Σ targets

This violates the calibration constraint. Survey estimates computed from the
clipped weights will be biased — they will not be calibrated to the targets
the user intended. The spec does not document this consequence. The test-spec
tests that `weights >= .Machine$double.eps` but does not test that the
calibration constraint remains satisfied after clipping.

This behavior is carried over from the existing implementation. The spec must
choose one of the following and document it:

Options:
- **[A]** Clip and document the constraint violation explicitly in `@details` and
  in the warning message ("Note: clipping breaks the calibration constraint;
  the resulting weights no longer sum to the target total.") — Effort: low,
  Risk: low, Impact: users are informed
- **[B]** Renormalize after clipping: after clipping, apply a proportional
  rescaling so the calibrated weight sum is restored — Effort: medium, Risk:
  medium (renormalization is ad hoc and changes other units' weights), Impact:
  preserves weight sum but not all calibration constraints
- **[C]** Remove clipping entirely: emit the warning for negative weights but
  do not clip. Users receive negative weights (which are statistically valid in
  linear calibration) — Effort: low, Risk: medium (user-visible negative
  weights may cause downstream errors in packages that expect positive weights)

**Recommendation: A** — The existing behavior (clip) is defensible for
usability, but the calibration constraint violation must be documented.
Silently returning weights that appear to satisfy the survey design but
violate calibration constraints is worse than a documented limitation.

---

**Issue 7: Weight sum conservation after `calibrate_to_estimate()` not stated**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The `calibrate_to_survey()` contract includes: "The calibration intercept
constraint forces the calibrated weight sum to equal the control survey's
weight sum." The `calibrate_to_estimate()` contract has no equivalent
statement. After calibration to a set of named population totals, what does
`sum(calibrated_weights)` equal?

For standard calibration with an intercept: `sum(calibrated_weights)` equals
the sum of all target totals divided by the number of variables... actually
this depends on how the intercept is handled. More precisely: for
`calibrate_to_estimate()`, the calibration model includes an intercept if one
variable (age_group, say) has targets that sum to the total population N. If
all target variables are cell proportions that sum to N, then
`sum(calibrated_weights) = N`. If targets are counts for overlapping
categories, the total is more complex.

At minimum, the spec should state: "The calibrated weight sum equals
`sum(primary_design@variables$weights)` after calibration (the intercept
constraint preserves the original total N)" — or whatever the correct
statement is for svrep's `calibrate_to_estimate()` behavior.

Fix: Add a weight-sum conservation statement to the Returns section of
`calibrate_to_estimate()`, mirroring the equivalent statement already
present in `calibrate_to_survey()`.

Options:
- **[A]** Check svrep::calibrate_to_estimate() behavior for weight sum and
  add the appropriate statement to the Returns section — Effort: low, Risk:
  low, Impact: users know what to expect
- **[B]** Do nothing — Risk: users who check `sum(result_weights)` get an
  unexpected value with no explanation

**Recommendation: A** — This is a one-sentence addition that closes a gap
already filled for the companion function.

---

#### Lens 4 — Statistical Assumptions

**Issue 8: `unit_scale` statistical interpretation absent from docs**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The `unit_scale` parameter's statistical meaning is not described in the spec.
In GREG calibration, the `q_k` parameters define a variance model:
Var(y_k | x_k) ∝ q_k. Setting `unit_scale[k] = 2` for unit k means assuming
that unit is twice as variable, which down-weights it in the calibration
(it receives a smaller calibration adjustment). This is a substantive
modeling assumption — the spec treats it as a generic "scaling factor" without
explaining what statistical model it implies.

Fix: Add to `@param unit_scale` or `@details`: "In linear calibration (GREG),
`unit_scale[k]` plays the role of the variance model parameter `q_k`: units
with larger values contribute less to the calibration adjustment. Setting all
values equal (or leaving `NULL`) corresponds to assuming homoscedasticity."

Options:
- **[A]** Add statistical interpretation to docs — Effort: low, Impact: users
  can make informed decisions about when to use non-trivial `unit_scale`
- **[B]** Do nothing — users use `unit_scale` without understanding the model
  assumption

**Recommendation: A** — One sentence in the parameter docs prevents misuse.

---

#### Lens 5 — Formula Integrity

No BLOCKING or REQUIRED formula issues. The formulas for rake/linear/logit
calibration and the replicate variance propagation are implemented in svrep
and referenced rather than derived in the spec. The @references section cites
Fuller (1998) and Opsomer & Erciulescu (2021). The ordering contract for
`vcov_estimate` rows/columns is precisely specified with an example.

Minor note: the spec does not give the closed-form expression for how
`unit_scale` enters the linear GREG estimator, but this is covered under
Issue 8 (Lens 4) and is a documentation gap, not a formula integrity failure.

Lens 5: No issues beyond those captured above.

---

#### Lens 6 — Literature Cross-Check

Lens 6 not applicable: Stage 0 was auto-transitioned (no methods — statistical
algorithms are in svrep). No `comprehension.md` was generated, and no papers
were attached.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 8

**Overall assessment:** The spec is methodologically sound — the core design
(require replicate designs, delegate calibration to svrep, propagate control
uncertainty via replicate calibration) follows Fuller (1998) and Opsomer &
Erciulescu (2021) correctly. The five REQUIRED issues are documentation and
behavioral specification gaps rather than wrong math: `unit_scale` needs
per-method clarity (Issue 1), the target perturbation delegation to svrep
needs to be explicit for the builder (Issue 3), the calibration constraint
violation from negative weight clipping needs to be documented (Issue 6), and
the convergence detection fragility needs acknowledgment (Issue 5). None of
these will cause silent wrong answers in the happy path, but Issues 5 and 6
will cause subtle biases or wrong behavior in edge cases that the current spec
does not address.

---

## Methodology Review: sample-calibration-api — Pass 2 (2026-06-11)

### Prior Issues (Pass 1)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | `unit_scale` applicability not stated per method | 1 | ✅ Resolved |
| 2 | Non-determinism when col-match args are NULL undocumented | 1 | ✅ Resolved |
| 3 | Target perturbation mechanism ambiguous for builder | 2 | ✅ Resolved |
| 4 | Replicate duplication understates control-survey variance | 2 | ✅ Resolved |
| 5 | Convergence detection via string matching is fragile | 3 | ✅ Resolved |
| 6 | Negative weight clipping breaks calibration constraint | 3 | ✅ Resolved |
| 7 | Weight sum conservation after calibrate_to_estimate() not stated | 3 | ✅ Resolved |
| 8 | unit_scale statistical interpretation absent from docs | 4 | ✅ Resolved |

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

No new issues.

#### Lens 6 — Literature Cross-Check

Lens 6 not applicable: no comprehension.md and no papers attached.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total new issues:** 0

**Overall assessment:** All 8 Pass 1 issues resolved. The spec now documents
per-method unit_scale semantics, non-determinism for both functions,
explicit vcov delegation to svrep, replicate duplication variance limitation,
convergence string-matching fragility, negative weight clipping constraint
violation, and weight-sum conservation for calibrate_to_estimate(). Verdict:
**PASS**.
