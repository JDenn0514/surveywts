## Spec Review: ipw-extensions — Pass 1 (2026-05-26)

---

### New Issues

#### Section: III.C — GEE NR loop / IV.B @param estimating_eq

**Issue 1: GEE balance test will fail because nps_fraction > 0.05 triggers reference weight adjustment, but test-spec assertion uses unadjusted reference totals**
Severity: BLOCKING
Violates: internal consistency between §III.C, §IV.D Rule 9a-ii, and test-spec H-6 test block 2

The GEE calibration score is `colSums(X_nps_fit / π_nps) − X_ref^T d_ref`, where `d_ref` is `ref_weights_for_fit` as passed to the engine. When `adjust_reference = TRUE` (the default) and `nps_fraction > 0.05`, Rule 9a-ii multiplies `ref_weights_for_fit` by `adjust_factor = 1 − nps_fraction` before the engine call. At GEE convergence the balance guarantee therefore holds against the *adjusted* reference totals:

```
sum(w_k × x_k) = adjust_factor × sum(d_k × x_k)
```

not against the original design weights.

Test-spec H-6 test block 2 constructs `nps_df` (n = 500) against `ref_design` with `design_weight = 1.0` for n = 2000 rows, giving `nps_fraction = 500/2000 = 0.25 > 0.05`. With the default `adjust_reference = TRUE`, `adjust_factor = 0.75`. The GEE optimiser converges so that `sum(w × x) = 0.75 × sum(d_ref × x)`. But the test asserts:

```r
expect_equal(sum(w * x_nps_age_34), sum(d_ref * x_ref_age_34), tolerance = 1e-6)
```

using `d_ref = ref_design@data[[ref_design@variables$weights]]` (original weights). This assertion will fail by a factor of 0.75 every time.

The same flaw affects the sex-indicator assertion in the same block.

Options:
- **[A]** Add `adjust_reference = FALSE` to the GEE balance test call and add a comment explaining why — isolates the GEE balance property from reference adjustment. Also add a separate, new test block for GEE + `adjust_reference = TRUE` that asserts balance against adjusted totals. Effort: low, Risk: low, Impact: fixes test failure + adds meaningful coverage, Maintenance: none.
- **[B]** Change the test-spec setup so `nps_fraction ≤ 0.05` (e.g., nps_df n = 50, ref n = 2000 → fraction = 0.025). Simpler fix but sacrifices coverage of the GEE × adjust_reference interaction. Effort: low, Risk: low.
- **[C] Do nothing** — test-spec block 2 will fail as written; builder will be surprised at CI.

**Recommendation: A** — suppressing the interaction in the balance test makes the GEE property testable cleanly, and the new explicit test for GEE × adjust_reference interaction addresses coverage.

---

**Issue 2: Spec does not document GEE balance guarantee semantics under `adjust_reference = TRUE` with `nps_fraction > 0.05`**
Severity: REQUIRED
Violates: contract completeness (Lens 3); creates silent ambiguity for builder and user

The `@param estimating_eq` documentation states:

> At convergence, the weighted NPS covariate totals exactly reproduce the reference-weighted totals: `sum(w_k * x_k) = sum(d_k * x_k)`.

Here `d_k` is ambiguous — it could mean original design weights or Valliant-adjusted weights. When `nps_fraction > 0.05` and `adjust_reference = TRUE`, the engine receives adjusted weights and the GEE calibration target becomes `adjust_factor × sum(d_k × x_k)`. The builder implementing the GEE path will get the math right automatically (since the engine receives adjusted weights), but the documentation is misleading to users who read the parameter description and compute the balance check manually.

The quality gate's GEE balance check (`sum(w * x) ≈ sum(d * x)` at tolerance 1e-6) in the spec is also stated against unadjusted `d`, which would fail when `nps_fraction > 0.05`. The quality gate must clarify which `d` it refers to.

Options:
- **[A]** Add one qualifying sentence to `@param estimating_eq`: "When `adjust_reference = TRUE` and `nps_fraction > 0.05`, the calibration target is the Valliant-adjusted reference totals `sum(adjust_factor × d_k × x_k)`, not the original design-weight totals." Also update the quality gate to read "at convergence, `sum(w * x) ≈ sum(d_adjusted * x)` where `d_adjusted = ref_weights_for_fit` after Rule 9a-ii." Effort: low, Risk: low, Maintenance: none.
- **[B]** Restrict the guarantee statement to the `adjust_reference = FALSE` case only. Effort: low, Risk: low.
- **[C] Do nothing** — the ambiguity in `d_k` will cause user confusion and a failing quality gate.

