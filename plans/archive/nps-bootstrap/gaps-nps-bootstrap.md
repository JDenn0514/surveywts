# Gap Report — nps-bootstrap

**Date:** 2026-05-26
**Source:** Stage 0 comprehension (4 papers) + cross-check against spec and implementation
**Status:** For resolution before implementation begins

Papers read: Elliott & Valliant (2017), Chrostowski et al. (2025), Kolenikov
(2014), AAPOR (2022).

Gaps are ordered within each severity tier by ease of fix.

---

## Severity: HIGH

---

### GAP B — `missing_method` replay omitted from within-draw `ipw()` call

**Severity:** HIGH — correctness bug for any user who called `ipw()` with
`missing_method = "separate"` or `"impute"` before bootstrapping.

**What the code does:**
`R/nonprob-ipw.R:742` writes `missing_method = missing_method` into the
weighting history entry.

**What the spec requires:**
`plans/spec-nps-bootstrap.md:269–278` shows the within-draw `ipw()` call:

```r
ipw_result_b <- ipw(
  data      = S_A_b,
  reference = ref_design,
  selection = ipw_entry$formula,
  method    = ipw_entry$method,
  trim      = ipw_entry$trim,
  wt_name   = data@variables$weights
)
```

`missing_method` is **not** replayed. It defaults to `"omit"`.

**What breaks:** If the original call used `missing_method = "separate"`,
NA rows were recoded to `"(Missing)"` and kept in `@data`. The within-draw
`ipw()` on `S_A_b` will drop those rows silently (via `"omit"`), producing
replicate weights on a systematically smaller sample than the full-sample
estimate. Bootstrap SE is therefore computed from structurally mismatched
numerator and denominator.

**Also missing from spec §VII** (`plans/spec-nps-bootstrap.md:428–439`):
`missing_method` is not listed as a required history field, even though the
implementation stores it and the bootstrap must replay it.

**Fix:** Add `missing_method = ipw_entry$missing_method` to the within-draw
`ipw()` call in §IV and add `missing_method` to the required fields table
in §VII.

---

### GAP 1 — SRS variance understatement not required in bootstrap man page

**Severity:** HIGH — user-visible methodological caveat; affects how users
interpret every SE produced by this function.

**Sources:** AAPOR (2022) §4; Chrostowski et al. (2025) §2.2 note.

**What the literature says:** SRSWR bootstrap for NPS "likely understates
sampling variability" because the actual recruitment mechanism cannot be
replicated. AAPOR calls this "likely impossible to avoid" and labels SRSWR
the accepted practical approximation. Understated variance is structural, not
fixable by increasing `replicates`.

**What the spec says:** `plans/spec-nps-bootstrap.md:197–201` has a
deferred-use statement about the missing analysis function. No mention of
systematic variance understatement.

**`ipw()` comparison:** `R/nonprob-ipw.R:188–190` already documents in
`@details`: "Naive variance estimates… do not account for the uncertainty in
the estimated propensity scores. Bootstrap variance estimation is recommended."
The bootstrap function needs an analogous but different warning: bootstrap
SEs from NPS are themselves understated because SRSWR ignores the unknown
recruitment mechanism.

**Fix:** Add a `@details` bullet to `create_bootstrap_weights()` man page
contract in spec §III. Suggested text:

> **Bootstrap variance for non-probability samples:** SRSWR resampling cannot
> replicate the original NPS recruitment mechanism. Bootstrap standard errors
> from `"quasi-randomization"` likely understate true sampling variability
> (AAPOR 2022, §4). Variance understatement is not reduced by increasing
> `replicates`. Additional understatement occurs when NPS units share cluster
> structure (e.g., panel recruitment).

---

## Severity: MEDIUM

---

### GAP A — `estimator = "ht"` in code; spec §VII shows `"hajek"`

**Severity:** MEDIUM — documentation inconsistency; no correctness impact on
the bootstrap itself, but could produce wrong field values if builder follows
spec §VII verbatim.

**Code:** `R/nonprob-ipw.R:745`:
```r
estimator = "ht",
```

**Spec:** `plans/spec-nps-bootstrap.md:435`:
```r
estimator = "hajek",  # or "ht"
```

The weights are `w = 1 / p_hat` (line 704 of `nonprob-ipw.R`), no
renormalization step — this is HT style (unnormalized). The spec's example
value `"hajek"` is wrong. The bootstrap does not use `estimator` from the
history for any computation (the user applies their own estimator to replicate
weight columns), so this doesn't affect output correctness. But a builder
reading §VII will store the wrong value.

