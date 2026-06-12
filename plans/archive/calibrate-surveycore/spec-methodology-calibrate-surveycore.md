## Methodology Review: calibrate-surveycore — Pass 1 (2026-06-04)

### Prior Issues (Pass 0)

_Omit this section on Pass 1._

---

### New Issues

#### Lens 1 — Method Validity

**Issue 1: Raking x_matrix with full dummy encoding is rank-deficient for 2+ variables**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec states (§ `calibrate_rake()` x_matrix construction):
> "Full dummy indicator matrix. For each variable v with levels L_1...L_m, create m columns: column j = (data_col == L_j). Stack all variables column-wise."

And the note asserts:
> "Using full encoding ensures the variance formula operates on the complete marginal structure... singular with full encoding only if a margin cell is exactly zero — already caught by validation."

This claim is **mathematically wrong**. With two or more raking variables, the full dummy indicator matrix is rank-deficient due to an algebraic constraint: for each variable v_j, the sum of its m_j indicator columns equals the all-ones vector. With two raking variables (levels m1 and m2), the combined X has columns satisfying I(v1=L1)+...+I(v1=Lm1) = ones = I(v2=L1)+...+I(v2=Lm2), giving the relation: sum(v1-columns) − sum(v2-columns) = 0. This is a non-trivial linear combination of the X columns equaling zero → X is rank-deficient regardless of whether any margin cell is empty. With k raking variables, rank deficiency equals k−1.

Consequence: `crossproduct_inv = solve(t(x_matrix) %*% (base_weights * q_weights * x_matrix))` will throw "system is computationally singular" for any raking calibration with 2+ variables. The function will error at runtime during provenance assembly.

The correct fix is to use the same encoding as `calibrate_greg()`: treatment contrasts (model.matrix default). For raking, this means building x_matrix by calling `model.matrix(~v1 + v2 + ..., data = data_df, contrasts = contr.treatment)`. This produces an intercept column plus (m_j − 1) dummies per variable. J = 1 + Σ(m_j − 1). This matches the treatment-contrast structure that the existing calibration engine already uses internally when it calls `survey::calibrate()` with a formula.

The `population_totals` stored in `@calibration` must match the treatment-contrast parameterization: the intercept column's population total is the sum of all design weights (≈ N), and each dummy column's total is the count in that level (in count scale).

Options:
- **[A]** Use `stats::model.matrix(formula, data = data_df)` for raking x_matrix, exactly as described for GREG. The formula is constructed from the names of raking variables (e.g., `~ age_group + sex`). This makes x_matrix non-singular for any non-empty level and produces J = 1 + Σ(m_j − 1). Effort: low, Risk: low, Impact: fixes BLOCKING runtime failure, Maintenance: none.
- **[B]** Retain full dummy encoding and use `MASS::ginv()` (Moore-Penrose pseudoinverse) for crossproduct_inv. This adds a Suggests dependency and requires documenting that `crossproduct_inv` is a pseudoinverse. Effort: medium, Risk: medium (behavior of downstream variance routines with pseudoinverse not verified), Impact: fixes the inversion failure but complicates surveycore contract, Maintenance: ongoing (need to document pseudoinverse semantics).
- **[C] Do nothing** — `crossproduct_inv` computation fails at runtime for all users who rake with 2+ variables.

**Recommendation: A** — Treatment contrasts are non-singular by construction, consistent with the GREG x_matrix approach, and require no new dependencies.

---

#### Lens 2 — Variance Estimation Validity

No issues found. The spec correctly identifies all fields needed for variance estimation at analysis time: `x_matrix` (for computing residuals), `base_weights` (for $d_k$), `g_weights` (for $a_k = \tilde{w}_k/d_k$), `crossproduct_inv` (for $\hat{B}_s$ without re-inverting), and `cell_factors` (for the Valliant 1991 adjusted linearization deviate in post-stratification). These are exactly the quantities that surveycore needs to form the linearized variable $a_k e_k$, where $e_k = y_k - z_k^T \hat{B}_s$.

For `survey_replicate` inputs, `@calibration` is populated from the full-sample calibration, which is the correct approach: replicate-based variance is computed from the calibrated replicate weight columns directly, while `@calibration` supports any auxiliary Taylor-linearization step surveycore might apply.

---

#### Lens 3 — Algorithmic Correctness

**Issue 2: `NA_integer_L` is not valid R syntax**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec states (§ `.build_calibration_provenance()` computed fields):
> "When `engine_result$convergence$iterations` is `NA_integer_` (logit/ipf paths in `.calibrate_engine()`), store `NA_integer_L`."

`NA_integer_L` is not a valid R expression. In R, the typed NA for integer is `NA_integer_` (a pre-existing constant). The `L` suffix creates integer literals (e.g., `1L`) but cannot be combined with `NA`. An implementer writing `NA_integer_L` in code will get an error or unexpected behavior.

Correct specification: "store `NA_integer_`."

Options:
- **[A]** Change "store `NA_integer_L`" to "store `NA_integer_`" in the spec. Effort: low, Risk: none, Impact: prevents implementer writing invalid R code.
- **[B] Do nothing** — implementer will notice the invalid syntax when they write the code.

