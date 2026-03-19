## Methodology Review: phase-1 — Pass 1 (2026-03-10)

### New Issues

#### Lens 1 — Method Validity

---

**Issue 1: RWYB Bootstrap — draw count contradicts correction factor**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

§III.b states: "Draw m_h = n_h PSUs with replacement from stratum h" and then
assigns replication factor `c_{hi} = (n_h / (n_h - 1)) * m*_{hi}`.

These are inconsistent. If you draw m_h = n_h PSUs with replacement, the
expected draw count for any PSU i is E[m*_{hi}] = n_h × (1/n_h) = 1, so:
E[c_{hi}] = (n_h / (n_h - 1)) × 1 = n_h / (n_h - 1) ≠ 1.

The correction factor (n_h / (n_h - 1)) is calibrated for m_h = **n_h − 1**
draws, in which case E[m*_{hi}] = (n_h − 1)/n_h and E[c_{hi}] = 1. The
Rao-Wu (1988) original paper and svrep's `make_rwyb_bootstrap_weights()` both
use m_h = n_h − 1. With m_h = n_h draws, the replicate weights are inflated by
a factor of n_h / (n_h − 1), producing variance estimates that are wrong
(biased upward) while passing all structural tests.

Fix: change "Draw m_h = n_h PSUs" → "Draw m_h = n_h − 1 PSUs with replacement."

Options:
- **[A]** Fix to m_h = n_h − 1 as specified by Rao-Wu (1988) and svrep — Effort:
  low, Risk: low, Impact: correct variance estimates, Maintenance: none
- **[B] Do nothing** — replication factors are systematically inflated; all
  downstream variance estimates using RWYB bootstrap will be biased upward

**Recommendation: A** — One-line fix; the correct formula is unambiguous.

---

**Issue 2: JK1 scale factor is incorrect for stratified designs**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

§II.d table lists `scale = (n_rep - 1) / n_rep` for JK1, where n_rep = Σ_h n_h
(total PSU count). For a stratified design, the correct delete-1 jackknife
variance estimator is:

  v = Σ_h ((n_h − 1) / n_h) × Σ_{k ∈ h} (θ̂_{−hk} − θ̂)²

This requires per-stratum scale factors: `rscales[replicate k from stratum h]
= (n_h − 1) / n_h`. This is only equal to the spec's global `(R − 1) / R`
(where R = Σ_h n_h) when all strata have equal n_h. For designs with unequal
stratum PSU counts — standard in real survey practice — the global scale
produces systematically wrong variance estimates. All structural tests pass
silently.

The survey package implements stratified JK1 via `rscales = (n_h - 1) / n_h`
per replicate and `scale = 1`.

Fix: replace the global `scale` entry in §II.d for JK1 with:
- `scale = 1`
- `rscales = (n_h − 1) / n_h` for each replicate, where n_h is the PSU count
  of the stratum that replicate belongs to

Update §IV.b and the output contract accordingly.

Options:
- **[A]** Use per-stratum `rscales` and `scale = 1` — Effort: low (computed
  from design structure already extracted by `.extract_taylor_structure()`),
  Risk: low, Impact: correct stratified JK1 variance, Maintenance: none
- **[B] Do nothing** — JK1 variance estimates wrong for all designs with unequal
  stratum PSU counts

**Recommendation: A** — Per-stratum rscales are the only correct approach.

---

**Issue 3: Fay scale factor omits the (1 − ρ)² denominator**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

§II.d lists `scale = 1 / n_rep` for Fay's method. The Fay (1989) variance
estimator is:

  v = (1 / (G × (1 − ρ)²)) × Σ_g (θ̂_g − θ̂)²

So the correct scale is `1 / (n_rep × (1 − ρ)²)`, not `1 / n_rep`. Omitting
the (1 − ρ)² factor produces variance estimates inflated by 1 / (1 − ρ)², which
can be a factor of 4× for ρ = 0.5 — the default in `create_fay_weights()`.

