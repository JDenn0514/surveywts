# Spec Methodology Review — nps-calibration-path — Pass 1 (2026-06-15)

## Scope Assessment

This feature modifies two variance estimation replication functions:
`create_bootstrap_weights(type = "quasi-randomization")` and
`create_group_jackknife_weights()`. Both produce replicate weights — numerical
quantities used to compute variance estimates for NPS point estimates. The
change introduces a calibration-only replication path, which involves iterative
algorithms (IPF via `calibrate_rake()`) and formulas for scale factors (DAGJK)
and initial weights (QR bootstrap). Stage 2 is applicable.

Lenses applied: 1, 2, 3, 4, 5, 6.

---

### Lens 1 — Method Validity

**Issue 1: Warning message text references IPW/propensity scores on calibration-only path**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The current `surveywts_warning_bootstrap_draws_failed` message text (in the
existing code, not yet addressed by the spec) reads:

> "A draw fails when `ipw()` or calibration does not converge
> (e.g., degenerate propensity scores in the resampled data)."

For the calibration-only path, `ipw()` is never called and there are no
propensity scores. Emitting this message when a calibration-only bootstrap draw
fails would be actively misleading. The spec says "the existing failed-draw
counting ... applies unchanged" (§`create_bootstrap_weights` → "Failed draw
handling") but does not require updating the warning text.

Fix: The spec should explicitly require the builder to update this warning
message to be path-aware. When IPW is present in the history, the message may
reference propensity scores; when calibration-only, the message should say
"calibrate_rake() did not converge" (or a path-agnostic version that is
accurate for both). A simple patch: change the message to
"A draw fails when calibration or IPW re-estimation does not converge
(e.g., degenerate inputs in the resampled data)."

Options:
- **[A]** Add to spec: "The `"i"` bullet of `surveywts_warning_bootstrap_draws_failed`
  must be updated to remove the propensity-score-specific language and describe
  calibration failures generically." — Effort: low, Risk: low, Impact: accurate
  user-facing messages, Maintenance: none
- **[B]** Leave as-is; rely on builder's judgment to notice the inaccuracy —
  Effort: none, Risk: medium (builder may miss it), Impact: misleading warning
  for calibration-only users
- **[C] Do nothing** — warning text remains IPW-specific even when no IPW was used

**Recommendation: A** — low effort fix, prevents misleading error messages.

---

No other issues found in Lens 1. The routing logic (four-way precedence), group
assignment, scale factor application, reference resolution, and edge case
handling are all clearly specified. The conditional reference requirement for
DAGJK (required for IPW path and calibration-only Level B, not for Level A) is
correctly derived from the structure of the weighting pipelines.

---

### Lens 2 — Variance Estimation Validity

The variance formula for the DAGJK is:

  V̂ = ((G_success − 1) / G_success) · Σ_{g=1}^{G_success} (θ̂^(g) − θ̂)²

Implemented via `@variables$scale = (G_success - 1) / G_success`,
`@variables$rscales = rep(1, G_success)`, `@variables$mse = TRUE`. This matches
the DAGJK variance estimator from Valliant (2020) §2.1.4 for NPS. ✓

The QR bootstrap variance formula is:

  V̂ = (1/B) · Σ_{b=1}^{B} (θ̂^(b) − θ̂)²

or the Chrostowski (2025) variant (1/(B−1)). Both are propagated via the
`mse` parameter, which is already stored in the history entry and handled by
downstream variance computation. The spec correctly defers this to existing
machinery. ✓

Degrees of freedom: not specified, but this is a pre-existing deferral
consistent with the existing paths. ✓

No new issues from Lens 2. The variance formula machinery is unchanged and
correctly applied.

---

### Lens 3 — Algorithmic Correctness

The calibrate_rake() call within the bootstrap/DAGJK loop is iterative (IPF).
The spec correctly defers convergence criterion, tolerance, and max-iterations to
calibrate_rake()'s own contract. ✓

**Convergence failure handling:** A draw fails if `calibrate_rake()` throws an
error (non-convergence, degenerate targets, etc.) — caught by `tryCatch()` and
counted toward the failed-draw total. ✓

**Weight conservation for QR bootstrap (calibration-only):**
- Equal initial weights (1 per unit) → after raking with `type = "prop"` targets,
  calibrated weights sum ≈ n_A.
- Equal initial weights (1 per unit) → after raking with `type = "count"` targets,
  calibrated weights sum ≈ N (population total).
This is inherited from `calibrate_rake()`'s behavior and is correct for both
target types. ✓

**Weight conservation for DAGJK (calibration-only):**
- Scaled initial weights w_i · a_g for retained units → after re-raking,
  calibrated weights satisfy the same marginal constraints as the original.
  The scaling + re-raking step ensures consistency with the original weighting
  procedure. ✓

No new issues from Lens 3.

---

### Lens 4 — Statistical Assumptions

**Issue 2: Statistical assumption of calibration-only QR bootstrap not stated**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The spec specifies the calibration-only QR bootstrap algorithm (SRSWR +
equal-weight initialization + re-rake) without stating the underlying
statistical assumption that makes this variance estimator valid: that the
SRSWR resampling, combined with re-raking, propagates the uncertainty from
both the sampling step (which units were selected into the NPS) and the
calibration step (how the weights were adjusted to meet population constraints).

This follows from Kolenikov (2014) §4.6, where the bootstrap + re-rake
procedure is shown to produce consistent variance estimates for raking-based
estimators. The spec's §References block cites Kolenikov (2014) but does not
connect the citation to this specific assumption.

