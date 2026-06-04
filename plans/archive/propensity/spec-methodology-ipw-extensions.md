# Methodology Review: ipw-extensions — Pass 1 (2026-05-26)

**Spec:** `plans/spec-ipw-extensions.md` v0.1
**Test-spec:** `plans/test-spec-ipw-extensions.md` v0.1
**Comprehension:** `plans/comprehension-ipw-extensions.md`
**Reviewer:** Stage 2 adversarial methodology pass

---

## Scope Assessment

The spec clearly triggers Stage 2:

- Iterative algorithm (Newton-Raphson) with convergence requirements
- Estimator definitions (IPW1 vs IPW2)
- Formulas that must produce numerically exact results (GEE covariate balance guarantee: `Σ w_k x_k = Σ d_k x_k` to 1e-6)
- Reference weight adjustment with a specific formula (Valliant 2020, Eq. 1)

All five lenses apply. Lens 6 applies because `comprehension-ipw-extensions.md` is present.

---

## New Issues

### Lens 1 — Method Validity

**Issue 1: GEE + `missing_method = "separate"` runtime decision missing from spec**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

The spec (§III.C) says: "This is documented in `ipw()`'s `@param missing_method`. No code change is needed inside the engine." The `@param estimating_eq` (§IV.H) adds: "When `missing_method = 'separate'`, the guarantee applies only to complete-case NPS rows."

The spec implies documentation-only (no runtime warning). But the comprehension's open questions says: "Option (a) — warn and allow. The warning class and message text must be added to the spec before implementation." These two artifacts disagree.

The test-spec explicitly flags this as HOLD: "is this covered by the existing caveat in `@param missing_method`, or does it warrant a runtime warning when both conditions are active?"

Without an explicit spec decision, the builder has no guidance and cannot close the test-spec HOLD. The builder could reasonably add a warning (creating an undocumented class) or omit one (leaving the limitation silent at runtime).

Options:
- **[A] Documentation only (current implicit spec choice)** — Add one sentence to §III.C: "No runtime warning is emitted; the limitation is documented in `@param estimating_eq`." Close the test-spec HOLD with this resolution. Effort: low, Risk: low (consistent with M-3 treatment), Impact: builder clarity, Maintenance: none.
- **[B] Emit a new runtime warning** — Define a new warning class `surveywts_warning_ipw_gee_calibration_partial` (or similar), add message text, update `plans/error-messages.md`, add a test. Effort: medium, Risk: low, Impact: user visibility when both conditions are active.
- **[C] Do nothing** — The test-spec HOLD is never closed; the builder guesses.

**Recommendation: [A]** — The M-3 treatment (doc-only caveat for "separate" interactions) is the established pattern. Option B adds complexity without significant user benefit since the limitation is already documented in the param description the user reads before calling the function.

---

**Issue 2: Rules 8b and 8c inspect pre-NA-deletion reference**
Severity: SUGGESTION
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec places Rules 8b and 8c (numeric range check and reference factor level check) "after Rule 8 (factor level alignment check)" — before Rule 9a (reference NA handling). This means the range and level checks inspect the full reference dataset including rows that will be dropped due to NA in selection variables.

