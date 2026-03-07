# Stage 2: Adversarial Methodology Review

You are reviewing a spec for statistical and methodological correctness. Your
job: find every flaw in the underlying methodology before a line of code is
written. Wrong math and invalid statistical assumptions produce silently wrong
answers that pass all tests — that is far worse than a crash.

This stage produces a **complete methodology issue list saved to a file**. It
is a batch pass — do not resolve issues here. Resolution happens in Stage 4.

---

## Scope Assessment

Before applying the lenses, determine whether this feature involves statistical
or mathematical computation. Answer the following:

- Does this feature implement, modify, or extend a statistical or mathematical
  method?
- Does it produce numerical quantities (weights, estimates, test statistics)
  with known statistical properties?
- Does it involve iterative algorithms, closed-form formulas, or numerical
  procedures that must be exactly specified?

**If none of these apply** — e.g., the feature is a `print()` method, a
format or display change, a utility with no mathematical content, or
documentation — declare Stage 2 not applicable and skip to Stage 3. Note the
reason briefly in the output file.

**If any apply**, proceed with all five lenses below. Within each lens, skip
sub-questions that genuinely don't apply to the feature being reviewed — but
err toward checking rather than skipping.

---

## Input Requirement

If no spec document is provided in the message, ask the user to paste the spec
or provide the file path. Read the full spec once before generating any output.
Do not start reporting issues mid-read.

---

## Five Methodology Lenses

### Lens 1 — Method Validity

The method must produce what the spec claims it produces. Inputs must be
well-defined, constraints must be achievable, and boundary cases must be
handled. Flag any of the following:

**General questions:**
- Are all inputs and their constraints clearly specified? Vague inputs produce
  vague outputs.
- Does the spec verify that the method is applicable to the inputs provided
  (e.g., does it require a probability sample? A minimum sample size? A
  specific data structure)?
- Are all configurable options (e.g., `type =`, `method =`) fully specified in
  their effect on the computation — not just listed by name?
- Does the spec define behavior for degenerate inputs: zero-cell cases,
  infeasible constraints, inputs where the method is undefined?

**When reviewing calibration and raking features:**
- For `rake()`: are marginal totals sourced from the same reference population?
  Raking marginals from different surveys or reference years will produce
  weights that satisfy no population jointly.
- For `calibrate()`: does the spec verify calibration feasibility (no
  conflicting constraints)? If targets are proportions, do they sum to 1? If
  counts, do they sum to the claimed population total?
- For `poststratify()`: what happens when population cell counts are provided
  for cells not present in the sample? The behavior (error, warning, omit)
  must be stated.
- Is the `type = "prop"` vs. `type = "count"` distinction propagated
  consistently? A proportion target requires dividing by the population total
  somewhere — is that step specified?
- Post-stratification divides by the sample cell count. A zero-count sample
  cell is a division-by-zero. Is this handled?
- Linear calibration (GREG) can produce negative weights when the sample is
  poorly aligned with the population or auxiliary variables are collinear. Is
  the spec silent on whether negative calibrated weights are permitted, warned
  on, or treated as errors?
- For `rake()`: does the spec state whether any cap or floor is applied per
  iteration, or only at convergence?
- When multiple raking variables are provided, marginals must be internally
  consistent (all must imply the same total N). Is this verified?

---

### Lens 2 — Variance Estimation Validity

**If this feature does not affect how variance is estimated**, skip this lens
and note "Lens 2 not applicable: [reason]."

Calibration and other weight transformations change the variance structure of
estimates. Using pre-transformation variance estimators on transformed weights
produces biased standard errors. Flag any of the following:

**General questions:**
- Does the spec state which variance estimator is appropriate after this
  transformation or operation?
- If the feature defers variance estimation to a later phase, does it
  explicitly document what is and is not valid in the interim? Silence is not
  acceptable — users who compute SEs on partially-adjusted weights will get
  wrong answers without being warned.
- Are degrees of freedom conventions stated, especially for downstream
  inference?

**When reviewing calibration features:**
- For each accepted input class (`data.frame`, `weighted_df`, `survey_taylor`,
  `survey_calibrated`): does the spec state what happens to the variance
  structure? A `survey_taylor` carries PSU/strata/FPC information that
  determines the variance estimator. If calibration silently converts it to
  `survey_calibrated`, the Taylor design is lost and linearized SEs can no
  longer be computed correctly. The spec must state, for each input class,
  (a) what is preserved, (b) what is discarded, and (c) whether the user is
  warned about any loss.
- Calibrated weights require either (a) replicate weights independently
  re-calibrated, or (b) a linearization-based estimator accounting for
  calibration constraints (the "g-weight" approach in GREG theory). Is this
  specified?
- If deferred to Phase 1: does the spec explicitly state that
  Taylor-linearized SEs on calibrated weights without re-calibrated replicates
  will be biased (typically upward — conservative — but not guaranteed)?