The assumption is NOT wrong in the spec — the algorithm is correct. But stating
the assumption explicitly in a "Limitations / Statistical Note" block would help
a future maintainer understand why equal initial weights (not the original raked
weights) are used.

Options:
- **[A]** Add a one-sentence note to the spec's calibration-only bootstrap
  algorithm section: "Equal initial weights are used because SRSWR assigns each
  NPS unit equal selection probability in each replicate; carrying forward the
  original raked weights would double-count calibration uncertainty." — Effort:
  low, Risk: none, Impact: future maintainability
- **[B]** Leave as-is; the comprehension.md §Gotchas already states this
  assumption explicitly and the builder will read it — Effort: none, Risk: low
- **[C] Do nothing** — assumption remains implicit in the spec

**Recommendation: B** — comprehension.md already documents this; the spec's
algorithm step 3 currently says "carrying forward original raked weights would
double-count calibration" which captures the assumption. No action required.

No other statistical assumption gaps found. The DAGJK scale factor assumption
(groups formed from BOTH NPS and reference for Level B, NPS only for Level A)
is correctly specified. The MAR assumption is not applicable to variance
estimation (only to point estimation, which is out of scope for this spec).

---

### Lens 5 — Formula Integrity

**Scale factor:** `a_g = n_A / (n_A − n_Ag)`. Symbols defined inline. ✓
Matches Valliant (2008) `n_h / (n_h − n_{hg})` exactly in the NPS-with-one-stratum
case. ✓

**DAGJK variance formula:** Implemented via `scale`, `rscales`, `mse` fields —
consistent with `(G_success − 1)/G_success · Σ (θ̂^(g) − θ̂)²`. ✓

**Bootstrap equal-weight initialization:** "Assign equal initial weight 1" is
stated explicitly. The spec acknowledges that `calibrate_rake()` may need the
initial weights passed as a weight column (not via the `weights` argument default
behavior). The builder must ensure the initial weight is actually passed to
`calibrate_rake()`, not left to default. This is implementation detail, not a
formula gap — but it should be verified in audit.

**No ambiguous or missing formulas found.**

No issues from Lens 5.

---

### Lens 6 — Literature Cross-Check

Comprehension.md is available. Checking against spec formulas and decisions.

**Formula fidelity:**
- `a_g = n_A / (n_A − n_Ag)` in spec matches comprehension.md §Formulas ✓
- "Equal initial weights for QR bootstrap calibration-only" in spec matches
  comprehension.md §Gotchas ✓
- "Apply scale factor to CURRENT (raked) weights" in spec matches
  comprehension.md §Formulas (DAGJK step 4) ✓

**Gotcha coverage:**
- "Starting weights in QR bootstrap must be equal": spec §step 3 ✓
- "Starting weights in DAGJK: scale factor on current weights": spec §step 4 ✓
- "Reference sample requirement — calibration-only Level B": spec §Reference
  resolution ✓
- "calibrate_rake() on plain data.frame returns weighted_df, not survey_nonprob":
  spec acknowledges this in §Calibration-only bootstrap algorithm ("builder's
  choice..."; "weight extraction must handle both classes") ✓
- "IPW history precedence": spec routing puts doubly-robust path first ✓
- "DAGJK: no reference for calibration-only Level A": spec specifies
  ref_design = NULL for Level A ✓
- "Error class update for dagjk_requires_nonprob": spec includes the message fix ✓
- "No history case": spec specifies `surveywts_error_qr_bootstrap_no_history`
  and `surveywts_error_dagjk_no_history` ✓

**Reference mapping completeness:**
- comprehension.md: "Elliott & Valliant (2017) p.234 → pseudo-weights recomputed
  each replicate" — the spec's routing logic reflects this (all three paths refit
  the weighting model per replicate) ✓
- comprehension.md: "Kolenikov (2014) §4.6 → bootstrap + re-rake algorithm" —
  the spec's algorithm steps 1–4 implement this ✓
- comprehension.md: "Valliant (2020) §2.1.4 → DAGJK 'refit per group'
  generalizes" — the spec's DAGJK calibration-only algorithm reflects this ✓

**Assumption alignment:**
All six assumptions from comprehension.md §Assumptions are covered:
1. No history → error ✓
2. Level B needs reference ✓
3. SRSWR step identical across paths ✓
4. DAGJK scale factor on current weights ✓
5. Failed calibration → failed-draw mechanism ✓
6. calibrate_rake() accepts resampled/group-deleted data ✓

No Lens 6 issues.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 1 |

**Total issues:** 2

**Overall assessment:** The spec is methodologically sound. The calibration-only
algorithms correctly implement the QR bootstrap (SRSWR + equal-weight re-rake)
and DAGJK (scale factor + re-rake) per the literature. One REQUIRED issue: the
`surveywts_warning_bootstrap_draws_failed` message text references IPW and
propensity scores, which is inaccurate for the calibration-only path; the spec
must require the builder to update this text. One SUGGESTION (Issue 2,
recommendation B): no action needed since the comprehension.md already documents
the statistical assumption. Proceed to Stage 2 Resolve (Issue 1 only).

---

### Mini-Pass 1 (2026-06-15) — Issue 1 Resolution

Issue 1 fix applied to spec: added "Failed draw handling" sub-section requirement
in `create_bootstrap_weights` contract, mandating the builder update
`surveywts_warning_bootstrap_draws_failed` message text to be path-agnostic.

Affected lens re-checked: Lens 1 (Method Validity) — the spec now correctly
requires path-agnostic warning text. Issue 1 resolved. ✅

Mini-pass complete: 0 new issues found. All prior issues resolved.
