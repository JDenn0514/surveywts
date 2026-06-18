## Methodology Review: calibrate-to-survey-opsomer — Pass 1 (2026-06-17)

### Scope Assessment

This spec implements the Opsomer & Erciulescu (2022) replication variance
adjustment for sample-based calibration with mixed fixed and random margins.
It includes:

- A variance estimation method (replicate-based variance after sample-based
  calibration propagating control-survey uncertainty)
- Iterative algorithms (IPF raking, Newton-Raphson calibration) with
  convergence requirements
- Formulas for `a_r` constants, perturbed control totals, and K expansion
  for the R_C > R case
- Configurable options with non-trivial statistical effects (`method`,
  `algorithm`, `type`)

**All five lenses apply. Lens 6 applies** — comprehension.md is present at
`.surveywts-workspace/runs/2026-06-17-calibrate-to-survey-opsomer/comprehension.md`.

---

### New Issues

#### Lens 1 — Method Validity

**Issue 1: `control_col_matches` default (random vs. sequential) not specified**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec says the control-to-primary replicate mapping comes "from
`control_col_matches`, or sequential/randomized mapping" — this is ambiguous
about the default. Opsomer & Erciulescu (2022), below eq. 2.10, explicitly
state that for the independence argument to hold, the assignment of which
control replicate maps to which primary replicate must be random. A sequential
(1→1, 2→2, …) mapping violates the independence assumption if control and
primary replicates have any structure (e.g., geographic blocks, ordered
strata).

Currently the spec neither enforces randomness nor documents its absence. An
implementer could choose sequential mapping — and the function would produce
slightly biased variance estimates that pass all tests.

Options:
- **[A]** State that the default is a random permutation drawn once per call
  (so `set.seed()` makes calls reproducible). Document in `@param control`
  and the Algorithm section. — Effort: low, Risk: low, Impact: correct
  independence behaviour by default, Maintenance: none
- **[B]** State that the default is sequential and document the statistical
  caveat — Effort: low, Risk: medium, Impact: users must set
  `control_col_matches` manually to achieve valid inference, Maintenance:
  long-term confusion
- **[C] Do nothing** — Implementers guess; the variance property may be wrong
  silently

**Recommendation: A** — The paper requires randomness; the function should
default to it.

---

**Issue 2: Level alignment between primary and control designs not specified**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

`.compute_control_totals()` computes control-survey totals "per level" for
each variable in `variables`, but the spec does not state *which* levels are
used. Three cases arise when primary and control designs have different factor
levels for the same variable:

1. Control has a level absent from primary: the calibration target includes a
   margin for a level with no primary sample units → calibration to a non-zero
   target for an empty cell fails or produces degenerate weights.
2. Primary has a level absent from control: the estimated control total for
   that level is 0 → raking will try to collapse that cell to zero weight →
   degenerate replicate weights without a clear error.
3. Level *ordering* differs: if levels are matched positionally rather than by
   name, the wrong totals are assigned to the wrong categories.

The spec must state: control totals are computed for the levels present in
`primary_design`, matched by name. If `control_design` lacks a level that
exists in `primary_design`, the function should raise
`surveywts_error_variables_not_found` (or a new descriptive error class) before
any calibration is attempted.

Options:
- **[A]** Document that control totals are computed for exactly the levels
  present in `primary_design`, matched by name. If any level is absent from
  control, raise an error before calibration. Add to validation step 8 or
  introduce a new validation step in `.compute_control_totals()`. — Effort:
  low, Risk: low, Impact: eliminates a silent degenerate-weight path,
  Maintenance: none
- **[B]** Use the intersection of levels; raise a warning when levels are
  dropped — Effort: low, Risk: medium, Impact: silently narrows calibration
  scope, Maintenance: ongoing user confusion
- **[C] Do nothing** — Degenerate weights or cryptic calibration errors result

**Recommendation: A** — Level-name matching with a pre-calibration error is
the least surprising and most informative behaviour.

---

**Issue 3: Format B tibble + `type` argument interaction unspecified**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

The spec supports two formats for `targets` elements:
- Format A: named numeric vector (type determined by the `type` argument)
- Format B: tibble with the variable column plus `"n"` (count) or `"prop"`
  (proportion) column (type implied by column name)

For mixed-format lists (some Format A, some Format B), it is unclear whether
`type` applies globally or only to Format A elements. Concrete conflict:

```r
# Format B tibble has "prop" column — but type = "count" is supplied:
list(
  age_group = tibble(age_group = c("18-34","35-54"), prop = c(0.4, 0.6))
)
```