- For `create_*_weights()` (Phase 1): does each replicate receive its own
  independent calibration pass? The former is correct; the latter understates
  variance.
- Are scale factors for BRR, JK1, JKn specified? Wrong scale factors produce
  wrong SEs.

**When reviewing diagnostic features:**
- For `effective_sample_size()`: there are at least two common formulas:
  - Kish (1965): n_eff = n / (1 + CV²(w))
  - Equivalent form: n_eff = (Σw_i)² / (n · Σw_i²)
  - Design-effect-based: n_eff = n / DEFF
  These can differ. Does the spec state exactly which formula is used?
- Does the diagnostic operate on final calibrated weights or design weights?
  The answer changes the interpretation entirely. The spec must be explicit.

---

### Lens 3 — Algorithmic Correctness

**If this feature does not involve iteration, optimization, or non-trivial
numerical computation**, skip this lens and note "Lens 3 not applicable:
[reason]."

Iterative procedures can converge slowly, diverge, or converge to wrong local
solutions. Numerical quantities with extreme values inflate variance. Flag any
of the following:

**General questions:**
- For any iterative algorithm: what is the convergence criterion? "Iterate
  until stable" is not a spec. Must include: the specific quantity being
  monitored, the numerical threshold, the maximum iteration count, and behavior
  on non-convergence (error, warn and return partial result, or silently
  return).
- Does the spec correctly identify whether an algorithm is closed-form or
  iterative? Misidentifying this is a methodological error.
- After the operation, are the relevant quantities conserved (weights summing
  to the right total, probabilities summing to 1, etc.)?
- Does the spec state distribution properties of the output — e.g., are values
  constrained to be positive? Bounded? Normalized?

**When reviewing calibration and raking features:**
- For `rake()` (iterative proportional fitting): does the spec state the
  convergence criterion including the specific quantity, threshold, max
  iterations, and behavior on failure?
- For `calibrate()` with `method = "linear"` (GREG): GREG has a closed-form
  solution and does not iterate. If the spec says GREG "iterates," that is a
  methodological error.
- For `calibrate()` with `method = "raking"`: this is IPF and does iterate —
  same convergence requirements as `rake()`.
- After calibration: the sum of calibrated weights should equal the target
  population total (or N, for proportion-based calibration). Is a weight
  conservation check specified?
- Is the normalization convention stated? (Sum to N vs. sum to population
  total vs. sum to 1 are different and must be explicit.)
- Does `weight_variability()` compute CV as sd(w)/mean(w)? Is the formula
  shown?
- Does `summarize_weights()` flag extreme weight ratios (max/min, or weights
  that deviate more than k × IQR)? If not, is that omission deliberate?

---

### Lens 4 — Statistical Assumptions

Statistical methods require assumptions. Unstated assumptions are silent
landmines — a user will apply a function in a context where the assumption
fails and not know it. Flag any of the following:

**General questions:**
- What assumptions does the method require about the input data? Are these
  stated in the spec?
- What happens when these assumptions are violated? Is the user warned?
- Does the spec distinguish between related but meaningfully different concepts
  that users are likely to conflate?
- Are estimates produced by this feature documented as design-consistent or
  otherwise? Under what conditions?

**When reviewing calibration and nonresponse features:**
- Calibration, raking, and post-stratification are defined for probability
  samples. Are design weights (`base_weight`) required as input? Optional?
  Ignored? If a user passes an unweighted data frame, is it treated as SRS
  (all weights = 1) or is it an error? Silence is not acceptable.
- Does the spec distinguish between *design weights* (inverse probability of
  selection) and *nonresponse-adjusted weights*? These are different objects
  with different properties. Conflating them is a methodological error.
- For `adjust_nonresponse()`: the method assumes nonresponse is Missing at
  Random conditional on the weighting class variables. Is this stated in the
  spec? Without MAR, nonresponse weighting redistributes rather than removes
  bias.
- Does the spec state that weighting class adjustment reduces nonresponse bias
  only to the extent that class variables predict both response propensity AND
  survey outcomes?
- `poststratify()` calibrates to joint cell counts, not marginal totals. Does
  the spec state this distinction explicitly? Users who conflate raking and
  post-stratification will misapply them.
- Raking (IPF) converges to the maximum-entropy distribution that matches all
  marginals. It does NOT impose a joint distribution — only marginal
  constraints. Does the spec state this?

---

### Lens 5 — Formula Integrity

Incorrect formulas produce wrong answers that pass all behavioral tests. This
lens is a formula audit. Flag every case where a formula is vague, ambiguous,
wrong, or absent when a specific formula is required.

**General questions:**
- Is every formula shown as a concrete mathematical expression, not described
  in words? "Adjust weights to match targets" is not a formula.
- For formulas with multiple algebraically equivalent forms: which exact form
  is implemented? Equivalents may differ numerically under different
  normalization conventions.
- For iterative update steps: is the exact update rule given, including the
  ordering of operations within each iteration?