**Fix:** Change spec §VII (`plans/spec-nps-bootstrap.md:435`) example to
`estimator = "ht"` and update the comment.

---

### GAP C — Per-draw trim bounds vary; spec doesn't state this

**Severity:** MEDIUM — undocumented behavior with non-obvious statistical
implications.

**Code:** `R/nonprob-ipw.R:715–718`:
```r
trim_result <- .trim_weights_internal(
  weights = w,
  upper   = stats::median(w) + 5 * stats::IQR(w),
  ...
)
```

The trim threshold is computed from within-draw weights, not from the
full-sample threshold. Each draw produces a different effective trim bound.

**Spec:** `plans/spec-nps-bootstrap.md:271` (`trim = ipw_entry$trim`) says to
replay the `trim` flag, but does not acknowledge that this means per-draw
bounds, not fixed bounds. An implementer might reasonably try to capture the
full-sample trim bound and pass it as a fixed constant to each within-draw
call — which would be a different statistical procedure.

**Implication:** Per-draw bounds propagate uncertainty in the trim threshold
through the bootstrap, which is methodologically correct. Fixed bounds would
not. But neither behavior is currently justified in the spec.

**Fix:** Add one sentence to the §IV algorithm note near line 271:
> "When `trim = TRUE`, the trimming threshold is re-estimated from within-draw
> weights (`median(w) + 5 * IQR(w)`) — not carried over from the full-sample
> call. This propagates trim-threshold uncertainty through the bootstrap."

---

### GAP 2 — Weight normalization convention not stated; spec wording misleads

**Severity:** MEDIUM — spec's "original base weight" wording is misleading;
no code bug.

**Code:** `R/nonprob-ipw.R:704`:
```r
w <- 1 / scores
```
No renormalization. `ipw()` accepts a plain `data.frame` and never reads a
pre-existing weight column. Within-draw `ipw()` on `S_A_b` starts fresh from
propensity estimation — the IPW weight column carried in resampled rows is
unused.

**Spec:** `plans/spec-nps-bootstrap.md:365–373` says:
> "Each row carries the original base weight from the ipw history entry's
> input (or `data@data[[data@variables$weights]]` if no pre-ipw weight exists)."

This is misleading. `data@data[[data@variables$weights]]` IS the IPW weight
after the original `ipw()` call — not a "base weight." The true behavior is
that within-draw `ipw()` ignores all existing weight columns and computes
fresh propensity weights. There is no concept of a "base weight" in this path.

**Fix:** Replace the S_A^(b) paragraph in §IV
(`plans/spec-nps-bootstrap.md:365–373`) with:
> "Within-draw `ipw()` receives `S_A_b` as a plain data frame. It does not
> read or use any weight column present in those rows; it fits the propensity
> model on the resampled units and computes fresh weights as `1 / p_hat`. The
> IPW weights from the full-sample call are irrelevant here."

Also add to §III or §IV: "IPW weights are raw `1 / p_hat` values with no
renormalization step. The sum of weights estimates the population size."

---

### GAP 4 — Variance formula departure from Chrostowski not justified

**Severity:** MEDIUM — methodology reviewer will flag; easy one-line fix.

**Source:** Chrostowski et al. (2025) Eq. 5 uses $\frac{1}{B-1}$ centered on
the original estimate. The spec uses $\frac{1}{B}$ for the MSE form.

**Spec:** `plans/spec-nps-bootstrap.md:351–358` states the formula but gives
no rationale for departing from the primary NPS bootstrap literature source.

**Fix:** Add one sentence after the variance formula in §IV:
> "The $\frac{1}{B}$ divisor (rather than $\frac{1}{B-1}$ as in Chrostowski
> et al. 2025 Eq. 5) is consistent with standard replicate-weight variance
> practice (cf. Kolenikov 2014 §4.6)."

---

### GAP 10 — Level B RNG independence mechanism underspecified

**Severity:** MEDIUM — reproducibility semantics unclear; implementer must
make a choice the spec doesn't resolve.

**Spec:** `plans/spec-nps-bootstrap.md:319–322`:
> "The NPS and reference resamples are independent — they use separate
> independent random sequences."

