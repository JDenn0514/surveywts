## Methodology Review: calibrate-unit-scale — Pass 1 (2026-06-09)

### Scope Assessment

This spec modifies the Newton-Raphson calibration engine (iterative algorithm),
adds per-unit q-weights to three formula locations (u_vec, Jacobian,
step-halving), and fixes absolute-bounds handling with per-unit vectors. All
five lenses apply. No paper was attached; Lens 6 not applicable.

---

### New Issues

#### Lens 1 — Method Validity

**Issue 1: `.make_calfun_logit()` must change for vector L/U — spec claims otherwise**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec's Architecture section states:

> `.make_calfun_logit()` argument contracts are extended — `L` and `U` may now
> be numeric vectors of length n (per-unit bounds) in addition to scalar.
> Since `pmax`, `pmin`, arithmetic, and `exp` all vectorize, the function
> bodies are unchanged; only the argument contract expands.

This claim is FALSE for `.make_calfun_logit()`. Reading the implementation at
`R/calibrate-utils.R:559–607`, the internal `.eval_f()` closure computes:

```r
A <- (U - L) / ((1 - L) * (U - 1))   # length-n vector when L, U are vectors

.eval_f <- function(u) {
  au <- A * u                          # length-n: fine
  ...
  large_pos <- au > 500
  if (any(large_pos)) {
    ena <- exp(-au[large_pos])         # length = sum(large_pos)
    f[large_pos] <- (L * (U - 1) * ena + U * (1 - L)) /    # L is length-n!
      ((U - 1) * ena + (1 - L))                              # dimension mismatch
  }
  ...
}
```

When `L` and `U` are length-n vectors, `L * (U - 1)` has length n, while
`ena` has length `sum(large_pos)`. R's recycling rules produce silently
wrong values (or an error if the lengths are not multiples of each other).
The `.eval_f()` function body **must** be modified to subset `L` and `U`
within the `large_pos` branch.

The `dF` function is unaffected — `A * (f - L) * (U - f) / (U - L)` is
element-wise and vectorizes cleanly.

The claim IS correct for `.make_calfun_linear()`: `pmax(lo, pmin(hi, u))` with
`lo = L - 1`, `hi = U - 1` as length-n vectors vectorizes correctly. That
half of the claim stands; only the logit half fails.

**Fix:** Modify the Architecture section to state that `.make_calfun_logit()`
**also** requires a body change: in the `large_pos` branch, subset L and U
(and A) to match the `large_pos` index. The corrected `.eval_f()`:

```r
.eval_f <- function(u) {
  au <- A * u
  f <- numeric(length(u))

  large_pos <- au > 500
  if (any(large_pos)) {
    ena    <- exp(-au[large_pos])
    L_sub  <- if (length(L) > 1L) L[large_pos] else L
    U_sub  <- if (length(U) > 1L) U[large_pos] else U
    f[large_pos] <- (L_sub * (U_sub - 1) * ena + U_sub * (1 - L_sub)) /
      ((U_sub - 1) * ena + (1 - L_sub))
  }

  normal <- !large_pos
  if (any(normal)) {
    ea     <- exp(au[normal])
    L_sub  <- if (length(L) > 1L) L[normal] else L
    U_sub  <- if (length(U) > 1L) U[normal] else U
    f[normal] <- (L_sub * (U_sub - 1) + U_sub * (1 - L_sub) * ea) /
      (U_sub - 1 + (1 - L_sub) * ea)
  }

  pmax(L, pmin(U, f))
}
```

The final `pmax(L, pmin(U, f))` also requires L and U to be broadcastable
against f (both length-n) — this works with either scalar or vector L/U.

Options:
- **[A]** Update Architecture section to remove "function bodies are unchanged"
  for `.make_calfun_logit()`. Add the corrected `.eval_f()` body to the write
  surface description, including the scalar-compat guard
  `if (length(L) > 1L) L[index] else L`. Also update the "no new error classes"
  rationale to confirm the `large_pos` branch stays as a numerical guard.
  Effort: low. Risk: low. Impact: prevents builder from silently writing a
  broken logit D6 implementation. Maintenance: none beyond the one-time fix.
- **[B]** Remove the D6 fix for logit absolute bounds entirely; keep only
  the mean-based approach for logit. Effort: low. Risk: low. Impact: D6 fix is
  not applied to logit, and Quality Gate 7 cannot hold for unequal base
  weights under logit. The spec's stated goal (exact per-unit bounds) is not
  achieved for logit.
- **[C] Do nothing** — Builder reads the spec, does not change `.make_calfun_logit()`
  body, ships a logit absolute-bounds calibration that silently produces wrong
  weights whenever any unit has `au > 500` (plausible in large surveys with
  extreme bounds).

**Recommendation: A** — The fix is a three-line index-subsetting change.
Excluding it from the write surface leaves the builder with a false claim
that will ship a silent numerical bug.

---