The output contract in §VI also needs updating: `@variables$scale` should store
`1 / (replicates * (1 - rho)^2)` or, if surveycore handles this automatically
when `type = "Fay"` and `rho` are both passed, the spec must explicitly state
that surveycore absorbs the correction and the stored scale value reflects that.

Fix: update §II.d scale entry for Fay from `1 / n_rep` to
`1 / (n_rep * (1 - rho)^2)`. Verify whether `surveycore::as_survey_repweights()`
with `type = "Fay"` requires the caller to compute this or handles it internally.

Options:
- **[A]** Compute and pass `scale = 1 / (n_rep * (1 - rho)^2)` explicitly —
  Effort: trivial, Risk: low, Impact: correct Fay variance, Maintenance: none
- **[B]** Pass `scale = 1 / n_rep` and rely on surveycore to correct for ρ
  internally — Effort: low, Risk: medium (depends on surveycore interface not
  specified here), Impact: correct only if surveycore applies the correction
- **[C] Do nothing** — Fay variance estimates are wrong by 1/(1−ρ)²

**Recommendation: A** — Compute the correct scale explicitly; do not depend
on undocumented surveycore behavior.

---

**Issue 4: Generalized bootstrap (SD1/SD2) formulas absent**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

§VII acknowledges the exact SD1 and SD2 replication factor formulas as a GAP.
Without these formulas, there is no specification for the implementer to follow.
An implementer who "figures it out from svrep source" could produce a correct
implementation or a wrong one, and the spec would not catch either.

The Beaumont & Patak (2012) formulas are:

**SD1** (for with-replacement cluster/element sampling):
  For each bootstrap replicate r and PSU i in stratum h with n_h PSUs:
    u_{hi}^(r) = 1 + sqrt(n_h / (n_h − 1)) × (ε_{hi}^(r) − ε̄_h^(r))
  where ε_{hi}^(r) ~ i.i.d. N(0, 1) and ε̄_h^(r) = (1/n_h) Σ_i ε_{hi}^(r).
  Alternatively, using multinomial draws: replication factor is
    c_{hi}^(r) = (n_h / (n_h − 1)) × m*_{hi}^(r)
  where m_h = n_h − 1 draws (same as RWYB) — this form is computationally
  simpler.

**SD2** (for without-replacement cluster sampling):
  Uses a different set of random variables designed to produce negative
  correlation between replicates from the same stratum, reducing Monte Carlo
  variance. The exact formula is more complex; see Beaumont & Patak (2012)
  §3.2 or svrep::make_gen_boot_factors().

The spec must pin the exact formula for each variant, with all variable
definitions, before implementation.

Options:
- **[A]** State both SD1 and SD2 formulas fully in §VII — Effort: medium
  (requires deriving from B&P 2012), Risk: low once documented, Impact: correct
  gen-boot variance, Maintenance: none
- **[B]** Drop SD2 from Phase 1 scope (implement SD1 only) — Effort: lower,
  Risk: low, Impact: SD2 not available until later phase
- **[C] Do nothing** — implementation proceeds without a spec; wrong formulas
  possible

**Recommendation: A** — Gen-boot is a listed deliverable; both variants must
be specified. Use svrep as the oracle to pin the formula.

---

**Issue 5: SDR algorithm, design requirements, and replication formula absent**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

§VIII acknowledges the SDR algorithm, design requirements, and whether
`replicates` must be even as GAPs. Without this, the function cannot be
implemented correctly. Key requirements from Fay & Train (1995) and Wolter (2007):

**Design requirement:** SDR is designed for systematic PPS samples. The PSUs
must be ordered in the sequence in which they were selected in the systematic
sample. The spec must state (a) whether the function requires this ordering to
be already present in the design, or (b) whether it accepts a `sort_var`
argument, or (c) whether it assumes the row order of the data is the systematic
selection order.

**Formula:** The SDR replication factor for PSU i (using two random sign vectors
z_1^(r) and z_2^(r) per replicate r) is:

  For odd replicate r (using z_1): c_i^(r) = 1 + (−1)^i × z_{⌈r/2⌉}^(1)
  For even replicate r (using z_2): c_i^(r) = 1 − (−1)^i × z_{⌈r/2⌉}^(2)