- Are all variable definitions present alongside the formula? Undefined symbols
  leave implementers to guess.

**When reviewing calibration and weighting features:**
- **ESS disambiguation:** Kish (1965) gives n_eff = n / (1 + CV²(w)). An
  equivalent form is (Σw_i)² / (n · Σw_i²) — but only when weights are not
  normalized to sum to n. If weights sum to n, the formula simplifies to
  n² / Σw_i². Does the spec show the exact formula as implemented, accounting
  for the normalization convention in use?
- **GREG weight formula:** The calibrated weight for unit k is:
  w_k^cal = w_k · (1 + (T − X'W·x) · (X'WX)^{−1} · x_k)
  where T is the vector of population totals, W = diag(w_k), and x_k is the
  auxiliary vector for unit k. Does the spec reference or derive this?
- **IPF update step:** At each iteration, for variable j with target marginal
  t_j:
  w_k^(new) = w_k^(old) · t_{j,c(k)} / (Σ_{k in cell c} w_k^(old))
  where c(k) is the cell of unit k for variable j. The order of variable
  updating within each iteration matters — does the spec state it?
- **Post-stratification weight:** For unit k in cell h:
  w_k^ps = w_k · (N_h / n_h)
  where N_h is the population count and n_h is the sample count for cell h.
- **CV of weights:** CV = sd(w) / mean(w). Does the spec state which weights
  (normalized vs. raw) are used in the CV calculation? The numeric result
  differs.

---

## Issue Format

Use this format for every issue:

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
Lens: [1–5 and lens name]

[Concrete description. Quote or reference the spec text that is missing or
wrong. State the specific methodological problem in plain language.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high], Impact: [what]
- **[B]** [Alternative description]
- **[C] Do nothing** — [what stays wrong or ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]
```

**Severity tiers:**

- **BLOCKING** — The function will produce wrong answers without resolving
  this. An implementer could write code that passes all tests and still be
  statistically incorrect.
- **REQUIRED** — A significant gap or ambiguity that will cause either silent
  wrong behavior or user confusion about methodology.
- **SUGGESTION** — A documentation or clarity improvement; the implementation
  would likely still be correct without it.

---

## If a Methodology Review File Already Exists

Before writing any output, check for `plans/spec-methodology-{id}.md`.

**If it exists:**
1. Read the full existing file
2. Complete your fresh review of the current spec
3. In the new pass section, list every previously flagged issue with a status:
   - ✅ Resolved — the spec was updated to address it
   - ⚠️ Still open — the spec was not changed
4. **Append** the new pass section to the bottom of the existing file — never
   overwrite or delete prior content

**If it does not exist:** create the file with Pass 1.

---

## Output Structure

Organize all issues by lens. If a lens has no issues, say "No issues found."
If a lens was skipped, say "Lens [N] not applicable: [reason]."

```markdown
## Methodology Review: [id] — Pass [N] ([YYYY-MM-DD])

### Prior Issues (Pass [N-1])
_Omit this section on Pass 1._

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | [title] | 1 | ✅ Resolved |
| 2 | [title] | 3 | ⚠️ Still open |

### New Issues

#### Lens 1 — Method Validity

**Issue [N]: [title]**
Severity: BLOCKING
Lens: 1 — Method Validity
...

#### Lens 2 — Variance Estimation Validity

Lens 2 not applicable: this feature (print method for weighted_df) does not
affect variance estimation.

[continue for all five lenses]

---

## Summary (Pass [N])

| Severity | Count |
|---|---|
| BLOCKING | N |
| REQUIRED | N |
| SUGGESTION | N |

**Total issues:** N

**Overall assessment:** [One honest sentence — e.g., "The calibration and
post-stratification contracts are sound, but variance estimation after
calibration is unspecified, which will produce wrong standard errors for
any downstream inference."]
```

---

## Before Outputting

Ask yourself:

- Did I complete the Scope Assessment and determine which lenses apply?
- Have I applied all applicable lenses, even for features that seem
  straightforward?
- Have I flagged every formula that is described vaguely instead of stated
  exactly?
- Have I checked every iterative procedure for a concrete convergence
  criterion?
- Have I flagged unstated statistical assumptions, not just code-level gaps?
- Is the overall assessment honest — does it match the issue count and
  severity?

If the methodology is genuinely sound, say so. Adversarial means rigorous, not
performatively negative.

---

## After Completing the Review

1. Determine `{id}` from the spec filename if not already known.
2. Append the new pass section to `plans/spec-methodology-{id}.md` (create on
   Pass 1).
3. End the session with:

   > "Methodology review Pass [N] complete: {N} new issues ({X} blocking,
   > {Y} required, {Z} suggestions). Start a new session with
   > `/spec-workflow stage 3` to run the adversarial spec review, or
   > `/spec-workflow stage 4` to resolve issues directly. Review appended to
   > `plans/spec-methodology-{id}.md`."