**Issue 2: Logit calfun precondition L < 1 < U undefined for absolute
per-unit bounds**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The logit calibration function formula requires `L < 1 < U` to satisfy
`F(0) = 1` (so initial g-weights equal base weights at `lambda = 0`) and
`A > 0` (so the function is monotone increasing). From `R/calibrate-utils.R:560`:

```r
A <- (U - L) / ((1 - L) * (U - 1))
```

When `U = 1`, `A` is Inf. When `L >= 1`, `(1 - L) <= 0` so A is zero or
negative. Both cases break the function.

For multiplicative bounds, `.validate_bounds()` already enforces `L < 1 < U`.
For absolute bounds, `.validate_bounds()` only enforces `0 < L < U`. After
the D6 fix, the per-unit bounds are `L_vec[k] = L_abs / d_k`. The condition
`L_vec[k] < 1` holds only when `d_k > L_abs`. If any unit has `d_k <= L_abs`,
the logit calfun is called with `L_vec[k] >= 1`, producing `A[k] <= 0` and
silently wrong calibrated weights (or numerical errors).

This is a pre-existing concern (the current mean-based approach has the same
issue when `mean(d_k) <= L_abs`), but the D6 fix exposes it per-unit for every
unit individually, making it more likely to trigger silently.

The spec does not document this constraint anywhere — not in the preconditions
for `calibrate_logit()`, not in the edge cases table, not in the D6 description.

**Fix:** Add to the spec's edge cases table (or a new precondition note) for
the D6 logit absolute path:

