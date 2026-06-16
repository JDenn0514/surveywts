## Spec Review: nonprob-repweights — Pass 1 (2026-06-15)

---

## Pass 2 Resolution (2026-06-15)

| # | Title | Status |
|---|---|---|
| 1 | Builder not told to update existing `@description` text | ✅ Resolved — `@description update` subsections added to both function contracts |
| 2 | Weighting history not tested for nonprob-with-repweights path | ✅ Resolved — `Weighting history` test tables added to both trim and stabilize sections in test-spec |
| 3 | "Main weights within bounds but replicate values outside" edge case untested | ✅ Resolved — edge case row added to trim_weights test-spec |
| 4 | nonprob-without-repweights fixture uses wrong `@variables` keys | ✅ Resolved — replaced with `as_survey_nonprob()` constructor |
| 5 | `character(0)` repweights edge case requires unclear S7 mutation | ✅ Applied — `modifyList()` pattern specified |
| 6 | `survey_nonprob` with repweights not tested in diagnostic functions | ⚠️ Intentionally deferred — paths are unchanged; tests would verify surveycore behavior, not surveywts logic |

**Pass 2 verdict: PASS** — All REQUIRED issues resolved. Spec is ready for implementation.

---

### New Issues

#### Section: Function contracts — `trim_weights()` and `stabilize_weights()` documentation

**Issue 1: Builder not told to update existing `@description` text**
Severity: REQUIRED
Violates testing-standards.md §Contract Completeness; the builder will produce a stale description.

Both `trim_weights.R` and `stabilize_weights.R` currently have `@description` text that reads "Applies to main weights and — for `survey_replicate` input — all replicate weight columns." The spec says to add a `@section Replicate Weights:` block and update `@param data`, but says nothing about the existing description sentence. The builder will read the spec and add the new section while leaving the description referencing `survey_replicate` only.

Options:
- **[A]** Add an explicit instruction to the spec: "The `@description` sentence 'Applies to main weights and — for `survey_replicate` input — all replicate weight columns' must be updated to include `survey_nonprob` with repweights: e.g., 'Applies to main weights and — for inputs that carry replicate weight columns (`survey_replicate` or `survey_nonprob` with `repweights`) — all replicate columns.'" — Effort: low, Risk: low, Impact: builder produces correct docs, Maintenance: none
- **[B]** Trust the builder to notice. — Effort: none, Risk: medium (description text is easy to overlook), Impact: stale docs
- **[C] Do nothing** — Builder ships with outdated `@description`

**Recommendation: A** — It's a two-sentence addition to the spec; the risk of the builder missing it is real.

---

#### Section: Test-spec — `trim_weights()` / `stabilize_weights()` weighting history

**Issue 2: Weighting history not tested for nonprob-with-repweights path**
Severity: REQUIRED
Violates testing-standards.md §Conditional categories — "Weighting history — required for any function that modifies or carries forward `weighting_history`".

The spec Behavior Rule 8 (trim_weights) and Behavior Rule 8 (stabilize_weights) state "history entry is appended regardless of input class." The test-spec has no test block confirming a history entry is appended when the input is a `survey_nonprob` with repweights. The existing test suite covers `survey_replicate` history, but the new path is new code and must be independently tested.

Options:
- **[A]** Add a test block to the test-spec for each function: after applying the function to `nonprob_rep`, assert that `length(result@metadata@weighting_history) == 1` and `result@metadata@weighting_history[[1]]$operation` equals `"trim_weights"` (or `"stabilize_weights"`). — Effort: low, Risk: low, Impact: history correctness covered, Maintenance: none
- **[B] Do nothing** — History bug could go undetected

**Recommendation: A**

---

#### Section: Test-spec — `trim_weights()` edge case absent from test plan

**Issue 3: "Main weights within bounds but replicate values outside" edge case untested**
Severity: REQUIRED

The spec's edge cases table for `trim_weights()` explicitly includes:

> "Main weights within bounds but some replicate values outside → Main weights unchanged (warning fires for main), replicate columns still clipped"

This is an observable behavioral contract (the `surveywts_warning_no_weights_trimmed` warning fires for main weights, but replicate columns are still modified). The test-spec does not include a test for this scenario. A builder implementing this correctly would have no coverage for the case where main-weight trimming is a no-op but replicate trimming is not.

