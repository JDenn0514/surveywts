## Methodology Review: utilities — Pass 1 (2026-05-15)

### Scope Assessment

The Utilities phase implements two statistical operations:

1. `trim_weights()` — clip-and-redistribute weight trimming with an IQR-based default
   cutpoint, iterative strict mode, and percentile-based bounds.
2. `stabilize_weights()` — rescale weights to sum to n (globally or within groups).
3. `.trim_weights_internal()` — the single-pass clip-and-redistribute primitive.

All five lenses apply. The spec contains explicit formulas, an iterative algorithm
(strict loop), and functions that directly modify survey weights with downstream
variance implications.

---

### New Issues

#### Lens 1 — Method Validity

**Issue 1: `surveywts_warning_no_weights_trimmed` placement not specified in behavior rules**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The warning table lists `surveywts_warning_no_weights_trimmed` (fires when "neither
bound clipped any main weights"), but the behavior rules (steps 1–10) do not specify
WHERE this check is placed in the algorithm flow. The while-loop in step 6c is entered
only when `any(weights < lower_abs | weights > upper_abs)`, so if no weights are outside
the bounds the loop is silently skipped — but the warning is never explicitly triggered.
The spec should add a step between 6a and 6c: "If `!any(outside_initial)`, emit
`surveywts_warning_no_weights_trimmed` and skip to step 9." Without this, an implementer
reading only the behavior rules will not know when to fire the warning.

Options:
- **[A]** Insert a substep 6b (renumbering the existing 6b→6c): "If
  `!any(outside_initial)`, emit `surveywts_warning_no_weights_trimmed` and proceed to
  step 9 (skip the trimming loop)." — Effort: low, Risk: low, Impact: makes the warning
  trigger unambiguous for implementers, Maintenance: none
- **[B] Do nothing** — Implementer infers the placement from the warning table; risk of
  inconsistent implementations or missing the warning entirely.

**Recommendation: A** — One-line fix that closes an explicit gap in the behavior rules.

---

#### Lens 2 — Variance Estimation Validity

**Issue 2: Variance estimation implications undocumented for both functions**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: JUDGMENT CALL

Both `trim_weights()` and `stabilize_weights()` modify the weights of `survey_taylor`
and `survey_nonprob` objects, directly changing downstream variance estimates. The spec
is silent on this. Specific consequences:

- `trim_weights(survey_taylor)`: The Taylor design structure (PSU, strata, FPC) is
  preserved but weights are modified. Taylor-linearized SEs computed after trimming use
  the trimmed weights, which no longer reflect the original inclusion probabilities.
  Trimming typically makes SEs smaller (trimming extreme weights reduces weight variance,
  reducing design effect) but introduces bias in point estimates. The spec's `@description`
  says "trimming reduces variance at the cost of introducing bias," but does not state that
  this tradeoff applies to downstream variance estimates as well as point estimates.

- `stabilize_weights(survey_taylor)`: Rescaling all weights by a constant n/W is NOT
  variance-neutral for total estimators. A Taylor estimator of a population total
  `T_hat = sum(w_i * y_i)` becomes `(n/W) * sum(w_i * y_i)` after stabilization, with
  corresponding change in the estimated variance. The spec does not document this.
  For ratio/mean estimators (both numerator and denominator use the same weights), the
  scale factor cancels and the estimate is unchanged, but this is not stated.

The Utilities spec does not claim to address variance estimation; the Diagnostics phase
owns that. But the spec should document what is and is not valid downstream so users are
not silently misled.

Options:
- **[A]** Add a short "Variance Implications" paragraph to sections III and IV:
  - For `trim_weights()`: "Trimming modifies the weights used by any downstream variance
    estimator. For `survey_taylor` objects, Taylor-linearized SEs after trimming will
    typically decrease (trimming reduces weight variance) but may be biased if the trimming
    cutpoint is correlated with the outcome. For `survey_replicate` objects, replicate
    weights are trimmed in parallel, so replicate-based variance estimates capture the
    effect of trimming."
  - For `stabilize_weights()`: "Stabilization rescales all weights by the constant factor
    n/W. This preserves all ratio estimators (means, proportions) exactly, but changes
    total estimators and their variances by the factor n/W. Users who intend to estimate
    population totals should not stabilize before analysis."
  Effort: low, Risk: low, Impact: prevents silent wrong variance estimates, Maintenance: none
- **[B]** Add only a warning in `@note` without specifying the direction of change.
  Effort: very low, Risk: low, Impact: partial — users are warned but not guided.
- **[C] Do nothing** — Users with `survey_taylor` objects who call `stabilize_weights()`
  before computing totals will get wrong answers with no signal. Users who trim and then
  compute SEs will not know whether the SEs are valid.

**Recommendation: A** — The mechanism is fully known; a short documentation note closes
the gap without requiring any new implementation logic.

---

#### Lens 3 — Algorithmic Correctness

**Issue 3: Weight sum not preserved when `surveywts_warning_trimming_failed` fires**
Severity: BLOCKING
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The output contract (§III, Output Contract) states unconditionally:

> "The total weight sum is preserved: `sum(result_weights) == sum(original_weights)`
> (up to floating-point rounding)."

The test plan also states for `strict = TRUE`: "weight sum preserved."

However, when `.trim_weights_internal()` fires `surveywts_warning_trimming_failed`
(the `!any(can_adjust)` branch), the redistribution step is skipped:

```r
if (!any(can_adjust)) {
  cli::cli_warn(...)   # redistribution skipped
} else {
  weights_new[can_adjust] <- weights_new[can_adjust] + sum(trimmings) / sum(can_adjust)
}
```

In this branch, `weights_new = pmax(lower_abs, pmin(weights, upper_abs))`. Because some
weights have been clipped, `sum(weights_new) < sum(weights)` (upper clipping) or
`sum(weights_new) > sum(weights)` (lower clipping) or a mixture. The sum is NOT preserved.

This violates the stated output contract. The test `abs(sum(result_weights) -
sum(original_weights)) < 1e-10` will fail whenever trimming_failed fires. The most common
scenario: with `strict = TRUE`, redistribution pushes a previously in-bounds unit above the
cutpoint; that unit gets clipped; if no unconstrained units remain, the warning fires and the
final sum differs from the original.

The fix must either (A) update the output contract to document the exception, or (B) change
the implementation to preserve the sum even in the failure case.

Options:
- **[A]** Amend the output contract: "The total weight sum is preserved unless
  `surveywts_warning_trimming_failed` fires, in which case the sum may differ from the
  original by the amount of unredistributed excess. The warning text should include the
  actual sum difference." Also update the test plan: "With `strict = TRUE`, weight sum
  preserved WHEN trimming succeeds; sum may differ when `trimming_failed` fires." —
  Effort: low, Risk: low, Impact: honest contract that matches the `survey` package
  behavior (`survey::trimWeights` has the same behavior), Maintenance: none
- **[B]** Change `.trim_weights_internal()`: when `!any(can_adjust)`, do not clip the
  remaining outside units at all — leave them at their current (redistributed) values and
  return. This guarantees sum preservation but means some weights remain outside
  `[lower_abs, upper_abs]` even after `strict = TRUE`. The strict guarantee would then
  only hold when trimming succeeds. Effort: low, Risk: medium (deviation from
  `survey::trimWeights` behavior), Maintenance: none
- **[C] Do nothing** — The test `abs(sum(result_weights) - sum(original_weights)) < 1e-10`
  will fail in CI when the edge case is hit.

**Recommendation: A** — Option A matches `survey::trimWeights` behavior, is honest about
the edge case, and requires only documentation changes. Option B would diverge from the
reference implementation for no methodological benefit, since the warning already signals
the pathological state.

---

**Issue 4: Strict loop termination guarantee not stated**
Severity: SUGGESTION
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The `strict = TRUE` while-loop's termination is not guaranteed anywhere in the spec.
In practice the loop terminates because `sum(has_trimmed)` is non-decreasing and bounded
by n: each iteration marks at least one new unit `has_trimmed = TRUE` (the units currently
outside), and once all weights are at or within the bounds (which `pmax/pmin` ensures) the
while condition becomes false. But this invariant is implicit.

A brief comment in the behavior rules ("The loop terminates in at most n iterations because
`has_trimmed` marks are never cleared and at least one new unit is marked per iteration")
would give implementers confidence that no guard against infinite loops is needed.

Options:
- **[A]** Add a parenthetical to step 6c: "…[the loop is guaranteed to terminate in ≤ n
  iterations since `has_trimmed` marks are monotonically set and `pmax/pmin` clips
  weights to the bound on each pass]." — Effort: very low, Risk: none, Maintenance: none
- **[B] Do nothing** — Sophisticated implementers will see the termination proof; the loop
  is in fact safe.

**Recommendation: A** — Adds zero implementation cost; prevents an unnecessary defensive
`max_iter` limit from being added during implementation.

---

#### Lens 4 — Statistical Assumptions

**Issue 5: stabilize_weights() changes total estimates — consequence unstated**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

(This issue is closely related to Issue 2 but distinct: Issue 2 covers variance
implications; this issue covers the point-estimate consequence of stabilization on total
estimators, which is a statistical assumption gap independent of variance.)

`stabilize_weights()` multiplies all weights by `n / W`. For mean and proportion
estimators of the form `(Σ w_i y_i) / (Σ w_i)`, the n/W factor cancels and estimates
are unchanged. But for total estimators of the form `Σ w_i y_i`, the estimate changes
by the factor `n / W`.

The spec's stated purpose is "making effective sample size calculations interpretable."
This purpose is consistent with the function being a pre-diagnostic utility, NOT a
pre-analysis transformation. However, users working with `survey_taylor` or
`survey_nonprob` objects may pipe results into population total estimators without
realizing the total has been rescaled.

The spec should state explicitly: "stabilize_weights() rescales all weights by a constant
and is appropriate for diagnostics and effective-sample-size calculations. It changes
population total estimates by the factor `n / W`. Ratio estimators (means, proportions)
are unaffected."

Options:
- **[A]** Add the above sentence to the `@description` of `stabilize_weights()` and to
  §IV Purpose. No code change needed. — Effort: very low, Risk: none, Impact: prevents
  silently wrong total estimates, Maintenance: none
- **[B] Do nothing** — The consequence is derivable by any user who reads the formula
  `w_new = w * (n / W)`.

**Recommendation: A** — The formula is simple but the consequence for total estimators
is non-obvious to casual users. One sentence closes the gap.

---

#### Lens 5 — Formula Integrity

**Issue 6: history scale_factor naming convention for within-group stabilization unspecified**
Severity: REQUIRED
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The output contract for `stabilize_weights()` (§IV) specifies:

```
scale_factor = <named numeric vector of per-group scale factors (when by is set)>
```

The spec says "named numeric vector" but does not specify the names. When `by = age_group`
and the groups are `"18-34"`, `"35-54"`, `"55+"`, the scale factor vector must have
predictable names for users to inspect and for tests to assert against. Without a stated
naming convention, implementers may use group indices, group values, or a concatenation
of multi-variable group identifiers, producing different results.

The fix: specify that names are derived from `paste(group_values, collapse = " | ")` for
multi-variable groups, or just the group value string for single-variable `by`. For
example, `by = age_group` → `names = c("18-34", "35-54", "55+")`;
`by = c(age_group, sex)` → `names = c("18-34 | F", "18-34 | M", ...)`.

Options:
- **[A]** Specify the naming convention in §IV Output Contract: "For single-variable `by`,
  names are the character representation of the group values. For multi-variable `by`,
  names are the group values pasted with ` | ` as separator." — Effort: very low,
  Risk: none, Maintenance: none
- **[B]** Leave names unspecified and add a note that names are implementation-defined.
  Tests then use `unname()` to check only the values. Effort: very low, Risk: low,
  Impact: weaker API contract.
- **[C] Do nothing** — Implementer chooses a naming convention; tests fail if a different
  one is expected.

**Recommendation: A** — Stating the naming convention up-front prevents
discrepancies between implementation and test expectations.

---

**Issue 7: IQR() type argument not specified in the default cutpoint formula**
Severity: SUGGESTION
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

§III Behavior Rules step 5 specifies `type = 7` for `quantile()` in the percentile
branch, but the IQR-based default formula:

```
upper_abs = median(weights) + k * IQR(weights)
```

does not specify the quantile type for `IQR()`. In R, `IQR()` calls `quantile()` with
`type = 7` by default, which matches the spec's percentile branch. But this should be
made explicit to prevent an implementer from passing a different type.

Options:
- **[A]** Update step 5 bullet to: `upper_abs = median(weights) + k * IQR(weights,
  type = 7)` — Effort: none, Risk: none, Maintenance: none
- **[B] Do nothing** — R's default already uses type = 7; the risk of inconsistency
  is very low.

**Recommendation: A** — Three-word fix that removes any ambiguity.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 7

**Overall assessment:** The clip-and-redistribute algorithm is correctly derived from
`survey::trimWeights` and the formulas are mostly sound, but one BLOCKING contract
inconsistency must be resolved: the output states unconditional weight sum preservation
while the `trimming_failed` code path silently violates it. Four REQUIRED gaps — primarily
around variance documentation, a missing warning placement in the behavior rules, and an
unspecified naming convention — are straightforward to close with documentation changes and
will not require implementation rework.

---

## Methodology Review: utilities — Pass 2 (2026-05-18)

### Prior Issues (Pass 1)

| # | Title | Lens | Severity | Status |
|---|---|---|---|---|
| 1 | `surveywts_warning_no_weights_trimmed` placement not specified in behavior rules | 1 | REQUIRED | ✅ Resolved (2026-05-18) |
| 2 | Variance estimation implications undocumented for both functions | 2 | REQUIRED | ✅ Resolved (2026-05-18) — two sentences per function added to Purpose |
| 3 | Weight sum not preserved when `surveywts_warning_trimming_failed` fires | 3 | BLOCKING | ✅ Resolved (2026-05-18) — contract amended to document exception |
| 4 | Strict loop termination guarantee not stated | 3 | SUGGESTION | ✅ Resolved (2026-05-18) |
| 5 | `stabilize_weights()` changes total estimates — consequence unstated | 4 | REQUIRED | ✅ Resolved (2026-05-18) |
| 6 | history `scale_factor` naming convention for within-group stabilization unspecified | 5 | REQUIRED | ✅ Resolved (2026-05-18) |
| 7 | `IQR()` type argument not specified in the default cutpoint formula | 5 | SUGGESTION | ✅ Resolved (2026-05-18) |

All 7 Pass 1 issues remain unresolved. The spec has not been updated since Pass 1.

---

### New Issues

#### Lens 1 — Method Validity

No new issues beyond those already filed in Pass 1.

---

#### Lens 2 — Variance Estimation Validity

No new issues beyond Issue 2 (Pass 1).

---

#### Lens 3 — Algorithmic Correctness

**Issue 8: Replicate column weight sum not preserved when all column units are outside bounds**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS
**Status: ✅ Resolved (2026-05-18) — Option A: contract amended to document the exception; no warning added**

Step 7.d specifies the replicate redistribution formula:

```
rwnew[!outside_j, j] <- rwnew[!outside_j, j] + sum(trimmings[, j]) / sum(!outside_j)
```

Step 7's closing sentence states: "This preserves the total weight sum within each
replicate column." This claim is unconditional, but it fails when all units in a column
are outside bounds.

When `all(outside_j)` for column j:
- `sum(!outside_j) = 0`
- `sum(trimmings[, j]) / 0` evaluates to `Inf` / `-Inf` / `NaN` in R
- `rwnew[FALSE, j]` is `numeric(0)` — indexing with all-FALSE mask returns empty vector
- `numeric(0) + Inf = numeric(0)` — the addition is a no-op
- Assignment `rwnew[FALSE, j] <- numeric(0)` is a no-op
- Result: column j of `rwnew` holds clipped values only; the trimmed excess is NOT
  redistributed, so `colSums(rwnew)[j] ≠ colSums(rep_weights)[j]`

No warning fires for replicate columns — unlike the main weight case, which has
`surveywts_warning_trimming_failed` in `.trim_weights_internal()`.

This is the replicate analogue of Issue 3 (Pass 1). The fix follows the same pattern:
amend the contract to document the exception.

Note: this also means the test plan item "For `survey_replicate`:
`abs(colSums(result_rep_weights) - colSums(original_rep_weights)) < 1e-10` for each
replicate column" will fail if any replicate column is entirely outside bounds. The test
plan must be amended in parallel with the contract.

Options:
- **[A]** Amend step 7 closing sentence: "This preserves the total weight sum within
  each replicate column, unless all units in that column are outside `[lower_abs,
  upper_abs]`, in which case no redistribution is possible and the column sum changes
  by the amount of unredistributed excess (mirroring the `surveywts_warning_trimming_failed`
  behavior for main weights, but without a warning)." Also amend the test plan to restrict
  the sum-preservation assertion to columns where redistribution succeeds. —
  Effort: low, Risk: low, Impact: honest contract, Maintenance: none
- **[B]** Add a per-column warning (`surveywts_warning_trimming_failed` or a new
  `surveywts_warning_replicate_trimming_failed`) when `sum(!outside_j) == 0`. No
  implementation change — just a warning call before the redistribution step. —
  Effort: low, Risk: low, Impact: parity with main weight warning behavior, Maintenance: none
- **[C] Do nothing** — The contract claim "preserves the total weight sum within each
  replicate column" is silently false for this edge case; a test will fail if the case
  is exercised.

**Recommendation: A** — Documents the exception without adding a new warning class.
Option B (adding a warning) is also valid if parity with main weight behavior is
preferred, but the replicate edge case is even rarer and may not warrant a new class.
Decide during Stage 2 Resolve.

---

#### Lens 4 — Statistical Assumptions

No new issues beyond Issue 5 (Pass 1).

---

#### Lens 5 — Formula Integrity

**Issue 9: `surveywts_warning_trimming_failed` reachability description is incorrect**
Severity: SUGGESTION
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS
**Status: ✅ Resolved (2026-05-18) — Warning Table description corrected**

The Warning Table (§III) states:

> `surveywts_warning_trimming_failed` — "Only reachable when `strict = TRUE`."

This is technically incorrect. The warning fires inside `.trim_weights_internal()` when
`!any(can_adjust)`, i.e., when `all(outside | has_trimmed)`. On the **first** call to
`.trim_weights_internal()` (first loop iteration), `has_trimmed` is all-FALSE, so
`can_adjust = !outside`. If ALL units are initially outside the bounds, `can_adjust` is
all-FALSE and the warning fires — regardless of whether `strict` is `TRUE` or `FALSE`.

With `strict = FALSE`, the loop breaks after this iteration, so the warning fires on
the single pass. With `strict = TRUE`, the loop would continue, but after clipping all
weights to bounds, the while condition `any(weights < lower_abs | weights > upper_abs)`
becomes FALSE and the loop exits normally.

Practical impact: the "only reachable with `strict = TRUE`" claim is widely true in
practice (degenerate all-outside scenario is pathological), but the spec description is
incorrect and could mislead implementers into adding a `strict` guard around the warning.

Options:
- **[A]** Change the Warning Table description to: "Fires when all remaining units have
  already been trimmed and no untrimmed units are available to absorb the redistributed
  excess. Most commonly triggered during `strict = TRUE` multi-pass trimming, but can
  also fire on the first pass if all weights are initially outside `[lower_abs,
  upper_abs]`." — Effort: none, Risk: none, Maintenance: none
- **[B] Do nothing** — The current description is nearly correct; the pathological
  all-outside scenario is unlikely in practice.

**Recommendation: A** — The description is wrong; the fix is one sentence.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 new (1 carried from Pass 1) |
| REQUIRED | 1 new |
| SUGGESTION | 1 new |

**New issues this pass:** 2 (Issues 8–9)
**Cumulative open issues:** 0 — all 9 issues resolved 2026-05-18 (see `plans/decisions-utilities.md`)

**Overall assessment:** No new BLOCKING issues discovered. The algorithm and formulas
are sound. The two new issues are an exact parallel of Pass 1's Issue 3 (the replicate
column sum-preservation contract has the same unconditional claim as the main weight
contract, and is similarly false in the redistribution-failure edge case) and a minor
description error in the Warning Table. All 9 issues are resolvable with documentation
changes only — no implementation logic changes are required.