**Recommendation: A** — precise language eliminates the ambiguity without requiring a behavioral change.

---

#### Section: IV.H — Documentation changes

**Issue 3: `@seealso` specification is absent from §IV.H despite being required by H-4**
Severity: REQUIRED
Violates: contract completeness (Lens 3); builder has no specification to implement

The scope table (§I) lists H-4 as:

> H-4 | Doc | Add doubly robust recommendation to `@details`; **add `@seealso`**

The `@details` additions for H-4 (doubly robust section) are specified in §IV.H. But §IV.H contains no `@seealso` subsection. The builder knows a `@seealso` is required but has no specification of which functions or entries to reference. The quality gate checks for H-4 documentation but does not explicitly verify `@seealso` content.

Options:
- **[A]** Add a `@seealso` subsection to §IV.H specifying the cross-reference targets — at minimum `adjust_nonresponse()` (nonresponse calibration alternative), the planned `diagnose_propensity()`, and a note that `calibrate_to_survey()` is the doubly robust complement. If the doubly robust function is not yet named, note the planned function family. Effort: low, Risk: low, Maintenance: none.
- **[B]** Remove the `@seealso` deliverable from H-4 scope — if the doubly robust function does not exist yet, there may be nothing useful to link. Effort: low.
- **[C] Do nothing** — the builder implements `@seealso` with no guidance; result is non-deterministic.

**Recommendation: A** — even linking to the existing `adjust_nonresponse()` and noting the planned `diagnose_propensity()` is better than leaving it unspecified.

---

**Issue 4: Missing `@references` additions specification**
Severity: REQUIRED
Violates: contract completeness (Lens 3); `R CMD check` will not fail but documentation will be inconsistent

The `@details` additions in §IV.H introduce multiple new in-text citations:
- Valliant & Dever (2011)
- Chen, Li & Wu (2021) — two separate mentions
- Yang et al. (2020)
- Elliott & Valliant (2017) — appears in multiple bullets
- Valliant (2020) — appears throughout
- Beresewicz et al. (2025)

Some of these citations may already appear in the existing `@references` block; others may not. The spec does not have a `@references` additions subsection in §IV.H. A builder running `devtools::document()` will produce a rendered help page with in-text citations that lack `@references` entries, making the manual page incomplete.

Options:
- **[A]** Add a `@references` additions subsection to §IV.H listing the full bibliographic entry for each new citation not already in the existing `@references`. Flag which are net-new vs. already present. Effort: medium (requires checking existing references), Risk: low, Maintenance: none.
- **[B]** Add a note in §IV.H that the builder must add BibTeX-style `@references` entries for all new in-text citations, and provide the author/year list for verification. Effort: low.
- **[C] Do nothing** — builder infers from the inline citations; may produce incomplete or wrong references.

**Recommendation: A** — the spec should be independently sufficient.

---

#### Section: III.C — GEE NR loop convergence

**Issue 5: Spec does not connect GEE non-convergence to the existing `surveywts_error_propensity_scores_degenerate` error class**
Severity: REQUIRED
Violates: contract completeness (Lens 3); test-spec is not independently sufficient for the tester

The GEE inner guard (§III.C) states:

```
if any(π_nps ≤ eps):
  return list(scores = link(X_nps_pred %*% gamma), converged = FALSE, final_delta = max(|delta|))
```

When the engine returns `converged = FALSE`, `ipw()` must throw an error. The test-spec (H-6 test block 5) asserts:

```r
expect_error(
  ipw(nps_extreme, ref_extreme, selection = ~age_group + sex, estimating_eq = "gee"),
  class = "surveywts_error_propensity_scores_degenerate"
)
```

This error class is never mentioned or cross-referenced anywhere in `spec-ipw-extensions.md`. The spec says "all existing behavior rules are unchanged" — which implies the existing convergence-failure handler (which throws this class) already exists — but a builder or tester working from the extension spec alone cannot confirm this without inspecting the pre-existing code.

The spec should explicitly state that when `.fit_participation_propensity()` returns `converged = FALSE` via the GEE inner guard, `ipw()` follows the same existing convergence-failure path that throws `surveywts_error_propensity_scores_degenerate`. This makes the behavior explicit and makes the test-spec independently sufficient.

Options:
- **[A]** Add one sentence to §III.C (or §IV.D Rule 14): "When `.fit_participation_propensity()` returns `converged = FALSE` for either the MLE outer saturation guard or the GEE inner saturation guard, `ipw()` throws `surveywts_error_propensity_scores_degenerate` — the same existing convergence-failure path used in the current implementation." Effort: low, Risk: low.
- **[B] Do nothing** — builder infers from "existing behavior unchanged"; tester cannot verify without checking existing code.