where z_k ∈ {−1, +1} i.i.d. with probability 1/2 each.

The requirement for even `replicates` is real: replicates come in pairs
(one using z_1, one using z_2), so an odd count is ill-defined.

The scale 2/n_rep in the output contract is correct per Fay & Train (1995).

Options:
- **[A]** State the complete SDR algorithm (formula, ordering requirement, pair
  structure) in §VIII — Effort: medium, Risk: low, Impact: correct SDR variance
- **[B]** Defer SDR to Phase 2 — Effort: low, Risk: low, Impact: SDR not in v0.2.0
- **[C] Do nothing** — implementation without a formula is guesswork

**Recommendation: A** if SDR is in Phase 1 scope; **B** if the algorithm
complexity is too high for this phase. Recommend resolving scope first.

---

**Issue 6: `as_taylor_design()` cannot recover original Taylor design structure**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

§X flags this as a blocking GAP and lists three options. This issue must be
resolved before Phase 1 implementation — `as_taylor_design()` is a listed
deliverable and the spec currently gives no viable implementation path.

The statistical stakes: if the original strata, PSU IDs, and FPC are not
recoverable from `survey_replicate`, then `as_taylor_design()` can only return
a `survey_taylor` without clustering and stratification. Such a design uses
incorrect variance estimators for all subsequent inference — wrong SEs, wrong
confidence intervals, wrong test statistics.

Options:
- **[A] Store Taylor structure in `survey_replicate@variables`** — e.g.,
  `$ids`, `$strata`, `$fpc`, `$nest`. Effort: medium (requires surveycore
  `survey_replicate` to accept arbitrary `@variables` keys — must be verified),
  Risk: medium (dependency on surveycore interface), Impact: correct round-trip
- **[B] Store original Taylor variables in `@metadata@weighting_history`** —
  Provenance entry records original design structure. Effort: low-medium,
  Risk: low, Impact: correct round-trip, but metadata carries structural data
- **[C] Require caller to supply `ids`, `strata`, `fpc`, `nest` arguments** —
  Effort: low for Phase 1, Risk: medium (user can provide wrong values),
  Impact: works if user knows original design

**Recommendation: A or B** — Either stores the structure without user burden.
Check surveycore's `@variables` API first; if it supports arbitrary keys, use A.
Otherwise B. Option C puts the burden on the user and is error-prone.

---

**Issue 7: `@calibration` provenance and Phase 0 output class ambiguity**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

§XI flags two blocking sub-questions:

**Q1: Phase 0 calibration functions produce `survey_taylor`, not `survey_nonprob`.**
The Phase 0 class matrix shows `calibrate(survey_taylor, ...)` → `survey_taylor`.
`survey_taylor` has no `@calibration` property. Therefore, there is currently no
`survey_nonprob` object that Phase 1 could accept as input for re-calibration.
Without resolving this, the "Bootstrap variance for `survey_nonprob`" row in
the deliverables table (§I) has no implementation path.

**Q2: `survey_nonprob@variables` does not store original Taylor design structure.**
Even if Q1 is resolved, if PSU/strata are not preserved in `survey_nonprob`,
bootstrap replicates cannot be drawn correctly.

These are inseparable design questions that must be resolved before Phase 1 can
begin.

Options for Q1:
- **[A] Amend Phase 0 spec:** Phase 0 calibration functions return
  `survey_nonprob` (not `survey_taylor`) when input is `survey_taylor`. This
  is a breaking change to Phase 0 but the correct long-term design. Effort: high
  (Phase 0 amendment + re-implementation), Risk: high (breaking change)
- **[B] Accept provenance as call-time arguments:** `as_replicate_design()` (or
  `create_*_weights()`) accepts `calibration_fn` and `calibration_args` arguments
  that are applied per-replicate. Effort: medium, Risk: medium, Impact: works but
  awkward API
