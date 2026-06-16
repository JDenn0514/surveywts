# Spec Methodology Review: jackknife-merge — Pass 1 (2026-06-16)

## Scope Assessment

This spec implements four variance estimation paths (JKn, JK1, grouped probability,
DAGJK nonprobability) producing replicate weights with known statistical properties and
formulas from six reviewed papers. All five lenses apply. `comprehension.md` is
present; Lens 6 applies.

---

## New Issues

### Lens 1 — Method Validity

**Issue 1: History entry `operation` field is contradicted within the spec**
Severity: BLOCKING
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec states `operation = "jackknife_weights"` for all four dispatch paths in
multiple places (@returns, History entry schema for JKn/JK1, quality gates). But the
backend contract for grouped + `survey_taylor` and the output contract for the
probability paths both state that `.convert_and_call()` writes
`operation = "replicate_creation"`. Both cannot be true. A builder following the
quality gate will conflict with a builder following the output contract.

Looking at the existing `create_bootstrap_weights()` and other `create_*_weights()`
functions that use `.convert_and_call()`, the convention is
`operation = "replicate_creation"` with `method` as the discriminator. Changing
`.convert_and_call()` to write `"jackknife_weights"` would break that convention and
potentially break downstream code that inspects history entries from other functions.

Fix: Update every occurrence of `operation = "jackknife_weights"` for the probability
paths to `operation = "replicate_creation"` (consistent with all other `create_*_weights`
functions via `.convert_and_call()`). The discriminator is `method = "jackknife"` and
`parameters$type = "jkn" | "jk1" | "grouped"`. The quality gate becomes:
- Probability paths: `operation = "replicate_creation"`, `method = "jackknife"`,
  `parameters$type` records the variant
- DAGJK path: `operation = "jackknife_weights"` (written directly, not via
  `.convert_and_call()`)

The @returns doc for `operation = "jackknife_weights"` in both cases is wrong for the
probability paths; update to reflect the actual field value.

Options:
- **[A]** Accept `"replicate_creation"` for probability paths (consistent with all other
  replicate functions); update spec to match. — Effort: low, Risk: low, Impact: correct
  quality gates and @returns; Maintenance: none
- **[B]** Change `.convert_and_call()` to write `"jackknife_weights"` — Effort: medium,
  Risk: high (breaks history entry convention for bootstrap, BRR, SDR, genboot, genrep),
  Impact: consistency at the cost of breaking existing convention
- **[C] Do nothing** — Builder and tester receive contradictory contracts; one will be
  wrong.

**Recommendation: A** — Consistent with established convention; low-risk.

---

**Issue 2: `n_hg = n_h` (entire stratum in one group) produces Inf weights, not caught by degenerate check**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The DAGJK weight multiplier `n_h / (n_h - n_hg)` is undefined when `n_hg = n_h` (all
PSUs from stratum h land in group g). The result is `n_h / 0 = Inf`. The spec's
degenerate replicate check fires for "non-positive or NA weights" — Inf weights are
positive and non-NA, so they would pass through uncaught, producing Inf replicate
weights and wildly wrong variance estimates downstream without any warning.

The spec inherits this from the "unchanged" `.dagjk_single_replicate()` helpers. Whether
the existing code catches Inf weights needs to be verified, and the spec's degenerate
replicate trigger condition must be updated to include non-finite weights.

Fix: Expand the trigger condition for `surveywts_error_jackknife_degenerate_replicate`
to: "A DAGJK group replicate produced non-positive, non-finite, or NA weights, or
reduced dataset has no NPS or reference units." Also verify the existing `.dagjk_single_replicate()` check against this condition.

Options:
- **[A]** Add "non-finite" to the degenerate replicate check in the spec (and verify
  the existing code catches this). — Effort: low, Risk: low, Impact: prevents silently
  wrong variance estimates from Inf weights; Maintenance: none
- **[B]** Add a pre-loop check that validates no group contains all PSUs of any stratum
  before the replicate loop starts. — Effort: medium, Risk: low, Impact: earlier and
  clearer error; avoids expensive partial loops; Maintenance: none