**Recommendation: A** — one sentence; makes both documents independently sufficient.

---

#### Section: test-spec-ipw-extensions.md — M-1

**Issue 6: M-1 test block 5 ("both warning types can fire simultaneously") references undefined variables**
Severity: REQUIRED
Violates: test-spec must be independently runnable

Test block 5 of M-1 reads:

```r
expect_warning(
  ipw(both_issue_nps, both_issue_ref, selection = ~age_group + score),
  class = "surveywts_warning_ipw_covariate_range_extrapolation"
)
expect_warning(
  ipw(both_issue_nps, both_issue_ref, selection = ~age_group + score),
  class = "surveywts_warning_ipw_reference_levels_absent_from_nps"
)
```

Neither `both_issue_nps` nor `both_issue_ref` is defined anywhere in the test-spec. No setup code block precedes or follows the test. The tester cannot run this block without inventing their own fixture, which defeats the purpose of the test-spec.

Options:
- **[A]** Add an inline setup block that constructs `both_issue_nps` (NPS with numeric `score` outside reference range AND missing one factor level) and `both_issue_ref` (reference with narrower `score` range AND an extra factor level absent from NPS). Mirror the construction patterns used in test blocks 1 and 3. Effort: low, Risk: low, Maintenance: none.
- **[B]** Delete test block 5 and rely on blocks 1 and 3 separately (no simultaneous-firing test). Effort: trivial, Risk: reduced coverage.
- **[C] Do nothing** — test block is unrunnable; tester will have to invent the fixture.

**Recommendation: A** — this is a concrete, valuable test (verifies both warnings can coexist); it just needs the fixture.

---

#### Section: test-spec-ipw-extensions.md — warning snapshot pattern

**Issue 7: `withCallingHandlers()` used in warning snapshot tests violates `testing-standards.md`**
Severity: REQUIRED
Violates: `testing-standards.md`: "Do not use `withCallingHandlers()` or `tryCatch()` in tests."

Four warning snapshot tests in the test-spec use:

```r
expect_snapshot(error = FALSE, withCallingHandlers(ipw(...), warning = identity))
```

This pattern appears in C-3 test blocks 1 and 2, and M-1 test blocks 1 and 3. `testing-standards.md` explicitly prohibits `withCallingHandlers()` in tests.

The correct pattern in testthat 3 for snapshotting warning message text is:

```r
expect_snapshot(
  expect_warning(ipw(...), class = "surveywts_warning_...")
)
```

`expect_snapshot()` captures all signaled conditions (including warnings) in the snapshot output; `expect_warning()` handles the warning and records the class assertion. This pattern is consistent with the warning capture pattern already specified in `testing-standards.md`.

Options:
- **[A]** Replace all four `withCallingHandlers` snapshot calls with `expect_snapshot(expect_warning(ipw(...), class = "..."))`. Effort: low, Risk: low, Maintenance: none.
- **[B]** Add a project-specific exception to `testing-standards.md` permitting this pattern for warning snapshots. Effort: low, but weakens the standard.
- **[C] Do nothing** — test-spec violates a firm rule; implementation tests will either be written incorrectly or require builder to deviate from test-spec.

**Recommendation: A** — mechanical replacement; no behavioral change.

---

#### Section: test-spec-ipw-extensions.md — `test_invariants()` completeness

**Issue 8: `test_invariants()` is absent from most test block descriptions despite being required for every survey_nonprob-producing call**
Severity: REQUIRED
Violates: `testing-surveywts.md`: "Every `test_that()` block that creates a `weighted_df` or `survey_nonprob` object must call `test_invariants(obj)` as its first assertion."

The invariants section of the test-spec states the rule. But the individual test blocks for C-3 (blocks 1–3), M-1 (blocks 1–3), M-4, M-6 (blocks 1–4), and L-4 (blocks 1–3) do not include `test_invariants()`. Only H-6 test block 1 explicitly calls it.

Because the test-spec is meant to be independently sufficient for the tester, every block that constructs a `survey_nonprob` result must include the `test_invariants(result)` call as the first assertion line, not just rely on the invariants section preamble.

Options:
- **[A]** Add `test_invariants(result)` as the first assertion in every test block that assigns a `survey_nonprob` result (C-3 blocks 1–3, M-4, M-6 blocks 1–4, L-4 blocks 1–3; blocks that only test error cases do not need it). Effort: low, Risk: low, Maintenance: none.
- **[B]** Add a box at the top of each test-spec section: "All result-constructing calls in this section call `test_invariants()` first — not repeated per block." Effort: very low, less explicit.
- **[C] Do nothing** — tester may omit `test_invariants()` in many blocks; coverage of structural invariants is incomplete.