- **[C] Separate function `as_calibrated_replicate_design()`** — Effort: medium,
  Risk: low, Impact: cleaner but adds API surface

For Q2: if surveycore's `survey_nonprob@variables` can store `$ids`, `$strata`,
`$fpc` keys (same question as Issue 6), this is resolvable in surveycore. Otherwise
provenance-based storage is needed.

**Recommendation: B or C** for Q1 — Option A requires amending a shipped phase,
which has large blast radius. Option B is the pragmatic path that avoids reopening
Phase 0. Resolve Q2 in conjunction with Issue 6.

---

#### Lens 2 — Variance Estimation Validity

---

**Issue 8: `mse = FALSE` behavior not specified anywhere in the output contracts**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

Every `create_*_weights()` function accepts `mse = TRUE/FALSE` but only the
`mse = TRUE` behavior is described: "MSE variance estimator (mean squared error
from full-sample estimate)."

The spec never states what `mse = FALSE` computes. The two forms are:
- `mse = TRUE`:  v = scale × Σ_r (θ̂_r − θ̂)²   [deviation from full-sample estimate]
- `mse = FALSE`: v = scale × Σ_r (θ̂_r − θ̄_rep)²  [deviation from replicate mean]

The `mse = FALSE` form uses the replicate mean θ̄_rep as the center rather than
the full-sample θ̂. It can underestimate variance for biased estimators. Users
need to know this. The output contract for `@variables$mse` should state which
form is stored as TRUE/FALSE, and the `mse` argument description should document
both behaviors.

Fix: add "If `FALSE`, the variance estimator deviates from the mean of the
replicate estimates, not the full-sample estimate. This can underestimate variance
for biased estimators." to the `mse` argument description in each function.

Options:
- **[A]** Document both forms in argument descriptions and output contracts —
  Effort: low (pure documentation), Risk: none, Impact: users understand what
  they're computing
- **[B] Do nothing** — users who set `mse = FALSE` get unexplained behavior

**Recommendation: A**

---

**Issue 9: Re-calibration convergence failure in bootstrap is unspecified**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: JUDGMENT CALL

§XI describes re-calibrating each bootstrap replicate independently. If raking
or linear calibration fails to converge for a particular replicate (e.g., a
resample has an empty cell for a calibration variable), the function must have
defined behavior. Three realistic failure modes:

1. A bootstrap resample drops all units in a calibration cell → raking diverges
2. Linear calibration produces a singular system → `solve()` throws
3. A replicate's weights hit numerical limits during re-calibration

The spec is silent on all three. In practice, with 500 replicates, at least
one convergence failure is likely for moderately complex calibration variables.

Options:
- **[A]** Error with `surveywts_error_recalibration_failed` when any replicate
  fails — Effort: low, Risk: low, Impact: strict; user knows exactly which
  replicate failed
- **[B]** Warn and drop failed replicates; return design with fewer replicates —
  Effort: medium (must update `@variables$repweights` count), Risk: medium
  (silently fewer replicates than requested), Impact: less strict
- **[C]** Error or warn controlled by a `on_recal_failure = c("error", "warn",
  "ignore")` argument — Effort: medium, Risk: low, Impact: flexible

**Recommendation: A for Phase 1** — conservative default; users can catch and
wrap in their own handling if needed.

---

#### Lens 3 — Algorithmic Correctness

---

**Issue 10: JKn stratified grouping is unspecified**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

§IV.b describes JKn: "Divide PSUs randomly into `replicates` groups of
approximately equal size." This does not specify whether grouping is done
**within each stratum** or **across all strata**.

The two approaches produce different variance estimates:

- **Within-stratum grouping** (stratified JKn): replicates groups per stratum;
  requires n_h ≥ replicates for every stratum. Per-stratum scale factors
  (n_h − 1)/n_h are used. Correct for stratified designs but constrains
  `replicates ≤ min_h(n_h)`.

- **Across all strata** (unstratified JKn): groups formed from all PSUs
  regardless of stratum. A single scale (G−1)/G applies. Simpler but
  statistically inferior — ignores the stratification structure.

