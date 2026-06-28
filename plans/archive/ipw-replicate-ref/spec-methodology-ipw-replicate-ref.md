# Methodology Review: ipw-replicate-ref — Pass 1 (2026-06-24)

## Scope Assessment

This feature widens the `reference` argument of `ipw()` from `survey_taylor`-only
to `survey_taylor | survey_replicate`. The propensity model (MLE and GEE paths)
is unchanged. The change touches the type-check guard, error class name, and
documentation.

- Implements/extends a statistical or mathematical method? **No** — method is unchanged.
- Produces numerical quantities with known statistical properties? **Yes** (IPW weights),
  but no formula change — the numerical behavior for survey_taylor inputs is identical
  to the pre-PR state.
- Involves iterative algorithms? **No new algorithms.**

Lenses 1–4 are applied selectively (only questions that could surface problems despite
no algorithm change). Lens 5 skipped (no formula changes). Lens 6 applied (papers
and comprehension.md present).

---

### Lens 1 — Method Validity

The new contract accepts `survey_replicate` as `reference`. The key claim is that
`survey_replicate` exposes `@variables$weights` and `@data` identically to `survey_taylor`,
so weight extraction is unchanged. Verified against the repo (`utils.R` line 221–222):
`data_df[[x@variables$weights]]` works the same for both types.

Edge cases are all specified:
- `data.frame` reference → `surveywts_error_reference_not_survey_design` ✓
- `survey_nonprob` reference → same error ✓
- `NULL` reference → same error ✓
- `survey_replicate` with BRR zeros in replicate columns → accepted; only main weight checked ✓
- `survey_replicate` with non-positive main weight → `surveywts_error_reference_weights_nonpositive` ✓

**Issue 1: `data.R` docstring contains outdated restriction**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

`R/data.R` line 524 reads:
> `mse = TRUE`. Cannot be passed directly to `ipw()` (which requires

After this PR, that statement is false. A user reading the `acs_wy_2022_svy` help
page would be misinformed about what `ipw()` accepts. The write surface in the spec
lists `R/data.R` as out of scope, but wrong inline documentation is always a bug.

Fix: Add `R/data.R` to the write surface. The builder removes the `"Cannot be
passed directly to ipw() (which requires survey_taylor)"` clause from the
`acs_wy_2022_svy` entry.

Options:
- **[A]** Add `R/data.R` to write surface; remove outdated restriction clause — Effort: low, Risk: low
- **[B]** Leave `data.R` for a follow-up PR — Effort: zero now, Risk: medium (user-visible wrong docs land)
- **[C]** Do nothing — Outdated docs remain.

**Recommendation: A** — Wrong documentation is always worse than an extra file in scope.

No other Lens 1 issues.

---

### Lens 2 — Variance Estimation Validity

The spec adds documentation only (no code change). The key claim is that V_p
(reference-design variance) can be estimated from a `survey_replicate` reference's
replicate columns per Wu (2022) §6.2, while V_q (propensity model variance) still
requires propensity model refitting per replicate.

The spec's @details documentation change makes this distinction explicit:
> "This is distinct from — and complementary to — the propensity model refitting
> requirement: the two variance components (V_q from propensity model uncertainty,
> V_p from reference design uncertainty) are both needed for a complete variance
> estimate, and they are estimated by separate procedures."

No issues found. The distinction is correctly specified.

---

### Lens 3 — Algorithmic Correctness

Not applicable: no algorithm change. Both MLE (Newton-Raphson) and GEE
(nleqslv) paths are unchanged. The type-widening at Behavior Rule 2 has no
effect on subsequent computation steps.

---

### Lens 4 — Statistical Assumptions

All existing assumptions (MAR, positivity, independence of NPS and reference,
small-sampling-fraction) are unchanged. The comprehension.md correctly notes
that these apply identically regardless of reference design type. The spec
documents this correctly.

No issues.

---

### Lens 5 — Formula Integrity

Not applicable: no formula changes.

---

### Lens 6 — Literature Cross-Check

**Formula fidelity:**
Comprehension.md §Formulas shows that only `d_i^B` (= `reference@data[[reference@variables$weights]]`)
from the reference enters the MLE score equation and GEE calibration equation. The spec
correctly reflects this (Behavior Rule 3 unchanged). ✓

**Gotcha coverage:**
| Gotcha (comprehension.md) | Spec coverage |
|---|---|
| Variance refit still required even with survey_replicate reference | @details documentation addition explicitly stated ✓ |
| BRR zeros in replicate columns are irrelevant | Edge case EC-1 in test-spec ✓ |
| Error class rename | Behavior Rule 2 revised; error-messages.md update specified ✓ |
| Small-sampling-fraction assumption unchanged | Spec §Out states assumptions unchanged ✓ |
| reference_design history field preserves replicate object | Quality gate 3 + H-R4 test scenario ✓ |

**Reference mapping completeness:**
- Wu (2022) §6.2, V_p → @details new paragraph ✓, @references entry added ✓
- Wu (2022) §6 preamble → @param reference note about preferred path ✓
- Chen, Li & Wu (2020) §3 → existing Behavior Rule 3 (unchanged) ✓
- Valliant (2020) §2.1.1 → Behavior Rule 3 (unchanged) ✓
- Elliott & Valliant (2017) §3.1 → existing @details variance section (unchanged) ✓

All mappings traceable to specific section/equation. ✓

**Assumption alignment:**
All 4 assumptions in comprehension.md §Assumptions are either reflected in spec or
explicitly documented as unchanged. ✓

No issues on Lens 6.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 0 |

**Total issues:** 1

**Overall assessment:** The spec is statistically sound. The one finding is
non-algorithmic (an outdated restriction in a dataset docstring), which is
REQUIRED-UNAMBIGUOUS and has a one-line fix.