**Recommendation: A** — Spec text should be unambiguously correct; no reason to leave a known error.

---

#### Lens 4 — Statistical Assumptions

No blocking issues. The spec correctly reflects the relevant assumptions from the literature:
- Population totals are treated as known without error (matches comprehension.md Assumption 1). The spec does not expose uncertainty propagation, which is consistent with the literature's framing.
- Base weights must be strictly positive for the main weight column (enforced by `.validate_weights()`, as the spec notes).
- Newton-Raphson convergence is not guaranteed for bounded distance functions — the spec correctly delegates convergence failure to `surveywts_error_calibration_not_converged` (full sample) and `surveywts_warning_replicate_calibration_failed` (replicates).
- The asymptotic equivalence result (DS1992 Result 5) justifying GREG residuals for raking and poststrat is correctly applied.

---

#### Lens 5 — Formula Integrity

No issues beyond Issue 1 (already flagged). The following formulas were verified:

- `g_weights = engine_result$weights / base_weights` — correct: $a_k = \tilde{w}_k / d_k$.
- `discrepancy = population_totals - drop(t(x_matrix) %*% base_weights)` — correct: $\mathbf{Z} - \hat{\mathbf{Z}}_\pi = \mathbf{Z} - \mathbf{X}^T \mathbf{d}$.
- `crossproduct_inv = solve(t(x_matrix) %*% (base_weights * q_weights * x_matrix))` — formula is correct for full-rank X; blocked by Issue 1 for raking with 2+ variables.
- `lambda = crossproduct_inv %*% discrepancy` for linear GREG — correct: $\lambda = \mathbf{T}_s^{-1}(\mathbf{Z} - \hat{\mathbf{Z}}_\pi)$.

---

#### Lens 6 — Literature Cross-Check

**Issue 3: Raking lambda — spec deviates from comprehension without documentation**
Severity: SUGGESTION
Lens: 6 — Literature Cross-Check
Resolution type: JUDGMENT CALL

The comprehension.md `@calibration` list structure states for `lambda`:
> "For raking: final Newton iterate."

But the spec states for `calibrate_rake()`:
> "`lambda` in `@calibration`: `NULL` (raking uses the multiplicative form; Lagrange multipliers are iteratively updated but are not stored)"

This is a deliberate scope decision that is not flagged as a deviation from the comprehension. The decision to store NULL for raking lambda is defensible (the lambda concept in multiplicative raking requires extracting iterates from the engine, which adds complexity), but the spec should document why it diverges from the comprehension's guidance.

The variance formula does not require lambda directly — it uses g_weights, x_matrix, and crossproduct_inv. Storing NULL is therefore safe for correctness.

Options:
- **[A]** Add a sentence to the spec's `calibrate_rake()` section: "This deviates from the `@calibration` list structure in `comprehension.md`, which suggested storing the final Newton iterate. Lambda is not required for variance estimation; the decision to store NULL reduces implementation complexity without affecting downstream correctness." Effort: low, Risk: none.
- **[B]** Store the actual raking lambda by extracting from the engine. Would require engine modification or post-hoc recomputation. Effort: high, Risk: medium.
- **[C] Do nothing** — the deviation is implicit.

**Recommendation: A** — Documenting the deviation is costless and clarifies intent for future readers.

No other literature cross-check issues: all comprehension.md gotchas are covered by the spec; all reference mappings are traceable; the three cross-paper conflicts are resolved consistently in the spec.

---

## Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 1 |
| REQUIRED | 1 |
| SUGGESTION | 1 |

**Total issues:** 3

**Overall assessment:** The spec is methodologically sound for GREG and post-stratification. The one blocking issue — raking x_matrix singularity — will cause a runtime `solve()` failure for any user who rakes with 2+ variables and requests @calibration provenance. This is a straightforward fix (use treatment contrasts, same as GREG). The required issue is a spec text typo (`NA_integer_L`). The suggestion is a minor documentation gap about raking lambda.

---

## Resolution (Stage 2r — 2026-06-04)

| Issue | Resolution |
|-------|------------|
| Issue 1 (BLOCKING) | Applied Recommendation A. Raking x_matrix changed to treatment contrasts (`stats::model.matrix()`, same as GREG) throughout spec: field contract table, `calibrate_rake()` section, x_matrix construction table, and raking x_matrix note. test-spec RT-5 updated: J = 1 + Σ(m_j − 1), not sum of all levels. |
| Issue 2 (REQUIRED) | Applied Recommendation A. `NA_integer_L` → `NA_integer_` in `.build_calibration_provenance()` computed fields. |
| Issue 3 (SUGGESTION) | Applied Recommendation A. Added sentence to `calibrate_rake()` lambda documentation explaining the deviation from comprehension.md, confirming lambda is not required for variance estimation per DS1992 Result 5. |

**Mini-pass verdict:**
- Lens 1 (Method Validity): PASS — treatment contrasts non-singular by construction; consistent throughout spec and test-spec.
- Lens 3 (Algorithmic Correctness): PASS — valid R syntax.
- Lens 6 (Literature Cross-Check): PASS — deviation documented with justification.

**Stage 2 verdict: PASS**