What happens when `replicates > min_h(n_h)` for within-stratum grouping? Some
strata would have fewer PSUs than groups, making balanced assignment impossible.
The spec needs to specify (a) which grouping strategy is used, (b) whether
`replicates > min_h(n_h)` is an error, and (c) the resulting `rscales` structure.

Options:
- **[A]** Within-stratum grouping; error if `replicates > min_h(n_h)` —
  Effort: medium, Risk: low, Impact: statistically correct for stratified designs
- **[B]** Across all strata; simpler `scale = (G-1)/G` — Effort: low, Risk: low,
  Impact: statistically suboptimal but valid

**Recommendation: A** — Stratified JKn is the standard approach for stratified
multistage designs. The constraint on `replicates` is well-defined and checkable.

---

**Issue 11: Bootstrap single-PSU stratum handling (acknowledged GAP §III.b)**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

When a stratum has only 1 PSU (n_h = 1), the RWYB formula breaks down:
- Drawing m_h = n_h − 1 = 0 PSUs produces m*_{hi} = 0 for all i, so all
  replication factors are 0 → replicate estimate is 0 → wrong
- The correction factor n_h/(n_h − 1) = 1/0 is undefined

Options (as listed in spec §III.b):
- **[A]** Error: require user to collapse singleton strata before calling —
  Effort: low, Risk: low, Impact: strict; user must prepare design correctly
- **[B]** Set c_{h1}^(r) = 1 for all replicates in singleton strata (no
  variance contribution from that stratum) — Effort: low, Risk: medium
  (silently produces no variance for singleton strata)
- **[C]** Warn and auto-collapse singleton strata to nearest stratum —
  Effort: high, Risk: medium, Impact: fragile heuristic

**Recommendation: A** — Singleton strata represent a fundamental design issue
(PSUs in singleton strata contribute no variance to Taylor estimators either).
Requiring users to collapse explicitly is the statistically defensible choice.

---

**Issue 12: Bootstrap unclustered design support (acknowledged GAP §III.c)**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

The spec's current error table fires `surveywts_error_no_psu_ids` when
`svy@variables$ids` is NULL — meaning unclustered designs are rejected entirely.
This is a design decision that has not been explicitly made.

For unclustered designs (SRS, stratified SRS), bootstrap can legitimately
resample individuals rather than PSUs. svrep supports this.

Options:
- **[A]** Require PSU IDs; error for unclustered designs — Effort: low (already
  the current error table), Risk: low, Impact: limits applicability to complex
  surveys only
- **[B]** Support unclustered designs by resampling individuals — Effort: medium
  (different algorithm path), Risk: low, Impact: broader applicability

**Recommendation: A for Phase 1** — simplifies the implementation; unclustered
design support can be added in a later phase. The error message should tell users
to construct a PSU variable if they have an element sample.

---

#### Lens 4 — Statistical Assumptions

---

**Issue 13: BRR vs Fay API distinction must be resolved (acknowledged GAP §V.b + §VI)**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: JUDGMENT CALL

The spec offers three options for the BRR/Fay API distinction but defers the
decision to Stage 2. The statistical distinction matters for user understanding:

- `create_brr_weights(fay_rho = ρ)` — uses Hadamard matrix; number of replicates
  is fixed by the design (smallest multiple of 4 ≥ H strata); exact orthogonal
  balance across half-samples
- `create_fay_weights(rho = ρ, replicates = G)` — uses random half-sample
  assignments; arbitrary replicate count; not exactly orthogonally balanced

These are genuinely different methods with different properties. Option A
(separate functions with different underlying algorithms) is the statistically
correct framing. Option B (sugar) conflates them. Option C (BRR-only for
`create_brr_weights()`) is cleanest.

Options from spec §VI:
- **[A]** `create_fay_weights()` = random half-samples (Pseudo-BRR with rho),
  `create_brr_weights()` = Hadamard-based (optionally with rho) — distinct algorithms