The spec also says (`plans/spec-nps-bootstrap.md:256–257`):
> "Setup: `set.seed(seed)` immediately before the loop (if seed non-NULL)."

For Level B, `svrep::as_bootstrap_design(ref_design, replicates = B)` is
called before the main loop (line 315–317 of spec). If a single `set.seed(seed)`
precedes the pre-computation call, the pre-computation and the main loop's NPS
resampling both draw from the same initialized RNG stream. They are
deterministically derived from a shared seed — not statistically independent
but fully reproducible given the seed.

The spec does not state: (a) whether independence here means "statistically
independent" (requires two seeds) or "reproducibly deterministic given one
seed" (acceptable for replication); (b) the exact call ordering — whether
`set.seed(seed)` is called once before pre-computation, or called again before
the main loop.

**Fix:** Add to §IV Level B setup:
> "`set.seed(seed)` is called once, immediately before
> `svrep::as_bootstrap_design()`. The reference pre-computation and the main
> NPS resample loop both draw from this initialized stream sequentially.
> 'Independent' means each draw's NPS resample and reference replicate are
> drawn from separate positions in the stream — not that they use separate
> seeds. Given the same `seed`, results are exactly reproducible."

---

## Severity: LOW

---

### GAP 5 — S_A^(b) wording misleading (no code bug)

**Severity:** LOW — wording only; implementation flow is correct.

**Spec:** `plans/spec-nps-bootstrap.md:365–373` (covered above under GAP 2).
The within-draw raking base weight concern from Kolenikov §4.6 applies to
reference-replicate calibration (Level B), not to the NPS resample. In the
NPS path: within-draw `ipw()` produces fresh weights → within-draw `rake()`
receives those fresh IPW weights as input. The chain is correct. The Kolenikov
caution (don't use calibrated weights as starting point for within-replicate
raking) is satisfied because within-draw `ipw()` starts from propensity
estimation, not from any calibrated weight.

**Fix:** Covered by the GAP 2 wording fix.

---

### GAP 6 — No pre-loop calibration target consistency check

**Severity:** LOW — fails loudly via `surveywts_error_bootstrap_all_draws_failed`,
but with no diagnostic about root cause.

**Spec:** `plans/spec-nps-bootstrap.md:296–305` (post-loop failure handling).
If `calib_entry$margins` are inconsistent (margins for different variables
sum to different population totals), every draw will fail with a raking
divergence. The spec's error `surveywts_error_bootstrap_all_draws_failed` fires,
but with no message indicating the root cause.

**Fix:** Add a pre-loop check before the draw loop in §IV prerequisites
(`plans/spec-nps-bootstrap.md:211–220`): verify that all calibration margins
in `calib_entry$margins` sum to a consistent population total. Emit a new
error class `surveywts_error_calibration_targets_inconsistent` if not. This
requires a new entry in `plans/error-messages.md`.

---

### GAP 7 — NPS/reference overlap not validated or documented

**Severity:** LOW — silent failure in rare cases.

**Code:** `R/nonprob-ipw.R:395–424` checks that NPS covariate levels appear
in the reference but does not check for unit-level overlap (same individual
in both datasets).

**Spec:** `plans/spec-nps-bootstrap.md` §VIII validation table
(`plans/spec-nps-bootstrap.md:456–469`) has no overlap check.

**Source:** Chrostowski et al. (2025) explicitly states estimators assume no
unit appears in both samples. Overlap biases propensity estimates toward 0.5
for overlapping units.

**Fix (minimal):** Add a `@details` note to `create_bootstrap_weights()` man
page contract in spec §III:
> "**Sample overlap:** The NPS and reference sample are assumed to be disjoint.
> If any unit appears in both, propensity estimates will be biased. No
> deduplication is performed; verify this precondition before calling."

---

### GAP 8 — NPS clustering understatement not documented

**Severity:** LOW — paired with GAP 1; single `@details` paragraph covers both.

**Source:** Chrostowski et al. (2025): SRSWR ignores cluster structure.
For panel-recruited or router-recruited NPS, variance understatement is
compounded beyond the general SRSWR approximation.

**Spec:** Not mentioned anywhere.

**Fix:** Include in the `@details` bullet added for GAP 1 (one sentence):
> "Additional understatement occurs when NPS units share cluster structure
> (e.g., panel recruitment), because SRSWR ignores within-cluster correlation."

---

### GAP 9 — Small sampling fraction assumption not documented

**Severity:** LOW — rare edge case; theoretical.