In edge cases, a numeric covariate's max value may be carried by a reference row that has NA in another selection variable and will be excluded. After NA deletion, the effective reference range is narrower — but the warning fires (or doesn't) based on the pre-deletion range. This produces a false positive (warns when fitting range is fine) or false negative (doesn't warn when the post-deletion fitting range is actually narrower than the NPS range).

Fix: move Rule 8b and 8c to after Rule 9a (reference NA deletion), using `ref_data_for_fit` rather than `reference@data` for the range and level lookups. The quality gate already specifies "Rules 8b and 8c execute before reference NA handling is cleared" — this should be reversed.

Options:
- **[A] Move Rules 8b/8c to after reference NA deletion** — use `ref_data_for_fit` (post-NA reference) for both checks. Effort: low, Risk: low, Impact: correctly reflects fitting range, Maintenance: none.
- **[B] Keep current placement** — minor edge case; most data will have no NAs in reference selection variables. Effort: none, Risk: low (minor false positive/negative in edge cases only).
- **[C] Do nothing** — quality gate and spec are inconsistent (gate says "before" but behavior is more correct "after").

**Recommendation: [A]** — The fix is a one-line position change and makes the checks more meaningful. Update the quality gate to match.

---

**Issue 3: `@param adjust_reference` documentation uses `sum(ref_weights)` vs. `ref_weights_for_fit`**
Severity: SUGGESTION
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The `@param adjust_reference` text (§IV.H) says:
> "When `nps_fraction = nrow(data) / sum(ref_weights) > 0.05`..."

The behavior spec (Rule 9a-ii) says:
> "`n_hat <- sum(ref_weights_for_fit)` (estimated population size from the post-NA-deletion reference)"

`ref_weights_for_fit` is the post-NA-deletion version. Using `sum(ref_weights)` in the documentation implies pre-deletion weights, which differs when the reference has NAs in selection variables. A user who computes `sum(ref_weights)` manually to predict whether the warning fires will get the wrong answer.

Fix: replace `sum(ref_weights)` with `sum(ref_weights_after_NA_deletion)` or equivalent in the `@param adjust_reference` text.

Options:
- **[A] Use precise notation in param doc** — "When `nps_fraction = nrow(data) / sum(d)` where `d` are the reference design weights after excluding rows with NA in the selection variables, and `nps_fraction > 0.05`...". Effort: trivial, Risk: none.
- **[B] Keep current text** — notation is "approximately right" for the common case where the reference has no NAs. Effort: none, Risk: minor user confusion in edge cases.

**Recommendation: [A]** — Trivial fix; eliminates the ambiguity.

---

### Lens 2 — Variance Estimation Validity

**Issue 4: Jackknife procedure absent from variance documentation**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec presents jackknife as the *primary recommended* variance method:
> "Jackknife is generally preferred over bootstrap when point estimates are nearly unbiased: Valliant (2020, Table 9) shows jackknife confidence interval coverage consistently nearer the 95% nominal level than bootstrap with replacement."

But the spec then provides only a 5-step bootstrap procedure and no jackknife procedure. The primary recommendation is unsubstantiated by any how-to guidance.

Valliant (2020, §2.1.4, eqs. (2)–(3)) specifies the grouped jackknife with model refit. The key elements are: (1) group units into G groups, (2) for each group g, drop those units and refit `ipw()` on the reduced dataset, (3) compute the jackknife variance from the G replicate estimates.

Fix: add a parallel 4–5 step jackknife procedure immediately after the bootstrap procedure in `@details`:

```
A correct jackknife procedure:
1. Partition `data` into G groups (G = 20 is typical; Valliant (2020) uses G = 20 in simulations).
2. For each group g (1..G), omit group g from `data` and refit `ipw()` on the reduced data
   and the full `reference`.
3. Compute the estimand from each of the G replicate weighted samples.
4. Use the jackknife variance formula: V_JK = ((G-1)/G) * sum((theta_g - theta_bar)^2).
The model must be refit at each deletion group — not just the weights re-applied.
```

Options:
- **[A] Add jackknife procedure to @details** — 4-5 sentences, parallel to the existing bootstrap block. Effort: low, Risk: none, Impact: spec's "preferred" claim is now actionable, Maintenance: none.
- **[B] Relabel bootstrap as "primary" and jackknife as "alternative"** — weakens the claim but avoids adding content. Effort: trivial.
- **[C] Do nothing** — preferred method is recommended but not documented; users cannot follow the advice.

**Recommendation: [A]** — The existing bootstrap block took 5 steps; jackknife takes 4. Adding it is trivial and makes the preference claim actionable.

---

**Issue 5: Variance documentation does not differentiate MLE vs. GEE paths**
Severity: SUGGESTION
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The variance `@details` section (§IV.H) is written without reference to `estimating_eq`. For both paths, the refit requirement is the same and the replication-based approach applies identically. However, the asymptotic variance formulae differ: the analytical variance of IPW2 under MLE involves the `b2^T D b2` term from estimation of γ (Chen 2021, Theorem 1, eq. 3.5). Under GEE, the asymptotic variance structure is different (Beresewicz 2025, Remark 3 connects GEE to doubly robust efficiency).

The practical consequence for users: the same replication procedure is used for both paths. The distinction is analytical only. A single sentence noting "The refit requirement applies equally when `estimating_eq = 'gee'"` would close this gap.

Options:
- **[A] Add one sentence** — "The refit requirement applies identically regardless of `estimating_eq`." Effort: trivial.
- **[B] Do nothing** — A careful reader will infer this from the general description. The replication procedure is the same.

**Recommendation: [B]** — The inference is clear; adding the sentence is optional for editorial completeness only.

---

### Lens 3 — Algorithmic Correctness

**Issue 6: GEE convergence criterion not explicitly stated**
Severity: SUGGESTION
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec (§III.B) says "All code before the NR loop... is unchanged" and (§III.C) says "The existing `solve(hess, score)` with `tryCatch` for Hessian singularity is reused for both paths." The convergence check is inherited by reference but never explicitly stated.

A reader implementing the GEE path would need to infer that the convergence criterion is `max(abs(delta)) < epsilon` — the same as MLE. This is correct but requires reading the current code to confirm.

Fix: add one sentence to §III.C after the return value description:
> "Both paths use the same convergence criterion: `max(abs(delta)) < epsilon` checked after each NR step."

Options:
- **[A] Add explicit convergence criterion sentence** — eliminates ambiguity for implementers. Effort: trivial.
- **[B] Do nothing** — "unchanged" carries the implication; the convergence check is in §III.B by reference.

**Recommendation: [A]** — Two words of spec text eliminate a class of implementer questions. Trivial addition.

---

No other Lens 3 issues. The GEE Jacobian is NPS-side (verified against comprehension Formula 6). The reference term in the GEE score is correctly identified as fixed within iterations (does not depend on γ). The NR sign conventions are consistent. Weight conservation (`Σ 1/π̂_k` as `estimated_population_size`) is correctly specified.

---

### Lens 4 — Statistical Assumptions

**Issue 7: Non-overlap assumption not documented**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The comprehension (§Assumptions) documents: "NPS and reference do not overlap: If units appear in both samples, the 0/1 coding for NPS membership is ambiguous. The implementation does not check for this; it is assumed to be handled by the caller."

The spec's `@note` and `@param reference` say nothing about this assumption. A user who runs the reference panel respondents through `ipw()` as the NPS will get incorrect propensity estimates with no warning — the pseudo-likelihood's 0/1 coding for membership is violated.

The comprehension also notes: "Valliant (2020, §2.1.2) notes duplicates should be removed."

Fix: add a bullet to the `@note` section:
> **Non-overlapping samples:** The pseudo-likelihood assumes each population unit appears in at most one of `data` and `reference`. If units appear in both samples, the 0/1 NPS membership coding is inconsistent and propensity estimates will be biased. Remove any overlapping units from `reference` before calling `ipw()`.

Options:
- **[A] Add non-overlap assumption to @note** — one paragraph, cites Valliant (2020, §2.1.2). Effort: low, Risk: none, Impact: prevents silent bias for overlapping samples.
- **[B] Do nothing** — the assumption is implicit from the method description. Effort: none, Risk: users with overlapping samples get biased results silently.

**Recommendation: [A]** — This assumption is stated in the comprehension and in Valliant (2020). Omitting it from the user-facing documentation is a clear documentation gap.

---

**Issue 8: `@param population_size` "IPW1-style downstream estimation" claim is inaccurate**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The `@param population_size` text (§IV.H) says:
> "enabling IPW1-style downstream estimation (`mean = sum(w * y) / N`)"

This is inaccurate. The `population_size` argument affects **only the history entry** (`estimated_population_size` field). The weights themselves are `1/π̂_k` (IPW2/Hájek type). When `svymean()` is called on the returned `survey_nonprob`, it computes `Σ(w_k y_k) / Σ(w_k)` — the Hájek estimator — regardless of what `population_size` was supplied.

IPW1 downstream estimation would require dividing by N (not `Σ(w_k)`), which `svymean()` does not do. No mechanism exists in the package to make `svymean()` use the `population_size` history field as a denominator.

The current wording will mislead users into believing supplying `population_size` changes their analysis when it changes only the metadata record.

Fix: replace "enabling IPW1-style downstream estimation (`mean = sum(w * y) / N`)" with:
> "This value is stored in the history entry for reference only and does not affect the returned weights or any downstream `svymean()` call. When `population_size` is known, it can be used manually for IPW1-style estimation: `sum(result@data$ipw_weight * y) / population_size`."

Options:
- **[A] Fix wording to be accurate** — describe population_size as informational; give the manual IPW1 formula. Effort: low, Risk: none, Impact: eliminates misleading claim.
- **[B] Implement functional integration** — wire `population_size` into `svymean()` via a custom `svytotal` method. Effort: high, Risk: high (out of scope for this phase), Impact: large.
- **[C] Do nothing** — the existing text misleads users.

**Recommendation: [A]** — Fixing the wording is trivial and correct. Option B is out of scope for this spec.

---

### Lens 5 — Formula Integrity

No BLOCKING or REQUIRED formula issues found.

- GEE score `G(γ) = Σ x_k/π_k - Σ d_k x_k`: matches comprehension Formula 5. ✓
- GEE Jacobian `J(γ) = -Σ x_k x_k^T (1-π_k)/π_k`: matches comprehension Formula 6. ✓
- MLE score and Hessian: unchanged; verified in comprehension as exact code match. ✓
- Valliant adjustment `adjust_factor = 1 - nps_fraction = (n_hat - n_NPS)/n_hat`: matches comprehension Formula 8. ✓
- R implementation `colSums(X_nps_fit / pi_nps)` for `Σ x_k/π_k`: correct — R recycles `pi_nps` (length = nrow) down each column, producing row-wise division. ✓
- R implementation `colSums(X_ref * d_ref)` for `X_ref^T d_ref`: correct column-sum of element-wise product. ✓
- NR sign convention (GEE): `delta = solve(J, G)`, `gamma_new = gamma - delta`. With J negative semi-definite and G > 0 implying underweighted NPS, `J^{-1} G < 0`, so `gamma - delta` increases γ, increasing π_k, reducing Σ x_k/π_k toward the reference total. ✓
- Warning template arithmetic `round(n_hat)`, `round(adjust_factor, 4)`, `round(nps_fraction * 100, 1)`: all consistent with the variables defined in Rule 9a-ii. ✓

---

### Lens 6 — Literature Cross-Check

A `comprehension-ipw-extensions.md` exists. Lens 6 applies.

#### Formula fidelity

| Spec formula / claim | Comprehension source | Match? |
|---|---|---|
| GEE score | Formula 5 (Beresewicz eq. 3.3) | ✓ |
| GEE Jacobian | Formula 6 (derived from eq. 3.3) | ✓ |
| MLE score | Formula 3 (Chen eq. 3.2; Beresewicz eq. 3.1) | ✓ |
| MLE Hessian | Formula 4 (current code — verified) | ✓ |
| Valliant adjustment | Formula 8 (Valliant 2020 Eq. 1) | ✓ |
| `estimator = "ipw2"` | Formula 7 (Chen eq. 3.3; IPW2 = Hájek) | ✓ |
| `@param method` logit-only formal backing | §Assumptions (logistic only formally proven) | ✓ |
| Jackknife preferred | Valliant (2020) Table 9 | ✓ but no jackknife procedure given → Issue 4 |

#### Gotcha coverage

| Comprehension gotcha | Spec handling | Covered? |
|---|---|---|
| NPS saturation guard (outer, `X_nps_pred`) | Retained for all paths per §III.C | ✓ |
| GEE division by zero (inner guard on `pi_nps`) | `pi_nps <= eps` inner guard → `converged = FALSE` | ✓ |
| GEE Jacobian is NPS-side (different singularity) | `solve(hess, score)` with `tryCatch` reused | ✓ |
| Reference weight adjustment order of ops | Rule 9a-ii position: after reference NA, before NPS NA | ✓ |
| GEE + missing_method="separate" calibration partial | Documented in `@param estimating_eq` only | Partially — see Issue 1 |
| Reverse factor level check (M-1) | Rule 8c: warning, not error | ✓ |
| `n_hat` changes after adjustment (pre vs post) | Rule 9a-ii specifies pre-adjustment `n_hat` for warning | ✓ |
| `estimator = "ht"` wrong label (C-1) | Rule 20: `estimator = "ipw2"` | ✓ |

#### Reference mapping completeness

All citations in the spec are traceable to specific equations in the comprehension's reference mapping with one gap:

**Issue 9: Yang et al. (2020) missing from doubly robust @details**
Severity: SUGGESTION
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

The comprehension's reference mapping attributes H-4 (doubly robust recommendation) to both Valliant (2020) conclusion and Yang et al. (2020) §6. The spec's doubly robust `@details` block (§IV.H) cites only Valliant (2020). Yang et al. (2020) "DR substantially outperforms IPW-only under misspecification" is a distinct supporting claim.

Fix: add "(Yang et al., 2020)" alongside the Valliant (2020) citation in the doubly robust @details sentence.

Options:
- **[A] Add Yang et al. (2020) to the citation** — two words. Effort: trivial.
- **[B] Do nothing** — Valliant (2020) citation is sufficient.

**Recommendation: [A]** — Two words; marginal improvement for literature traceability.

#### Assumption alignment

| Comprehension assumption | Spec coverage | Status |
|---|---|---|
| MAR (A1) | `@note` MAR section | ✓ |
| Positivity (A2) | Common support `@note` | ✓ |
| Independence (A3) | M-5 `@note` | ✓ |
| Logistic model formal backing | `@param method` | ✓ |
| Reference quality | `@param reference` (H-3) | ✓ |
| Measurement equivalence | `@param reference` (L-3) | ✓ |
| Common support (both directions) | Rules 8, 8b, 8c | ✓ |
| Non-overlap | NOT in spec | → Issue 7 |
| NPS fraction of population | `@param adjust_reference` + Rule 9a-ii | ✓ |

#### Open question resolution

| Comprehension open question | Spec resolution | Closed? |
|---|---|---|
| 5% threshold: argument vs. hardcode | Hardcoded; no `adjust_reference_threshold` arg | ✓ |
| GEE + separate: warn vs. doc-only | Spec implies doc-only; not stated explicitly | → Issue 1 |
| GEE warning class `surveywts_warning_ipw_gee_nps_scores_degenerate` | Resolved: existing error path reused | ✓ |
| L-4 + GEE: `population_size` affects only history | Spec says "affects only history entry" | ✓ but misleading → Issue 8 |
| `estimating_eq` in history entry | Rule 20 includes `estimating_eq` | ✓ |
| M-6 propensity_scores memory | Spec deems ~80KB acceptable; gives stripping instruction | ✓ |

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 5 |

**Total issues:** 9

**Overall assessment:** The core mathematics — MLE and GEE formulas, reference weight adjustment, propensity score history, common support checks — are all correctly specified and verified against the comprehension. No formula will produce wrong answers. The four REQUIRED issues are: (1) jackknife procedure absent despite being the primary recommendation, (2) inaccurate `population_size` documentation implying functionality that doesn't exist, (3) GEE + `missing_method = "separate"` decision left implicit, blocking the test-spec HOLD from closing, and (4) the non-overlap assumption documented in the comprehension but absent from user-facing docs. All four are documentation fixes requiring no algorithmic changes.

---

## Verdict: PASS

**Blocking findings:** 0
**JUDGMENT CALL resolution:** Issue 1 resolved — Option A (doc-only). Recorded in `decisions-ipw-extensions.md`.

All 9 issues resolved in Stage 2r (same session):
- Issue 1 (GEE + separate): explicit doc-only decision added to §III.C; test-spec HOLD closed ✅
- Issue 2 (Rules 8b/8c position): moved to after Rule 9a; use `ref_data_for_fit`; quality gate updated ✅
- Issue 3 (`adjust_reference` notation): `sum(ref_weights)` → precise post-NA notation ✅
- Issue 4 (jackknife procedure): 4-step jackknife procedure added to @details ✅
- Issue 5 (GEE variance note): accepted SUGGESTION-B (do nothing — inference is clear) ✅
- Issue 6 (GEE convergence criterion): explicit sentence added to §III.C ✅
- Issue 7 (non-overlap assumption): added to @note ✅
- Issue 8 (`population_size` IPW1 claim): fixed to "informational only" ✅
- Issue 9 (Yang et al. citation): added to doubly robust @details ✅

**Spec status advanced to:** METHODS_REVIEWED (v0.2). Ready for Stage 3 spec review.