Does `type = "count"` cause 0.4 and 0.6 to be treated as counts (clearly
wrong, they're proportions) or does the column name take precedence? This
ambiguity affects both validation (`surveywts_error_targets_totals_invalid`)
and the conversion from proportions to counts.

Options:
- **[A]** Column name takes precedence for Format B; `type` applies only to
  Format A elements. Validation error if `type` and the column name imply
  contradictory interpretations (e.g., `type = "count"` with a `"prop"` column
  or values summing to 1). — Effort: medium, Risk: low, Impact: unambiguous
  semantics, Maintenance: low
- **[B]** `type` applies globally; the column name (`"n"` vs. `"prop"`) is
  purely documentary. Validation uses `type` regardless of column name. —
  Effort: low, Risk: medium, Impact: Format B column name becomes misleading
  if mismatched, Maintenance: user confusion
- **[C] Do nothing** — Implementer chooses; the two interpretations produce
  different weights

**Recommendation: A** — Column names in Format B carry semantic meaning (they
are the output of the user naming the column `"prop"` deliberately); treating
`type` as an override would silently misinterpret user-supplied data.

---

#### Lens 2 — Variance Estimation Validity

**Issue 4: Independence assumption not documented in spec**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

Opsomer & Erciulescu (2022), eq. 2.5, derive their variance estimator's
consistency under the assumption that the primary and control surveys are
drawn independently. The comprehension.md flags this explicitly: "The two
surveys are independent — the consistency proof in eq. 2.5 depends on this.
Overlapping samples would invalidate the method, but this cannot be detected
from the data."

The spec does not document this assumption anywhere: not in the function
contract, not in the `@param control_design` documentation, not in the roxygen2
requirements. A user who applies the function to:
- Two waves of the same panel (overlapping respondents)
- A subsample of the control survey as the primary sample
- Any linked-sample design

will receive no warning and get silently understated variance estimates. Since
overlap cannot be detected from the data alone, this must be documented.

Fix: add to the roxygen2 documentation requirements — specifically, a
**Limitations** section (or as a paragraph at the end of the Algorithm
section) stating: "The Opsomer & Erciulescu (2022) consistency proof assumes
`primary_design` and `control_design` are independent samples from
non-overlapping draws. Using overlapping samples produces variance estimates
that do not account for the covariance between the two sample totals. This
function cannot detect overlap; users are responsible for verifying the
independence condition."

Options:
- **[A]** Add a Limitations section to the roxygen2 requirements (or append to
  the Algorithm section) with the independence statement as above. — Effort:
  low, Risk: low, Impact: users informed, Maintenance: none
- **[B]** Do nothing — Effort: zero, Risk: high, Impact: users silently
  misapply the method

**Recommendation: A** — This is a precondition of the method's validity.

---

#### Lens 3 — Algorithmic Correctness

**Issue 5: Starting weights for per-replicate calibration not stated**
Severity: BLOCKING
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

Step 6 of the Opsomer algorithm says: "Calibrate primary replicate-r weights
to the combined target set … using `.calibrate_engine()` with `method` and
`algorithm`." The spec does not state what the starting (initial) weight
vector is for each per-replicate calibration call. There are at least two
plausible interpretations:

**(a) Start from the original primary replicate weights `w_i^(r)`** — the
correct interpretation per Opsomer & Erciulescu (2022). Each replicate
calibration starts from the same starting point as the uncalibrated replicate
weights, independently of the full-sample calibration.

**(b) Start from the calibrated full-sample weights `w_i^*`** — incorrect.
If an implementer starts from `w_i^*`, the per-replicate calibration is
merely a small adjustment from the already-calibrated weights to the
perturbed targets. This produces replicate weights that are much closer to
the full-sample calibrated weights, understating the variance contribution of
the control-survey calibration by a factor proportional to the perturbation
magnitude. This would pass all behavioral tests (returns a valid design,
satisfies the combined target) but produce statistically wrong variance
estimates.

The distinction is critical: interpretation (b) would survive all tests in
the test-spec (which validates constraint satisfaction and `a_r` values but
not the variance estimator's statistical properties directly).

Fix: Step 6 should read: "For each primary replicate r, start from the
*original* (pre-calibration) primary replicate weights `w_i^(r)`
(`primary_design@variables$repweights[[r]]` from the input design). Calibrate
these to the combined target set … using `.calibrate_engine()`."

Options:
- **[A]** Clarify Step 6 to state explicitly that the starting weights for
  each replicate calibration are the original primary replicate weights
  `w_i^(r)` from the input design — not the calibrated full-sample weights.
  — Effort: low, Risk: low, Impact: eliminates a statistically catastrophic
  implementation error, Maintenance: none
- **[B] Do nothing** — Risk: high; an implementer following interpretation (b)
  produces wrong variance estimates that pass all tests

**Recommendation: A** — No alternative; this is a matter of statistical
correctness.

---

**Issue 6: Replicate total computation formula not stated**
Severity: SUGGESTION
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

Step 4 of the algorithm gives a complete formula for the full-sample control
totals: "for each variable in `variables`, sum
`control_design@data[[v]] * control_full_weights` per level." Step 6 uses
`t̂_{Cx}^(c_s)` (control replicate-`c_s` totals) without a parallel
specification. The analogous formula is clear in principle — sum
`control_design@data[[v]] * control_design@variables$repweights[[c_s]]` per
level — but it should be stated to match the completeness of Step 4.

Options:
- **[A]** Add a parallel formula in Step 6: "Compute replicate control totals:
  for each variable in `variables`, `t̂_{Cx}^(r) = sum(control_design@data[[v]]
  * control_design@variables$repweights[[r]])` per level." — Effort: low,
  Risk: none, Impact: spec completeness, Maintenance: none
- **[B] Do nothing** — Implied by analogy; unlikely to be misimplemented

**Recommendation: A** — Parallel to Step 4 is cheap and eliminates ambiguity.

---

#### Lens 4 — Statistical Assumptions

Lens 4 — independence assumption is already flagged as Issue 4. One additional
item:

**Issue 7: `survey_nonprob` inputs — method validity not documented**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: JUDGMENT CALL

The spec accepts `survey_nonprob` as valid input for both `primary_design` and
`control_design`. The Opsomer & Erciulescu (2022) method is derived in the
framework of probability samples with design-based replicate variance. For a
nonprobability sample (`survey_nonprob`), the replicate weights typically
encode bootstrap or jackknife variance of a pseudo-estimator — a different
epistemic object. The method works mechanically but produces variance estimates
whose statistical interpretation differs from the paper's setting.

This is not a blocking issue (the existing function already accepted
`survey_nonprob` and nothing in the spec removes that), but the roxygen2
documentation should note that the statistical justification is
design-specific.

Options:
- **[A]** Add a sentence to the Limitations section: "The Opsomer & Erciulescu
  (2022) consistency proof assumes probability samples. When `survey_nonprob`
  designs are supplied, the method operates mechanically but the variance
  interpretation depends on how the replicate weights were constructed." —
  Effort: low, Maintenance: none
- **[B] Do nothing** — Already implicit; users of `survey_nonprob` understand
  the design context

**Recommendation: A** — One sentence in Limitations is cheap relative to the
confusion it prevents.

---

#### Lens 5 — Formula Integrity

**Issue 8: `type = "prop"` — population total for proportion-to-count conversion not specified**
Severity: BLOCKING
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

When `type = "prop"`, the proportions in `targets` must be converted to
population-count totals before being passed to `survey::calibrate()`. The
formula is:

```
count(level) = proportion(level) × N
```

where `N` is the implied population size. The spec does not state what `N` is.
The options are:

**(a)** `N = sum(primary_design@data[[primary_design@variables$weights]])` — the
estimated population size from the original (pre-calibration) primary
full-sample weights. Standard approach: aligns the fixed margins with the same
population the primary survey estimates.

**(b)** `N = sum(w_i^*)` — the estimated population size from the calibrated
full-sample weights. Self-referential: the value of `N` depends on the
calibration result, creating a circular dependency.

**(c)** `N = sum(control_design@data[[control_design@variables$weights]])` —
the estimated population size from the control survey. Wrong: the control
survey estimates a population total that may differ from the primary survey's
target.

**(d)** Some external user-supplied total — not exposed in the current API.

Using option (b) or (c) produces fixed margins that target the wrong population
size, so the calibrated full-sample weights do not satisfy the stated `targets`
proportions relative to the primary survey's estimated population.

Fix: state explicitly in the spec that `N = sum(primary_design@data[[weights]])`,
where `weights` is the original primary full-sample weight column name, before
any calibration. Add this conversion step to the Opsomer algorithm (between
Step 4 and Step 5, or as a sub-step of the targets normalization).

Options:
- **[A]** State: `N = sum(original primary full-sample weights)`. Normalization
  happens during `targets` format normalization (producing named count vectors
  internally before Step 5). — Effort: low, Risk: low, Impact: eliminates
  ambiguity in proportion calibration, Maintenance: none
- **[B] Do nothing** — Implementers infer from context or delegate to
  `.calibrate_engine()`; risk of inconsistent behaviour across methods

**Recommendation: A** — The population total must be stated; options (b) and
(c) are wrong and an implementer might choose them.

---

**Issue 9: Spec formulas are correct — affirmative note**
The following formulas were checked against comprehension.md (eq. 2.9 and
2.10) and are correct:

- Perturbed total formula: `t̂*_{Cx}(s) = t̂_{Cx} + a_s * (t̂_{Cx}^(c_s) - t̂_{Cx})` ✓
- `a_r` for standard case: `sqrt(A_C / A)` for `r ≤ min(R, R_C)`, `0` for
  `r > min(R, R_C)` ✓
- K expansion: `K = ceiling(R_C / R)`, `A_eff = A / K` ✓
- `a_r` for expanded case: `sqrt(A_C / A_eff)` = `sqrt(A_C * K / A)` ✓
- Variance estimator: `A * Σ_r (θ̂^(r) − θ̂)²` — unchanged by the Opsomer
  method (all work is in w_i^*(r)) ✓

No formula errors found.

---

#### Lens 6 — Literature Cross-Check

**Formula fidelity:** All formulas in the spec match comprehension.md ✓ (see
Issue 9 above).

**Gotcha coverage:**

| Gotcha from comprehension.md | Covered in spec? |
|------------------------------|-----------------|
| Fixed and random targets asymmetric (T_fixed invariant) | ✓ — Edge cases table; Algorithm Step 5 |
| A and A_C from `@variables$scale`, not `rscales` | ✓ — `surveywts_error_scale_not_found` |
| svrep not used in production; retained as oracle | ✓ — Scope section; quality gates |
| Randomise control replicate mapping | ⚠️ — default behaviour ambiguous (Issue 1) |
| R > R_C: a_r = 0 for excess replicates | ✓ — Step 3; edge cases |
| R_C > R: repeat primary, don't subsample control | ✓ — Step 2; K expansion |
| Non-rake methods unproven | ✓ — roxygen2 requirements, Algorithm subsection |
| Perturbed + fixed targets may be inconsistent → convergence failure | ✓ — Error table |
| Near-zero replicate weights expected, don't clip | ✓ — Quality gates |

One gotcha is partially covered with an ambiguity (Issue 1). All others are
well-addressed.

**Reference mapping completeness:** All design decisions in the spec trace to
specific equations in Opsomer & Erciulescu (2022) as listed in comprehension.md.
✓

**Assumption alignment:**

| Assumption from comprehension.md | In spec? |
|----------------------------------|---------|
| Both designs have non-NULL scalar `@variables$scale` | ✓ — `surveywts_error_scale_not_found` |
| `@variables$scale` satisfies V̂ = scale × Σ (θ̂^(r) - θ̂)² | Not stated (implicit surveycore convention — acceptable as package-level invariant) |
| Two surveys are independent | ✗ — Not documented (Issue 4) |
| `targets` format matches `calibrate_rake()` | ✓ — Targets format section |
| Convergence conditions hold | ✓ — Convergence error classes |

**Open question resolution:** No explicit open questions in comprehension.md;
the main open question (non-rake method validity) is addressed by the spec
with a documentation caveat. ✓

---

### Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 2 |
| REQUIRED | 4 |
| SUGGESTION | 3 |

**Total issues:** 9

**Issue index:**

| # | Title | Lens | Severity | Resolution |
|---|-------|------|----------|------------|
| 1 | `control_col_matches` default not specified | 1 | REQUIRED | UNAMBIGUOUS |
| 2 | Level alignment between primary and control designs | 1 | REQUIRED | UNAMBIGUOUS |
| 3 | Format B tibble + `type` interaction unspecified | 1 | REQUIRED | JUDGMENT CALL |
| 4 | Independence assumption not documented | 2 | REQUIRED | UNAMBIGUOUS |
| 5 | Starting weights for per-replicate calibration not stated | 3 | BLOCKING | UNAMBIGUOUS |
| 6 | Replicate total computation formula not stated | 3 | SUGGESTION | UNAMBIGUOUS |
| 7 | `survey_nonprob` inputs — method validity not documented | 4 | SUGGESTION | JUDGMENT CALL |
| 8 | `type = "prop"` population total for conversion not specified | 5 | BLOCKING | UNAMBIGUOUS |
| 9 | Formula affirmation (no issues) | 5 | — | — |

**Overall assessment:** The core statistical algorithm is correctly specified —
the Opsomer formulas are accurate, all gotchas from the paper are covered, and
the replicate architecture is sound. Two BLOCKING issues could produce
silently wrong variance estimates if unresolved: ambiguity about starting
weights for per-replicate calibration (an implementer could start from the
calibrated full-sample weights instead of the original replicate weights, and
all tests would still pass), and the missing population-total specification for
`type = "prop"` (proportions cannot be converted to calibration targets without
knowing N). The REQUIRED issues are methodologically important but would
surface as detectable errors rather than silent wrong answers.