**Source:** Elliott & Valliant (2017) §3: the Bayes-rule derivation of
pseudo-weights (Eqs. 3–6) requires both NPS and reference to constitute small
fractions of the population.

**Spec:** Not mentioned anywhere.

**Fix:** One sentence in `@details` of `create_bootstrap_weights()` contract
in spec §III:
> "**Sampling fraction:** IPW pseudo-weights are theoretically justified when
> both the NPS and the reference sample are small fractions of the target
> population (Elliott & Valliant 2017). The approximation degrades as either
> sample approaches the population in size."

---

### GAP 11 — `@references` not required by spec for `create_bootstrap_weights()`

**Severity:** LOW — easy fix; `ipw()` at `R/nonprob-ipw.R:202–214` provides
the template.

**Spec:** `plans/spec-nps-bootstrap.md` §III function contract has no
`@references` requirement. §XI quality gates (`plans/spec-nps-bootstrap.md:648–660`)
do not include a roxygen completeness check.

**Fix:** Add to §III or §XI:
> "`create_bootstrap_weights()` must include an `@references` roxygen tag citing
> Elliott & Valliant (2017), Chrostowski et al. (2025), and Kolenikov (2014).
> Full citation details are in `plans/comprehension-nps-bootstrap.md`."

---

### GAP 12 — EC2 test case construction underspecified

**Severity:** LOW — tester can work around it, but the mechanism isn't clear.

**Spec:** `plans/spec-nps-bootstrap.md:618–622`:
> "Constructed NPS such that every resample produces degenerate propensity
> scores (e.g., single-level covariates after resampling)."

"Single-level covariates after resampling" only guarantees degeneracy if the
propensity model has only one covariate and that covariate is constant in the
resampled data. For a small NPS with a binary covariate where one level
appears once, SRSWR draws will frequently exclude that level but not always.

**Fix:** Replace the EC2 description in §X with a concrete construction:
> "Construct an NPS of 3 rows where `selection = ~x` and `x` is a factor
> with two levels, but only one level appears (all rows have `x = "A"`). The
> propensity model will have a collinear design matrix in every draw; each
> draw catches `surveywts_error_propensity_hessian_singular`
> (`R/nonprob-ipw.R:85–93`), increments `failed_draws`, and the post-loop
> check fires `surveywts_error_bootstrap_all_draws_failed`."

---

## Summary Table

| ID | File | Lines | Severity | Category |
|----|------|-------|----------|----------|
| GAP B | `plans/spec-nps-bootstrap.md`; `R/nonprob-ipw.R` | spec:269–278, 428–439; code:742 | **HIGH** | Correctness bug |
| GAP 1 | `plans/spec-nps-bootstrap.md` | 197–201 | **HIGH** | Documentation |
| GAP A | `plans/spec-nps-bootstrap.md`; `R/nonprob-ipw.R` | spec:435; code:745 | MEDIUM | Inconsistency |
| GAP C | `plans/spec-nps-bootstrap.md`; `R/nonprob-ipw.R` | spec:271; code:715–718 | MEDIUM | Undocumented behavior |
| GAP 2 | `plans/spec-nps-bootstrap.md`; `R/nonprob-ipw.R` | spec:365–373; code:704 | MEDIUM | Misleading wording |
| GAP 4 | `plans/spec-nps-bootstrap.md` | 351–358 | MEDIUM | Missing justification |
| GAP 10 | `plans/spec-nps-bootstrap.md` | 256–257, 315–322 | MEDIUM | Algorithm ambiguity |
| GAP 5 | `plans/spec-nps-bootstrap.md` | 365–373 | LOW | Wording (covered by GAP 2) |
| GAP 6 | `plans/spec-nps-bootstrap.md` | 211–220, 296–305 | LOW | Missing validation |
| GAP 7 | `plans/spec-nps-bootstrap.md`; `R/nonprob-ipw.R` | spec:456–469; code:395–424 | LOW | Missing guard |
| GAP 8 | `plans/spec-nps-bootstrap.md` | §III | LOW | Documentation |
| GAP 9 | `plans/spec-nps-bootstrap.md` | §III | LOW | Documentation |
| GAP 11 | `plans/spec-nps-bootstrap.md` | §III, §XI:648–660 | LOW | Missing requirement |
| GAP 12 | `plans/spec-nps-bootstrap.md` | 618–622 | LOW | Test underspecified |