- **[B]** `create_fay_weights()` = sugar for `create_brr_weights(fay_rho=rho)` —
  remove one function
- **[C]** `create_fay_weights()` is primary Fay function; `create_brr_weights()`
  drops `fay_rho` argument

**Recommendation: C** — `create_brr_weights()` does standard BRR (Hadamard,
fay_rho = 0 only). `create_fay_weights()` does Fay's method (Hadamard-based,
rho required). If pseudo-BRR (random assignment) is needed, it can be a later
addition. This avoids API ambiguity and the `fay_rho = 0` in `create_brr_weights()`
being identical to `rho = 0` in `create_fay_weights()`.

---

#### Lens 5 — Formula Integrity

---

No additional issues beyond those already raised in Lenses 1–4. The SDR and
gen-boot formulas are entirely absent (Issues 4, 5). The RWYB formula error
(Issue 1), JK1 stratified scale (Issue 2), and Fay scale (Issue 3) are
documented above.

---

### Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 7 |
| REQUIRED | 6 |
| SUGGESTION | 0 |

**Total issues:** 13

**Issue index:**

| # | Title | Lens | Severity | Resolution type |
|---|-------|------|----------|-----------------|
| 1 | RWYB Bootstrap: draw count contradicts correction factor | 1 | BLOCKING | UNAMBIGUOUS |
| 2 | JK1 scale factor incorrect for stratified designs | 1 | BLOCKING | UNAMBIGUOUS |
| 3 | Fay scale factor missing (1−ρ)² denominator | 1 | BLOCKING | UNAMBIGUOUS |
| 4 | Generalized bootstrap (SD1/SD2) formulas absent | 1 | BLOCKING | JUDGMENT CALL |
| 5 | SDR algorithm, design requirements, formula absent | 1 | BLOCKING | UNAMBIGUOUS |
| 6 | `as_taylor_design()` cannot recover original Taylor structure | 1 | BLOCKING | JUDGMENT CALL |
| 7 | `@calibration` provenance + Phase 0 output class ambiguity | 1 | BLOCKING | JUDGMENT CALL |
| 8 | `mse = FALSE` behavior undocumented | 2 | REQUIRED | UNAMBIGUOUS |
| 9 | Re-calibration convergence failure handling unspecified | 2 | REQUIRED | JUDGMENT CALL |
| 10 | JKn stratified grouping unspecified | 3 | REQUIRED | JUDGMENT CALL |
| 11 | Bootstrap single-PSU stratum (acknowledged GAP §III.b) | 3 | REQUIRED | JUDGMENT CALL |
| 12 | Bootstrap unclustered design behavior (acknowledged GAP §III.c) | 3 | REQUIRED | JUDGMENT CALL |
| 13 | BRR vs Fay API distinction unresolved (acknowledged GAP §V.b + §VI) | 4 | REQUIRED | JUDGMENT CALL |

**Overall assessment:** The spec is structurally well-organized and the
acknowledged GAPs are correctly identified, but three of the seven BLOCKING
issues are formula errors in the spec itself — not acknowledged gaps. The RWYB
draw count, JK1 stratified scale factor, and Fay scale factor would produce
silently wrong variance estimates that pass all structural tests. The two missing
algorithm specs (gen-boot, SDR) and two architectural blocking questions
(`as_taylor_design()` round-trip, `@calibration` provenance) must also be
resolved before any replicate weight code is written.

---

### Code Verification Addendum (2026-03-10)

Pass 1 was written from pre-existing knowledge. The following corrections were
made after reading svrep and survey package source code directly. Issues 1, 3,
and 6–13 are unchanged. Issues 2, 4, and 5 required corrections.

---

**Issue 1 — CONFIRMED:** svrep source (`make_rwyb_bootstrap_weights.R`) contains
`m_h <- n_h - 1` explicitly. The draw count error in the spec is real.