Options:
- **[A]** Add a test block: construct a `nonprob_rep` where all main weights fall within an explicit `[lower_abs, upper_abs]` but some replicate column values do not. Assert (1) `expect_warning(class = "surveywts_warning_no_weights_trimmed")`, (2) main weights unchanged, (3) at least one replicate column value changed. — Effort: low, Risk: low, Impact: important behavioral divergence covered
- **[B] Do nothing** — This path is uncovered; silent regressions possible

**Recommendation: A**

---

#### Section: Test-spec — nonprob-without-repweights fixture

**Issue 4: `survey_nonprob` without-repweights fixture uses wrong `@variables` keys**
Severity: REQUIRED
Violates surveywts-conventions.md §6 (S7 Classes — `survey_nonprob` variables).

The test-spec's "variant without repweights" constructs:
```r
nonprob_norep <- surveycore::survey_nonprob(
  data      = make_surveywts_data(n = 200, seed = <seed>),
  variables = list(ids = NULL, strata = NULL, fpc = NULL,
                   weights = "base_weight", nest = FALSE),
  ...
)
```

`ids`, `strata`, `fpc`, and `nest` are `survey_taylor` design variables, not `survey_nonprob` design variables. `survey_nonprob@variables` should have `weights`, `repweights`, `type`, `scale`, `rscales`, `mse`, `probs_provided`. Passing incorrect keys (a) is misleading, (b) could trigger silent errors if surveycore adds validation in the future, and (c) produces a non-representative fixture that doesn't reflect what `as_survey_nonprob()` actually constructs.

The test-spec should use the public constructor:
```r
nonprob_norep <- surveycore::as_survey_nonprob(
  make_surveywts_data(n = 200, seed = <seed>),
  weights = base_weight
)
```

Options:
- **[A]** Replace the low-level constructor call with `as_survey_nonprob()` in the test-spec. — Effort: low, Risk: low, Impact: fixture matches real-world objects, Maintenance: none
- **[B] Do nothing** — Fixture works now but is wrong and fragile

**Recommendation: A**

---

#### Section: Test-spec — `.has_repweights()` edge case — character(0) mutation

**Issue 5: `character(0)` repweights edge case requires unclear S7 mutation**
Severity: SUGGESTION
Violates testing-standards.md §4 (edge case data should be inline and self-documenting).

The test-spec says to test `.has_repweights()` with a `survey_nonprob` that has `repweights = character(0)` by "manually set[ting] `@variables$repweights <- character(0)`". In S7, you cannot index-assign into a property with `obj@variables$repweights <- x` — you must replace the whole list: `obj@variables <- modifyList(obj@variables, list(repweights = character(0)))`. The test-spec should specify the correct mutation pattern so the builder doesn't write broken setup code.

Options:
- **[A]** Add the correct mutation pattern to the test-spec: `obj@variables <- modifyList(obj@variables, list(repweights = character(0)))`. — Effort: low, Risk: low
- **[B] Do nothing** — Builder probably figures it out; not a correctness issue

**Recommendation: A** — Single-line fix; removes ambiguity for the tester.

---

#### Section: Test-spec — Diagnostic functions

**Issue 6: `survey_nonprob` with repweights not tested in diagnostic functions**
Severity: SUGGESTION

The test-spec covers `survey_replicate` acceptance for all three diagnostic functions but has no tests for `survey_nonprob` with repweights. `survey_nonprob` (regardless of repweights) was already accepted before this change — so strictly speaking, these tests aren't needed to verify the current PR's changes. However, adding one smoke test per function that passes a `nonprob_rep` fixture would close any doubt that the `.diag_validate_input()` path works for the combination.

Options:
- **[A]** Add one `expect_no_error()` test per diagnostic function with the `nonprob_rep` fixture. — Effort: low, Risk: low
- **[B] Do nothing** — These paths already work; adding tests is optional

**Recommendation: B** — These paths are unchanged; the test would be testing surveycore behavior, not surveywts logic. Omit.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 6

**Overall assessment:** The spec is nearly implementable — the behavioral contracts are precise and the predicate design is clean. Four REQUIRED issues must be resolved before coding begins: the missing `@description` update instruction (builder will ship stale docs), two missing test blocks (history correctness, main-within-bounds-rep-outside edge case), and the incorrect fixture constructor in the test-spec.