**Recommendation: A** — explicit is better than relying on a preamble note.

---

#### Section: I. Scope (DRY)

**Issue 9: History entry schema duplicated between §IV.D (Rule 20) and §V**
Severity: SUGGESTION
Violates: `engineering-preferences.md §1` — DRY; risk of drift

Section §IV.D Rule 20 contains the full R code for the history entry (field names, values). Section §V contains a markdown table of all the same fields with types and descriptions. These two representations must stay in sync. Currently they are consistent, but any future amendment to the history schema (adding a field, renaming a type) would require two edits. In a multi-reviewer setting, one will be missed.

Options:
- **[A]** Designate §V as the canonical schema table, and in §IV.D Rule 20 add a comment: "see §V for field types and descriptions." Remove the §V table rows that duplicate what is already derivable from the code snippet (i.e., keep §V but link §IV.D to it). Effort: low.
- **[B]** Keep both as-is; add a note: "§IV.D and §V must be kept in sync." Effort: trivial.
- **[C] Do nothing** — they are currently consistent; risk of drift is low during single-PR implementation.

**Recommendation: B** — for a spec that will be read as a document, the redundancy aids comprehension. A sync note is sufficient.

---

#### Section: IV.C — Validation rules

**Issue 10: No validation or warning when `population_size < nrow(data)`**
Severity: SUGGESTION
Violates: `engineering-preferences.md §4` — handle more edge cases

The `population_size` validation (Rule 0f) checks for `> 0` and finite. But a population size smaller than the NPS row count is impossible (`N < n`) and indicates a user error — the user has confused `population_size` (N) with something else. The history entry would record `estimated_population_size < n_nps`, which is mathematically nonsensical and would produce negative design effects if used downstream.

The spec does not address this case. Since `population_size` "affects only the history entry, not the returned weights," a user would not discover the mistake until they try to use the recorded value.

Options:
- **[A]** Add a warning (`surveywts_warning_ipw_population_size_less_than_nps`) when `population_size < nrow(data)` (after NPS NA handling, so `nrow(data)` reflects the effective NPS size). Add the warning class to `plans/error-messages.md`. Effort: low.
- **[B]** Add a note in `@param population_size`: "If `population_size < nrow(data)` the recorded value will be smaller than the sample size — verify the value is the population count N, not a subsample size." No code change. Effort: trivial.
- **[C] Do nothing** — low-frequency mistake; user is expected to know what they're supplying.

**Recommendation: B** — documentation-only; the behavioral contract is clear enough, and a warning class for this edge case would add complexity disproportionate to the risk.

---

#### Section: IV.H — Examples

**Issue 11: No `@examples` updates specified for new arguments**
Severity: SUGGESTION

The spec adds three new arguments (`estimating_eq`, `adjust_reference`, `population_size`). The quality gate requires all `@examples` to run without error. But the existing `@examples` do not use any new arguments, so the gate passes trivially. A user reading `?ipw` has no runnable example demonstrating GEE, reference adjustment behavior, or known population size.

Options:
- **[A]** Add `@examples` additions to §IV.H: one block calling `ipw()` with `estimating_eq = "gee"` and a comment noting the balance property; one block with `population_size` showing the manual IPW1 formula. Use the bundled `ns_wave1_ipw` / `gss_ipw_ref` datasets to keep examples consistent with existing patterns. Effort: low.
- **[B] Do nothing** — existing examples remain valid; new arguments are self-documenting from `@param` text.

**Recommendation: A** — examples for the two most user-visible changes (GEE and population_size) are worth adding, consistent with the project's existing `@examples` depth for `ipw()`.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 7 |
| SUGGESTION | 3 |

**Total issues:** 11

**Overall assessment:** The spec is well-structured and methodologically thorough. One blocking issue stands out: the GEE balance test in test-spec H-6 block 2 will fail every time because the test fixture has `nps_fraction = 0.25`, which (with the default `adjust_reference = TRUE`) scales the reference weights before the GEE optimizer runs, causing convergence to adjusted rather than original reference totals. The seven REQUIRED issues are all resolvable with small, targeted edits — missing `@seealso`, missing `@references`, a prohibited `withCallingHandlers` pattern, a missing `test_invariants()` in most blocks, undefined variables in one test block, and a documentation gap connecting GEE convergence failure to the existing error class. The three suggestions improve completeness but do not block implementation.