**Issue 2 — STRENGTHENED:** The survey package source (`as.svrepdesign.default`)
contains:
```r
if (type == "JK1" && design$has.strata)
  stop("Can't use JK1 for a stratified design")
```
JK1 is only valid for unstratified (single-stratum) designs in the survey
package. For stratified designs, JKn is the correct tool. The spec's
`create_jackknife_weights(type = "delete-1")` needs to decide: (a) error for
stratified designs (matching survey package), or (b) support stratified delete-1
via per-stratum rscales (matching svrep `as_jackknife_design()`). Either choice
is valid but must be stated. The original Issue 2 finding (global scale wrong
for stratified) still holds if option (b) is chosen.

**Issue 3 — CONFIRMED:** survey package source contains:
```r
scale <- 1/(ncol(repweights) * (1 - fay.rho)^2)
```
exactly matching Issue 3's stated formula.

**Issue 4 — DESCRIPTION CORRECTED:** The SD1/SD2 description in Pass 1 was
wrong. SD1 and SD2 are NOT two variants of the Beaumont & Patak (2012)
random-weight bootstrap. In svrep, `variance_estimator = "SD1"` and
`variance_estimator = "SD2"` select the **Ash (2014) successive-difference
variance estimators** as the target quadratic forms for the generalized
bootstrap:

- **SD1 (non-circular):** v̂_SD1(Ŷ) = (1 − n/N) × n/(2(n−1)) × Σ_{k=2}^n (ỹ_k − ỹ_{k−1})²
- **SD2 (circular):** v̂_SD2(Ŷ) = (1 − n/N) × (1/2) × [Σ_{k=2}^n (ỹ_k − ỹ_{k−1})² + (ỹ_n − ỹ_1)²]

where ỹ_k = y_k/π_k. The gen-boot generates weights by drawing from
MVN(1, Σ) where Σ is the quadratic form matrix encoding the SD1 or SD2
estimator. Applied to clusters per stratum in multistage samples.

The conclusion of Issue 4 (formulas must be fully specified before
implementation) still stands. The spec needs to state which quadratic form
Σ is constructed for SD1 and SD2, with all variable definitions. The severity
remains BLOCKING.

**Issue 5 — THREE CORRECTIONS:**

**(a) Replication factor formula was wrong.** The actual formula from svrep
(`successive-difference-replication.R`) is:

```r
f_{i,r} = 1 + (h_{row1(i),r} − h_{row2(i),r}) × 2^(−3/2)
```

where H is a Hadamard matrix (entries ±1) and each PSU i is assigned two rows
(row1, row2) based on its position in the sorted order. The differences
`h_row1,r − h_row2,r ∈ {−2, 0, +2}` give factors ∈ {1 − √2/2, 1, 1 + √2/2}.

The "alternating signs ε_i ∈ {−1, +1}" description in Pass 1 was incorrect.

**(b) Scale factor was wrong.** The Pass 1 text said scale = 2/n_rep. The
svrep documentation states:
> "The scale factor to be used for variance estimation with the replicate
> weights is **4/R**, where R is the number of replicates."

Scale = 4/R, not 2/R. This correction propagates to the spec's §II.d scale
column for SDR.

**(c) Replicate count constraint is stricter than "even".** The replicates
must be a **multiple of 4** (Hadamard matrix order constraint), not merely even.
The spec §VIII says "must be even" — this should be "must be a multiple of 4."
This tightens the `surveywts_error_sdr_replicates_not_even` error class name:
the name is misleading. Consider `surveywts_error_sdr_replicates_not_multiple_of_4`.

svrep also confirms the sort variable requirement: `as_sdr_design()` accepts a
`sort_variable` argument and the function errors if sort_variable contains NA.
The spec should add `sort_var` as an argument to `create_sdr_weights()`.

**Revised Issue 5 options:**
- **[A]** State the complete SDR algorithm with the correct formula
  (Hadamard-based, scale = 4/R, multiple-of-4 constraint, `sort_var` argument),
  referencing svrep `make_sdr_replicate_factors()` as the implementation oracle.
- **[B]** Defer SDR to Phase 2.

**Recommendation unchanged: A if in scope, B if complexity too high.**