> **Logit absolute bounds precondition:** `.make_calfun_logit()` requires
> `L_vec[k] < 1 < U_vec[k]` for all k, i.e., `L_abs < d_k < U_abs` for every
> unit. When this fails (unit's base weight is outside the absolute bounds),
> the logit function is ill-defined (A ≤ 0). Callers should either (a) add a
> pre-engine validation step checking `all(d_k > L_abs & d_k < U_abs)`, or
> (b) document this as a known precondition and let the engine surface
> `surveywts_error_calibration_singular_system` or non-convergence.

The preferred resolution (a) is a single `any(weights_vec <= abs_L | weights_vec >= abs_U)` check before building the calfun.

Options:
- **[A]** Add a precondition check before building the absolute logit calfun:
  if any `d_k <= L_abs` or `d_k >= U_abs`, emit `surveywts_error_bounds_invalid_calibration`
  (or a new class) with an actionable message. Effort: low. Risk: low. Impact:
  surfaces a configuration error explicitly instead of producing wrong weights.
  Maintenance: none.
- **[B]** Document the constraint as a known limitation without validation.
  Add to the edge cases table: "Logit absolute bounds require `L_abs < d_k < U_abs`
  for all k; violated units may cause non-convergence or wrong weights." Effort:
  trivial. Risk: low but leaves silent failure possible. Maintenance: none.
- **[C] Do nothing** — silent wrong output or non-convergence when any
  `d_k <= L_abs`. Not documented. Users will not understand why calibration
  fails or produces wrong weights.

**Recommendation: A** — The check is one line. Silent wrong output is
unacceptable for a calibration function.

---

#### Lens 2 — Variance Estimation Validity

Lens 2 not applicable: this feature modifies the calibrated weight values
(by adding per-unit q-weights and fixing absolute bounds) but does not change
the variance estimator or the replicate loop structure. The replicate loop
correctly applies the same `q_for_engine` vector (a full-sample-constant
quantity) to every replicate calibration, which is correct — unit_scale is a
property of each respondent, not of the replication scheme.

---

#### Lens 3 — Algorithmic Correctness

The NR algorithm with D1/D2/D3 fixes is mathematically correct:

- **D1** (`u_k = q_k * x_k' lambda`): correct — this is the standard
  Deville-Sarndal linear predictor with q-weighting.
- **D2** (Jacobian `= X' diag(d * F'(u) * q) X`): correct — this is the
  exact first derivative of `phi(lambda) = X' (d * F(q * X lambda))` with
  respect to lambda.
- **D3** (step-halving guard uses `q_weights * (X %*% lambda_new)`): correct
  — the guard should evaluate `g_k = F(u_k^{new})` at the candidate lambda,
  and `u_k = q_k * x_k' lambda` is the correct argument.

Convergence criterion is unchanged (same epsilon, maxit, same relative misfit
formula). Weight conservation holds at convergence by construction.

**Issue 3: `drop()` inconsistency between D1 table and pseudocode**
Severity: SUGGESTION
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The D1 row of the discrepancy table shows:
```
u_vec = q_weights * drop(x_matrix %*% lambda)
```
But the NR pseudocode (§Function contracts §Corrected pseudocode) shows:
```
u_vec = q_weights * (X %*% lambda)
```
No `drop()` in the pseudocode. In R, `x_matrix %*% lambda` returns an n×1
matrix. Multiplying by `q_weights` (a length-n vector) would broadcast to an
n×1 matrix, not a length-n vector. Without `drop()`, subsequent uses of
`u_vec` (e.g., `calfun$Fm1(u_vec)`) would operate on a matrix rather than a
vector, which may produce wrong output dimensions. The current engine code uses
`drop(x_matrix %*% lambda)` consistently. The pseudocode should also use
`drop()`.

Options:
- **[A]** Add `drop()` to the pseudocode. Effort: trivial. Risk: none.
- **[C] Do nothing** — implementer may read the pseudocode and omit `drop()`,
  causing downstream dimension mismatches that could surface as hard-to-debug
  shape errors.

**Recommendation: A** — trivial fix, prevents a confusing shape error.

---

#### Lens 4 — Statistical Assumptions

No new statistical assumptions introduced. The spec correctly documents:

- `q_weights` positivity validated by callers (`.validate_unit_scale()`).
- D4 (convention: `q_k` vs `1/q_k`) documented, not in scope.
- Replicate loop uses the full-sample `q_for_engine` (not per-replicate) — this
  is correct because unit_scale is a per-unit sample property.
- Quality Gate 1 (unit_scale = NULL → identical to pre-fix) is properly
  justified: `u_k = 1 * X lambda = X lambda`. ✓

Lens 4: no issues beyond Issue 2 already flagged under Lens 1.

---

#### Lens 5 — Formula Integrity

Formulas D1, D2, D3 are stated precisely with symbol bindings and are
mathematically correct (verified by deriving `phi'(lambda)` from the
Lagrangian). The convergence formula `max(|misfit| / (1 + |population|)) < epsilon`
is standard. The D6 transformation `L_vec = L_abs / d_k → d_k * g_k in [L_abs, U_abs]`
is algebraically correct for both linear and logit (when the logit function body
is fixed per Issue 1).

Issue 3 (the `drop()` inconsistency) is the only formula presentation gap —
see Lens 3 above.

Lens 5: no additional issues beyond Issue 3.

---

#### Lens 6 — Literature Cross-Check

Lens 6 not applicable: no paper attached, no `comprehension.md` present.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 1 |
| SUGGESTION | 1 |

**Total issues:** 3

**Overall assessment:** The q-weights algebra (D1/D2/D3) and the D6 linear
absolute-bounds fix are mathematically sound. The D6 logit fix has a
BLOCKING implementation error: the spec claims `.make_calfun_logit()` function
body is unchanged with vector L/U, but the internal `.eval_f()` uses
index-based subsetting that fails when L and U are vectors. A builder following
the spec as written would ship silent numerical errors for logit absolute bounds
whenever any calibration linear predictor exceeds 500. This must be resolved
before implementation.

---

## Methodology Review: calibrate-unit-scale — Pass 2 (2026-06-09)

### Prior Issues (Pass 1)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | `.make_calfun_logit()` must change for vector L/U | 1 | ✅ Resolved |
| 2 | Logit calfun precondition L < 1 < U undefined for absolute per-unit bounds | 1 | ✅ Resolved |
| 3 | `drop()` inconsistency between D1 table and pseudocode | 3 | ✅ Resolved |

### Resolution notes

**Issue 1** — Architecture section updated. `.make_calfun_logit()` now explicitly
listed as requiring a body fix, with the corrected `.eval_f()` implementation
(scalar-compat guards `L_sub <- if (length(L) > 1L) L[idx] else L` in both
branches). The claim "function bodies unchanged" has been removed for the logit
calfun.

**Issue 2** — Applied Option A using the existing `surveywts_error_bounds_invalid_calibration`
class (no new error class required). The `calibrate_logit.R` write surface now
specifies a pre-calfun check: `all(weights_vec > abs_L & weights_vec < abs_U)`
before building the logit calfun with vector bounds — applied in both the
full-sample and replicate-loop branches. Edge cases table extended with two rows
(base weight below L_abs; base weight above U_abs). Test-spec extended with
HGE-4 and HGE-5 using the dual error pattern.

**Issue 3** — All four occurrences of `q_weights * (X %*% lambda*)` in the NR
pseudocode updated to `q_weights * drop(X %*% lambda*)`, matching the discrepancy
table and the current engine implementation.

### New Issues

No new methodology issues found on re-review of the updated spec.

Lens 1 check on Issue 2 resolution: the precondition `all(d_k > L_abs & d_k < U_abs)` is
now stated in the write surface and edge cases table. The existing
`surveywts_error_bounds_invalid_calibration` class is correctly scoped to
`calibrate_logit()`. Reusing it for this condition is consistent with its
existing semantics (invalid bounds configuration). ✓

Lens 3 check on Issue 3 resolution: all four `drop()` sites in the pseudocode
now match the D1 entry in the discrepancy table and the actual engine code. ✓

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total new issues:** 0

**Overall assessment:** All three Pass 1 issues resolved. The spec is
methodologically sound and ready for Stage 3 review.