- **[C] Do nothing** — Inf weights would be returned as valid replicate weights,
  producing silently wrong variance estimates.

**Recommendation: A** — Minimal change; correct spec; verify existing code handles this.

---

### Lens 2 — Variance Estimation Validity

**Issue 3: Extended DAGJK formula (`n_h < G`) — spec does not state whether it is implemented**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: JUDGMENT CALL

The comprehension (Formulas §Extended DAGJK) states: "When `n_h < G`, the standard
formula is upward-biased. Kott (2001) §3 eq. 2 gives a correction." The spec's DAGJK
backend contract shows only the standard formula (`n_h / (n_h - n_hg)`). The DAGJK
helpers are inherited "unchanged" — but the spec never states whether the extended
formula is implemented in the existing helpers.

In typical `survey_nonprob` usage with no explicit stratum variable, `n_h = n_nps`
(one stratum), and `n_h < G` requires `n_nps < G`, which is prevented by
`surveywts_error_jackknife_replicates_exceeds_n`. So the extended formula case is
unreachable in the standard NPS context. However, the spec should state this
explicitly rather than leaving it implicit.

Options:
- **[A]** Add a note to the DAGJK backend contract: "For `survey_nonprob` inputs with
  no explicit stratum variable, `n_h = n_nps` and the condition `n_h < G` is prevented
  by `surveywts_error_jackknife_replicates_exceeds_n`. The extended DAGJK formula
  (Kott 2001 §3 eq. 2) is therefore unreachable on this path and is not implemented."
  — Effort: low, Risk: low, Impact: removes an open question from the builder
- **[B]** Implement the extended formula in `.dagjk_single_replicate()` to support
  NPS data with explicit strata where `n_h < G`. — Effort: high, Risk: medium (adds
  new algorithmic complexity), Impact: handles a rare NPS use case with explicit
  strata; Maintenance: ongoing
- **[C] Do nothing** — Builder faces an unstated question about whether to implement
  the extended formula; test-spec cannot test for correct behavior in the `n_h < G`
  case.

**Recommendation: A** — Correctness is preserved in all reachable cases; explicitly
documents the scope boundary.

---

**Issue 4: Degrees of freedom not documented in output contract or `@returns`**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The comprehension (Gotcha 10, Assumptions §1) specifies:
- JKn: df = sum_h n_h − H (total PSUs minus strata count)
- DAGJK: df = G − 1

Downstream t-tests, F-tests, and CIs derived from the replicate design use these
degrees of freedom. The spec's output contract and @returns do not document the df for
any path. Users will not know how to compute or report CIs without this.

Fix: Add a degrees-of-freedom row to the output contract and a one-sentence note to
@returns: "The number of degrees of freedom is `G - 1` for the DAGJK path and
`sum_h n_h - H` for the JKn path."

Options:
- **[A]** Add df specification to output contract and @returns. — Effort: low, Risk: low
- **[C] Do nothing** — df is implicit; users must derive it from the replicate count
  and stratum structure themselves.

**Recommendation: A**

---

### Lens 3 — Algorithmic Correctness

Lens 3 not applicable for the JKn/JK1/grouped+taylor paths (closed-form weight
construction, no convergence criterion — delegated to survey and svrep backends).

For the DAGJK path, the loop is not iterative in the convergence sense; it is a
finite loop over G groups. Within each replicate, IPW and calibration replay can fail;
the spec correctly handles this via `tryCatch()` and failure counting. No additional
Lens 3 issues beyond Issue 2 (Inf weight catch) and Issue 3 (extended formula).

---

### Lens 4 — Statistical Assumptions

**Issue 5: FPC / with-replacement sampling assumption missing from Limitations for probability paths**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The comprehension (Assumptions §1) states: "All jackknife formulas are derived under WR
or near-WR conditions. Kott (2001) §2 states FPC must be negligible. Wolter (2007)
§4.3.3 shows JKn is upward biased for WOR designs by a factor of f/(1-f) when sampling
fractions are non-trivial. For the `survey_taylor` paths, it is the user's
responsibility."

The spec's Limitations section mentions FPC for the DAGJK path only. It does not
warn users that JKn and JK1 assume negligible FPC; users with designs that have
substantial sampling fractions may get positively biased variance estimates without
any indication.

