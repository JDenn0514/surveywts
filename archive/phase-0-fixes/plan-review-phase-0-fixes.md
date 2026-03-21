# Plan Review: phase-0-fixes

## Pass 1 (2026-03-18)

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — Utils Housekeeping

**Issue 1: `.get_history()` class check not updated to `survey_base`**
Severity: SUGGESTION
Inconsistency with Change 3's future-proofing pattern.

PR 1 moves `.get_history()` to utils.R and inlines `%||%`, but leaves the class
check as `S7::S7_inherits(x, surveycore::survey_taylor) || S7::S7_inherits(x, surveycore::survey_nonprob)`.
PR 2 updates `.check_input_class()` and `.diag_validate_input()` to use
`surveycore::survey_base`, but `.get_history()` is not mentioned.

The spec (Change 3) only requires updating `.check_input_class()` and
`.diag_validate_input()`, so this is spec-compliant. But all three functions
have the same pattern, and `.get_history()` accesses `@metadata@weighting_history`
which is defined on `survey_base`.

Options:
- **[A]** Add `.get_history()` update to PR 2 (alongside the other `survey_base`
  changes). — Effort: low, Risk: low, Impact: consistency across all class checks
- **[B] Do nothing** — spec-compliant; inconsistency is cosmetic until a new
  survey class is added

**Recommendation: A** — Low effort, eliminates a future bug when a new
`survey_base` subclass is added.

---

#### Section: PR 2 — Input Validation Modernization

No new issues found.

---

#### Section: PR 3 — Diagnostics & Cosmetic Fixes

**Issue 2: `summarize_weights()` grouped path row ordering changes**
Severity: SUGGESTION
Potential test regression not mentioned in plan.

The current code uses `data_df[[by_names]]` (preserves factor level order) for
single variables, and `interaction()` for multiple variables. The replacement
uses `paste(sep = "//")` + `split()` for all cases. `split()` on character
keys produces alphabetical order, not factor-level order.

If any existing `summarize_weights()` tests assert specific row order (e.g.,
factor level order like `"18-34"`, `"35-54"`, `"55+"` rather than alphabetical
`"18-34"`, `"35-54"`, `"55+"`), they will still pass for this example. But
groups like `c("B", "A", "C")` would change from factor order to alphabetical.

Options:
- **[A]** Note the ordering change in the plan and add explicit `arrange()` or
  `match()` if factor-level ordering is desired. — Effort: low, Risk: low
- **[B] Do nothing** — the spec doesn't specify row ordering; fix tests if
  they break

**Recommendation: B** — The spec doesn't mandate order, and the implementer
will discover any failures during the test run. Worth a heads-up comment in
the plan though.

---

#### Section: PR 4 — Poststratify Default Type

**Issue 3: Missing NEWS.md or changelog entry for breaking API change**
Severity: REQUIRED
`poststratify()` default changing from `"count"` to `"prop"` is user-visible.

PR 4 changes the default `type` argument from `"count"` to `"prop"`. This is a
breaking API change — any user calling `poststratify()` without `type =` and
passing count-based population data will get a validation error. The plan's
Notes section says "This is an API change. Pre-CRAN semver allows it without
deprecation." but does not include a NEWS.md entry.

PR 6 includes a NEWS.md entry for its breaking change. PR 4 should do the same.

Options:
- **[A]** Add a NEWS.md entry to PR 4 acceptance criteria:
  ```
  * `poststratify()` now defaults to `type = "prop"`, consistent with
    `calibrate()` and `rake()`. Existing code that relies on the count default
    should add explicit `type = "count"`.
  ```
  Effort: low, Risk: low, Impact: users upgrading know about the change
- **[B] Do nothing** — pre-CRAN package, no external users yet

**Recommendation: A** — A single NEWS.md line is minimal effort and establishes
good release hygiene. Even pre-CRAN, the breaking-change section documents
intent for when the package is eventually published.

---

#### Section: PR 5 — Vendor Delegation

**Issue 4: `calibration_spec` format insufficient for poststratify delegation**
Severity: BLOCKING
Plan step 18 cannot be implemented without modifying `calibration_spec`.

The current `calibration_spec` for poststratify is:
```r
list(type = "poststratify", cells = list(list(indices = <int>, target = <num>), ...))
```

`survey::postStratify()` requires:
- A formula: `~var1 + var2` (needs strata column names)
- A population data frame with strata columns + `Freq` column (needs strata
  names and per-cell targets keyed by factor levels, not row indices)

Neither `strata_names` nor the original `population` data frame is available
inside `.calibrate_engine()`. The `cells` structure only has row indices and
target counts — these cannot be reverse-mapped to factor levels without the
original column names.

Options:
- **[A]** Enrich `calibration_spec` for poststratify: add `strata_names` and
  `population` (the original population data frame with strata columns + target)
  to `calibration_spec`. The engine builds the formula and renames `target` →
  `Freq`. — Effort: low, Risk: low, Impact: clean delegation
- **[B]** Have `poststratify()` call `survey::postStratify()` directly,
  bypassing `.calibrate_engine()` entirely. — Effort: medium, Risk: medium
  (architectural change), Impact: poststratify no longer uses the shared engine
- **[C] Do nothing** — step 18 cannot be implemented as written

**Recommendation: A** — Minimal change. The calling function
(`poststratify.R` lines 202-205) already has `strata_names` and `population`
in scope — pass them through `calibration_spec`:
```r
calibration_spec <- list(
  type = "poststratify",
  cells = cells,           # retained for the pre-validation guard
  strata_names = strata_names,
  population = population  # data frame with strata cols + "target"
)
```
The engine renames `target` → `Freq` and builds the formula from `strata_names`.

**Issue 5: `.throw_not_converged()` and `.throw_not_converged_zero_maxit()` disposition deferred**
Severity: REQUIRED
Plan Notes section says "evaluate during implementation" — not sufficient.

After the engine rewrite, the vendored code paths that called
`.throw_not_converged()` (lines 650, 689, 738) no longer exist. The delegation
paths use different convergence detection mechanisms:
- Logit/IPF: `withCallingHandlers()` intercepting warnings → throw typed error directly
- Anesrake: `$converge == FALSE` → throw typed error directly

The plan describes throwing `surveywts_error_calibration_not_converged` in
each delegation path but doesn't specify whether the existing helper functions
are reused, replaced, or deleted.

The `maxit = 0` fast-fail at line 616 still calls
`.throw_not_converged_zero_maxit()`, so that helper must be kept. But
`.throw_not_converged()` (lines 834-895) may be dead code after the rewrite.

Options:
- **[A]** Keep `.throw_not_converged_zero_maxit()` for the `maxit = 0` guard.
  Delete `.throw_not_converged()` after verifying no remaining callers.
  Delegation paths throw typed errors inline. — Effort: low, Risk: low
- **[B]** Refactor `.throw_not_converged()` to accept delegation-specific
  context (warning text from `survey`, converge flag from `anesrake`) and
  reuse it from all paths. — Effort: medium, Risk: low
- **[C] Do nothing** — dead code remains; implementer figures it out

**Recommendation: A** — The new delegation paths have different convergence
signals (warnings vs boolean flag), so a single helper wouldn't simplify much.
Delete the unused one and keep the `maxit = 0` helper.

**Issue 6: `survey::calibrate()` contrast mechanism ambiguous**
Severity: SUGGESTION
Plan text says "with `contrasts.arg = list(...)`" but `survey::calibrate()`
doesn't accept a `contrasts.arg` parameter.

Plan step 15 (inherited from spec §II) describes building the formula with
`contrasts.arg`. But `contrasts.arg` is a parameter of `model.matrix()`, not
`survey::calibrate()`. The actual mechanism is:

```r
# Set contrasts on the factor columns in data_df BEFORE building svydesign
data_df[[var]] <- factor(data_df[[var]], levels = level_names)
contrasts(data_df[[var]]) <- contr.treatment(length(level_names), contrasts = FALSE)

# Then the formula ~var1 + var2 - 1 produces full indicator encoding
svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)
```

Options:
- **[A]** Clarify step 15: "Set `contrasts()` on each factor column in
  `data_df` to `contr.treatment(..., contrasts = FALSE)` before constructing
  the svydesign. The formula `~var1 + var2 - 1` then produces full indicator
  columns." — Effort: low, Risk: low
- **[B] Do nothing** — implementer will discover the correct mechanism

**Recommendation: A** — Prevents a false start during implementation.

**Issue 7: Test comments referencing vendored code may need updating**
Severity: SUGGESTION

Step 24 says to delete unit tests for vendored internals, but the only
reference found is a comment in `test-02-calibrate.R:802`:
```
# Covers vendor-calibrate-greg.R lines 128-130 and 182 (.greg_logit only):
```
This is a comment in a test that tests *public API behavior* (not the vendored
internal). The test itself should be kept; only the comment needs updating to
reference the new delegation path.

Options:
- **[A]** Add "Update comments referencing vendored files in test files" to
  step 24. — Effort: low, Risk: low
- **[B] Do nothing** — stale comments are harmless

**Recommendation: A** — A stale reference to a deleted file is confusing.

---

#### Section: PR 6 — Nonresponse Zero Weights

No new issues found.

---

#### Section: Quality Gates

**Issue 8: 98% coverage criterion missing from individual PR acceptance criteria**
Severity: REQUIRED
Quality Gates section (line 750) says "98%+ line coverage maintained (every PR)"
but no individual PR acceptance criteria list includes this.

The Quality Gates section at the bottom of the plan correctly states the
requirement, but each PR's acceptance criteria checklist is the actionable
reference during implementation. An implementer working through PR 3, for
example, would see the PR 3 criteria and not cross-reference the Quality Gates.

Options:
- **[A]** Add `- [ ] 98%+ line coverage maintained` to every PR's acceptance
  criteria. — Effort: low, Risk: low, Impact: each PR is self-contained
- **[B] Do nothing** — Quality Gates section exists; implementer should read it

**Recommendation: A** — Each PR should be independently implementable from its
own section. The five-second fix prevents a coverage regression.

---

#### Section: Dependency Graph

No issues found.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 3 |
| SUGGESTION | 4 |

**Total issues:** 8

**Overall assessment:** The plan is well-structured with clear TDD ordering,
correct dependency sequencing, and thorough spec coverage. The one blocking
issue (poststratify `calibration_spec` gap) has a straightforward fix — enrich
the spec with strata names and population data. After resolving that and the
three required issues, the plan is ready to implement.

---

## Resolution (2026-03-18)

All 8 issues resolved. Decisions:

| Issue | Resolution |
|---|---|
| 1 — `.get_history()` survey_base | **A** — Added to PR 2 |
| 2 — Row ordering | **A** — Preserve first-occurrence order |
| 3 — NEWS.md for PR 4 | **A** — Added NEWS.md step + criterion |
| 4 — calibration_spec poststratify (BLOCKING) | **A** — Enriched with strata_names + population |
| 5 — .throw_not_converged() disposition | **A** — Delete after verifying; keep zero_maxit |
| 6 — Contrast mechanism | **A** — Clarified step 15 |
| 7 — Stale vendor comments | **A** — Added to cleanup step 25 |
| 8 — 98% coverage per PR | **A** — Added to all 6 PRs |

Plan approved. Decisions logged in `plans/decisions-phase-0-fixes.md`.