Fix: Add one Limitations bullet: "JKn and JK1 assume negligible finite population
correction (WR or near-WR first-stage sampling). For designs with substantial sampling
fractions, jackknife variance estimates are positively biased; use `fpc =` in the
design object to enable FPC-adjusted estimation or consider BRR."

Options:
- **[A]** Add FPC bullet to Limitations. — Effort: low
- **[C] Do nothing** — Assumption is implicit; sophisticated users know it.

**Recommendation: A**

---

### Lens 5 — Formula Integrity

**Issue 6: JKn `mse = FALSE` centering form not shown in Algorithm section**
Severity: SUGGESTION
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The Algorithm section shows only the `mse = TRUE` (v_4) centering formula for JKn.
The `mse` @param contract describes both forms in prose ("centers on full-sample
estimate" vs "within-stratum mean of replicate estimates") but the Algorithm section
does not show the v_1 formula. A user reading the Algorithm section to understand the
difference between `mse = TRUE` and `mse = FALSE` would not find a concrete formula
for the `mse = FALSE` case.

Fix: Add the v_1 form alongside the v_4 form in the JKn Algorithm sub-section:

```
\deqn{
  v_1(\hat\theta) = \sum_{h=1}^{H} \frac{n_h - 1}{n_h}
    \sum_{i=1}^{n_h} (\hat\theta_{(hi)} - \bar\theta_{(h\cdot)})^2
}
```

where `bar_theta_{(h·)} = (1/n_h) sum_i hat_theta_{(hi)}` is the within-stratum mean
of replicate estimates (Wolter 2007 v_1 form, `mse = FALSE`).

Options:
- **[A]** Add v_1 formula and symbol binding to Algorithm sub-section. — Effort: low
- **[C] Do nothing** — `mse` @param describes both forms; Algorithm section is
  incomplete but @param is clear.

**Recommendation: A**

---

### Lens 6 — Literature Cross-Check

**Formula fidelity:** All formulas in the spec (JKn weight rule, JKn variance, JK1,
DAGJK weight rule, DAGJK variance) match the corresponding equations in
`comprehension.md`. Symbol bindings are consistent with the comprehension §Symbols
table. No formula discrepancies found.

**Gotcha coverage:**

| Comprehension gotcha | Spec coverage |
|---|---|
| 1 — Single-PSU strata | Delegated to backends for probability paths (acceptable); not applicable to standard DAGJK (n_h = n_nps, prevented by ceiling validation). Adequately handled. |
| 2 — Extended DAGJK negative weights (`n_h = 2`) | Spec includes `surveywts_warning_jackknife_negative_replicate_weights`. Adequately covered. However, Issue 3 notes the extended formula path is unreachable on standard NPS inputs. |
| 3 — Pseudo-weights must be recomputed per replicate | Covered: spec states IPW refit and calibration replay happen inside each iteration. ✓ |
| 4 — Jackknife not consistent for quantiles | Covered: Limitations §1 explicitly states this. ✓ |
| 5 — G = 50 is a simulation choice | Covered: @param for `replicates` attributes this to VDK (2018) Table 15.2 df threshold, not to Valliant (2020) as a "validated default." ✓ |
| 6 — Unequal group sizes | Spec's `surveywts_warning_jackknife_small_groups` fires at avg size < 5. Adequately covered. |
| 7 — All PSUs from one stratum in one group | Issue 2 flags that the Inf weight case is not caught by current degenerate check. ⚠️ |
| 8 — `mse = FALSE` silently forced — must warn | Covered: spec correctly specifies warn-and-override, not silent fix. ✓ |
| 9 — FPC not applicable to DAGJK | Covered: Limitations §4 states this. ✓ |
| 10 — Degrees of freedom | Issue 4 flags this as missing from output contract. ⚠️ |

**Reference mapping:** All six spec decisions in the comprehension's Reference mapping
section are traceable to specific equations or sections (Kott eq. 1, Wolter §4.5,
Valliant, Dever & Kreuter eq. 15.11–15.12, etc.). No unverified inline citations found
in the @references block. ✓

**Assumption alignment:**

| Comprehension assumption | Spec coverage |
|---|---|
| 1 — WR/negligible FPC | DAGJK Limitations §4 ✓; probability paths: Issue 5 |
| 2 — Calibration/IPW replay required | Covered in DAGJK backend contract §3 and §6. ✓ |
| 3 — Smooth estimator only | Limitations §1 ✓ |
| 4 — Random group formation | Covered in DAGJK backend contract §5 (sample() call). ✓ |
| 5 — No group spans entire stratum | Not pre-validated; Issue 2 covers the consequence. |
| 6 — MAR (non-ignorable mechanism) | Limitations §3 ✓ |
| 7 — Equal group sizes | `sample(rep(...))` produces maximally equal groups; `surveywts_warning_jackknife_small_groups` fires when avg < 5. ✓ |

**Open question resolution:** The comprehension has no open questions section.
Cross-paper conflicts are resolved consistently with the spec (centering convention
→ match survey package mse parameter; G = 50 attribution → VDK Table 15.2; DAGJK
vs v_GJ3 → DAGJK appropriate for nonprob; JK1 on stratified designs → user choice
with documentation). ✓

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 2 |
| SUGGESTION | 3 |

**Total issues:** 6

**Overall assessment:** The statistical methodology is sound across all four dispatch
paths. The formulas match the literature, the mse centering conventions are correctly
specified, and the DAGJK limitations are appropriately documented. Two substantive
issues need resolution before implementation: the history entry `operation` field is
contradicted within the spec (BLOCKING), and the degenerate replicate check does not
cover Inf weights from the n_hg = n_h case (REQUIRED). The extended DAGJK formula
question is clarification-only — it is unreachable in the standard NPS case but should
be stated explicitly.

---

## Resolutions (2026-06-16)

All 6 issues resolved in `plans/spec-jackknife-merge.md`. Verdict: **PASS**.

| Issue | Severity | Resolution |
|-------|----------|------------|
| 1 — History `operation` field contradiction | BLOCKING | Accepted option A. Updated all probability path history entries to `operation = "replicate_creation"`, `method = "jackknife"`, `parameters$type` records variant. Updated @returns, output contracts, quality gate, and history entry schema accordingly. DAGJK path retains `operation = "jackknife_weights"`. |
| 2 — Inf weights not caught by degenerate check | REQUIRED | Accepted option A. Expanded degenerate replicate trigger condition in `.dagjk_single_replicate()` and `.dagjk_single_replicate_calib()` from "non-positive or NA" to "non-positive, non-finite, or NA". |
| 3 — Extended DAGJK formula unspecified | REQUIRED (JUDGMENT CALL) | User chose to implement. `.dagjk_single_replicate()` moved from "Unchanged" to "Modified". Full per-stratum dispatch logic added with standard formula (`n_h >= G`) and extended formula (Kott 2001 §3 eq. 2, `n_h < G`). Documented boundary continuity (`n_h == G` reduces to standard), negative weight trap (`n_h = 2`), and one-stratum NPS case (unreachable via `surveywts_error_jackknife_replicates_exceeds_n`). Algorithm section updated with extended formula `\deqn{}` block. |
| 4 — Degrees of freedom missing from output contract | SUGGESTION | Accepted option A. Degrees of freedom added to output contracts (JKn: `sum_h n_h - H`; grouped+taylor: `G - 1`; DAGJK: `G_success - 1`) and to @returns documentation. |
| 5 — FPC assumption missing for probability paths | SUGGESTION | Accepted option A. Added Limitation #3 to @section Limitations: "JKn and JK1 assume negligible finite population correction (WR or near-WR first-stage sampling, Wolter 2007 §4.3.3). For designs with substantial sampling fractions, jackknife variance estimates are positively biased; set `fpc =` in the design object to enable FPC-adjusted estimation or consider BRR." |
| 6 — JKn mse=FALSE formula not shown | SUGGESTION | Accepted option A. Added v_1 form (`mse = FALSE`, Wolter 2007 §4.5) alongside v_4 form in Algorithm section for JKn, with `\deqn{}` and symbol binding for within-stratum mean `bar_theta_{(h·)}`. |
